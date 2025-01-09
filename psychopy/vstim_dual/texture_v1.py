from psychopy import visual, core, event, logging, clock
import numpy as np
import random
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class TextureStimParams:
    imgdir: str # directory where texture images are stored
    patterns: List[int] = field(default_factory=lambda: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    variations: List[int] = field(default_factory=lambda: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
    random_seed: int = 2025 # random seed to shuffle the image order
    t1: float = 1.0 # duration of blank screen in seconds
    t2: float = 1.0 # duration of texture stimulation in seconds
    blank_color: List[float] = field(default_factory=lambda: [0.0, 0.0, 0.0])
    lum_stim_size: List[int] = field(default_factory=lambda: [1280, 720]) # size of the luminance stimuli
    lum_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the luminance stimuli
    pol_stim_size: List[int] = field(default_factory=lambda: [1024, 768]) # size of the polarization stimuli
    pol_stim_pos: List[int] = field(default_factory=lambda: [0, 0]) # center position of the polarization stimuli
    pol_background_value: float = 0

def texture_stim(win_lum, win_pol, exp_handler, p: TextureStimParams, framerate=60, dlp=None, code_on=b'1', code_off=b'Q'):
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
        Parameters for texture stimulus
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """
    t1_frames = int(p.t1 * framerate) # conver from secs to frames
    t2_frames = int(p.t2 * framerate) # conver from secs to frames

    # image_files = [f"img_{i:03d}_v_{j}.png" for j in np.random.choice(p.variations, len(p.variations), replace=False)
    #                for i in np.random.choice(p.patterns, len(p.patterns), replace=False)]
    image_files = [f"img_{i:03d}_v_{j}.png" for j in p.variations for i in p.patterns]
    random.seed(p.random_seed)
    random.shuffle(image_files)
    image_files = [os.path.join(p.imgdir, x) for x in image_files]

    # background on polarization screen
    rect = visual.rect.Rect(win=win_pol, pos=p.pol_stim_pos, size=p.pol_stim_size,
                            fillColor=[p.pol_background_value, p.pol_background_value, p.pol_background_value])
    rect.draw()
    win_pol.flip()

    image_stim = visual.ImageStim(win=win_lum, pos=p.lum_stim_pos, size=p.lum_stim_size)
    gray_screen = visual.Rect(win=win_lum, pos=p.lum_stim_pos, size=p.lum_stim_size, fillColor=p.blank_color)

    frame_counter = 0
    stop_loop = False

    if dlp is not None:
        dlp.write(code_off)

    for image_path in image_files:
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('image', image_path)
        exp_handler.nextEntry()

        for j in range(t1_frames):
            frame_counter += 1
            # Display gray screen
            gray_screen.draw()
            win_lum.flip()

        image_stim.image = image_path
        for j in range(t2_frames):
            frame_counter += 1
            if dlp is not None:
                if j == 0:
                    dlp.write(code_on)
                else:
                    dlp.write(code_off)
            image_stim.draw()
            win_lum.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop = True
        event.clearEvents()
        if stop_loop == True:
            break

    return stop_loop
