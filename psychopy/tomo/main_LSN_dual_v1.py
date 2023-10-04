from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim_dual_screen import LSN_luminance, LSN_polarization, LocallySparseNoiseParams

if __name__ == "__main__":
    """
    Main function to generate locally sparse noise (LSN) stimulus.
    """
    ###### PARAMETERS BEGIN ######
    exp_name = "test2"
    mode = "lum_only" # choices are []"lum_only", "pol_only"]
    logdir = r"D:\experiments\20230922_squid_48dph_cal520_LSN_DRG"
    p = LocallySparseNoiseParams(
        npy_filepath="LSN/EVM3010_6cm_4DEG.npy",
        stim_time=1.0
    )
    com_port = "COM3" # for DLP-IO8-G
    ###### PARAMETERS END ########

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

    win_lum = visual.Window(monitor='projector', size=[1280,720],
                            fullscr=True, screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    win_pol = visual.Window(monitor='test', size=[1280,800],
                            fullscr=True, screen=2,
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
    if mode == "lum_only":
        LSN_luminance(win_lum, win_pol, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')
    if mode == "pol_only":
        LSN_polarization(win_lum, win_pol, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')

    exp_handler.close()
    win_lum.close()
    win_pol.close()

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.5)
    dlp.write(b'E')
    dlp.close()
