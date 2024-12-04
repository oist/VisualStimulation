from psychopy import visual, event
import numpy as np

if __name__ == "__main__":
    """
    The pixel values in projector image is changed from 0 to 255 with a increment of X.
    Hit "n" key to go to the next pixel value.
    """
    ###### PARAMETERS BEGIN ######
    steps = 20
    ###### PARAMETERS END ########

    win_lum = visual.Window(monitor='DLP3010EVM-LC', size=[1280,720],
                            fullscr=True, screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    # initialize matrix shown on the screens
    image_lum = np.zeros(win_lum.size)

    for i in np.linspace(0, 255, steps):
        print("pixel value:", i)
        image_lum[:] = (i / 127) - 1.0
        stim_lum = visual.ImageStim(win_lum, image=image_lum, size=win_lum.size)
        while True:
            stim_lum.draw()
            win_lum.flip()
            keys = event.getKeys()
            if any(k in ['n'] for k in keys):
                break

    win_lum.close()
    win_pol.close()
