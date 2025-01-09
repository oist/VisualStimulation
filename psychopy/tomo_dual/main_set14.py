from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim_dual import texture_stim, TextureStimParams
from vstim import reset_screen3

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "rec7"
    logdir = r"D:\experiments\20250109"
    repeats = 8
    p1 = TextureStimParams(
        imgdir=r"C:\Users\tomoy\Documents\visual_stim\20250106_texture_sam",
        patterns=[0, 3, 5, 7, 8],
        variations=[0, 1, 2, 3, 4, 5, 6, 7],
        t1=1.5,
        t2=1.5,
        blank_color=[0.0, 0.0, 0.0],
        lum_stim_size=[1280, 720],
        lum_stim_pos=[0, 0], # center position of the luminance stimuli
        pol_stim_size=[657, 364], # size of the polarization stimuli
        pol_stim_pos=[0, 0], # center position of the polarization stimuli; portrait mode
        pol_background_value=0.783
    )
    com_port = "COM3" # for DLP-IO8-G
    ###### PARAMETERS END ######

    # initialize DLP-IO8-G
    dlp = Serial(port=com_port, baudrate=115200)

    now = datetime.now()
    dt_string = now.strftime("%Y%m%d_%H%M%S")
    log_filename =  os.path.join(logdir, f"log_{exp_name}_{dt_string}")
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
            event.clearEvents()
            break

    # black -> gray
    reset_screen3(win_lum, start_color=[-1,-1,-1], end_color=[0, 0, 0], ramp_time=3, hold_time=3, framerate=fr, stim_size=s1)
    for rep in range(repeats):
        p1.random_seed = rep
        stop_loop = texture_stim(win_lum, win_pol, exp_handler, p1, framerate=fr, dlp=dlp, code_on=b'1', code_off=b'Q')
        if stop_loop: break
    # gray -> black
    reset_screen3(win_lum, start_color=[0,0,0], end_color=[-1,-1,-1], ramp_time=3, hold_time=3, framerate=fr, stim_size=s1)

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
    win_pol.close()
