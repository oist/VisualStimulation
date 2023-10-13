from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field

@dataclass
class LocallySparseNoiseParams:
    npy_filepath: str # path to the pre-computed LSN matrix
    stim_time: float = 1.0 # Length of each stimulation in seconds

def LSN_luminance(win_lum, win_pol, exp_handler, p: LocallySparseNoiseParams, dlp=None, code_on=b'1', code_off=b'Q'):
    """
    This function generates locally sparse noise (LSN) stimulus only in the luminance channel.
    The polarization screen is fixed at 0 (i.e. horizontal polarization).

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

    framerate = win_lum.getActualFrameRate()
    stim_frames = int(p.stim_time * framerate) # conver from secs to frames

    mat = np.load(p.npy_filepath)

    # make polarization screen black
    win_pol.color = [-1, -1, -1]
    win_pol.flip()

    # initiate stimulus
    frame_counter = 0
    stop_loop=False

    for i in range(mat.shape[0]):
        if i%10 == 0:
            print(f"{i}/{mat.shape[0]}")
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('index', i)
        exp_handler.nextEntry()

        image = mat[i, :, :]
        stim = visual.ImageStim(win_lum, image=image, size=win_lum.size)
        for j in range(stim_frames):
            frame_counter += 1
            if dlp is not None:
                if j == 0:
                    dlp.write(code_on)
                else:
                    dlp.write(code_off)
            stim.draw()
            win_lum.flip()
        
        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop = True
        event.clearEvents()
        if stop_loop == True:
            break

def LSN_polarization(win_lum, win_pol, exp_handler, p: LocallySparseNoiseParams, dlp=None, code_on=b'1', code_off=b'Q'):
    """
    This function generates locally sparse noise (LSN) stimulus only in the polarization channel.
    The luminance screen is fixed at 1 (i.e. max brightness).

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

    framerate = win_pol.getActualFrameRate()
    stim_frames = int(p.stim_time * framerate) # conver from secs to frames

    mat = np.load(p.npy_filepath)

    # initiate stimulus
    frame_counter = 0
    stop_loop=False

    for i in range(mat.shape[0]):
        if i%10 == 0:
            print(f"{i}/{mat.shape[0]}")
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('index', i)
        exp_handler.nextEntry()

        image = mat[i, :, :]
        image[np.abs(image) > 0] = 1
        image[image ==0 ] = -1
        stim = visual.ImageStim(win_pol, image=image, size=win_pol.size)
        for j in range(stim_frames):
            frame_counter += 1
            if dlp is not None:
                if j == 0:
                    dlp.write(code_on)
                else:
                    dlp.write(code_off)
            stim.draw()
            win_pol.flip()
            win_lum.color = [1, 1, 1]
            win_lum.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop = True
        event.clearEvents()
        if stop_loop == True:
            break
