from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim import chirp, ChirpParams

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "squid1_rec7"
    logdir = r"C:\Users\tomoyuki\Documents\tmp"
    p = ChirpParams(
        f0=0.5,
        f1=10,
        method="logarithmic",
        repeats=50,
        t1= 2,
        t2 = 4,
        t3 = 4,
        t4 = 2,
        t5 = 8,
        t6 = 4,
        t7 = 2,
        stim_size=[640, 720],
        stim_pos=[-320, 0]
    )
    com_port = "COM3" # for DLP-IO8-G
    ###### PARAMETERS END ######

    # initialize DLP-IO8-G
    # dlp = Serial(port=com_port, baudrate=115200)

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
                        fullscr=True, screen=0,
                        units='pix', color=[0,0,0], allowGUI=False, waitBlanking=True)

    # wait for TTL HIGH in channel 2 or keyboard input
#    while True:
#        dlp.write(b'S')  # request to read
#        x = dlp.read(3).decode('utf-8')
#        if x[0] == '1':
#            break # the line is HIGH
#        keys = event.getKeys()
#        if keys:
#            break

    time.sleep(0.1) # wait 5 sec before proceeding
    # start session; generate TTL pulses from channel 1
    chirp(win, exp_handler, p)

    time.sleep(0.1) # wait 10 sec after the session is over

    # using channel 3, send TTL to DAQ to notify the completion of the session
#    dlp.write(b'3')
#    time.sleep(0.1)
#    dlp.write(b'E')
#    dlp.close()

    exp_handler.close()
    win.close()
