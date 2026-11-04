"""
Grid spacing/background sweep with a random rotation on every trial.

Conditions are all (spacing_range, background_brightness) pairs. Each pair appears
`repeat` times. A randomized sequence balances directed transitions across the
whole session: off-diagonal counts differ by at most one, and identical conditions
never occur consecutively. There are no shuffled blocks. The terminal matrix counts
transitions between stimuli actually displayed, including an interrupted stimulus.
Rotation is independent of condition and is uniform in [0, 180) degrees per trial.
Both t1 (blank) and t2 (stimulus) use that trial's background; t1=0 skips the blank.

The grid fills the specified-size window and is centered in that window. Its extent is
calculated from the window size, smallest spacing, and transform, so every rotation
is covered. Circle centers are transformed: rotate -> shear -> scale.
For column vectors, A = S @ H @ R. Positive rotation is
counterclockwise. Shear is simultaneous; circle shapes and sizes are unchanged.
Trial rows record the rotation in theta_sampled and theta (identical columns retained
for log compatibility), along with the condition and transform.
Logged spacing is the shared base spacing before transformation. The repeat column
is the zero-based occurrence of that condition, not a shuffled-block index.
Channel 1 marks each stimulus onset; channel 3 marks the end of the experiment.
Set com_port=None to start automatically without a DLP device or TTL pulses.
Otherwise, wait for a TTL start trigger. Both modes then wait sleep_before seconds.

Key bindings:
    Escape      : end session

Parameters (SweepParams):
    t1                : blank screen duration (s)
    t2                : stimulus duration (s)
    diameter          : circle diameter (pix)
    background_brightness : background levels [-1, 1] swept for both t1 and t2
    circle_brightness : circle brightness [-1, 1]
    spacing_range     : discrete base spacing values (pix), shared by both axes before transformation
    sx, sy            : x and y scale factors applied after rotation and shear
    kx, ky            : simultaneous shear coefficients: x_new=x+kx*y, y_new=ky*x+y
    repeat            : number of times each (spacing, background) pair is shown
    sleep_before      : delay after the start trigger and before the trial sequence (s; 0 skips)
    sleep_after       : delay after the trial sequence and before cleanup/end TTL (s; 0 skips)
"""
import numpy as np
import os
from datetime import datetime
import time
from dataclasses import dataclass, field
from typing import List


@dataclass
class SweepParams:
    t1: float = 2.0
    t2: float = 2.0
    diameter: float = 10.0
    background_brightness: List[float] = field(default_factory=lambda: [-1.0, -0.8])
    circle_brightness: float = 1.0
    spacing_range: List[float] = field(default_factory=lambda: [50.0, 100.0, 150.0, 200.0])
    repeat: int = 10
    sx: float = 1.0
    sy: float = 1.0
    kx: float = 0.0
    ky: float = 0.0
    sleep_before: float = 5.0
    sleep_after: float = 5.0


def make_trial_sequence(n_conditions, repeat, rng):
    """Return condition indices with equal occurrences and balanced transitions.

    Build a directed graph with `repeat` incoming/outgoing edges per condition.
    Every off-diagonal edge gets q copies; r extra cyclic shifts distribute the
    remainder evenly. A randomized Euler circuit visits every edge once. Remove
    one closing edge (an extra edge when r > 0) to produce an open trial sequence.
    This preserves exactly `repeat` occurrences of each condition and the smallest
    possible spread in transition counts, even if repeat % (n_conditions - 1) != 0.
    """
    if not isinstance(n_conditions, (int, np.integer)) or n_conditions < 2:
        raise ValueError("At least two distinct conditions are required.")
    if not isinstance(repeat, (int, np.integer)) or repeat < 1:
        raise ValueError("repeat must be a positive integer.")
    q, r = divmod(repeat, n_conditions - 1)
    edges = np.full((n_conditions, n_conditions), q, dtype=int)
    np.fill_diagonal(edges, 0)
    order = rng.permutation(n_conditions)
    extra = np.zeros_like(edges, dtype=bool)
    for shift in range(1, r + 1):
        for i, source in enumerate(order):
            target = order[(i + shift) % n_conditions]
            edges[source, target] += 1
            extra[source, target] = True

    neighbors = [list(rng.permutation(np.repeat(np.arange(n_conditions), row)))
                 for row in edges]
    stack = [int(rng.integers(n_conditions))]
    circuit = []
    while stack:
        source = stack[-1]
        if neighbors[source]:
            stack.append(int(neighbors[source].pop()))
        else:
            circuit.append(stack.pop())
    circuit.reverse()
    # Choose the omitted edge, then start immediately after it around the circuit.
    candidates = [i for i in range(len(circuit) - 1)
                  if r == 0 or extra[circuit[i], circuit[i + 1]]]
    cut = int(rng.choice(candidates))
    cycle = circuit[:-1]
    return cycle[cut + 1:] + cycle[:cut + 1]


