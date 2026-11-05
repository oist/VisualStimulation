"""Full-window, static Gaussian noise with configurable pixel blocks.

Precompute "repeats" independent images for each mean before the start
trigger. Every mean appears "repeats" times in one shuffled trial sequence.
Each precomputed image is shown exactly once. Each trial shows
background_brightness for "t1", then holds its image for "t2".
Samples use the requested mean and sigma before clipping to [-1, 1]; clipping
can change the displayed mean and standard deviation.

Each reduced-resolution image is enlarged without interpolation, giving one
independent sample per pixel block across the entire window. The "binning"
parameter accepts only "2x2", "4x4", or "8x8" (default "2x2"). Window dimensions
must be divisible by the selected block size.
The background is also shown during sleep_before and sleep_after.
Channel 1 pulses at noise onset; channel 3 pulses after sleep_after.
Start on a channel 2 DLP trigger or any key other than Escape, then wait
sleep_before. With com_port=None, wait for a key. Escape ends the session,
including during waits.
Set seed to an integer to reproduce both the image pools and trial sequence.
CSV columns are trial, repeat, mean, sigma; session details remain in the raw log.
"""
import csv
import numpy as np
import os
from contextlib import ExitStack
from datetime import datetime
import time
from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class GaussianNoiseParams:
    t1: float = 2.0
    t2: float = 2.0
    background_brightness: float = -1.0
    mean_values: List[float] = field(default_factory=lambda: [-0.5, 0.0, 0.5])
    sigma: float = 0.2
    repeats: int = 10  # Images generated and presented once for EACH mean.
    sleep_before: float = 5.0
    sleep_after: float = 5.0
    seed: Optional[int] = None
    binning: str = "2x2"  # Allowed values: "2x2", "4x4", "8x8".


def get_bin_size(binning):
    """Validate the binning option and return the block width/height in pixels."""
    if not isinstance(binning, str) or binning not in ('2x2', '4x4', '8x8'):
        raise ValueError('binning must be "2x2", "4x4", or "8x8".')
    return int(binning[0])


def validate_params(p):
    get_bin_size(p.binning)
    means = np.asarray(p.mean_values, dtype=float)
    if (means.ndim != 1 or means.size == 0 or
            not np.all(np.isfinite(means)) or np.any(np.abs(means) > 1)):
        raise ValueError("mean_values must be a nonempty list of finite values in [-1, 1].")
    if len(np.unique(means)) != len(means):
        raise ValueError("mean_values must contain unique values.")
    if (not np.isscalar(p.background_brightness) or
            not np.isfinite(p.background_brightness) or
            not -1 <= p.background_brightness <= 1):
        raise ValueError("background_brightness must be a finite scalar in [-1, 1].")
    if not np.isfinite(p.sigma) or p.sigma < 0:
        raise ValueError("sigma must be nonnegative and finite.")
    for name in ('t1', 'sleep_before', 'sleep_after'):
        value = getattr(p, name)
        if not np.isfinite(value) or value < 0:
            raise ValueError(f"{name} must be nonnegative and finite.")
    if not np.isfinite(p.t2) or p.t2 <= 0:
        raise ValueError("t2 must be positive and finite.")
    if (isinstance(p.repeats, bool) or
            not isinstance(p.repeats, (int, np.integer)) or p.repeats < 1):
        raise ValueError("repeats must be a positive integer.")
    if p.seed is not None and (isinstance(p.seed, bool) or
                              not isinstance(p.seed, (int, np.integer)) or p.seed < 0):
        raise ValueError("seed must be None or a nonnegative integer.")


