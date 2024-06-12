from psychopy import visual, core, event, logging, clock
import os
import numpy as np

def show_interval(win, interval_secs, color):
    framerate = win.getActualFrameRate()
    interval_frames = int(interval_secs * framerate) # convert secs to frames
    for i in range(interval_frames):
        win.color = color
        win.flip()

def reset_screen(win, start_color, end_color, ramp_time, hold_time):
    start_color = np.array(start_color)
    end_color = np.array(end_color)
    framerate = win.getActualFrameRate()
    ramp_frames = int(ramp_time * framerate) # convert secs to frames
    hold_frames = int(hold_time * framerate) # convert secs to frames

    for i in range(ramp_frames):
        c = start_color * (ramp_frames - i) / ramp_frames + end_color * i / ramp_frames
        c = c.clip(-1,1).astype("float")
        win.color = c
        win.flip()
    for i in range(hold_frames):
        win.color = end_color
        win.flip()
