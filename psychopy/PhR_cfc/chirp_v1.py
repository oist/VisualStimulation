"""Rectangular chirp stimulus based on tomo/main_chirp_stimuli.py.

stim_size sets (width, height) in pixels. stim_pos sets the rectangle's
center (x, y) in pixels relative to the window center; positive x is right
and positive y is up. The area outside the rectangle stays black.

Each repeat presents t1 black, t2 white, t3 black, t4 gray,
t5 frequency chirp, and t7 black. The chirp retains the original
90-degree phase, evaluated using elapsed time within t5.
Timing, serial triggering, logging, and
session cleanup follow main_grid_sweep_v2.py. Channel 1 pulses at the
start of t2 and t5 using the reference's first-frame TTL scheme.
Set com_port=None to run without a DLP device; use a key to start.
Key bindings during all stimulus phases:
    Escape (or Q): end session
    1 / 2        : increase / decrease width and height by 5 pixels (minimum 5)
    3 / 4        : increase / decrease center x by 5 pixels
    5 / 6        : increase / decrease center y by 5 pixels
Adjustments persist across repeats. Trial rows record the final size and
position; individual adjustments are recorded in the raw log.
"""
from psychopy import visual, core, event, data, logging
from scipy import signal
import os
from datetime import datetime
import time
from dataclasses import dataclass
from typing import Tuple


@dataclass
class ChirpParams:
    f0: float = 0.5  # Frequency at the start of t5 (Hz).
    f1: float = 10.0  # Frequency at the end of t5 (Hz).
    method: str = "logarithmic"
    repeats: int = 50
    t1: float = 2.0  # Black.
    t2: float = 4.0  # White.
    t3: float = 4.0  # Black.
    t4: float = 2.0  # Gray.
    t5: float = 8.0  # Frequency chirp.
    t7: float = 1.0  # Black.
    stim_size: Tuple[float, float] = (1280, 720)  # Width, height (pix).
    stim_pos: Tuple[float, float] = (0, 0)  # Center x, y (pix).
    sleep_before: float = 5.0
    sleep_after: float = 10.0


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off):
    dlp = None
    if com_port is not None:
        from serial import Serial
        dlp = Serial(port=com_port, baudrate=115200)
        dlp.write(code_off)

    now = datetime.now()
    dt_string = now.strftime("%Y%m%d_%H%M%S")
    log_filename_raw = os.path.join(logdir, f"log_{exp_name}_{dt_string}_raw")
    log_filename = os.path.join(logdir, f"log_{exp_name}_{dt_string}")
    log_file = logging.LogFile(log_filename_raw, level=logging.EXP)
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                         extraInfo={},
                                         runtimeInfo=None,
                                         dataFileName=log_filename,
                                         saveWideText=True,
                                         savePickle=False)

    win = visual.Window(monitor=monitor_name, size=[1280, 720], screen=screen_idx,
                        units='pix', color=[-1, -1, -1], allowGUI=False, waitBlanking=True)

    rect = visual.Rect(win=win, size=p.stim_size, pos=p.stim_pos,
                       units='pix', fillColor=-1, lineColor=None)

    trial_num = 0
    clock = core.Clock()

    phases = [
        ('t1', p.t1, -1),
        ('t2', p.t2, 1),
        ('t3', p.t3, -1),
        ('t4', p.t4, 0),
        ('t5', p.t5, None),
        ('t7', p.t7, -1),
    ]

    # Wait for TTL HIGH in channel 2 (if connected) or keyboard input.
    while True:
        if dlp is not None:
            dlp.write(b'S')
            x = dlp.read(3).decode('utf-8')
            if x[0] == '1':
                break
        keys = event.getKeys()
        if keys:
            break

    time.sleep(p.sleep_before)

    try:
        for rep in range(p.repeats):
            trial_num += 1
            event.clearEvents()

            for phase, duration, level in phases:
                clock.reset()
                first_frame = True
                while clock.getTime() < duration:
                    keys = event.getKeys(keyList=['escape', 'q', '1', '2', '3', '4', '5', '6'])
                    if any(key in ['escape', 'q'] for key in keys):
                        raise StopIteration
                    for key in keys:
                        delta = 5 if key in ('1', '3', '5') else -5
                        if key in ('1', '2'):
                            p.stim_size = tuple(max(5, size + delta) for size in p.stim_size)
                        elif key in ('3', '4'):
                            p.stim_pos = (p.stim_pos[0] + delta, p.stim_pos[1])
                        elif key in ('5', '6'):
                            p.stim_pos = (p.stim_pos[0], p.stim_pos[1] + delta)
                        logging.exp(
                            f"Trial {trial_num}: key={key}, "
                            f"stim_size={p.stim_size}, stim_pos={p.stim_pos}"
                        )
                    if keys:
                        rect.size = p.stim_size
                        rect.pos = p.stim_pos
                    if dlp is not None:
                        code = code_on if first_frame and phase in ('t2', 't5') else code_off
                        dlp.write(code)
                    first_frame = False

                    # Sweep frequency during t5; all other phases are uniform.
                    value = level
                    if phase == 't5':
                        value = float(signal.chirp(
                            clock.getTime(), f0=p.f0, f1=p.f1,
                            t1=p.t5, phi=90, method=p.method,
                        ))
                    rect.fillColor = (value, value, value)
                    rect.draw()
                    win.flip()

            exp_handler.addData('trial', trial_num)
            exp_handler.addData('repeat', rep)
            exp_handler.addData('stim_size', p.stim_size)
            exp_handler.addData('stim_pos', p.stim_pos)
            exp_handler.nextEntry()
            print(f"  Trial {trial_num}: repeat={rep + 1}/{p.repeats}")

    except StopIteration:
        pass

    # Return to black and reset the stimulus TTL.
    if dlp is not None:
        dlp.write(code_off)
    win.flip()

    time.sleep(p.sleep_after)

    exp_handler.close()

    # TTL to signal the end of the stimuli
    if dlp is not None:
        dlp.write(b'3')
        time.sleep(0.1)
        dlp.write(b'E')
        dlp.close()
    win.close()


if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "full_field_chirp"
    logdir = r"D:\experiments"
    p = ChirpParams(
        f0=0.5,
        f1=10,
        method="logarithmic",
        repeats=50,
        t1=2,
        t2=4,
        t3=4,
        t4=2,
        t5=8,
        t7=2,
        stim_size=(1280, 720),  # Width, height (pix).
        stim_pos=(0, 0),  # Center x, y relative to window center (pix).
        sleep_before=5.0,
        sleep_after=10.0,
    )
    monitor_name = "DLP3010EVM-LC"
    screen_idx = 0
    com_port = None  # Set to None to disable DLP communication and TTL pulses.
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
