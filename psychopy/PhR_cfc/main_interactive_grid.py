"""
Interactive grid stimulus.

Displays a fixed N×M grid of circles centered on screen in a repeating t1 (blank) / t2 (stimulus) cycle.
All parameters can be adjusted live during the experiment via keyboard.

Key bindings:
    Arrow keys  : shift grid position
    s / l       : decrease / increase circle diameter
    1 / 2       : decrease / increase circle brightness (fg)
    3 / 4       : decrease / increase horizontal circle spacing
    5 / 6       : decrease / increase vertical circle spacing
    Escape      : end session

Parameters (GridParams):
    t1              : blank screen duration (s)
    t2              : stimulus duration (s)
    shift_step      : position step size (pix)
    n_cols          : number of grid columns
    n_rows          : number of grid rows
    diameter        : initial circle diameter (pix)
    diameter_step   : diameter step size (pix)
    spacing_x       : horizontal center-to-center distance between circles (pix)
    spacing_y       : vertical center-to-center distance between circles (pix)
    spacing_step    : spacing adjustment step (pix)
    pos             : initial grid center position (pix)
    bg1             : background brightness during t1 [-1, 1]
    bg2             : background brightness during t2 [-1, 1]
    circle_brightness : circle brightness [-1, 1]
    brightness_step : brightness adjustment step
"""
from psychopy import visual, core, event, data, logging
import numpy as np
import os
from datetime import datetime
from serial import Serial
import time
from dataclasses import dataclass
from typing import Tuple


@dataclass
class GridParams:
    t1: float = 4.0
    t2: float = 1.0
    shift_step: float = 10.0
    n_cols: int = 5
    n_rows: int = 5
    diameter: float = 50.0
    diameter_step: float = 5.0
    spacing_x: float = 100.0
    spacing_y: float = 100.0
    spacing_step: float = 10.0
    pos: Tuple[float, float] = (0.0, 0.0)
    bg_brightness_t1: float = -1.0
    bg_brightness_t2: float = -1.0
    circle_brightness: float = 1.0
    brightness_step: float = 0.1


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

    pos = list(p.pos)
    diameter = p.diameter
    spacing_x = p.spacing_x
    spacing_y = p.spacing_y
    circle_brightness = p.circle_brightness

    xys = make_grid_xys(p.n_cols, p.n_rows, spacing_x, spacing_y, pos)
    grid = visual.ElementArrayStim(
        win,
        nElements=len(xys),
        xys=xys,
        sizes=diameter,
        colors=[circle_brightness] * 3,
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

    def update_grid():
        new_xys = make_grid_xys(p.n_cols, p.n_rows, spacing_x, spacing_y, pos)
        grid.nElements = len(new_xys)
        grid.xys = new_xys
        grid.sizes = diameter
        grid.colors = [circle_brightness] * 3

    def update_info():
        info_text.text = (
            f"pos=({pos[0]:.0f}, {pos[1]:.0f})  "
            f"diam={diameter:.0f}  "
            f"spacing=({spacing_x:.0f}, {spacing_y:.0f})  "
            f"circ={circle_brightness:.2f}  "
            f"trial={trial_num}"
        )

    def process_keys():
        nonlocal pos, diameter, spacing_x, spacing_y, circle_brightness
        keys = event.getKeys()
        changed = False
        for key in keys:
            if key == "escape":
                return True
            elif key == "left":
                pos[0] -= p.shift_step
                changed = True
            elif key == "right":
                pos[0] += p.shift_step
                changed = True
            elif key == "up":
                pos[1] += p.shift_step
                changed = True
            elif key == "down":
                pos[1] -= p.shift_step
                changed = True
            elif key == "s":
                diameter = max(p.diameter_step, diameter - p.diameter_step)
                changed = True
            elif key == "l":
                diameter += p.diameter_step
                changed = True
            elif key == "1":
                circle_brightness = max(-1.0, circle_brightness - p.brightness_step)
                changed = True
            elif key == "2":
                circle_brightness = min(1.0, circle_brightness + p.brightness_step)
                changed = True
            elif key == "3":
                spacing_x = max(p.spacing_step, spacing_x - p.spacing_step)
                changed = True
            elif key == "4":
                spacing_x += p.spacing_step
                changed = True
            elif key == "5":
                spacing_y = max(p.spacing_step, spacing_y - p.spacing_step)
                changed = True
            elif key == "6":
                spacing_y += p.spacing_step
                changed = True
        if changed:
            update_grid()
        return False

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
        while True:
            trial_num += 1
            event.clearEvents()

            # blank screen
            win.color = [p.bg_brightness_t1] * 3
            update_info()
            clock.reset()
            while clock.getTime() < p.t1:
                info_text.draw()
                win.flip()
                if process_keys():
                    raise StopIteration
                update_info()

            # stimulus on
            win.color = [p.bg_brightness_t2] * 3
            update_info()
            clock.reset()
            first_frame = True
            while clock.getTime() < p.t2:
                dlp.write(code_on if first_frame else code_off)
                first_frame = False
                grid.draw()
                info_text.draw()
                win.flip()
                if process_keys():
                    raise StopIteration
                update_info()

            exp_handler.addData('trial', trial_num)
            exp_handler.addData('x', pos[0])
            exp_handler.addData('y', pos[1])
            exp_handler.addData('diameter', diameter)
            exp_handler.addData('spacing_x', spacing_x)
            exp_handler.addData('spacing_y', spacing_y)
            exp_handler.addData('circle_brightness', circle_brightness)
            exp_handler.nextEntry()
            print(f"  Trial {trial_num}: pos=({pos[0]:.0f}, {pos[1]:.0f}), diam={diameter:.0f}, spacing=({spacing_x:.0f}, {spacing_y:.0f}), circ={circle_brightness:.2f}")

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
    logdir = r"D:\experiments\20260701"
    p = GridParams(
        t1=0.5,
        t2=0.5,
        n_cols=8,
        n_rows=8,
        shift_step=0.2 * 11.87,
        diameter=0.5 * 11.87,
        diameter_step=0.2 * 11.87,
        spacing_x=2 * 11.87,
        spacing_y=2 * 11.87,
        spacing_step=0.2 * 11.87,
        pos=(0.0, 0.0),
        bg_brightness_t1=-1.0,
        bg_brightness_t2=-1.0,
        circle_brightness=1.0,
        brightness_step=0.1,
    )
    monitor_name = "DLP3010EVM-LC"
    screen_idx = 0
    com_port = "COM3"
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
