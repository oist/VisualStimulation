"""Full-field flashes through configurable ND filters on a Thorlabs ELL18.

Edit the parameter block at the bottom, then run this script in PsychoPy's Python
environment. nd_filters is a list of {"position": angle_degrees, "ND": density}
dictionaries. nd_order selects ND values from these dictionaries, independent of
their list order. Each ND value and each physical position must be unique.
The default nd_order [1, 2, 1, 3, 2, 3, 1] visits each directed transition once.
A session is one entry in nd_order; the experiment is the entire nd_order sequence.
Every session independently shuffles all fg_values once per repeat.

Startup: show black, home the stage, wait for channel 2 HIGH, then sleep_before.
Each session: command its ND position, hold black for at least t3 seconds AND
until motion finishes, then present repeat blocks of (t1 black, t2 flash).
Normal completion: after ALL sessions in nd_order have finished, show black for
sleep_after ONCE, then pulse channel 3 for 100 ms. There is no sleep_after delay
or channel-3 pulse between ND sessions.
Escape: stop the experiment, return to black, and pulse channel 3 for 100 ms
without waiting for sleep_after. Escape during sleep_after ends that wait early
and sends the pulse. Logs are saved on both normal completion and Escape.
Channel 1 pulses for one display frame at each flash onset.
Hardware errors save logs and close resources without sending a completion pulse.
Set com_dlp=None to skip the start trigger and all DLP pulses; ELL18 is still used.

t1 and t2 use elapsed-time loops, with at least one flip per phase. Screen changes
occur on display refreshes; no refresh-rate measurement is needed. t3, sleep_before,
and sleep_after hold black continuously. A stage error or stage_timeout stops the experiment.
The driver installed as thorlabs_elliptec is used if available; otherwise the
repository's thorlabs_rotation/thorlabs_elliptec driver is loaded.

CSV: one row per displayed flash, including interrupted flashes (completed=False).
ND and position record the selected filter's density and configured angle (degrees);
actual_position records the angle reported by the stage after movement finishes.
session and trial are one-based; repeat and intensity_index are zero-based.
All *_s timestamps are seconds since initialization of this run's clock.
The raw log also records homing, the trigger, filter changes, and run status.
"""

from contextlib import ExitStack
from dataclasses import asdict, dataclass, field
from datetime import datetime
import math
from numbers import Real
from pathlib import Path
import random
import sys
import time
from typing import Dict, List, Optional


@dataclass
class FlashParams:
    fg_values: List[float] = field(default_factory=lambda: [
        -0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0,
    ])
    repeat: int = 1
    nd_order: List[float] = field(default_factory=lambda: [1, 2, 1, 3, 2, 3, 1])
    nd_filters: List[Dict[str, float]] = field(default_factory=lambda: [
        {"position": 0.0, "ND": 1},
        {"position": 90.0, "ND": 2},
        {"position": 180.0, "ND": 3},
    ])
    t1: float = 4.0
    t2: float = 4.0
    t3: float = 5.0
    sleep_before: float = 5.0
    sleep_after: float = 5.0
    stage_timeout: float = 60.0
    random_seed: Optional[int] = None


