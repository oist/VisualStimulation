from psychopy import visual, core, event, data, logging
import numpy as np
import os
import time
from datetime import datetime
from serial import Serial
from dataclasses import dataclass, field
from typing import List


@dataclass
class AnnulusParams:
    center_pos: List[float] = field(default_factory=lambda: [0.0, 0.0])
    inner_radius: float = 10.0
    outer_radius: float = 30.0
    inner_brightness: List[float] = field(default_factory=lambda: [0.5, 1.0])
    outer_brightness: List[float] = field(default_factory=lambda: [0.0, 1.0])
    repeats: int = 2
    bg: float = -1
    t1: int = 4
    t2: int = 2
    fiducial_diameter: float = 10.0
    fiducial_spacing_x: float = 50.0
    fiducial_spacing_y: float = 50.0
    fiducial_brightness: float = 1.0
    shift_step: float = 10.0


def main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off, framerate=60):
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

    outer_circle = visual.Circle(
        win,
        radius=p.outer_radius,
        pos=p.center_pos,
        fillColor=(-1, -1, -1),
        lineColor=None,
        units='pix'
    )
    inner_circle = visual.Circle(
        win,
        radius=p.inner_radius,
        pos=p.center_pos,
        fillColor=(1, 1, 1),
        lineColor=None,
        units='pix'
    )

    half_x = p.fiducial_spacing_x / 2.0
    half_y = p.fiducial_spacing_y / 2.0
    cx, cy = p.center_pos[0], p.center_pos[1]
    fiducial_offsets = [(-half_x, -half_y), (-half_x, half_y), (half_x, -half_y), (half_x, half_y)]
    fiducials = [
        visual.Circle(
            win,
            radius=p.fiducial_diameter / 2.0,
            pos=(cx + dx, cy + dy),
            fillColor=(p.fiducial_brightness,) * 3,
            lineColor=None,
            units='pix'
        )
        for dx, dy in fiducial_offsets
    ]

    center = list(p.center_pos)

    def update_positions():
        outer_circle.pos = center
        inner_circle.pos = center
        for f, (dx, dy) in zip(fiducials, fiducial_offsets):
            f.pos = (center[0] + dx, center[1] + dy)

    def process_keys():
        keys = event.getKeys()
        for key in keys:
            if key in ['q', 'escape']:
                return True
            elif key == 'left':
                center[0] -= p.shift_step
            elif key == 'right':
                center[0] += p.shift_step
            elif key == 'up':
                center[1] += p.shift_step
            elif key == 'down':
                center[1] -= p.shift_step
        update_positions()
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

    frame_counter = 0
    stop_loop = False

    for rep in range(p.repeats):
        conditions = [[i, j] for i in p.inner_brightness for j in p.outer_brightness]
        conditions = np.random.permutation(conditions)
        for c in conditions:
            ib, ob = c[0], c[1]
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('x', center[0])
            exp_handler.addData('y', center[1])
            exp_handler.addData('inner_brightness', ib)
            exp_handler.addData('outer_brightness', ob)
            exp_handler.nextEntry()

            # t1: blank screen
            win.color = (p.bg, p.bg, p.bg)
            for i in range(int(p.t1 * framerate)):
                frame_counter += 1
                win.flip()
                if process_keys():
                    stop_loop = True
                    break
            if stop_loop:
                break

            # t2: annulus
            for i in range(int(p.t2 * framerate)):
                dlp.write(code_on if i == 0 else code_off)
                frame_counter += 1
                inner_circle.fillColor = (ib, ib, ib)
                outer_circle.fillColor = (ob, ob, ob)
                outer_circle.draw()
                inner_circle.draw()
                for f in fiducials:
                    f.draw()
                win.flip()
                if process_keys():
                    stop_loop = True
                    break
            event.clearEvents()
        if stop_loop:
            break

    time.sleep(5.0)

    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win.close()


if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20260701"
    p = AnnulusParams(
        center_pos=(239.7739999999997,-144.81399999999988),
        inner_radius=0.5 * 11.87,
        outer_radius=50 * 11.87,
        outer_brightness=[-1, -.98, -.96, -.94, -.92, -.90, -.88, -.86, -.84, -.82, -.80],
        #outer_brightness=[-1]*10,
        inner_brightness=[-1, -.8],
        repeats=10,
        bg=-1,
        t1=1.0,
        t2=1.0,
        fiducial_diameter=0.25 * 11.87,
        fiducial_spacing_x=2 * 11.87,
        fiducial_spacing_y=3 * 11.87,
        fiducial_brightness=1.0,
        shift_step=0.25 * 11.87,
    )
    monitor_name = "DLP3010EVM-LC"
    screen_idx = 0
    com_port = "COM3"      # for DLP-IO8-G
    code_on = b'1'
    code_off = b'Q'
    ###### PARAMETERS END ######

    main(p, exp_name, logdir, monitor_name, screen_idx, com_port, code_on, code_off)
