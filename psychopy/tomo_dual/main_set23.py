from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim_dual import dual_locally_sparse_noise, DualLocallySparseNoiseParams
from vstim import reset_screen3

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "rec4"
    logdir = r"D:\experiments\20250303"
    com_port = "COM3" # for DLP-IO8-G
    # luminance LSN, unpolarized background, 2 degree
    repeats = 1
    p1 = DualLocallySparseNoiseParams(
        mode="lum_only",
        npy_filepath=r"C:\Users\tomoy\Documents\visual_stim\20241021_LSN_matrix\LSN_2DEG.npy",
        stim_time=1.0,
        binary=False,
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0],
        lum_stim_value=1,
        lum_background_value=0,
        pol_stim_size=[1024, 768], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_stim_value=(220-128)/128,
        pol_background_value=(220-128)/128,
        pol_flip_horiz=True,
        pol_flip_vert=False,
    )
    # luminance LSN, unpolarized background, 4 degree
    p2 = DualLocallySparseNoiseParams(
        mode="lum_only",
        npy_filepath=r"C:\Users\tomoy\Documents\visual_stim\20241021_LSN_matrix\LSN_4DEG.npy",
        stim_time=1.0,
        binary=False,
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0],
        lum_stim_value=1,
        lum_background_value=0,
        pol_stim_size=[1024, 768], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_stim_value=(220-128)/128,
        pol_background_value=(220-128)/128,
        pol_flip_horiz=True,
        pol_flip_vert=False,
    )
    # luminance LSN, unpolarized background, 8 degree
    p3 = DualLocallySparseNoiseParams(
        mode="lum_only",
        npy_filepath=r"C:\Users\tomoy\Documents\visual_stim\20241024_LSN_matrix\LSN_8DEG.npy",
        stim_time=1.0,
        binary=False,
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0],
        lum_stim_value=1,
        lum_background_value=0,
        pol_stim_size=[1024, 768], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_stim_value=(220-128)/128,
        pol_background_value=(220-128)/128,
        pol_flip_horiz=True,
        pol_flip_vert=False,
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

    win_lum = visual.Window(monitor='test', size=[1280,720], screen=2,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    win_pol = visual.Window(monitor='test', size=[1024, 768], pos=[0, 0], screen=1, fullscr=True,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

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
    reset_screen3(win_lum, start_color=[-1,-1,-1], end_color=[0, 0, 0], ramp_time=3, hold_time=0, framerate=fr, stim_size=s1)
    for rep in range(repeats):
        # gray -> gray
        reset_screen3(win_lum, start_color=[0,0,0], end_color=[0,0,0], ramp_time=3, hold_time=2, framerate=fr, stim_size=s1)
        stop_loop = dual_locally_sparse_noise(win_lum, win_pol, exp_handler, p1, framerate=fr, dlp=dlp, code_on=b'1', code_off=b'Q')
        if stop_loop: break
        # gray -> gray
        reset_screen3(win_lum, start_color=[0,0,0], end_color=[0, 0, 0], ramp_time=3, hold_time=2, framerate=fr, stim_size=s1)
        stop_loop = dual_locally_sparse_noise(win_lum, win_pol, exp_handler, p2, framerate=fr, dlp=dlp, code_on=b'1', code_off=b'Q')
        if stop_loop: break
        # gray -> gray
        reset_screen3(win_lum, start_color=[0,0,0], end_color=[0,0,0], ramp_time=3, hold_time=2, framerate=fr, stim_size=s1)
        stop_loop = dual_locally_sparse_noise(win_lum, win_pol, exp_handler, p3, framerate=fr, dlp=dlp, code_on=b'1', code_off=b'Q')
        if stop_loop: break
    # gray -> black
    reset_screen3(win_lum, start_color=[0,0,0], end_color=[-1,-1,-1], ramp_time=5, hold_time=5, framerate=fr, stim_size=s1)

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
    win_pol.close()
