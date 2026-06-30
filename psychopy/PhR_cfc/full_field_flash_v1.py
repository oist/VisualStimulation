from psychopy import visual, data, event, logging
import os, time
from datetime import datetime
from serial import Serial
import numpy as np

if __name__ == "__main__":
    """
    """

    ###### PARAMETERS BEGIN ######
    exp_name = "rec3"
    logdir = r"D:\experiments\20260608"
    repeats = 10
    fg_values = [-1, -.98, -.96, -.94, -.92, -.90, -.88, -.86, -.84, -.82]
    fg_values = [-1, -.95, -.90, -.85, -.80, -.75, -.70, -.65, -.60, -.55]
    bg = -1
    t1 = 2.0
    t2 = 2.0
    monitor_name = "DLP3010EVM-LC"
    com_port = "COM3" # for DLP-IO8-G
    code_on = b'1'
    code_off = b'Q'
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

    # initialize projector
    win_lum = visual.Window(monitor=monitor_name, size=[1280,720], screen=1, fullscr=True,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    framerate = win_lum.getActualFrameRate()
    rect = visual.rect.Rect(win=win_lum, size=[1280,720], pos=[0,0])

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

    frame_counter = 0
    stop_loop = False
    if dlp is not None:
        dlp.write(code_off)

    time.sleep(5.0)

    for rep in range(repeats):
        conditions = np.random.permutation(fg_values)
        if stop_loop == True:
            break
        for fg in conditions:
            exp_handler.addData('frame', frame_counter)
            exp_handler.addData('rep', rep)
            exp_handler.addData('fg', fg)
            exp_handler.nextEntry()

            # OFF state
            for i in range(int(t1 * framerate)):
                frame_counter += 1
                rect.fillColor = (bg, bg, bg)
                rect.draw()
                win_lum.flip()

            # ON state
            for i in range(int(t2 * framerate)):
                if dlp is not None:
                    if i == 0:
                        dlp.write(code_on)
                    else:
                        dlp.write(code_off)
                frame_counter += 1
                rect.fillColor = (fg, fg, fg)
                rect.draw()
                win_lum.flip()

            keys = event.getKeys()
            if any(k in ['q','escape'] for k in keys):
                stop_loop = True
                break
    
    # back to background color
    rect.fillColor = (bg, bg, bg)
    rect.draw()
    win_lum.flip()

    # post stimulation sleep
    time.sleep(5.0)

    # using channel 3, send TTL to DAQ to notify the completion of the session
    dlp.write(b'3')
    time.sleep(0.1)
    dlp.write(b'E')
    dlp.close()

    exp_handler.close()
    win_lum.close()
