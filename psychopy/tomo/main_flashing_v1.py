from psychopy import visual, data, event, logging
import os
from serial import Serial

import sys
sys.path.append("..")
from vstim import flashing, FlashingParams


if __name__ == "__main__":
    logdir = os.path.dirname(os.path.abspath(__file__))
    logfile = os.path.join(logdir, "log_raw.log")
    exp_name = "test"

    # initialize DLP-IO8-G
    dlp = Serial(port="COM3", baudrate=115200)

    # this is to log all events
    log_file = logging.LogFile(os.path.join(logdir, "log_raw.log"), level=logging.EXP)
    # this is to log important events
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                        extraInfo={},
                                        runtimeInfo=None,
                                        dataFileName=os.path.join(logdir, "log.csv"),
                                        saveWideText=True,
                                        savePickle=False)

    win = visual.Window(monitor='projector', size=[2560,1440], 
                        fullscr=True, screen=1,
                        units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    p = FlashingParams(
        on_time=2,
        off_time=3,
        repeats=10,
    )

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    flashing(win, exp_handler, p, dlp=dlp)

    exp_handler.close()
    win.close()
    dlp.close()
