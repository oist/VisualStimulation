from psychopy import visual, core, event, logging, clock
import numpy as np
from scipy import signal
import os
from dataclasses import dataclass, field

@dataclass
class TemporalChirpParams:
    f0: float = 0.5 # Frequency in Hz at time t=0.
    f1: float = 10 # Frequency in Hz at time t = end
    method: str = "linear" # Method of frequency modulation; "linear", "logarithmic", "hyperbolic", "quadratic"
    repeats: int = 10 # number of repeats
    trial_time: float = 20 # The total length of the chirp stimulation
    interval_time: float = 2 # Interval between repeats in seconds

def temporal_chirp(win, exp_handler, p: TemporalChirpParams, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
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
    trial_frames = int(p.trial_time * framerate) # conver to secs to frames
    interval_frames = int(p.trial_time * framerate) # conver to secs to frames

    t = np.linspace(0, p.trial_time, int(p.trial_time*framerate))
    w = signal.chirp(t, f0=p.f0, f1=p.f1, t1=p.trial_time, phi=90, method=p.method)

    ###### Initiate Stimulus ########
    frame_counter = 0
    stop_loop=False
    if dlp is not None:
        dlp.write(code_off)

    for rep in range(p.repeats):
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('index', rep)
        exp_handler.nextEntry()

        # temporal chirp starts
        if dlp is not None:
            dlp.write(code_on)
        for v in enumerate(w):
            frame_counter += 1
            win.color = [v, v, v]
            win.flip()
        # show inverval frames, i.e. blank image
        if dlp is not None:
            dlp.write(code_off)
        for i in range(interval_frames):
            frame_counter += 1
            win.color = [0, 0, 0]
            win.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
        event.clearEvents()
        exp_handler.nextEntry()
        if stop_loop==True:
            break
