from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim_dual import dual_chirp_v1, DualChirpParamsV1
from vstim import reset_screen2

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "rec11"
    logdir = r"D:\experiments\20241022"
    repeats = 18
    # p1: luminance chirp on unpolarized background
    p1 = DualChirpParamsV1(
        mode="lum_only",
        f0=0.5,
        f1=10,
        method="logarithmic",
        c0=0.05,
        c1=1.0,
        f=1.0,
        repeats=1,
        t1=2,
        t2=4,
        t3=4,
        t4=2,
        t5=8,
        t6=0,
        t7=1,
        t8=2,
        skip_contrast_chirp=True,
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0], # center position of the luminance stimuli
        lum_stim_value=1,
        lum_background_value=-1,
        pol_stim_size=[657, 364], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_stim_value=0.783,
        pol_background_value=0.783
    )
    # p2: luminance chirp on vertically polarized background
    p2 = DualChirpParamsV1(
        mode="lum_only",
        f0=0.5,
        f1=10,
        method="logarithmic",
        c0=0.05,
        c1=1.0,
        f=1.0,
        repeats=1,
        t1=2,
        t2=4,
        t3=4,
        t4=2,
        t5=8,
        t6=0,
        t7=1,
        t8=2,
        skip_contrast_chirp=True,
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0], # center position of the luminance stimuli
        lum_stim_value=1,
        lum_background_value=-1,
        pol_stim_size=[657, 364], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_stim_value=0.783,
        pol_background_value=-1
    )
    # p3: polarization chirp
    p3 = DualChirpParamsV1(
        mode="pol_only",
        f0=0.5,
        f1=10,
        method="logarithmic",
        c0=0.05,
        c1=1.0,
        f=1.0,
        repeats=1,
        t1=4,
        t2=4,
        t3=4,
        t4=2,
        t5=8,
        t6=0,
        t7=1,
        t8=2,
        skip_contrast_chirp=True,
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0], # center position of the luminance stimuli
        lum_stim_value=1,
        lum_background_value=1,
        pol_stim_size=[657, 364], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_stim_value=0.783,
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
    # portrait mode
    win_pol = visual.Window(monitor='test', size=[657, 364], pos=[78, 328], screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    # landscape mode
    # win_pol = visual.Window(monitor='test', size=[657, 364], pos=[127, 68], screen=1,
    #                     units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    # black -> black
    reset_screen2(win_lum, start_color=[-1,-1,-1], end_color=[-1,-1,-1], ramp_time=3, hold_time=2)
    for rep in range(repeats):
        dual_chirp_v1(win_lum, win_pol, exp_handler, p1, dlp=dlp, code_on=b'1', code_off=b'Q')
        dual_chirp_v1(win_lum, win_pol, exp_handler, p2, dlp=dlp, code_on=b'1', code_off=b'Q')
        dual_chirp_v1(win_lum, win_pol, exp_handler, p3, dlp=dlp, code_on=b'1', code_off=b'Q')

    # black -> black
    reset_screen2(win_lum, start_color=[-1,-1,-1], end_color=[-1,-1,-1], ramp_time=5, hold_time=5)

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
    win_pol.close()
