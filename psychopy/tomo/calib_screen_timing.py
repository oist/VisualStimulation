from psychopy import visual, event
import numpy as np
from serial import Serial

if __name__ == "__main__":
    """
    This script is used to calibrate the timing between TTL pulse, projector refresh and LCD screen refresh.
    On the projector, this script shows half black and half white image for X frames, and full white image for Y frames.
    In sync, this script shows on the LCD a full black for X frames and full white image for Y frames.
    Place two detectors, one in front of the projector (detecting left half of the image) and one in front of the LCD (detecting right half of the image).
    
    From the DAQ device, collect pulses from (1) DLP-IO8-G (2) pulse from photodetector #1 (projector) (3) pulse from photodetector #2 (LCD).
    By analyzing the timings of each TTL pulses, you can measure the delay.
    """
    ###### PARAMETERS BEGIN ######
    num_repeats = 10
    on_frames = 30
    off_frames = 30
    code_on = b'1'
    code_off = b'Q'
    com_port = "COM3" # for DLP-IO8-G
    ###### PARAMETERS END ########

    # initialize DLP-IO8-G
    dlp = Serial(port=com_port, baudrate=115200)

    win_lum = visual.Window(monitor='projector', size=[1280,720],
                            fullscr=True, screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    win_pol = visual.Window(monitor='test', size=[1280,800],
                            fullscr=True, screen=2,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    # initialize matrix shown on the screens
    image_lum = np.zeros(win_lum.size)
    image_pol = np.zeros(win_pol.size)

    # main loop
    for rep in range(num_repeats):
        print("Image (lum): Left half = ON, Right half = ON")
        print("Image (pol): Whole screen ON")
        image_lum[:, int(image_lum.shape[1]/2):] = 1
        image_lum[:, :int(image_lum.shape[1]/2)] = 1
        image_pol[:, :] = 1
        stim_lum = visual.ImageStim(win_lum, image=image_lum, size=win_lum.size)
        stim_pol = visual.ImageStim(win_pol, image=image_pol, size=win_pol.size)
        for i in range(on_frames):
            if dlp is not None:
                dlp.write(code_on) # TTL HIGH
            stim_lum.draw()
            stim_pol.draw()
            win_lum.flip()
            win_pol.flip()

        print("Image (lum): Left half = ON, Right half = OFF")
        print("Image (pol): Whole screen OFF")
        image_lum[:, int(image_lum.shape[1]/2):] = 1
        image_lum[:, :int(image_lum.shape[1]/2)] = -1
        image_pol[:, :] = -1
        stim_lum = visual.ImageStim(win_lum, image=image_lum, size=win_lum.size)
        stim_pol = visual.ImageStim(win_pol, image=image_pol, size=win_pol.size)
        for i in range(off_frames):
            if dlp is not None:
                dlp.write(code_off) # TTL LOW
            stim_lum.draw()
            stim_pol.draw()
            win_lum.flip()
            win_pol.flip()

        # stop if 'q' or 'escape' keys are hit
        keys = event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
        else:
            stop_loop = False
        event.clearEvents()
        if stop_loop==True:
            break

    win_lum.close()
    win_pol.close()
