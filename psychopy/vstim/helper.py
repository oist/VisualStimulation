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

def reset_screen2(win, start_color, end_color, ramp_time, hold_time, stim_size=None, stim_pos=[0,0]):
    if stim_size is None:
        stim_size = win.size
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


def reset_screen3(win, start_color, end_color, ramp_time, hold_time, stim_size=None, stim_pos=[0,0], framerate=60):
    if stim_size is None:
        stim_size = win.size
    start_color = np.array(start_color)
    end_color = np.array(end_color)
    ramp_frames = int(ramp_time * framerate) # convert secs to frames
    hold_frames = int(hold_time * framerate) # convert secs to frames

    for i in range(ramp_frames):
        c = start_color * (ramp_frames - i) / ramp_frames + end_color * i / ramp_frames
        c = c.clip(-1,1).astype("float")
        rect = visual.rect.Rect(win=win, size=stim_size, pos=stim_pos,
                                fillColor=c)
        rect.draw()
        win.flip()
    for i in range(hold_frames):
        rect = visual.rect.Rect(win=win, size=stim_size, pos=stim_pos,
                                fillColor=end_color)
        rect.draw()
        win.flip()
