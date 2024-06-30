from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("..")
from vstim import locally_sparse_noise, LocallySparseNoiseParams
from vstim import drifting_gratings, DriftingGratingsParams
from vstim import temporal_chirp, TemporalChirpParams
from vstim import reset_screen

if __name__ == "__main__":

    ###### PARAMETERS BEGIN ######
    exp_name = "squid1_rec4"
    logdir = r"D:\experiments\20240620"
    com_port = "COM3" # for DLP-IO8-G
    num_cycles = 3
    p1 = LocallySparseNoiseParams(
        npy_filepath=r"C:\Users\tomoy\Documents\visual_stim\20240613_LSN_matrix\LSN_5d0DEG.npy",
        stim_time=1.0,
        stim_mode="on_only"
    )
    p2 = LocallySparseNoiseParams(
        npy_filepath=r"C:\Users\tomoy\Documents\visual_stim\20240613_LSN_matrix\LSN_5d0DEG.npy",
        stim_time=1.0,
        stim_mode="off_only"
    )
    p3 = DriftingGratingsParams(
        SFs=[0.015],
        TFs=[0, 3.0, 5.0],
        ORIs=[0, 45, 90, 135, 180, 225, 270, 315],
        texture='sqr',
        repeats=15,
        t1=1.0,
        t2=1.5,
        t3=0.0,
        stim_size=[2000, 2000],
        stim_pos=[0, 0]
    )
    p4 = TemporalChirpParams(
        f0=0.5,
        f1=10,
        method="logarithmic",
        repeats=15,
        trial_time=8,
        interval_time=5
    )
    ###### PARAMETERS END ######

    # initialize DLP-IO8-G
    dlp = Serial(port=com_port, baudrate=115200)

    win = visual.Window(monitor='DLP3010EVM-LC', size=[1280,720],
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
    
    time.sleep(5.0) # wait 5 sec before proceeding
    for cycle in range(num_cycles):
        log_filename =  os.path.join(logdir, f"log_{exp_name}_LSNON_cycle{cycle}")
        exp_handler = data.ExperimentHandler(name=exp_name, version='', extraInfo={}, runtimeInfo=None, dataFileName=log_filename, saveWideText=True, savePickle=False)
        locally_sparse_noise(win, exp_handler, p1, dlp=dlp, code_on=b'1', code_off=b'Q')
        exp_handler.close()
        reset_screen(win, start_color=[-1,-1,-1], end_color=[1,1,1], ramp_time=3, hold_time=2)

        log_filename =  os.path.join(logdir, f"log_{exp_name}_LSNOFF_cycle{cycle}")
        exp_handler = data.ExperimentHandler(name=exp_name, version='', extraInfo={}, runtimeInfo=None, dataFileName=log_filename, saveWideText=True, savePickle=False)
        locally_sparse_noise(win, exp_handler, p2, dlp=dlp, code_on=b'1', code_off=b'Q')
        exp_handler.close()
        reset_screen(win, start_color=[1,1,1], end_color=[0,0,0], ramp_time=3, hold_time=2)

        log_filename =  os.path.join(logdir, f"log_{exp_name}_DRG_cycle{cycle}")
        exp_handler = data.ExperimentHandler(name=exp_name, version='', extraInfo={}, runtimeInfo=None, dataFileName=log_filename, saveWideText=True, savePickle=False)
        drifting_gratings(win, exp_handler, p3, dlp=dlp, code_on=b'1', code_off=b'Q')
        exp_handler.close()
        reset_screen(win, start_color=[0,0,0], end_color=[0,0,0], ramp_time=3, hold_time=2)

        log_filename =  os.path.join(logdir, f"log_{exp_name}_TCHIRP_cycle{cycle}")
        exp_handler = data.ExperimentHandler(name=exp_name, version='', extraInfo={}, runtimeInfo=None, dataFileName=log_filename, saveWideText=True, savePickle=False)
        temporal_chirp(win, exp_handler, p4, dlp=dlp, code_on=b'1', code_off=b'Q')
        exp_handler.close()
        reset_screen(win, start_color=[0,0,0], end_color=[-1,-1,-1], ramp_time=3, hold_time=2)

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win.close()
