from psychopy import visual
import os
import numpy as np

def reset_screen(win_lum, win_pol, start_color, end_color, ramp_time, hold_time, stim_size=[1280, 720], stim_pos=[0,0]):
    start_color = np.array(start_color)
    end_color = np.array(end_color)
    framerate = win.getActualFrameRate()
    ramp_frames = int(ramp_time * framerate) # convert secs to frames
    hold_frames = int(hold_time * framerate) # convert secs to frames
    stim = visual.ImageStim(win, size=stim_size, pos=stim_pos)

    for i in range(ramp_frames):
        c = start_color * (ramp_frames - i) / ramp_frames + end_color * i / ramp_frames
        c = c.clip(-1,1).astype("float")
        image = c * np.ones((1,1))
        stim.setImage(image)
        stim.draw()
        win.flip()
    for i in range(hold_frames):
        image = end_color * np.ones((1,1))
        stim.setImage(image)
        stim.draw()
        win.flip()
