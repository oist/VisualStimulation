from psychopy import visual, core, event, logging, clock
import numpy as np
import os
from dataclasses import dataclass, field

@dataclass
class DriftingGratingsParams:
    SFs: list = field(default_factory=list) # spatial frequencies
    TFs: list = field(default_factory=list) # temporal frequencies
    ORIs: list = field(default_factory=list) # temporal frequencies
    repeats: int = 5 # number of repeats
    trial_time: float = 3 # seconds
    interval_time: float = 2 # seconds
    random_seed: int = 2024

def drifting_gratings(win, exp_handler, p: DriftingGratingsParams, dlp=None, code_on=b'1', code_off=b'Q', save_movie=False):
    """
    This function generates drifting gratings pattern on a screen.

    Parameters
    ----------
    win: psychopy.visual.Window object
        Window must be set up by the parent python code and passed to this function.
    exp_handler: psychopy.data.ExperimentHandler
        ExperimentHandler object must be set up by the parent python code and passed to this function.
    p:
        Parameters for drifting gratings
    dlp: serial.Serial object
        This is to generate TTL pulses via DLP-IO8-G. If you don't need this, make this value None
    code_on: str
        Byte code to switch to HIGH
    code_off: str
        Byte code to switch to LOW
    """

    framerate = win.getActualFrameRate()
    trial_frames = int(p.trial_time * framerate) # convert secs to frames
    interval_frames = int(p.interval_time * framerate) # convert secs to frames

    conditions = [[i,j,k] for i in p.SFs for j in p.TFs for k in p.ORIs]

    grat = visual.GratingStim(win=win, pos=[0,0], units='pix', size=[4000,4000]) 
    phase_clock = core.Clock()

    ###### Initiate Stimulus ########
    frame_counter = 0
    phase_clock.reset()
    stop_loop=False
    np.random.seed(p.random_seed)

    if dlp is not None:
        dlp.write(code_off)

    for rep in range(p.repeats):
        np.random.shuffle(conditions)
        for cond in conditions:
            grat.sf = cond[0]
            grat.ori = cond[2]
            # if temporal frequency is 0, randomize phase
            if cond[1] == 0:
                phase = np.random.uniform(0.0, 1.0)
            exp_handler.addData('SF', cond[0])
            exp_handler.addData('TF', cond[1])
            exp_handler.addData('Ori', cond[2])
            exp_handler.addData('frame', frame_counter)
            print('Ori=', cond[2], ', SF=', cond[0], ', TF=', cond[1])

            # show trial frame, i.e. drifting gratings
            phase_clock.reset()
            for i in range(trial_frames):
                frame_counter += 1
                if cond[1] != 0:
                    grat.phase = cond[1]*phase_clock.getTime()
                elif cond[1] == 0:
                    grat.phase = phase
                grat.draw()
                if save_movie:
                    win.getMovieFrame()
                win.flip()
                if dlp is not None:
                    if i == 0:
                        dlp.write(code_on)
                    else:
                        dlp.write(code_off)

            # show inverval frames, i.e. blank image
            print("interval...")
            for i in range(interval_frames):
                frame_counter += 1
                win.color = [0, 0, 0]
                if save_movie:
                    win.getMovieFrame()
                win.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop=True
                break
            event.clearEvents()
            exp_handler.nextEntry()
        if stop_loop==True:
            break
    if save_movie:
        win.saveMovieFrames("stimulis.mp4")
