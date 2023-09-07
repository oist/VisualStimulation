from psychopy import visual, data, event, logging
import os
from serial import Serial

import sys
sys.path.append("..")
from vstim import locally_sparse_noise, LocallySparseNoiseParams


if __name__ == "__main__":
    logdir = os.path.dirname(os.path.abspath(__file__))
    logfile = os.path.join(logdir, "log_raw.log")
    exp_name = "test"

    # this is to log all events
    log_file = logging.LogFile(os.path.join(logdir, "log_raw.log"), level=logging.EXP)
    # this is to log important events
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                        extraInfo={},
                                        runtimeInfo=None,
                                        dataFileName=os.path.join(logdir, "log.csv"),
                                        saveWideText=True,
                                        savePickle=False)

    win = visual.Window(monitor='projector', size=[1280, 720], 
                        fullscr=False, screen=1,
                        units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    p = LocallySparseNoiseParams(
        npy_filepath="LSG/LSG_4DEG.npy",
        stim_time=1.0
    )

    # wait for keyboard input
    while True:
        keys = event.getKeys()
        if keys:
            break

    locally_sparse_noise(win, exp_handler, p)

    exp_handler.close()
    win.close()
