from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class DriftingGratingsParams:
    SFs: list = field(default_factory=list) # spatial frequencies; given as cycles per pixel
    TFs: list = field(default_factory=list) # temporal frequencies; given in Hz
    ORIs: list = field(default_factory=list) # temporal frequencies
    texture: str = 'sin' # 'sin' or 'sqr' or 'saw' or 'tri'
    repeats: int = 5 # number of repeats
    t1: int = 1 # static grating period
    t2: int = 1.5 # drifting grating period
    t3: int = 0 # blank image
    mask: str = None # ‘circle’, ‘sin’, ‘sqr’, ‘saw’, ‘tri’
    stim_size: List[int] = field(default_factory=lambda: [1280, 720])
    stim_pos: List[int] = field(default_factory=lambda: [0, 0])

def drifting_gratings(win, exp_handler, p: DriftingGratingsParams, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
    """
    This function generates drifting gratings pattern on a screen.

    Parameters
    ----------
    win: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    exp_handler: psychopy.data.ExperimentHandler
        ExperimentHandler object must be set up by the parent python code and passed to this function.
    p:
        Parameters for drifting gratings
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """

    framerate = win.getActualFrameRate()

    ###### Initiate Stimulus ########
    grat = visual.GratingStim(win=win, tex=p.texture, units='pix', mask=p.mask, pos=p.stim_pos, size=p.stim_size)
    phase_clock = core.Clock()
    phase_clock.reset()
    frame_counter = 0
    stop_loop = False
    if dlp is not None:
        dlp.write(code_off)

    for rep in range(p.repeats):
        c = [[i,j] for i in p.SFs for j in p.TFs]
        c = [np.random.permutation(c) for i in p.ORIs]
        params = []
        for i in range(c[0].shape[0]):
            for j in np.random.permutation(len(p.ORIs)):
                params.append([p.ORIs[j], c[j][i,0], c[j][i,1]])
        for param in params:
            ori, sf, tf = param[0], param[1], param[2]
            grat.sf = sf
            grat.ori = ori
            grat.tf = tf
            phase = np.random.uniform(0.0, 1.0) # randomize phase
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('SF', sf)
            exp_handler.addData('TF', tf)
            exp_handler.addData('Ori', ori)
            exp_handler.addData('phase', phase)
            exp_handler.nextEntry()

            # show static gratings
            for i in range(int(p.t1 * framerate)):
                frame_counter += 1
                grat.phase = phase
                grat.draw()
                win.flip()

            # show drifting gratings
            phase_clock.reset()
            for i in range(int(p.t2 * framerate)):
                if dlp is not None:
                    if i == 0:
                        dlp.write(code_on)
                    else:
                        dlp.write(code_off)
                frame_counter += 1
                grat.phase = phase + tf * phase_clock.getTime()
                grat.draw()
                if save_movie:
                    win.getMovieFrame()
                win.flip()

            # show inverval frames, i.e. blank image
            for i in range(int(p.t3 * framerate)):
                frame_counter += 1
                win.color = [0, 0, 0]
                if save_movie:
                    win.getMovieFrame()
                win.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
                break
            event.clearEvents()

        if stop_loop == True:
            break

    if save_movie:
        win.saveMovieFrames("stimulis.mp4")
