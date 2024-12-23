from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class NoisyLSNParams:
    mode: str # "lum_only" or "pol_only"
    stim_time: float = 1.0 # Length of each stimulation in seconds
    noise_refresh_rate: float = 0.1 # refresh interval in seconds
    binary: bool = True
    noise_resolution: List[int] = field(default_factory=lambda: [1280, 720]) # Resolution of the noise grid
    mat_start: int = None # first frame of the LSN matrix
    mat_end: int = None # last frame of the LSN matrix
    lum_stim_size: List[int] = field(default_factory=lambda: [1280, 720]) # size of the luminance stimuli
    lum_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the luminance stimuli
    lum_stim_value: float = 1 # in range [0, 1]
    lum_background_value: float = 0
    pol_stim_size: List[int] = field(default_factory=lambda: [1024, 768]) # size of the polarization stimuli
    pol_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the polarization stimuli
    pol_stim_value: float = 1 # in range [0, 1]
    pol_background_value: float = 0
    pol_flip_horiz: bool = False
    pol_flip_vert: bool = False

def noisy_lsn(win_lum, win_pol, exp_handler, p: NoisyLSNParams, framerate=60, dlp=None, code_on=b'1', code_off=b'Q'):
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
    stim_frames = int(p.stim_time * framerate) # conver from secs to frames
    noise_refresh_frames = int(p.noise_refresh_rate * framerate) # conver from secs to frames

    mat = np.load(p.npy_filepath)
    if p.mat_start is None:
        p.mat_start = 0
    if p.mat_end is None:
        p.mat_end = mat.shape[0]

    # initiate stimulus
    if p.mode == "lum_only":
        stim = visual.ImageStim(win_lum, size=p.lum_stim_size, pos=p.lum_stim_pos, anchor='center')
        noise_texture = visual.ImageStim(win_pol, size=p.pol_stim_size, pos=p.pol_stim_pos, anchor='center', interpolate=False)
        stim_f, stim_b = p.lum_stim_value, p.lum_background_value
        noise_f, noise_b = p.pol_stim_value, p.pol_background_value
    elif p.mode == "pol_only":
        stim = visual.ImageStim(win_pol, size=p.pol_stim_size, pos=p.pol_stim_pos, anchor='center',
                                flipHoriz=p.pol_flip_horiz, flipVert=p.pol_flip_vert)
        noise_texture = visual.ImageStim(win_lum, size=p.lum_stim_size, pos=p.lum_stim_pos, anchor='center', interpolate=False)
        stim_f, stim_b = p.pol_stim_value, p.pol_background_value
        noise_f, noise_b = p.lum_stim_value, p.lum_background_value
    frame_counter = 0
    stop_loop = False

    if dlp is not None:
        dlp.write(code_off)

    for i in range(p.mat_start, p.mat_end):
        if i%10 == 0:
            print(f"{i}/{mat.shape[0]}")
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('index', i)
        exp_handler.nextEntry()

        raw = mat[i, :, :]
        if p.binary:
            image = np.zeros_like(raw)
            image[raw != 0] = stim_f
            image[raw == 0] = stim_b
        else:
            image = np.zeros_like(raw)
            image[raw > 0] = stim_f
            image[raw < 0] = -stim_f
            image[raw == 0] = stim_b
        stim.setImage(image)
        for j in range(stim_frames):
            if dlp is not None:
                if j == 0:
                    dlp.write(code_on)
                else:
                    dlp.write(code_off)
            if j % noise_refresh_frames == 0:
                noise = np.random.uniform(noise_b, noise_f, p.noise_resolution)
                noise_texture.setImage(noise)
            frame_counter += 1
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
