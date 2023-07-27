from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field

@dataclass
class FlashingParams:
    on_time: int = 2 # seconds
    off_time: int = 3 # seconds
    repeats: int = 100

def flashing(win, exp_handler, p: FlashingParams, dlp=None, code_on=b'1', code_off=b'Q'):
    """
    This function generates flashing stimulus (simple transition between full screen white and black).

    Parameters
    ----------
    win: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    exp_handler: psychopy.data.ExperimentHandler
        ExperimentHandler object must be set up by the parent python code and passed to this function.
    p:
        Parameters for flashing stimulus
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """

    framerate = win.getActualFrameRate()
    on_frames = int(p.on_time * framerate) # conver to secs to frames
    off_frames = int(p.off_time * framerate) # conver to secs to frames

    phase_clock = core.Clock() # Will be used to as input to the grating phase

    ###### Initiate Stimulus ########
    frame_counter = 0
    phase_clock.reset()
    stop_loop=False

    for rep in range(p.repeats):
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('ON', 1)
        exp_handler.nextEntry()
        if dlp is not None:
            dlp.write(code_on)
        for i in range(on_frames):
            frame_counter += 1
            win.color = [1, 1, 1]
            win.flip()

        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('ON', 0)
        exp_handler.nextEntry()
        if dlp is not None:
            dlp.write(code_off)
        for i in range(off_frames):
            frame_counter += 1
            win.color = [-1, -1, -1]
            win.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
        event.clearEvents()
        if stop_loop==True:
            break
