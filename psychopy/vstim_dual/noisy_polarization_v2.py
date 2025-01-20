from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class NoisyPolarizationParamsV2:
    mode: str # "lum_only" or "pol_only"
    contrast_steps: List[float] = field(default_factory=lambda: [-0.95, 0, 1.0])
    blank_background: float = -1
    repeats: int = 2 # number of repeats
    t1: float = 2 # blank
    t2: float = 2 # on
    t3: float = 2 # blank
    noise_refresh_rate: float = 0.1 # refresh interval in seconds
    noise_resolution: List[int] = field(default_factory=lambda: [1280, 720]) # Resolution of the noise grid
    lum_stim_size: List[int] = field(default_factory=lambda: [1280, 720]) # size of the luminance stimuli
    lum_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the luminance stimuli
    lum_background_max: float = 1
    lum_background_min: float = -1
    pol_stim_size: List[int] = field(default_factory=lambda: [1024, 768]) # size of the polarization stimuli
    pol_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the polarization stimuli
    pol_background_max: float = 1
    pol_background_min: float = -1
    pol_flip_horiz: bool = False
    pol_flip_vert: bool = False

def noisy_polarization_v2(win_lum, win_pol, exp_handler, p: NoisyPolarizationParamsV2, framerate=60, dlp=None, code_on=b'1', code_off=b'Q'):
    """

    Parameters
    ----------
    win_lum: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    win_pol: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    exp_handler: psychopy.data.ExperimentHandler
        ExperimentHandler object must be set up by the parent python code and passed to this function.
    p:
        Parameters for LSN stimulus
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """
    noise_refresh_frames = int(p.noise_refresh_rate * framerate) # conver from secs to frames

    # initiate stimulus
    if p.mode == "lum_only":
        stim = visual.rect.Rect(win=win_lum, pos=p.lum_stim_pos, size=p.lum_stim_size, fillColor=[0,0,0])
        noise_texture = visual.ImageStim(win_pol, size=p.pol_stim_size, pos=p.pol_stim_pos, anchor='center', interpolate=False)
        noise_max, noise_min = p.pol_background_max, p.pol_background_min
    elif p.mode == "pol_only":
        stim = visual.rect.Rect(win=win_pol, pos=p.pol_stim_pos, size=p.pol_stim_size, fillColor=[0,0,0])
        noise_texture = visual.ImageStim(win_lum, size=p.lum_stim_size, pos=p.lum_stim_pos, anchor='center', interpolate=False)
        noise_max, noise_min = p.lum_background_max, p.lum_background_min
    frame_counter = 0
    stop_loop = False

    if dlp is not None:
        dlp.write(code_off)
    
    for rep in range(p.repeats):
        np.random.shuffle(p.contrast_steps)
        for cont in p.contrast_steps:
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('contrast', cont)
            exp_handler.addData('lum_noise_min', p.lum_background_min)
            exp_handler.addData('lum_noise_max', p.lum_background_max)
            exp_handler.addData('pol_noise_min', p.pol_background_min)
            exp_handler.addData('pol_noise_max', p.pol_background_max)
            exp_handler.nextEntry()

            # blank period
            for i in range(int(p.t1 * framerate)):
                frame_counter += 1
                if i % noise_refresh_frames == 0:
                    noise = np.random.uniform(noise_min, noise_max, p.noise_resolution)
                    noise_texture.setImage(noise)
                stim.color = [p.blank_background, p.blank_background, p.blank_background]
                stim.draw()
                noise_texture.draw()
                win_lum.flip()
                win_pol.flip()
            
            if dlp is not None:
                dlp.write(code_on)
            # ON state
            for i in range(int(p.t2 * framerate)):
                frame_counter += 1
                if i % noise_refresh_frames == 0:
                    noise = np.random.uniform(noise_min, noise_max, p.noise_resolution)
                    noise_texture.setImage(noise)
                stim.color = [cont, cont, cont]
                stim.draw()
                noise_texture.draw()
                win_lum.flip()
                win_pol.flip()
            if dlp is not None:
                dlp.write(code_off)
            
            # blank period
            for i in range(int(p.t3 * framerate)):
                frame_counter += 1
                if i % noise_refresh_frames == 0:
                    noise = np.random.uniform(noise_min, noise_max, p.noise_resolution)
                    noise_texture.setImage(noise)
                stim.color = [p.blank_background, p.blank_background, p.blank_background]
                stim.draw()
                noise_texture.draw()
                win_lum.flip()
                win_pol.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
            event.clearEvents()
            if stop_loop == True:
                break

    return stop_loop
