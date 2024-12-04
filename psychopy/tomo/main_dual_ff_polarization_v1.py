from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim_dual import FF_polarization, FF_polarization2, FullFieldPolarizationParams

if __name__ == "__main__":
    """
    This script generates a full field polarization stimulation (polarization angle of the entire screen is changed in [0,90] degree).
    
    DLP-IO8-G channel assignments:
    line 1 is used to send TTL pulse to external DAQ to notify the timing of the session. line 1 is HIGH when the screen is white and LOW when the screen is black.
    line 2 is used to receive session start signal from external DAQ. As soon as line 2 receives HGIH signal, the session is started. Until then, the screen stays black.
    line 3 is used to send session complete signal to external DAQ. When the session is complete, line 3 becomes HIGH for 0.5 seconds.
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "squid1_rec4"
    logdir = r"D:\experiments\20231225"
    p = FullFieldPolarizationParams(
        on_time=1.0,
        off_time=4.0, 
        ORIs=[0,10,20,30,40,50,60,70,80,90],
        repeats=20
    )
    com_port = "COM3" # for DLP-IO8-G
    ###### PARAMETERS END ########

    # initialize DLP-IO8-G
    dlp = Serial(port=com_port, baudrate=115200)

    now = datetime.now()
    dt_string = now.strftime("%Y%m%d_%H%M%S")
    log_filename_raw = os.path.join(logdir, f"log_{exp_name}_{dt_string}_raw.log")
    log_filename =  os.path.join(logdir, f"log_{exp_name}_{dt_string}")
    # this is to log all events
    log_file = logging.LogFile(log_filename_raw, level=logging.EXP)
    # this is to log important events
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                        extraInfo={},
                                        runtimeInfo=None,
                                        dataFileName=log_filename,
                                        saveWideText=True,
                                        savePickle=False)

    win_lum = visual.Window(monitor='projector', size=[1280,720],
                            fullscr=True, screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=True, waitBlanking=True)
    win_pol = visual.Window(monitor='test', size=[1280,800],
                            fullscr=True, screen=2,
                            units='pix', color=[-1,-1,-1], allowGUI=True, waitBlanking=True)

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
    # start flashing; generate TTL pulses from channel 1
    # FF_polarization(win_lum, win_pol, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')
    FF_polarization2(win_lum, win_pol, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')

    exp_handler.close()
    win_lum.close()
    win_pol.close()

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.5)
    dlp.write(b'E')
    dlp.close()
