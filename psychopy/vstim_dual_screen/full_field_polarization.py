from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field

@dataclass
class FullFieldPolarizationParams:
    on_time: float = 3.0 # seconds
    off_time: float = 5.0 # seconds
    ORIs: list = field(default_factory=list) # polarization angles in degrees
    repeats: int = 25

def FF_polarization(win_lum, win_pol, exp_handler, p: FullFieldPolarizationParams, dlp=None, code_on=b'1', code_off=b'Q'):
    """
    This function generates full field polarization stimulation.
    It cycles through the specified polarization angles at random orders.
    During ON period, luminance is 1 (i.e. max brightness).
    During OFF period, liminance is -1 (i.e. min brightness).

    Parameters
    ----------
    win_lum: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    win_pol: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    exp_handler: psychopy.data.ExperimentHandler
        ExperimentHandler object must be set up by the parent python code and passed to this function.
    p:
        Parameters for full field polarization stimulus
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """

    framerate = win_lum.getActualFrameRate()
    on_frames = int(p.on_time * framerate) # conver from secs to frames
    off_frames = int(p.off_time * framerate) # conver from secs to frames

    angles = np.array([(e-45)/45 for e in p.ORIs]) # convert degree [0, 90] to [-1, 1]

    # initiate stimulus
    frame_counter = 0
    stop_loop=False

    for rep in range(p.repeats):
        np.random.shuffle(angles)
        for i in angles:
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('angle', i)
            exp_handler.nextEntry()
            print(i)
            if dlp is not None:
                dlp.write(code_off)
            for k in range(off_frames):
                frame_counter += 1
                win_pol.color = [i, i, i]
                win_pol.flip()
                win_lum.color = [0, 0, 0]
                win_lum.flip()
            if dlp is not None:
                dlp.write(code_on)
            for k in range(on_frames):
                frame_counter += 1
                win_pol.color = [i, i, i]
                win_pol.flip()
                win_lum.color = [1, 1, 1]
                win_lum.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
            event.clearEvents()
            if stop_loop == True:
                break
    
    # before closing, record the last frame
    exp_handler.addData('frame', frame_counter)
    exp_handler.addData('angle', i)
    exp_handler.nextEntry()

def FF_polarization2(win_lum, win_pol, exp_handler, p: FullFieldPolarizationParams, dlp=None, code_on=b'1', code_off=b'Q'):
    """
    This function generates full field polarization stimulation.
    It cycles through the specified polarization angles at random orders.
    During ON period, luminance is 1 (i.e. max brightness).
    During OFF period, liminance is -1 (i.e. min brightness).

    Parameters
    ----------
    win_lum: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    win_pol: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    exp_handler: psychopy.data.ExperimentHandler
        ExperimentHandler object must be set up by the parent python code and passed to this function.
    p:
        Parameters for full field polarization stimulus
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """

    framerate = win_lum.getActualFrameRate()
    on_frames = int(p.on_time * framerate) # conver from secs to frames
    off_frames = int(p.off_time * framerate) # conver from secs to frames

    angles = np.array([(e-45)/45 for e in p.ORIs]) # convert degree [0, 90] to [-1, 1]

    # initiate stimulus
    frame_counter = 0
    stop_loop=False

    for rep in range(p.repeats):
        np.random.shuffle(angles)
        for i in angles:
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('angle', i)
            exp_handler.nextEntry()
            print(i)
            if dlp is not None:
                dlp.write(code_off)
            for k in range(off_frames):
                frame_counter += 1
                win_pol.color = [0, 0, 0]
                win_pol.flip()
                win_lum.color = [0, 0, 0]
                win_lum.flip()
            if dlp is not None:
                dlp.write(code_on)
            for k in range(on_frames):
                frame_counter += 1
                win_pol.color = [i, i, i]
                win_pol.flip()
                win_lum.color = [0, 0, 0]
                win_lum.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
            event.clearEvents()
            if stop_loop == True:
                break
    
    # before closing, record the last frame
    exp_handler.addData('frame', frame_counter)
    exp_handler.addData('angle', i)
    exp_handler.nextEntry()
