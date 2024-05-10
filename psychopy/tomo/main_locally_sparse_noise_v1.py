from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim import locally_sparse_noise, locally_sparse_noise2, LocallySparseNoiseParams

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "squid1_rec6"
    logdir = r"D:\experiments\20240510"
    p = LocallySparseNoiseParams(
        npy_filepath=r"C:\Users\tomoy\Documents\visual_stim\20240409_LSN_matrix\LSN_4DEG.npy",
        stim_time=1,
        stim_mode="on_only"
    )
    com_port = "COM3" # for DLP-IO8-G
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

    win = visual.Window(monitor='DLP3010EVM-LC', size=[1280,720],
                        fullscr=True, screen=1,
                        units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
#    win = visual.Window(monitor='DLP3010EVM-LC', size=[640,360], pos=(640,300),
#                        fullscr=False, screen=1,
#                        units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    time.sleep(5.0) # wait 1 sec before proceeding
    # start session; generate TTL pulses from channel 1
    locally_sparse_noise(win, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')

    # wait 5 sec after the session is over
    time.sleep(5)

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win.close()
