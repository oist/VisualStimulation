"""
Grid spacing sweep stimulus.

Displays a fixed N×M grid of circles centered on screen in a repeating t1 (blank) / t2 (stimulus)
cycle. On each trial, the grid spacing is drawn from a discrete set of conditions (spacing_range),
with the y-spacing derived from the x-spacing via aspect_ratio. Each condition in spacing_range is
shown `repeat` times; within each repeat, the conditions are presented in a freshly shuffled order
(block randomization), matching the sampling style used in phr_search.py.

Key bindings:
    Escape      : end session

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
    spacing_range     : discrete set of x-spacing values (pix) sampled as trial conditions
    aspect_ratio      : ratio of y-spacing to x-spacing (spacing_y = spacing_x * aspect_ratio)
    repeat            : number of times each condition in spacing_range is shown
    display_info      : if True, show live stimulus info (trial num, etc.) on screen; if False, show nothing
"""
from psychopy import visual, core, event, data, logging
import numpy as np
import os
from datetime import datetime
from serial import Serial
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
    aspect_ratio: float = 1.0
    repeat: int = 10
    display_info: bool = True


def make_grid_xys(n_cols, n_rows, spacing_x, spacing_y, pos):
    ox, oy = pos[0], pos[1]
    xys = [(ox + (i - (n_cols - 1) / 2) * spacing_x,
            oy + (j - (n_rows - 1) / 2) * spacing_y)
           for i in range(n_cols)
           for j in range(n_rows)]
    return np.array(xys, dtype=float)


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off):
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
        xys=make_grid_xys(p.n_cols, p.n_rows, p.spacing_range[0], p.spacing_range[0] * p.aspect_ratio, p.pos),
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

    def update_grid(spacing_x, spacing_y):
        new_xys = make_grid_xys(p.n_cols, p.n_rows, spacing_x, spacing_y, p.pos)
        grid.nElements = len(new_xys)
        grid.xys = new_xys

    def update_info(rep, spacing_x, spacing_y):
        info_text.text = (
            f"repeat={rep + 1}/{p.repeat}  "
            f"spacing=({spacing_x:.0f}, {spacing_y:.0f})  "
            f"trial={trial_num}"
        )

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break
        keys = event.getKeys()
        if keys:
            break

    time.sleep(5.0)

    try:
        for rep in range(p.repeat):
            conditions = np.random.permutation(p.spacing_range)
            for spacing_x in conditions:
                spacing_y = spacing_x * p.aspect_ratio
                trial_num += 1
                update_grid(spacing_x, spacing_y)
                update_info(rep, spacing_x, spacing_y)
                event.clearEvents()

                # blank screen
                win.color = [p.bg_brightness_t1] * 3
                clock.reset()
                while clock.getTime() < p.t1:
                    if p.display_info:
                        info_text.draw()
                    win.flip()
                    if event.getKeys(['escape']):
                        raise StopIteration

                # stimulus on
                win.color = [p.bg_brightness_t2] * 3
                clock.reset()
                first_frame = True
                while clock.getTime() < p.t2:
                    dlp.write(code_on if first_frame else code_off)
                    first_frame = False
                    grid.draw()
                    if p.display_info:
                        info_text.draw()
                    win.flip()
                    if event.getKeys(['escape']):
                        raise StopIteration

                exp_handler.addData('trial', trial_num)
                exp_handler.addData('repeat', rep)
                exp_handler.addData('spacing_x', spacing_x)
                exp_handler.addData('spacing_y', spacing_y)
                exp_handler.addData('diameter', p.diameter)
                exp_handler.addData('circle_brightness', p.circle_brightness)
                exp_handler.nextEntry()
                print(f"  Trial {trial_num}: repeat={rep + 1}/{p.repeat}, spacing=({spacing_x:.0f}, {spacing_y:.0f})")

    except StopIteration:
        pass

    time.sleep(5.0)

    exp_handler.close()

    # TTL to signal the end of the stimuli
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()
    win.close()


if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20260702"
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
        spacing_range=[1 * 11.87, 2 * 11.87, 3 * 11.87, 4 * 11.87],
        aspect_ratio=1.0,
        repeat=10,
        display_info=False
    )
    monitor_name = "DLP3010EVM-LC"
    screen_idx = 0
    com_port = "COM3"
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
