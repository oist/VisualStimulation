from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim import drifting_gratings, DriftingGratingsParams

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    com_port = "COM3" # for DLP-IO8-G
    exp_name = "test1"
    logdir = r"D:\experiments\20230922_squid_48dph_cal520_LSN_DRG"
    p = DriftingGratingsParams(
        # SFs=[0.01, 0.025, 0.05],
        SFs=[0.01, 0.025,],
        TFs=[0, 1.5, 3.0],
        ORIs=[0, 45, 90, 135, 180, 225, 270, 315],
        repeats=15, # number of repeats
        trial_time=2.0, # seconds
        interval_time=1.0 # seconds
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

    # wait for TTL HIGH in DLP-IO8G (channel 2) or keyboard input
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
    drifting_gratings(win, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')

    exp_handler.close()
    win.close()

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.5)
    dlp.write(b'E')
    dlp.close()
