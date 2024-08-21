from psychopy import visual, core, event, logging, clock
import numpy as np
from scipy import signal
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class ChirpParamsV2:
    f0: float = 0.5 # Frequency in Hz at time t=0.
    f1: float = 10 # Frequency in Hz at time t = end
    method: str = "linear" # Method of frequency modulation; "linear", "logarithmic", "hyperbolic", "quadratic"
    c0: float = 0.5 # contrast level at time t=0.
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
    stim_size: List[int] = field(default_factory=lambda: [1280, 720])
    stim_pos: List[int] = field(default_factory=lambda: [0, 0])

def chirp_v2(win, exp_handler, p: ChirpParamsV2, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
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
    t1 = np.linspace(0, p.t5, int(p.t5*framerate))
    w1 = signal.chirp(t1, f0=p.f0, f1=p.f1, t1=p.t5, phi=90, method=p.method)
    t2 = np.linspace(0, p.t7, int(p.t7*framerate))
    a = p.c0 * (1 - t2/t2[-1]) + p.c1 * t2 / t2[-1]
    w2 = a * np.sin(p.f * t2 * 2 * np.pi)

    ###### Initiate Stimulus ########
    stim = visual.ImageStim(win, size=p.stim_size, pos=p.stim_pos)
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
            frame_counter += 1
            image = (-1) * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()
        if dlp is not None:
            dlp.write(code_on)
        for i in range(int(p.t2 * framerate)):
            frame_counter += 1
            image = np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()
        if dlp is not None:
            dlp.write(code_off)
        for i in range(int(p.t3 * framerate)):
            frame_counter += 1
            image = (-1) * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()

        ### begining of temporal chirp ###
        for i in range(int(p.t4 * framerate)):
            frame_counter += 1
            image = 0 * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()
        if dlp is not None:
            dlp.write(code_on)
        for v in w1:
            frame_counter += 1
            image = v * np.ones((2,2))
            stim = visual.ImageStim(win, image=image, size=p.stim_size, pos=p.stim_pos)
            stim.draw()
            win.flip()
        if dlp is not None:
            dlp.write(code_off)
        for i in range(int(p.t6 * framerate)):
            frame_counter += 1
            image = 0 * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()
        if dlp is not None:
            dlp.write(code_on)
        for v in w2:
            frame_counter += 1
            image = v * np.ones((2,2))
            stim = visual.ImageStim(win, image=image, size=p.stim_size, pos=p.stim_pos)
            stim.draw()
            win.flip()
        if dlp is not None:
            dlp.write(code_off)
        for i in range(int(p.t8 * framerate)):
            frame_counter += 1
            image = (-1) * np.ones((2,2))
            stim.setImage(image)
            stim.draw()
            win.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop = True
        event.clearEvents()
        if stop_loop == True:
            break