def make_noise_pool(p, window_size, rng):
    """Return float32 arrays shaped (repeats, height/bin, width/bin)."""
    bin_size = get_bin_size(p.binning)
    size = np.asarray(window_size)
    if (size.shape != (2,) or not np.all(np.isfinite(size)) or
            np.any(size <= 0) or np.any(size % bin_size != 0)):
        raise ValueError(f"Window width and height must be positive pixel counts "
                         f"divisible by {bin_size} for {p.binning} binning.")
    width, height = map(int, size)
    pools = []
    for mean in p.mean_values:
        samples = rng.normal(mean, p.sigma,
                             (p.repeats, height // bin_size, width // bin_size))
        np.clip(samples, -1.0, 1.0, out=samples)
        pools.append(samples.astype(np.float32))
    return pools


def make_trial_sequence(p, rng):
    """Shuffle all (condition_id, image_id) pairs, presenting every image once."""
    trials = [(condition, image) for condition in range(len(p.mean_values))
              for image in range(p.repeats)]
    return [trials[int(index)] for index in rng.permutation(len(trials))]


def finish_dlp(dlp, finished):
    """Reset TTL outputs and pulse channel 3 only after a completed session."""
    try:
        dlp.write(b'Q')  # Channel 1 LOW.
        if finished:
            dlp.write(b'3')  # Channel 3 HIGH after the final sleep.
            time.sleep(0.1)
    finally:
        dlp.write(b'E')  # Always attempt to leave channel 3 LOW.


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port):
    validate_params(p)
    from psychopy import visual, core, event, logging

    # Record the actual seed even when a fresh random session was requested.
    seed = int(np.random.SeedSequence(p.seed).entropy)
    rng = np.random.default_rng(seed)
    dlp = None
    win = None
    csv_file = None
    log_file = None
    finished = False

    try:
        os.makedirs(logdir, exist_ok=True)
        dt_string = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_filename_raw = os.path.join(logdir, f"log_{exp_name}_{dt_string}_raw")
        log_filename = os.path.join(logdir, f"log_{exp_name}_{dt_string}.csv")
        log_file = logging.LogFile(log_filename_raw, level=logging.EXP)
        csv_file = open(log_filename, 'x', newline='', encoding='utf-8')
        csv_writer = csv.writer(csv_file)
        csv_writer.writerow(['trial', 'repeat', 'mean', 'sigma'])
        csv_file.flush()
        logging.exp(f"Gaussian noise: parameters={p}, actual_seed={seed}, numpy={np.__version__}")

        if com_port is not None:
            from serial import Serial
            dlp = Serial(port=com_port, baudrate=115200, timeout=0.05)
            dlp.write(b'Q')  # Initialize channel 1 LOW.
            dlp.write(b'E')  # Initialize channel 3 LOW.

        win = visual.Window(
            monitor=monitor_name, size=[1280, 720], screen=screen_idx,
            fullscr=False, units='pix', color=[p.background_brightness] * 3,
            colorSpace='rgb', allowGUI=False, waitBlanking=True,
        )
        win.flip()
        clock = core.Clock()

        def check_abort():
            if 'escape' in event.getKeys(keyList=['escape']):
                raise StopIteration

        def wait_with_abort(duration):
            clock.reset()
            while clock.getTime() < duration:
                check_abort()
                time.sleep(0.01)

        print(f"Precomputing {p.repeats} noise images per mean...")
        pools = make_noise_pool(p, win.size, rng)
        sequence = make_trial_sequence(p, rng)
        # Upload all textures before the start trigger, avoiding trial-time uploads.
        stimuli = []
        for pool in pools:
            condition_stimuli = []
            for image in pool:
                check_abort()
                condition_stimuli.append(visual.ImageStim(
                    win, image=image, size=win.size, pos=(0, 0), units='pix',
                    color=(1, 1, 1), colorSpace='rgb', contrast=1,
                    interpolate=False, autoLog=False,
                ))
            stimuli.append(condition_stimuli)
        logging.exp(f"Noise pools ready: window_size={list(win.size)}, binning={p.binning}")
        occurrences = np.zeros(len(p.mean_values), dtype=int)

        print("Waiting for a start key or DLP trigger (Escape aborts)...")
        while True:
            keys = event.getKeys()
            if 'escape' in keys:
                raise StopIteration
            if keys:
                logging.exp("Session started by keyboard.")
                break
            if dlp is not None:
                dlp.write(b'S')  # Listen to channel 2.
                if dlp.read(3).startswith(b'1'):
                    logging.exp("Session started by DLP trigger.")
                    break
            time.sleep(0.01)
        wait_with_abort(p.sleep_before)

        for trial_num, (condition_id, image_id) in enumerate(sequence, start=1):
            mean = p.mean_values[condition_id]
            rep = int(occurrences[condition_id])
            stim = stimuli[condition_id][image_id]
            logging.exp(f"Trial {trial_num}: condition={condition_id}, mean={mean:g}, "
                        f"sigma={p.sigma:g}, image_id={image_id}")

            # t1=0 skips the blank entirely, as in the grid sweep script.
            clock.reset()
            while clock.getTime() < p.t1:
                check_abort()
                win.flip()

            clock.reset()
            first_frame = True
            while first_frame or clock.getTime() < p.t2:
                check_abort()
                if dlp is not None:
                    dlp.write(b'1' if first_frame else b'Q')
                stim.draw()
                win.flip()
                first_frame = False

            if dlp is not None:
                dlp.write(b'Q')  # Also end the pulse for a one-frame stimulus.

            occurrences[condition_id] += 1
            csv_writer.writerow([trial_num, rep, mean, p.sigma])
            csv_file.flush()
            print(f"  Trial {trial_num}/{len(sequence)}: mean={mean:g}, "
                  f"image={image_id}, repeat={rep + 1}/{p.repeats}")

        win.flip()  # Remove the last noise image before the final sleep.
        wait_with_abort(p.sleep_after)
        finished = True
    except StopIteration:
        logging.exp("Session stopped with Escape.")
    finally:
        # Callbacks run in reverse order, even if another cleanup step fails:
        # finish TTLs, close serial, close CSV, flush logs, close the window.
        with ExitStack() as cleanup:
            if win is not None:
                cleanup.callback(win.close)
            if log_file is not None:
                cleanup.callback(logging.flush)
            if csv_file is not None:
                cleanup.callback(csv_file.close)
            if dlp is not None:
                cleanup.callback(dlp.close)
                cleanup.callback(finish_dlp, dlp, finished)

            # Blank the display before running the registered cleanup steps.
            if win is not None:
                win.flip()


if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "gaussian_noise"
    logdir = "logs"
    p = GaussianNoiseParams(
        t1=0.2,
        t2=0.2,
        background_brightness=-1.0,
        mean_values=[-0.5, 0.0, 0.5],
        sigma=0.5,
        repeats=100,  # Generate this many images per mean; present each once.
        binning="4x4",  # Choose "2x2", "4x4", or "8x8".
        sleep_before=5.0,
        sleep_after=5.0,
        seed=None,  # Set to an integer for a reproducible session.
    )
    monitor_name = "test"
    screen_idx = 0
    com_port = None  # Set e.g. "COM3" to enable DLP communication and TTL pulses.
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port)
