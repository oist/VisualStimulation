from psychopy import visual, data, event, logging, core
import os, time
from datetime import datetime
from serial import Serial

import sys
sys.path.append("../psychopy/")
from vstim import reset_screen3

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "test"
    logdir = r"D:\experiments\20250317"
    com_port = "COM3" # for DLP-IO8-G
    repeats = 2
    movies= [
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\squid_disappear.mp4",
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\yellowspotted_treval.mp4",
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\squid_in_the_morning_2.mp4",
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\mystery_ghost_leaf.mp4",
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\squid_fleet.mp4",
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\shark_revisited.mp4",
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\pelagic_squid.mp4",
        r"C:\Users\tomoy\Documents\visual_stim\20250922_natural_movie\barrel_oik.mp4",
    ]
    offsets = [
        0.0,
        3.0,
        25.0,
        0.0,
        2.0,
        0.0,
        1.0,
        0.0,
        0.0
    ]
    durations = [
        10.0,
        10.0,
        10.0,
        10.0,
        10.0,
        10.0,
        10.0,
        10.0,
        10.0
    ]
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

    mvs = []
    for i in range(len(movies)):
        movie = visual.MovieStim3(
            win_lum,
            filename=movies[i],
            size=None,
            pos=(0, 0),
            flipVert=False,
            flipHoriz=False,
            loop=False,
            noAudio=True,
            autoLog=False,
        )
        # resize movie
        screen_w, screen_h = win_lum.size
        movie_w, movie_h = movie.size
        scale = min(screen_w / movie_w, screen_h / movie_h)
        scaled_size = (int(movie_w * scale), int(movie_h * scale))
        movie.size = scaled_size
        mvs.append(movie)

    # constant polarization
    rect = visual.rect.Rect(win=win_pol, pos=[0, 0], size=[1024, 768],
                            fillColor=[(220-128)/128, (220-128)/128, (220-128)/128,])
    rect.draw()
    win_pol.flip()

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
    reset_screen3(win_lum, start_color=[-1,-1,-1], end_color=[0,0,0], ramp_time=3, hold_time=5, framerate=fr, stim_size=s1)
    
    frame_counter = 0
    stop_loop = False
    for rep in range(repeats):
        for i in range(len(movies)):
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('movie', i)
            exp_handler.addData('rep', rep)
            exp_handler.nextEntry()
            movie = mvs[i]
            offset = offsets[i]
            duration = durations[i]
            movie.reset()
            movie.seek(offset)
            movie.play()
            n_frames = int(duration * win_lum.getActualFrameRate())
            for i in range(n_frames):
                frame_counter += 1
                if i == 0:
                    dlp.write(b'1')
                else:
                    dlp.write(b'Q')
                movie.draw()
                win_lum.flip()

                # exit early
                if any(k in ['q','escape'] for k in event.getKeys()):
                    stop_loop = True
                if stop_loop:
                    break
            if stop_loop:
                break
        if stop_loop:
            break
    # gray -> black
    reset_screen3(win_lum, start_color=[-1,-1,-1], end_color=[-1,-1,-1], ramp_time=3, hold_time=5, framerate=fr, stim_size=s1)

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
    win_pol.close()