def validate_params(p):
    if isinstance(p.repeat, bool) or not isinstance(p.repeat, int) or p.repeat < 1:
        raise ValueError("repeat must be a positive integer.")
    if not p.fg_values or not all(math.isfinite(v) and -1 <= v <= 1
                                  for v in p.fg_values):
        raise ValueError("fg_values must contain finite PsychoPy RGB levels in [-1, 1].")
    if len(set(p.fg_values)) != len(p.fg_values):
        raise ValueError("fg_values must contain unique intensities.")
    if not p.nd_filters:
        raise ValueError("nd_filters must contain at least one filter dictionary.")
    for info in p.nd_filters:
        if not isinstance(info, dict) or not {"position", "ND"}.issubset(info):
            raise ValueError("Each nd_filters entry must have position and ND keys.")
        if any(isinstance(info[key], bool) or not isinstance(info[key], Real)
               or not math.isfinite(info[key]) for key in ("position", "ND")):
            raise ValueError("Filter position and ND must be finite numbers.")
        if info["ND"] < 0:
            raise ValueError("Filter ND values must be nonnegative.")
    nd_values = {info["ND"] for info in p.nd_filters}
    if len(nd_values) != len(p.nd_filters):
        raise ValueError("Each filter must have a unique ND value.")
    if len({info["position"] % 360 for info in p.nd_filters}) != len(p.nd_filters):
        raise ValueError("ND filters must have distinct positions modulo 360 degrees.")
    if not p.nd_order or any(isinstance(nd, bool) or not isinstance(nd, Real)
                             or nd not in nd_values for nd in p.nd_order):
        raise ValueError("nd_order must be a nonempty list of ND values defined in nd_filters.")
    for name in ("t1", "t2", "stage_timeout"):
        value = getattr(p, name)
        if not math.isfinite(value) or value <= 0:
            raise ValueError(f"{name} must be positive and finite.")
    for name in ("t3", "sleep_before", "sleep_after"):
        value = getattr(p, name)
        if not math.isfinite(value) or value < 0:
            raise ValueError(f"{name} must be nonnegative and finite.")
    if p.stage_timeout < p.t3:
        raise ValueError("stage_timeout must be at least t3.")


def load_stage_class():
    try:
        from thorlabs_elliptec import ELLx
    except ModuleNotFoundError as exc:
        if exc.name != "thorlabs_elliptec":
            raise  # Do not conceal a missing dependency of the installed driver.
        driver_dir = Path(__file__).resolve().parents[2] / "thorlabs_rotation"
        sys.path.insert(0, str(driver_dir))
        try:
            from thorlabs_elliptec import ELLx
        finally:
            sys.path.pop(0)
    return ELLx


class ExperimentAborted(Exception):
    """Escape was pressed during presentation or a wait."""


