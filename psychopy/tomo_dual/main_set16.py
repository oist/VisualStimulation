from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial
import numpy as np

import sys
sys.path.append("..")
from vstim_dual import noisy_polarization_v1, NoisyPolarizationParamsV1
from vstim_dual import reset_screen

if __name__ == "__main__":
    """
    """
    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20250110"
    com_port = "COM3" # for DLP-IO8-G
    repeats = 12
    p1 = NoisyPolarizationParamsV1(
        mode="pol_only",
        contrast_steps=[-1, -0.3858, 0.0157, 0.2992, 0.5354, 0.6456, 0.6929, 0.7165],
        blank_background=0.740,
        repeats=1,
        t1=3, # blank
        t2=2, # on
        noise_refresh_rate=0.1,
        noise_resolution=[36, 64],
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0],
        lum_background_max=1,
        lum_background_min=-1,
        pol_stim_size=[657, 364],
        pol_stim_pos=[0, 0],
        pol_background_min=None,
        pol_background_max=None,
        pol_flip_horiz=True,
        pol_flip_vert=False,
    )
    p2 = NoisyPolarizationParamsV1(
        mode="pol_only",
        contrast_steps=[-1, -0.3858, 0.0157, 0.2992, 0.5354, 0.6456, 0.6929, 0.7165],
        blank_background=0.740,
        repeats=1,
        t1=3, # blank
        t2=2, # on
        noise_refresh_rate=0.1,
        noise_resolution=[36, 64],
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0],
        lum_background_max=0,
        lum_background_min=0,
        pol_stim_size=[657, 364],
        pol_stim_pos=[0, 0],
        pol_background_min=None,
        pol_background_max=None,
        pol_flip_horiz=True,
        pol_flip_vert=False,
    )
    # p1 = NoisyPolarizationParamsV1(
    #     mode="lum_only",
    #     contrast_steps=[-0.9, -0.8,-0.6, 0, 0.5, 1.0],
    #     blank_background=-1,
    #     repeats=1,
    #     t1=3, # blank
    #     t2=2, # on
    #     noise_refresh_rate=0.1,
    #     noise_resolution=[36, 65],
    #     lum_stim_size=[1280, 720],
    #     lum_stim_pos=[0, 0],
    #     lum_background_max=1,
    #     lum_background_min=-1,
    #     pol_stim_size=[657, 364],
    #     pol_stim_pos=[0, 0],
    #     pol_background_min=-1,
    #     pol_background_max=0.783,
    #     pol_flip_horiz=True,
    #     pol_flip_vert=False,
    # )
    # p2 = NoisyPolarizationParamsV1(
    #     mode="lum_only",
    #     contrast_steps=[-0.9, -0.8,-0.6, 0, 0.5, 1.0],
    #     blank_background=-1,
    #     repeats=1,
    #     t1=3, # blank
    #     t2=2, # on
    #     noise_refresh_rate=0.1,
    #     noise_resolution=[36, 65],
    #     lum_stim_size=[1280, 720],
    #     lum_stim_pos=[0, 0],
    #     lum_background_max=1,
    #     lum_background_min=-1,
    #     pol_stim_size=[657, 364],
    #     pol_stim_pos=[0, 0],
    #     pol_background_min=0.783,
    #     pol_background_max=0.783,
    #     pol_flip_horiz=True,
    #     pol_flip_vert=False,
    # )
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

    win_lum = visual.Window(monitor='test', size=[1280,720], screen=2, fullscr=True,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    # portrait mode
    win_pol = visual.Window(monitor='test', size=[657, 364], pos=[78, 328], screen=1, fullscr=True,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    # landscape mode
    # win_pol = visual.Window(monitor='test', size=[657, 364], pos=[127, 68], screen=1,
    #                     units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    fr = min(win_lum.getActualFrameRate(), win_pol.getActualFrameRate())
    s1 = win_lum.size
    s2 = win_pol.size
    print(fr, s1, s2)

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    # black -> gray
    reset_screen(win_lum, win_pol,
                 ramp_time=3, hold_time=3, framerate=fr, stim_size_lum=s1, stim_size_pol=s2,
                 start_color_lum=[-1,-1,-1], end_color_lum=[0,0,0],
                 start_color_pol=[-1,-1,-1], end_color_pol=[0.74, 0.74, 0.74])
    for rep in range(repeats):
        stop_loop = noisy_polarization_v1(win_lum, win_pol, exp_handler, p1, framerate=fr, dlp=dlp, code_on=b'1', code_off=b'Q')
        if stop_loop: break
        # gray -> gray
        reset_screen(win_lum, win_pol,
                 ramp_time=1, hold_time=1, framerate=fr, stim_size_lum=s1, stim_size_pol=s2,
                 start_color_lum=[0,0,0], end_color_lum=[0,0,0],
                 start_color_pol=[0.74,0.74,0.74], end_color_pol=[0.74, 0.74, 0.74])
        stop_loop = noisy_polarization_v1(win_lum, win_pol, exp_handler, p2, framerate=fr, dlp=dlp, code_on=b'1', code_off=b'Q')
        if stop_loop: break
        # gray -> gray
        reset_screen(win_lum, win_pol,
                 ramp_time=1, hold_time=1, framerate=fr, stim_size_lum=s1, stim_size_pol=s2,
                 start_color_lum=[0,0,0], end_color_lum=[0,0,0],
                 start_color_pol=[0.74,0.74,0.74], end_color_pol=[0.74, 0.74, 0.74])
    # gray -> black
    reset_screen(win_lum, win_pol,
                 ramp_time=3, hold_time=3, framerate=fr, stim_size_lum=s1, stim_size_pol=s2,
                 start_color_lum=[0,0,0], end_color_lum=[-1,-1,-1],
                 start_color_pol=[0.74,0.74,0.74], end_color_pol=[-1,-1,-1])
    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
    win_pol.close()
