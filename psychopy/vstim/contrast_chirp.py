from psychopy import visual, core, event, logging, clock
import numpy as np
from scipy import signal
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class ContrastChirpParams:
    c0: float = 0.5 # contrast level at time t=0.
    c1: float = 1 # contrast level at time t = end
    f: float = 1 # sine frequency
    repeats: int = 10 # number of repeats
    trial_time: float = 20 # The total length of the chirp stimulation
    interval_time: float = 2 # Interval between repeats in seconds
    stim_size: List[int] = field(default_factory=lambda: [1280, 720])
    stim_pos: List[int] = field(default_factory=lambda: [0, 0])

def contrast_chirp(win, exp_handler, p: ContrastChirpParams, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
    """
    This function generates drifting gratings pattern on a screen.

    Parameters
    ----------
    win: psychopy.visual.Window object
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

    framerate = win.getActualFrameRate()
    interval_frames = int(p.trial_time * framerate) # conver to secs to frames

    t = np.linspace(0, p.trial_time, int(p.trial_time*framerate))
    a = p.c0 * (1 - t/t[-1]) + p.c1 * t / t[-1]
    w = a * np.sin(p.f * t * 2 * np.pi)

    ###### Initiate Stimulus ########
    frame_counter = 0
    stop_loop=False
    if dlp is not None:
        dlp.write(code_off)

    stim = visual.ImageStim(win, size=p.stim_size, pos=p.stim_pos)

    for rep in range(p.repeats):
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('index', rep)
        exp_handler.nextEntry()

        # temporal chirp starts
        if dlp is not None:
            dlp.write(code_on)
        for v in w:
            frame_counter += 1
            image = v * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()
        # show inverval frames, i.e. blank image
        if dlp is not None:
            dlp.write(code_off)
        for i in range(interval_frames):
            frame_counter += 1
            image = np.zeros((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
        event.clearEvents()
        exp_handler.nextEntry()
        if stop_loop==True:
            break
