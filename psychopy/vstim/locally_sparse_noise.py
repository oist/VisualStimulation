from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field
from typing import List

@dataclass
class LocallySparseNoiseParams:
    npy_filepath: str # path to the pre-computed LSN matrix
    stim_time: float = 1.0 # Length of each stimulation in seconds
    stim_mode: str = "on_only" # "on_off", "on_only", "off_only"
    stim_size: List[int] = field(default_factory=lambda: [1280, 720])
    stim_pos: List[int] = field(default_factory=lambda: [0, 0])

def locally_sparse_noise(win, exp_handler, p: LocallySparseNoiseParams, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
    """
    This function generates locally sparse noise (LSN) stimulus.

    Parameters
    ----------
    win: psychopy.visual.Window object
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

    framerate = win.getActualFrameRate()
    stim_frames = int(p.stim_time * framerate) # conver from secs to frames

    mat = np.load(p.npy_filepath)

    # initiate stimulus
    frame_counter = 0
    stop_loop=False

    if dlp is not None:
        dlp.write(code_off)

    for i in range(mat.shape[0]):
        if i%10 == 0:
            print(f"{i}/{mat.shape[0]}")
        exp_handler.addData('frame', frame_counter)
        exp_handler.addData('index', i)
        exp_handler.nextEntry()

        image = mat[i, :, :]
        if p.stim_mode == "on_off":
            pass
        elif p.stim_mode == "on_only":
            image = (-1)*np.ones_like(image) + 2 * (image != 0)
        elif p.stim_mode == "off_only":
            image = (1)*np.ones_like(image) - 2 * (image != 0)
        stim = visual.ImageStim(win, image=image, size=p.stim_size, pos=p.stim_pos)
        for j in range(stim_frames):
            frame_counter += 1
            if dlp is not None:
                if j == 0:
                    dlp.write(code_on)
                else:
                    dlp.write(code_off)
            stim.draw()
            if save_movie:
                win.getMovieFrame()
            win.flip()

        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop = True
        event.clearEvents()
        if stop_loop == True:
            break
    if save_movie:
        win.saveMovieFrames("stimulis.mp4")
