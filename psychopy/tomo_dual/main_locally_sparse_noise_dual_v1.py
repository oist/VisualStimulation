from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim_dual import dual_locally_sparse_noise, DualLocallySparseNoiseParams
from vstim import reset_screen2

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20241003"
    p = DualLocallySparseNoiseParams(
        mode="pol_only",
        npy_filepath=r"C:\Users\tomoy\Documents\visual_stim\20240611_LSN_matrix\LSN_5d0DEG.npy",
        stim_time=1.0,
        binary=True,
        # mat_start=0,
        # mat_end=30,
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0], # center position of the luminance stimuli
        lum_stim_value=1,
        lum_background_value=0,
        pol_stim_size=[647, 368], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_stim_value=0.718,
        pol_background_value=-1
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

    win_lum = visual.Window(monitor='test', size=[1280,720], screen=2,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    win_pol = visual.Window(monitor='test', size=[647, 368], pos=[70, 325], screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=False)

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    time.sleep(1.0) # wait 5 sec before proceeding
    # start session; generate TTL pulses from channel 1
    dual_locally_sparse_noise(win_lum, win_pol, exp_handler, p, dlp=dlp, code_on=b'1', code_off=b'Q')

    time.sleep(1.0) # wait 10 sec after the session is over

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
    win_pol.close()
