from psychopy import visual, data, event, logging
import os
from vstim import drifting_gratings, DriftingGratingsParams
from serial import Serial

if __name__ == "__main__":
    logdir = os.path.dirname(os.path.abspath(__file__))
    logfile = os.path.join(logdir, "log_raw.log")
    exp_name = "test"

    # initialize DLP-IO8-G
    dlp = Serial(port="COM3", baudrate=115200)

    # this is to log all events
    log_file = logging.LogFile(os.path.join(logdir, "log_raw.log"), level=logging.EXP)
    # this is to log important events
    exp_handler = data.ExperimentHandler(name=exp_name, version='',
                                        extraInfo={},
                                        runtimeInfo=None,
                                        dataFileName=os.path.join(logdir, "log.csv"),
                                        saveWideText=True,
                                        savePickle=False)

    win = visual.Window(monitor='projector', size=[2560,1440], 
                        fullscr=True, screen=1,
                        units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    p = DriftingGratingsParams(
        SFs=[0.01,0.03,0.05,0.07,0.1],
        TFs=[1,3,5,7,12],
        ORIs=[0,45,90,135,180],
        repeats=5, # number of repeats
        trial_time=3, # seconds
        interval_time=2 # seconds
    )

    # wait for TTL HIGH in channel 2 or keyboard input
    while True:
        dlp.write(b'S')  # request to read
        x = dlp.read(3).decode('utf-8')
        if x[0] == '1':
            break # the line is HIGH
        keys = event.getKeys()
        if keys:
            break

    drifting_gratings(win, exp_handler, p, dlp=dlp)

    exp_handler.close()
    win.close()
    dlp.close()
