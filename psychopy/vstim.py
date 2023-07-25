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

def drifting_gratings(win, exp_handler, p: DriftingGratingsParams):
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
    """

    framerate = win.getActualFrameRate()
    trial_frames = int(p.trial_time * framerate) # conver to time to frames
    interval_frames = int(p.trial_time * framerate) # conver to time to frames

    conditions = [[i,j,k] for i in p.SFs for j in p.TFs for k in p.ORIs]

    grat = visual.GratingStim(win=win, pos=[0,0], units='pix', size=[4000,4000]) 
    phase_clock = core.Clock() # Will be used to as input to the grating phase

    ###### Initiate Stimulus ########
    event.waitKeys() # wait until user hits some key
    frame_counter = 0
    phase_clock.reset()
    stop_loop=False

    for rep in range(p.repeats):
        np.random.shuffle(conditions)
        for cond in conditions:
            grat.sf = cond[0]
            grat.ori = cond[2]
            exp_handler.addData('SF', cond[0])
            exp_handler.addData('TF', cond[1])
            exp_handler.addData('Ori', cond[2])
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('frame_time', phase_clock.getTime())

            # show trial frame, i.e. drifting gratings
            phase_clock.reset()
            for i in range(trial_frames):
                grat.phase=cond[1]*phase_clock.getTime()
                grat.draw()
                win.flip()
                frame_counter += 1
            
            # show inverval frames, i.e. blank image
            for i in range(interval_frames):
                win.flip()
                frame_counter += 1
            
            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop=True
                break
            event.clearEvents()
            exp_handler.nextEntry()
        if stop_loop==True:
            break
