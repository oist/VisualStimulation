from psychopy import visual, core, event, logging, clock
import numpy as np
from scipy import signal
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class DualChirpParamsV1:
    mode: str # "lum_only" or "pol_only"
    f0: float = 0.5 # Frequency in Hz at time t=0.
    f1: float = 10 # Frequency in Hz at time t = end
    method: str = "linear" # Method of frequency modulation; "linear", "logarithmic", "hyperbolic", "quadratic"
    c0: float = 0.05 # contrast level at time t=0.
    c1: float = 1 # contrast level at time t = end
    f: float = 1 # sine frequency
    repeats: int = 10 # number of repeats
    t1: int = 2 # off
    t2: int = 4 # on
    t3: int = 4 # off
    t4: int = 2 # gray
    t5: int = 8 # temporal chirp
    t6: int = 2 # gray
    t7: int = 8 # contrast chirp
    t8: int = 2 # off
    skip_contrast_chirp: bool = False
    lum_stim_size: List[int] = field(default_factory=lambda: [1280, 720]) # size of the luminance stimuli
    lum_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the luminance stimuli
    lum_stim_value: float = 1 # in range [0, 1]
    lum_background_value: float = 0
    pol_stim_size: List[int] = field(default_factory=lambda: [1024, 768]) # size of the polarization stimuli
    pol_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the polarization stimuli
    pol_stim_value: float = 1 # in range [0, 1]
    pol_background_value: float = 0

def dual_chirp_v1(win_lum, win_pol, exp_handler, p: DualChirpParamsV1, framerate=60, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
    """
    This function generates drifting gratings pattern on a screen.

    Parameters
    ----------
    win_lum: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    win_pol: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    exp_handler: psychopy.data.ExperimentHandler
        ExperimentHandler object must be set up by the parent python code and passed to this function.
    p:
        Parameters for temporal chirp
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """
    ###### Initiate Stimulus ########
    if p.mode == "lum_only":
        stim = visual.ImageStim(win_lum, size=p.lum_stim_size, pos=p.lum_stim_pos, anchor='center')
        f = p.lum_stim_value
        b = p.lum_background_value
        m = (f + b) / 2
        # background on polarization screen
        rect = visual.rect.Rect(win=win_pol, pos=p.pol_stim_pos, size=p.pol_stim_size,
                                fillColor=[p.pol_background_value, p.pol_background_value, p.pol_background_value])
        rect.draw()
        win_pol.flip()
    elif p.mode == "pol_only":
        stim = visual.ImageStim(win_pol, size=p.pol_stim_size, pos=p.pol_stim_pos, anchor='center')
        f = p.pol_stim_value
        b = p.pol_background_value
        m = (f + b) / 2
        # background on luminance screen
        rect = visual.rect.Rect(win=win_lum, pos=p.lum_stim_pos, size=p.lum_stim_size,
                                fillColor=[p.lum_background_value, p.lum_background_value, p.lum_background_value])
        rect.draw()
        win_lum.flip()

    t1 = np.linspace(0, p.t5, int(p.t5*framerate))
    w1 = signal.chirp(t1, f0=p.f0, f1=p.f1, t1=p.t5, phi=90, method=p.method)
    w1 = w1 * (f - b) / 2 + m
    t2 = np.linspace(0, p.t7, int(p.t7*framerate))
    a = p.c0 * (1 - t2/t2[-1]) + p.c1 * t2 / t2[-1]
    w2 = a * np.sin(p.f * t2 * 2 * np.pi)
    w2 = (w2 - m) * (f - b) / 2

    frame_counter = 0
    stop_loop = False

    if dlp is not None:
        dlp.write(code_off)

    for rep in range(p.repeats):
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('index', rep)
        exp_handler.nextEntry()

        ### beginning of square pulse ###
        for i in range(int(p.t1 * framerate)):
            # OFF state
            frame_counter += 1
            image = b * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            if p.mode == "lum_only":
                win_lum.flip()
            elif p.mode == "pol_only":
                win_pol.flip()
        if dlp is not None:
            dlp.write(code_on)
        for i in range(int(p.t2 * framerate)):
            # ON state 
            frame_counter += 1
            image = f * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            if p.mode == "lum_only":
                win_lum.flip()
            elif p.mode == "pol_only":
                win_pol.flip()
        if dlp is not None:
            dlp.write(code_off)
        for i in range(int(p.t3 * framerate)):
            ### OFF
            frame_counter += 1
            image = b * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            if p.mode == "lum_only":
                win_lum.flip()
            elif p.mode == "pol_only":
                win_pol.flip()

        ### begining of temporal chirp ###
        for i in range(int(p.t4 * framerate)):
            frame_counter += 1
            image = m * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            if p.mode == "lum_only":
                win_lum.flip()
            elif p.mode == "pol_only":
                win_pol.flip()
        if dlp is not None:
            dlp.write(code_on)
        for v in w1:
            frame_counter += 1
            image = v * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            if p.mode == "lum_only":
                win_lum.flip()
            elif p.mode == "pol_only":
                win_pol.flip()
        if dlp is not None:
            dlp.write(code_off)

        ### begining of contrast chirp ###
        for i in range(int(p.t6 * framerate)):
            frame_counter += 1
            image = m * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            if p.mode == "lum_only":
                win_lum.flip()
            elif p.mode == "pol_only":
                win_pol.flip()
        if not p.skip_contrast_chirp:
            if dlp is not None:
                dlp.write(code_on)
            for v in w2:
                frame_counter += 1
                image = v * np.ones((2,2))
                stim.setImage(image)
                stim.draw()
                if p.mode == "lum_only":
                    win_lum.flip()
                elif p.mode == "pol_only":
                    win_pol.flip()
            if dlp is not None:
                dlp.write(code_off)
        for i in range(int(p.t8 * framerate)):
            # OFF state
            frame_counter += 1
            image = b * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            if p.mode == "lum_only":
                win_lum.flip()
            elif p.mode == "pol_only":
                win_pol.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            # event.clearEvents()
            stop_loop = True
        if stop_loop == True:
            break
    
    return stop_loop
