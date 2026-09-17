"""
Grid spacing sweep stimulus with transformed circle positions.

Displays a fixed N×M grid of circles centered on screen in a repeating t1 (blank) / t2 (stimulus)
cycle. On each trial, the grid spacing is drawn from a discrete set of conditions (spacing_range),
with equal base spacing on both axes before transformation. Each condition in spacing_range is
shown `repeat` times; within each repeat, the conditions are presented in a freshly shuffled order
(block randomization), matching the sampling style used in phr_search.py.

Circle centers are transformed about pos: rotate -> scale -> shear.
Theta is in degrees, positive counterclockwise. For column vectors,
A = H @ S @ R, with S = diag(sx, sy) and H = [[1, kx], [ky, 1]].
Shear components act simultaneously, not sequentially. Circle shapes and
sizes are unchanged. Keyboard adjustments persist across trials. Trial rows record
the final parameter values; individual adjustments are recorded in the raw log.
Logged spacing is the shared base spacing before transformation.
Set com_port=None to run without a DLP device or TTL pulses; use a key to start.

Key bindings:
    Escape      : end session
    1 / 2       : increase / decrease theta by 5 degrees
    3 / 4       : increase / decrease sx by 0.1
    5 / 6       : increase / decrease kx by 0.1
    Adjustments are active during blank and stimulus periods.

Parameters (SweepParams):
    t1                : blank screen duration (s)
    t2                : stimulus duration (s)
    n_cols            : number of grid columns
    n_rows            : number of grid rows
    diameter          : circle diameter (pix)
    pos               : grid center position (pix)
    bg_brightness_t1  : background brightness during t1 [-1, 1]
    bg_brightness_t2  : background brightness during t2 [-1, 1]
    circle_brightness : circle brightness [-1, 1]
    spacing_range     : discrete base spacing values (pix), shared by both axes before transformation
    theta             : rotation angle in degrees (positive counterclockwise)
    sx, sy            : x and y scale factors applied after rotation
    kx, ky            : simultaneous shear coefficients: x_new=x+kx*y, y_new=ky*x+y
    repeat            : number of times each condition in spacing_range is shown
    display_info      : if True, show live stimulus info (trial num, etc.) on screen; if False, show nothing
    sleep_before      : delay after the start trigger and before the trial sequence (s; 0 skips)
    sleep_after       : delay after the trial sequence and before cleanup/end TTL (s; 0 skips)
"""
from psychopy import visual, core, event, data, logging
import numpy as np
import os
from datetime import datetime
import time
from dataclasses import dataclass, field
from typing import List, Tuple


@dataclass
class SweepParams:
    t1: float = 4.0
    t2: float = 1.0
    n_cols: int = 5
    n_rows: int = 5
    diameter: float = 50.0
    pos: Tuple[float, float] = (0.0, 0.0)
    bg_brightness_t1: float = -1.0
    bg_brightness_t2: float = -1.0
    circle_brightness: float = 1.0
    spacing_range: List[float] = field(default_factory=lambda: [50.0, 100.0, 150.0, 200.0])
    repeat: int = 10
    display_info: bool = True
    theta: float = 0.0
    sx: float = 1.0
    sy: float = 1.0
    kx: float = 0.0
    ky: float = 0.0
    sleep_before: float = 5.0
    sleep_after: float = 5.0


