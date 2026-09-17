from psychopy import visual, event
import numpy as np

if __name__ == "__main__":
    """
    This is a function to calibrate LCD pixel value with the absolute polarization angle.
    The projector always displays white screen.
    The pixel values in LCD is changed from 0 to 255 with a increment of X.n
    Hit "n" key to go to the next pixel value.
    """
    ###### PARAMETERS BEGIN ######
    brightness = -1
    ###### PARAMETERS END ########

    win_lum = visual.Window(monitor='DLP3010EVM-LC', size=[1280,720],
                            fullscr=True, screen=0,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
    image_lum = brightness * np.ones((3,) + win_lum.size)
    stim_lum = visual.ImageStim(win_lum, image=image_lum, size=win_lum.size)
    while True:
        stim_lum.draw()
        win_lum.flip()
        keys = event.getKeys()
        if any(k in ['n', 'escape'] for k in keys):
            break

    win_lum.close()
