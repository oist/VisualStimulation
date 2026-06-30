from psychopy import visual, core, event
from dataclasses import dataclass
from typing import Tuple


@dataclass
class RFMapperParams:
    t1: float = 1.0
    t2: float = 2.0
    shift_step: int = 10
    diameter_step: int = 10
    initial_diameter: int = 50
    initial_pos: Tuple[int, int] = (0, 0)
    bg_color: Tuple[float, float, float] = (-1.0, -1.0, -1.0)
    initial_brightness: float = 1.0
    brightness_step: float = 0.1

def interactive_rf_mapping(win, exp_handler, p: RFMapperParams, dlp=None, code_on=b'1', code_off=b'Q'):
    win_size = win.size

    circle = visual.Circle(
        win,
        radius=p.initial_diameter / 2.0,
        fillColor=[p.initial_brightness] * 3,
        lineColor=[p.initial_brightness] * 3,
        pos=list(p.initial_pos),
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

    pos = list(p.initial_pos)
    diameter = p.initial_diameter
    brightness = p.initial_brightness
    trial_num = 0
    clock = core.Clock()

    def update_info():
        info_text.text = (
            f"pos=({pos[0]:.0f}, {pos[1]:.0f})  "
            f"diam={diameter:.0f}  "
            f"bright={brightness:.2f}  "
            f"trial={trial_num}"
        )

    def process_keys():
        nonlocal pos, diameter, brightness
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
            elif key == "w":
                brightness = min(1.0, brightness + p.brightness_step)
            elif key == "b":
                brightness = max(-1.0, brightness - p.brightness_step)
        circle.pos = pos
        circle.radius = diameter / 2.0
        circle.fillColor = [brightness] * 3
        circle.lineColor = [brightness] * 3
        return False

    if dlp is not None:
        dlp.write(code_off)

    try:
        while True:
            trial_num += 1
            event.clearEvents()

            # blank screen
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
                if dlp is not None:
                    dlp.write(code_on if first_frame else code_off)
                first_frame = False
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
            exp_handler.addData('brightness', brightness)
            exp_handler.nextEntry()
            print(f"  Trial {trial_num}: pos=({pos[0]:.0f}, {pos[1]:.0f}), diam={diameter:.0f}, bright={brightness:.2f}")

    except StopIteration:
        pass