def make_grid_xys(n_cols, n_rows, spacing, pos,
                  theta=0.0, sx=1.0, sy=1.0, kx=0.0, ky=0.0):
    """Rotate, scale, then simultaneously shear offsets about pos.

    Only circle centers are transformed; identity defaults reproduce v1.
    """
    xys = np.array([
        ((i - (n_cols - 1) / 2) * spacing,
         (j - (n_rows - 1) / 2) * spacing)
        for i in range(n_cols)
        for j in range(n_rows)
    ], dtype=float)
    angle = np.deg2rad(theta)
    c, s = np.cos(angle), np.sin(angle)
    rotation = np.array([[c, -s], [s, c]])
    scaling = np.diag([sx, sy])
    shear = np.array([[1.0, kx], [ky, 1.0]])
    transform = shear @ scaling @ rotation
    # Positions are row vectors, so multiply by the transpose.
    return xys @ transform.T + np.asarray(pos, dtype=float)


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
    win_size = win.size

    grid = visual.ElementArrayStim(
        win,
        nElements=p.n_cols * p.n_rows,
        xys=make_grid_xys(p.n_cols, p.n_rows, p.spacing_range[0],
                          p.pos, p.theta, p.sx, p.sy, p.kx, p.ky),
        sizes=p.diameter,
        colors=[p.circle_brightness] * 3,
        elementTex=None,
        elementMask='circle',
        units='pix',
    )

    info_text = visual.TextStim(
        win,
        text="",
        pos=(-win_size[0] / 2 + 15, win_size[1] / 2 - 20),
        anchorHoriz="left",
        anchorVert="top",
        color=(-1, 1, -1),
        height=16,
        units="pix",
        bold=True,
    )

    trial_num = 0
    clock = core.Clock()

    def update_grid(spacing):
        new_xys = make_grid_xys(p.n_cols, p.n_rows, spacing,
                                p.pos, p.theta, p.sx, p.sy, p.kx, p.ky)
        grid.nElements = len(new_xys)
        grid.xys = new_xys

    def update_info(rep, spacing):
        info_text.text = (
            f"repeat={rep + 1}/{p.repeat}  "
            f"spacing={spacing:.0f}  "
            f"trial={trial_num}\n"
            f"theta={p.theta:g} deg  scale=({p.sx:g}, {p.sy:g})  "
            f"shear=({p.kx:g}, {p.ky:g})"
        )

    key_adjustments = {
        '1': ('theta', 5.0),
        '2': ('theta', -5.0),
        '3': ('sx', 0.1),
        '4': ('sx', -0.1),
        '5': ('kx', 0.1),
        '6': ('kx', -0.1),
    }

    def handle_keys(rep, spacing):
        keys = event.getKeys(keyList=['escape', *key_adjustments])
        if 'escape' in keys:
            raise StopIteration
        changed = False
        for key in keys:
            name, delta = key_adjustments[key]
            value = round(getattr(p, name) + delta, 10)
            setattr(p, name, value)
            logging.exp(f"Trial {trial_num}: key={key}, {name}={value:g}")
            changed = True
        if changed:
            update_grid(spacing)
            update_info(rep, spacing)

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
        for rep in range(p.repeat):
            conditions = np.random.permutation(p.spacing_range)
            for spacing in conditions:
                trial_num += 1
                update_grid(spacing)
                update_info(rep, spacing)
                event.clearEvents()

                # blank screen
                win.color = [p.bg_brightness_t1] * 3
                clock.reset()
                while clock.getTime() < p.t1:
                    handle_keys(rep, spacing)
                    if p.display_info:
                        info_text.draw()
                    win.flip()

                # stimulus on
                win.color = [p.bg_brightness_t2] * 3
                clock.reset()
                first_frame = True
                while clock.getTime() < p.t2:
                    handle_keys(rep, spacing)
                    if dlp is not None:
                        dlp.write(code_on if first_frame else code_off)
                    first_frame = False
                    grid.draw()
                    if p.display_info:
                        info_text.draw()
                    win.flip()

                exp_handler.addData('trial', trial_num)
                exp_handler.addData('repeat', rep)
                exp_handler.addData('spacing', spacing)
                exp_handler.addData('diameter', p.diameter)
                exp_handler.addData('circle_brightness', p.circle_brightness)
                exp_handler.addData('theta', p.theta)
                exp_handler.addData('sx', p.sx)
                exp_handler.addData('sy', p.sy)
                exp_handler.addData('kx', p.kx)
                exp_handler.addData('ky', p.ky)
                exp_handler.nextEntry()
                print(f"  Trial {trial_num}: repeat={rep + 1}/{p.repeat}, spacing={spacing:.0f}")

    except StopIteration:
        pass

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
    exp_name = "test"
    logdir = r"C:\Users\tomoyuki\Documents\New folder"
    p = SweepParams(
        t1=0.5,
        t2=0.5,
        n_cols=8,
        n_rows=8,
        diameter=0.5 * 11.87,
        pos=(0.0, 0.0),
        bg_brightness_t1=-1.0,
        bg_brightness_t2=-1.0,
        circle_brightness=1.0,
        spacing_range=[2 * 11.87, 3 * 11.87, 4 * 11.87],
        repeat=30,
        display_info=True,
        sleep_before=5.0,
        sleep_after=5.0,
        # Circle positions: rotate (degrees CCW), then scale, then shear.
        theta=51.3,
        sx=1.77,
        sy=1.0,
        kx=1.0,
        ky=0.0,
    )
    monitor_name = "testMonitor"
    screen_idx = 0
    com_port = None  # Set to None to disable DLP communication and TTL pulses.
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
