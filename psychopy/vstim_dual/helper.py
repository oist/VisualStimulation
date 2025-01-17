from psychopy import visual
import os
import numpy as np

def reset_screen(win_lum, win_pol, start_color_lum, end_color_lum, start_color_pol, end_color_pol,
                ramp_time, hold_time,
                stim_size_lum=None, stim_pos_lum=[0,0], stim_size_pol=None, stim_pos_pol=[0,0], framerate=60):
    """
    """
    start_color_lum, end_color_lum = np.array(start_color_lum), np.array(end_color_lum)
    start_color_pol, end_color_pol = np.array(start_color_pol), np.array(end_color_pol)
    ramp_frames = int(ramp_time * framerate) # convert secs to frames
    hold_frames = int(hold_time * framerate) # convert secs to frames
    rect_lum = visual.rect.Rect(win=win_lum, size=stim_size_lum, pos=stim_pos_lum)
    rect_pol = visual.rect.Rect(win=win_pol, size=stim_size_pol, pos=stim_pos_pol)

    for i in range(ramp_frames):
        c1 = start_color_lum * (ramp_frames - i) / ramp_frames + end_color_lum * i / ramp_frames
        c1 = c1.clip(-1,1).astype("float")
        rect_lum.fillColor = c1
        c2 = start_color_pol * (ramp_frames - i) / ramp_frames + end_color_pol * i / ramp_frames
        c2 = c2.clip(-1,1).astype("float")
        rect_pol.fillColor = c2
        rect_lum.draw()
        rect_pol.draw()
        win_lum.flip()
        win_pol.flip()

    for i in range(hold_frames):
        rect_lum.fillColor = end_color_lum
        rect_pol.fillColor = end_color_pol
        rect_lum.draw()
        rect_pol.draw()
        win_lum.flip()
        win_pol.flip()

