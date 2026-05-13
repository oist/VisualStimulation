from psychopy import visual, core, event, logging, clock
import numpy as np
import os
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

def annulus_stim(win, exp_handler, p: AnnulusParams, framerate=60, dlp=None, code_on=b'1', code_off=b'Q'):
    """
    """
    # initiate stimulus
    outer_circle = visual.Circle(
        win,
        radius=p.outer_radius,
        pos=p.center_pos,
        fillColor=(-1,-1,-1),
        lineColor=None,
        units='pix'
    )
    inner_circle = visual.Circle(
        win,
        radius=p.inner_radius,
        pos=p.center_pos,
        fillColor=(1,1,1),
        lineColor=None,
        units='pix'
    )
    frame_counter = 0
    stop_loop = False

    if dlp is not None:
        dlp.write(code_off)
    
    for rep in range(p.repeats):
        conditions = [[i,j] for i in p.inner_brightness for j in p.outer_brightness]
        conditions = np.random.permutation(conditions)
        for c in conditions:
            ib = c[0]
            ob = c[1]
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('inner_brightness', ib)
            exp_handler.addData('outer_brightness', ob)
            exp_handler.nextEntry()

            # t1: show background
            win.color = (p.bg, p.bg, p.bg)
            for i in range(int(p.t1 * framerate)):
                frame_counter += 1
                win.flip()

            # t2: show annulus
            for i in range(int(p.t2 * framerate)):
                if dlp is not None:
                    if i == 0:
                        dlp.write(code_on)
                    else:
                        dlp.write(code_off)
                frame_counter += 1
                inner_circle.fillColor = (ib, ib, ib)
                outer_circle.fillColor = (ob, ob, ob)
                outer_circle.draw()
                inner_circle.draw()
                win.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
                break
            event.clearEvents()
        if stop_loop:
            break

    return stop_loop
