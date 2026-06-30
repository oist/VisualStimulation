"""
Interactive receptive field mapping stimulus.

Displays a single circle on a uniform background in a repeating t1 (blank) / t2 (stimulus) cycle.
All parameters can be adjusted live during the experiment via keyboard.

Key bindings:
    Arrow keys  : move circle position
    s / l       : decrease / increase circle diameter
    1 / 2       : decrease / increase circle brightness (fg)
    3 / 4       : decrease / increase stimulus background brightness (bg2)
    p           : swap fg and bg2
    Escape      : end session

Parameters (RFMapperParams):
    t1              : blank screen duration (s)
    t2              : stimulus duration (s)
    shift_step      : position step size (pix)
    diameter_step   : diameter step size (pix)
    diameter        : initial circle diameter (pix)
    pos             : initial circle position (pix)
    bg1             : background brightness during t1 [-1, 1]
    bg2             : background brightness during t2 [-1, 1]
    fg              : circle brightness [-1, 1]
    brightness_step : brightness adjustment step
"""
from psychopy import visual, core, event, data, logging
import os
from datetime import datetime
from serial import Serial
import time
from dataclasses import dataclass
from typing import Tuple


@dataclass
class RFMapperParams:
    t1: float = 4.0
    t2: float = 1.0
    shift_step: int = 10
    diameter_step: int = 10
    diameter: int = 50
    pos: Tuple[int, int] = (0, 0)
    bg1: float = -1.0
    bg2: float = -1.0
    fg: float = 1.0
    brightness_step: float = 0.1


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off):
    dlp = Serial(port=com_port, baudrate=115200)

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

    circle = visual.Circle(
        win,
        radius=p.diameter / 2.0,
        fillColor=[p.fg] * 3,
        lineColor=[p.fg] * 3,
        pos=list(p.pos),
        units="pix",
    )

    info_text = visual.TextStim(
        win,
        text="",
        pos=(-win_size[0] / 2 + 15, win_size[1] / 2 - 20),
        anchorHoriz="left",
        anchorVert="top",
        color=(0, 1, 0),
        height=16,
        units="pix",
        bold=True,
    )

    pos = list(p.pos)
    diameter = p.diameter
    fg = p.fg
    bg2 = p.bg2
    trial_num = 0
    clock = core.Clock()

    def update_info():
        info_text.text = (
            f"pos=({pos[0]:.0f}, {pos[1]:.0f})  "
            f"diam={diameter:.0f}  "
            f"circ={fg:.2f}  "
            f"bg_t2={bg2:.2f}  "
            f"trial={trial_num}"
        )

    def process_keys():
        nonlocal pos, diameter, fg, bg2
        keys = event.getKeys()
        for key in keys:
            if key == "escape":
                return True
            elif key == "left":
                pos[0] -= p.shift_step
            elif key == "right":
                pos[0] += p.shift_step
            elif key == "up":
                pos[1] += p.shift_step
            elif key == "down":
                pos[1] -= p.shift_step
            elif key == "s":
                diameter = max(p.diameter_step, diameter - p.diameter_step)
            elif key == "l":
                diameter += p.diameter_step
            elif key == "1":
                fg = max(-1.0, fg - p.brightness_step)
            elif key == "2":
                fg = min(1.0, fg + p.brightness_step)
            elif key == "3":
                bg2 = max(-1.0, bg2 - p.brightness_step)
            elif key == "4":
                bg2 = min(1.0, bg2 + p.brightness_step)
            elif key == "p":
                fg, bg2 = bg2, fg
        circle.pos = pos
        circle.radius = diameter / 2.0
        circle.fillColor = [fg] * 3
        circle.lineColor = [fg] * 3
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

    dlp.write(code_off)

    try:
        while True:
            trial_num += 1
            event.clearEvents()

            # blank screen
            win.color = [p.bg1] * 3
            update_info()
            clock.reset()
            while clock.getTime() < p.t1:
                info_text.draw()
                win.flip()
                if process_keys():
                    raise StopIteration
                update_info()

            # stimulus on
            update_info()
            clock.reset()
            first_frame = True
            while clock.getTime() < p.t2:
                dlp.write(code_on if first_frame else code_off)
                first_frame = False
                win.color = [bg2] * 3
                circle.draw()
                info_text.draw()
                win.flip()
                if process_keys():
                    raise StopIteration
                update_info()

            exp_handler.addData('trial', trial_num)
            exp_handler.addData('x', pos[0])
            exp_handler.addData('y', pos[1])
            exp_handler.addData('diameter', diameter)
            exp_handler.addData('fg', fg)
            exp_handler.addData('bg2', bg2)
            exp_handler.nextEntry()
            print(f"  Trial {trial_num}: pos=({pos[0]:.0f}, {pos[1]:.0f}), diam={diameter:.0f}, circ={fg:.2f}, bg_t2={bg2:.2f}")

    except StopIteration:
        pass

    time.sleep(5.0)

    exp_handler.close()
    dlp.write(code_off)
    dlp.close()
    win.close()


if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20260528"
    p = RFMapperParams(
        t1=4.0,
        t2=1.0,
        shift_step=0.25 * 11.87,
        diameter_step=0.25 * 11.87,
        diameter=5 * 11.87,
        pos=(0, 0),
        bg1=-1.0,
        bg2=-1.0,
        fg=0.0,
        brightness_step=0.1,
    )
    monitor_name = "DLP3010EVM-LC"
    screen_idx = 0
    com_port = "COM3"      # for DLP-IO8-G
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