def print_transition_matrix(conditions, counts):
    """Print observed counts, with rows=previous and columns=next condition."""
    print("\nObserved stimulus transitions (rows=previous, columns=next):")
    for i, (spacing, background) in enumerate(conditions):
        print(f"  C{i}: spacing={spacing:g}, background={background:g}")
    width = max(6, len(str(int(counts.max()))) + 1,
                len(f"C{len(conditions) - 1}") + 1)
    print(" " * width + "".join(f"C{i}".rjust(width) for i in range(len(conditions))))
    for i, row in enumerate(counts):
        print(f"C{i}".rjust(width) + "".join(str(int(value)).rjust(width) for value in row))
    print(f"Total transitions: {counts.sum()}")


def make_grid_xys(window_size, spacing, diameter,
                  sx=1.0, sy=1.0, kx=0.0, ky=0.0):
    """Build an untransformed lattice covering the window after S @ H @ R.

    Expand the window by the circle radius, then undo scaling and shear. Enclose
    those corners in a disk: undoing any rotation leaves them within that disk.
    Keep all lattice points in this disk at the smallest spacing so every trial
    uses the same element count, including at larger spacings.
    """
    scaling = np.diag([sx, sy])
    shear = np.array([[1.0, kx], [ky, 1.0]])
    transform = scaling @ shear
    if not np.all(np.isfinite(transform)):
        raise ValueError("Grid scale and shear must be finite.")
    try:
        inverse = np.linalg.inv(transform)
    except np.linalg.LinAlgError as exc:
        raise ValueError("Grid scale/shear must be invertible to cover the screen.") from exc
    half_size = np.asarray(window_size) / 2 + diameter / 2
    corners = np.array([[-1, -1], [-1, 1], [1, -1], [1, 1]]) * half_size
    radius = np.max(np.linalg.norm(corners @ inverse.T, axis=1))
    limit = int(np.ceil(radius / spacing))
    x, y = np.meshgrid(np.arange(-limit, limit + 1), np.arange(-limit, limit + 1))
    xys = np.column_stack((x.ravel(), y.ravel())) * spacing
    return xys[np.linalg.norm(xys, axis=1) <= radius]


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port):
    from psychopy import visual, core, event, data, logging

    conditions = [(spacing, background) for spacing in p.spacing_range
                  for background in p.background_brightness]
    if len(set(conditions)) != len(conditions):
        raise ValueError("Spacing and background lists must contain unique values.")
    if not all(np.isfinite(spacing) and spacing > 0 and
               np.isfinite(background) and -1 <= background <= 1
               for spacing, background in conditions):
        raise ValueError("Spacings must be positive and finite; backgrounds must be in [-1, 1].")
    if not np.isfinite(p.t1) or p.t1 < 0 or not np.isfinite(p.t2) or p.t2 <= 0:
        raise ValueError("t1 must be nonnegative and t2 must be positive and finite.")
    if not np.isfinite(p.diameter) or p.diameter <= 0:
        raise ValueError("diameter must be positive and finite.")
    rng = np.random.default_rng()
    sequence = make_trial_sequence(len(conditions), p.repeat, rng)
    transition_counts = np.zeros((len(conditions), len(conditions)), dtype=int)
    occurrences = np.zeros(len(conditions), dtype=int)
    previous_condition = None

    dlp = None
    if com_port is not None:
        from serial import Serial
        dlp = Serial(port=com_port, baudrate=115200, timeout=0.05)
        dlp.write(b'Q') # Initialize channel 1 LOW.
        dlp.write(b'E') # Initialize channel 3 LOW.

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
                        fullscr=False, units='pix', color=[-1, -1, -1],
                        allowGUI=False, waitBlanking=True)
    min_spacing = min(p.spacing_range)
    base_xys = make_grid_xys(win.size, min_spacing, p.diameter, p.sx, p.sy, p.kx, p.ky)
    scaling = np.diag([p.sx, p.sy])
    shear = np.array([[1.0, p.kx], [p.ky, 1.0]])

    grid = visual.ElementArrayStim(
        win,
        nElements=len(base_xys),
        xys=base_xys,
        sizes=p.diameter,
        colors=[p.circle_brightness] * 3,
        elementTex=None,
        elementMask='circle',
        units='pix',
    )

    trial_num = 0
    clock = core.Clock()

    def check_abort():
        if 'escape' in event.getKeys(keyList=['escape']):
            raise StopIteration

    def wait_with_abort(duration):
        clock.reset()
        while clock.getTime() < duration:
            check_abort()
            time.sleep(0.01)

    try:
        # Without a device, proceed automatically. Escape also works during waits.
        while dlp is not None:
            check_abort()
            dlp.write(b'S')  # Listen to channel 2.
            if dlp.read(3).startswith(b'1'):
                break
        wait_with_abort(p.sleep_before)

        for condition_id in sequence:
            spacing, background = conditions[condition_id]
            rep = int(occurrences[condition_id])
            trial_num += 1
            theta_sampled = float(rng.uniform(0.0, 180.0))
            angle = np.deg2rad(theta_sampled)
            c, s = np.cos(angle), np.sin(angle)
            rotation = np.array([[c, -s], [s, c]])
            transform = scaling @ shear @ rotation
            # Positions are row vectors; transpose the column-vector transform.
            grid.xys = (base_xys * (spacing / min_spacing)) @ transform.T
            logging.exp(f"Trial {trial_num}: condition={condition_id}, spacing={spacing:g}, "
                        f"background_brightness={background:g}, theta_sampled={theta_sampled!r}")

            # Both phases use the selected background. With t1=0 there is no blank flip.
            win.color = [background] * 3
            # Apply the new color to the back buffer before the very first flip.
            win.clearBuffer()
            clock.reset()
            while clock.getTime() < p.t1:
                check_abort()
                win.flip()

            clock.reset()
            first_frame = True
            # Always present at least one frame, even for a sub-frame t2.
            while first_frame or clock.getTime() < p.t2:
                check_abort()
                if dlp is not None:
                    dlp.write(b'1' if first_frame else b'Q')
                grid.draw()
                win.flip()
                if first_frame:
                    if previous_condition is not None:
                        transition_counts[previous_condition, condition_id] += 1
                    previous_condition = condition_id
                    occurrences[condition_id] += 1
                    logging.exp(f"Trial {trial_num}: stimulus displayed, condition={condition_id}")
                    first_frame = False

            # Ensure the onset pulse ends even when t2 lasted only one frame.
            if dlp is not None:
                dlp.write(b'Q')

            exp_handler.addData('trial', trial_num)
            exp_handler.addData('condition', condition_id)
            exp_handler.addData('repeat', rep)
            exp_handler.addData('spacing', spacing)
            exp_handler.addData('background_brightness', background)
            exp_handler.addData('diameter', p.diameter)
            exp_handler.addData('circle_brightness', p.circle_brightness)
            exp_handler.addData('theta_sampled', theta_sampled)
            exp_handler.addData('theta', theta_sampled)
            exp_handler.addData('sx', p.sx)
            exp_handler.addData('sy', p.sy)
            exp_handler.addData('kx', p.kx)
            exp_handler.addData('ky', p.ky)
            exp_handler.nextEntry()
            print(f"  Trial {trial_num}/{len(sequence)}: C{condition_id}, "
                  f"repeat={rep + 1}/{p.repeat}, spacing={spacing:g}, "
                  f"background={background:g}, theta_sampled={theta_sampled:.3f}")

        wait_with_abort(p.sleep_after)
    except StopIteration:
        pass

    print_transition_matrix(conditions, transition_counts)

    # Reset the stimulus TTL channel after completion or Escape.
    if dlp is not None:
        dlp.write(b'Q')

    exp_handler.close()

    # TTL to signal the end of the stimuli
    if dlp is not None:
        dlp.write(b'3') # channel 3 HIGH
        time.sleep(0.1)
        dlp.write(b'E') # channel 3 LOW
        dlp.close()
    win.close()


if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "rec5"
    logdir = r"D:\experiments\20260917"
    p = SweepParams(
        t1=1,
        t2=1,
        diameter=0.5 * 10.87,
        background_brightness=[-1.0, 0],
        circle_brightness=1.0,
        spacing_range=[2 * 10.87, 4 * 10.87],
        # spacing_range=[1 * 10.87, 2 * 10.87, 4 * 10.87],
        repeat=25,
        sleep_before=5.0,
        sleep_after=5.0,
        # Circle positions: random rotation, then shear, then scale (S @ H @ R).
        sx=1/1, sy=1.0,  #1/1.77, 1
        #sx=1/1.77, sy=1.0,  #1/1.77, 1
        kx=1.0, ky=0.0, #1, 0
    )
    monitor_name = "test"
    screen_idx = 0
    com_port = None  # Set to None to disable DLP communication and TTL pulses.
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port)
