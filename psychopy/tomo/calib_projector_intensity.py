from psychopy import visual, event
import numpy as np

if __name__ == "__main__":
    """
    The pixel values in projector image is changed from 0 to 255 with a increment of X.
    Hit "n" key to go to the next pixel value.
    """
    ###### PARAMETERS BEGIN ######
    increment = 10
    ###### PARAMETERS END ########

    win_lum = visual.Window(monitor='projector', size=[1280,720],
                            fullscr=True, screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    win_pol = visual.Window(monitor='LCD', size=[1280,800],
                            fullscr=True, screen=2,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    # initialize matrix shown on the screens
    image_lum = np.zeros(win_lum.size)
    image_pol = np.zeros(win_pol.size)

    for i in range(0, 255, increment):
        print("LCD pixel value:", i)
        image_pol[:] = 1
        image_lum[:] = (i / 127) - 1.0
        stim_lum = visual.ImageStim(win_lum, image=image_lum, size=win_lum.size)
        stim_pol = visual.ImageStim(win_pol, image=image_pol, size=win_pol.size)
        while True:
            stim_lum.draw()
            stim_pol.draw()
            win_lum.flip()
            win_pol.flip()
            keys = event.getKeys()
            if any(k in ['n'] for k in keys):
                break

    win_lum.close()
    win_pol.close()
