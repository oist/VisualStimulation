from psychopy import visual, data, event, logging
import os, time
from serial import Serial

import sys
sys.path.append("..")
from vstim import flashing, FlashingParams


if __name__ == "__main__":
    """
    This script generates a simple flashing stimulation (switches between white and black screen).
    
    DLP-IO8-G channel assignments:
    line 1 is used to send TTL pulse to external DAQ to notify the timing of the session. line 1 is HIGH when the screen is white and LOW when the screen is black.
    line 2 is used to receive session start signal from external DAQ. As soon as line 2 receives HGIH signal, the session is started. Until then, the screen stays black.
    line 3 is used to send session complete signal to external DAQ. When the session is complete, line 3 becomes HIGH for 0.5 seconds.
    """

    ###### PARAMETERS BEGIN ######
    com_port = "COM3" # for DLP-IO8-G
    exp_name = "test"
    logdir = os.path.dirname(os.path.abspath(__file__))
    p = FlashingParams(
        on_time=2,
        off_time=3,
        repeats=10,
    )
    ###### PARAMETERS END ######

    # initialize DLP-IO8-G
    dlp = Serial(port=com_port, baudrate=115200)

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

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    # start flashing; generate TTL pulses from channel 1
    flashing(win, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')

    exp_handler.close()
    win.close()

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.5)
    dlp.write(b'E')

    dlp.close()
