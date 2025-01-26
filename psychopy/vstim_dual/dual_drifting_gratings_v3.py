from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class DualDriftingGratingsParamsV3:
    mode: str # "lum_only" or "pol_only"
    color_max: float = 1
    color_min: float = -1
    black_white_ratio: int = 1
    SFs: list = field(default_factory=list) # spatial frequencies; given as cycles per pixel
    TFs: list = field(default_factory=list) # temporal frequencies; given in Hz
    ORIs: list = field(default_factory=list) # temporal frequencies
    repeats: int = 5 # number of repeats
    t1: int = 1 # static grating period
    t2: int = 1.5 # drifting grating period
    t3: int = 1 # blank image
    mask: str = None # ‘circle’, ‘sin’, ‘sqr’, ‘saw’, ‘tri’
    lum_stim_size: List[int] = field(default_factory=lambda: [1280, 720]) # size of the luminance stimuli
    lum_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the luminance stimuli
    lum_background_value: float = 0
    pol_stim_size: List[int] = field(default_factory=lambda: [1024, 768]) # size of the polarization stimuli
    pol_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the polarization stimuli
    pol_background_value: float = 0

def dual_drifting_gratings_v3(win_lum, win_pol, exp_handler, p: DualDriftingGratingsParamsV3, framerate=60, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
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
    # generate a custom texture
    one_cycle = np.concatenate((
        np.full(p.black_white_ratio, p.color_min),  # Black
        np.full(1, p.color_max)   # White
    ))
    texture = one_cycle.reshape(1, -1)  # Make it 2D

    ###### Initiate Stimulus ########
    
    if p.mode == "lum_only":
        grat = visual.GratingStim(win=win_lum, tex=texture, units='pix',
                                  mask=p.mask, pos=p.lum_stim_pos, size=p.lum_stim_size)
        rect = visual.rect.Rect(win=win_pol, pos=p.pol_stim_pos, size=p.pol_stim_size,
                                fillColor=[p.pol_background_value, p.pol_background_value, p.pol_background_value])
        rect.draw()
        win_pol.flip()
    elif p.mode == "pol_only":
        grat = visual.GratingStim(win=win_pol, tex=texture, units='pix',
                                  mask=p.mask, pos=p.pol_stim_pos, size=p.pol_stim_size)
        rect = visual.rect.Rect(win=win_lum, pos=p.lum_stim_pos, size=p.lum_stim_size,
                                fillColor=[p.lum_background_value, p.lum_background_value, p.lum_background_value])
        rect.draw()
        win_lum.flip()
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
            exp_handler.addData('mode', p.mode)
            exp_handler.addData('lum_background_value', p.lum_background_value)
            exp_handler.addData('pol_background_value', p.pol_background_value)
            exp_handler.nextEntry()

            # show inverval frames, i.e. blank image
            for i in range(int(p.t1 * framerate)):
                frame_counter += 1
                win_pol.color = [p.pol_background_value, p.pol_background_value, p.pol_background_value]
                win_lum.color = [p.lum_background_value, p.lum_background_value, p.lum_background_value]
                win_lum.flip()
                win_pol.flip()

            # show static gratings
            for i in range(int(p.t2 * framerate)):
                frame_counter += 1
                grat.phase = phase
                grat.draw()
                if p.mode == "lum_only":
                    win_lum.flip()
                elif p.mode == "pol_only":
                    win_pol.flip()

            # show drifting gratings
            phase_clock.reset()
            for i in range(int(p.t3 * framerate)):
                if dlp is not None:
                    if i == 0:
                        dlp.write(code_on)
                    else:
                        dlp.write(code_off)
                frame_counter += 1
                grat.phase = phase + tf * phase_clock.getTime()
                grat.draw()
                if p.mode == "lum_only":
                    win_lum.flip()
                elif p.mode == "pol_only":
                    win_pol.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
                break
            event.clearEvents()

        if stop_loop == True:
            break
    return stop_loop
