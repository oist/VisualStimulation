from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim import locally_sparse_noise, LocallySparseNoiseParams

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    com_port = "COM3" # for DLP-IO8-G
    exp_name = "DRG"
    logdir = os.path.dirname(os.path.abspath(__file__))
    p = LocallySparseNoiseParams(
        npy_filepath="LSG/LSG_4DEG.npy",
        stim_time=1.0
    )
    ###### PARAMETERS END ######

    # initialize DLP-IO8-G
    dlp = Serial(port=com_port, baudrate=115200)

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
                        fullscr=True, screen=1,
                        units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    time.sleep(1.0) # wait 1 sec before proceeding
    # start session; generate TTL pulses from channel 1
    locally_sparse_noise(win, exp_handler, p)

    exp_handler.close()
    win.close()

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.5)
    dlp.write(b'E')
    dlp.close()