from psychopy import visual, data, event, logging
import os, time
from datetime import datetime

import sys
sys.path.append("..")
from vstim import locally_sparse_noise, LocallySparseNoiseParams

if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "test1"
    logdir = r"D:\tmp"
    p = LocallySparseNoiseParams(
        npy_filepath=r"..\tomo\LSN\LSN_4DEG.npy",
        stim_time=0.5
    )
    ###### PARAMETERS END ######

    now = datetime.now()
    dt_string = now.strftime("%Y%m%d_%H%M%S")
    log_filename_raw = os.path.join(logdir, f"log_{exp_name}_{dt_string}_raw.log")
    log_filename =  os.path.join(logdir, f"log_{exp_name}_{dt_string}.csv")
    # this is to log all events
    log_file = logging.LogFile(log_filename_raw, level=logging.EXP)
    # this is to log important events
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                        extraInfo={},
                                        runtimeInfo=None,
                                        dataFileName=log_filename,
                                        saveWideText=True,
                                        savePickle=False)

    win = visual.Window(monitor='projector', size=[1280,720],
                        fullscr=False, screen=0,
                        units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    time.sleep(1.0) # wait 1 sec before proceeding
    locally_sparse_noise(win, exp_handler, p, save_movie=True)

    exp_handler.close()
    win.close()