def main(p, exp_name, logdir, monitor_name="DLP3010EVM-LC", screen_idx=1,
         com_dlp="COM3", com_port_elliptec="COM4", fullscr=True):
    validate_params(p)
    positions_by_nd = {info["ND"]: info["position"] for info in p.nd_filters}
    if not com_port_elliptec:
        raise ValueError("com_port_elliptec must specify the ELL18 serial port.")
    if com_dlp is not None and com_dlp.upper() == com_port_elliptec.upper():
        raise ValueError("DLP and ELL18 must use different serial ports.")

    from psychopy import visual, core, event, data, logging
    ELLx = load_stage_class()

    rng = random.Random(p.random_seed)
    logdir = Path(logdir)
    logdir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    log_base = logdir / f"log_{exp_name}_{stamp}"
    metadata = asdict(p)
    metadata.update(monitor_name=monitor_name, screen_idx=screen_idx, fullscr=fullscr,
                    com_dlp=com_dlp, com_port_elliptec=com_port_elliptec,
                    background_brightness=-1.0)
    run_clock = core.Clock()
    clock = core.Clock()
    frame_counter = 0
    pending_trial = None
    dlp = None
    status = "initializing"

    def check_abort():
        if "escape" in event.getKeys(keyList=["escape"]):
            raise ExperimentAborted

    def wait_with_abort(duration):
        deadline = run_clock.getTime() + duration
        while run_clock.getTime() < deadline:
            check_abort()
            time.sleep(0.01)
        check_abort()

    def wait_for_stage(start_s, minimum=0.0):
        while True:
            check_abort()
            moving = stage.is_moving(raise_errors=True)
            elapsed = run_clock.getTime() - start_s
            if not moving and elapsed >= minimum:
                return
            if elapsed >= p.stage_timeout:
                raise TimeoutError(f"ELL18 did not finish within {p.stage_timeout:g} s.")
            time.sleep(0.01)

    # ExitStack attempts every cleanup even if another resource fails to close.
    with ExitStack() as resources:
        log_file = logging.LogFile(str(log_base) + "_raw.log", level=logging.EXP)
        resources.callback(logging.flush)
        exp_handler = data.ExperimentHandler(
            # Prefix configuration columns so e.g. the configured repeat count
            # cannot overwrite the per-trial repeat index in the CSV.
            name=exp_name, version="1",
            extraInfo={f"param_{key}": value for key, value in metadata.items()},
            runtimeInfo=None,
            dataFileName=str(log_base), saveWideText=True, savePickle=False,
        )
        resources.callback(exp_handler.close)
        logging.exp(f"Configuration: {metadata!r}")

        if com_dlp is not None:
            from serial import Serial
            dlp = Serial(port=com_dlp, baudrate=115200, timeout=0.5,
                         write_timeout=1.0)
            resources.callback(dlp.close)
            resources.callback(dlp.write, b'E')
            resources.callback(dlp.write, b'Q')
            dlp.write(b'Q')
            dlp.write(b'E')

        win = visual.Window(monitor=monitor_name, size=[1280, 720], screen=screen_idx,
                            fullscr=fullscr, units="pix", color=[-1, -1, -1],
                            colorSpace="rgb", allowGUI=False, waitBlanking=True)
        resources.callback(win.close)

        def flip(level, pulse=None, allow_abort=True):
            nonlocal frame_counter
            if allow_abort:
                check_abort()
            win.color = [level] * 3
            win.clearBuffer()
            marker = {}
            win.callOnFlip(lambda: marker.update(time=run_clock.getTime()))
            if dlp is not None and pulse is not None:
                win.callOnFlip(dlp.write, pulse)
            win.flip()
            frame_counter += 1
            return marker["time"]

        def finish_trial(offset_s, completed):
            nonlocal pending_trial
            if pending_trial is None:
                return
            row = pending_trial
            pending_trial = None
            row.update(flash_offset_s=offset_s,
                       actual_t2=offset_s - row["flash_onset_s"], completed=completed)
            for key, value in row.items():
                exp_handler.addData(key, value)
            exp_handler.nextEntry()
            print(f"Trial {row['trial']}/{total_trials}: session={row['session']}, "
                  f"ND{row['ND']}, position={row['position']:g}, "
                  f"repeat={row['repeat'] + 1}/{p.repeat}, "
                  f"fg={row['fg']:g}, completed={completed}")

        total_trials = len(p.nd_order) * p.repeat * len(p.fg_values)
        try:
            flip(-1)
            print(f"ND order: {p.nd_order}; {total_trials} flashes. Logs: {log_base}")

            stage = ELLx(serial_port=com_port_elliptec)
            resources.callback(stage.close)
            logging.exp(f"ELL18 connected on {com_port_elliptec}; homing")
            home_start = run_clock.getTime()
            stage.home()
            wait_for_stage(home_start)
            logging.exp(f"Homing complete at {run_clock.getTime():.6f} s; "
                        f"position={stage.get_position():g}")

            print("Waiting for channel 2 HIGH." if dlp is not None else "Starting without DLP.")
            while dlp is not None:
                check_abort()
                dlp.write(b'S')
                if dlp.read(3).startswith(b'1'):
                    break
            trigger_s = run_clock.getTime()
            logging.exp(f"Start {'trigger' if dlp is not None else 'automatic'} at {trigger_s:.6f} s")
            status = "running"
            wait_with_abort(p.sleep_before)

            trial = 0
            for session, nd in enumerate(p.nd_order, start=1):
                check_abort()
                position = positions_by_nd[nd]
                previous_nd = p.nd_order[session - 2] if session > 1 else None
                # Black is on the front buffer before every motor command.
                flip(-1, b'Q')
                rotation_start_s = run_clock.getTime()
                logging.exp(f"Session {session}: ND {previous_nd} -> {nd}, "
                            f"position={position:g}, rotation_start_s={rotation_start_s:.6f}")
                stage.move_absolute(position)
                wait_for_stage(rotation_start_s, minimum=p.t3)
                rotation_end_s = run_clock.getTime()
                actual_position = stage.get_position()
                logging.exp(f"Session {session}: stage ready at {rotation_end_s:.6f} s, "
                            f"ND={nd:g}, position={position:g}, actual_position={actual_position:g}")

                for rep in range(p.repeat):
                    indices = list(range(len(p.fg_values)))
                    rng.shuffle(indices)
                    for intensity_index in indices:
                        fg = p.fg_values[intensity_index]
                        # The first blank flip also ends the preceding flash. Log
                        # that trial while black is visible, without adding a frame.
                        clock.reset()
                        blank_onset_s = flip(-1, b'Q')
                        finish_trial(blank_onset_s, completed=True)
                        while clock.getTime() < p.t1:
                            flip(-1)

                        clock.reset()
                        flash_onset_s = flip(fg, b'1')
                        trial += 1
                        pending_trial = dict(
                            trial=trial, session=session, ND=nd, previous_nd=previous_nd,
                            position=position, actual_position=actual_position,
                            repeat=rep, intensity_index=intensity_index, fg=fg,
                            background_brightness=-1.0, frame=frame_counter,
                            trigger_s=trigger_s, rotation_start_s=rotation_start_s,
                            rotation_end_s=rotation_end_s,
                            rotation_wait_s=rotation_end_s - rotation_start_s,
                            blank_onset_s=blank_onset_s, flash_onset_s=flash_onset_s,
                            actual_t1=flash_onset_s - blank_onset_s,
                            t1=p.t1, t2=p.t2, t3=p.t3,
                        )
                        logging.exp(f"Trial {trial}: session={session}, ND={nd:g}, "
                                    f"position={position:g}, actual_position={actual_position:g}, fg={fg:g}, "
                                    f"flash_onset_s={flash_onset_s:.6f}")
                        while clock.getTime() < p.t2:
                            flip(fg, b'Q')

                # End the final flash before any waiting, logging, or filter motion.
                finish_trial(flip(-1, b'Q'), completed=True)
                logging.exp(f"Session {session} completed")

            wait_with_abort(p.sleep_after)
            status = "completed"
        except ExperimentAborted:
            status = "aborted"
        except BaseException:
            status = "error"
            logging.exp("Experiment failed; see the Python exception for details.")
            raise
        finally:
            # Cleanup bypasses Escape checks so that the screen always returns to black.
            # Keep the black flip/logging independent of a disconnected DLP device.
            offset_s = flip(-1, allow_abort=False)
            finish_trial(offset_s, completed=False)
            logging.exp(f"Run status={status}, end_s={run_clock.getTime():.6f}")
            if dlp is not None:
                dlp.write(b'Q')

        if dlp is not None:
            dlp.write(b'3')
            time.sleep(0.1)
            dlp.write(b'E')
        print(f"Experiment {status}. Logs: {log_base}.csv and {log_base}_raw.log")


if __name__ == "__main__":
    ###### PARAMETERS BEGIN ######
    exp_name = "nd_flash"
    logdir = str(Path(r"D:\experiments") / datetime.now().strftime("%Y%m%d"))
    p = FlashParams(
        fg_values=[-0.8, -0.6, -0.4, -0.2, 0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
        repeat=1,  # Number of shuffled full intensity sets in EACH ND session.
        nd_order=[1, 2, 1, 3, 2, 3, 1],  # ND values, not dictionary list indices.
        nd_filters=[
            {"position": 0.0, "ND": 1},
            {"position": 90.0, "ND": 2},
            {"position": 180.0, "ND": 3},
        ],
        t1=4.0,
        t2=4.0,
        t3=5.0,
        sleep_before=5.0,
        sleep_after=5.0,
        stage_timeout=60.0,
        random_seed=None,
    )
    monitor_name = "DLP3010EVM-LC"
    screen_idx = 1
    fullscr = True
    com_dlp = "COM3"  # None disables DLP communication and starts automatically.
    com_port_elliptec = "COM4"
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_dlp,
         com_port_elliptec, fullscr)
