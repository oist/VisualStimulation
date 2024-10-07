from psychopy import visual, event
import numpy as np

if __name__ == "__main__":
    """
    This is a simple function to calibrate the positions of the image stimuli on the LCD screen.
    """
    ###### PARAMETERS BEGIN ######
    increment = 5
    stim_pos = [-5, 110]
    stim_size = [647, 368]
    ###### PARAMETERS END ########

    win_lum = visual.Window(monitor='test', size=[1280,720],
                            fullscr=True, screen=2,
                            units='pix', color=[1,1,1], allowGUI=False, waitBlanking=True)
    win_pol = visual.Window(monitor='test', size=[1024,768],
                            fullscr=True, screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    while True:
        stim = visual.ImageStim(win_pol, image=np.ones((2,2)), size=stim_size, pos=stim_pos)
        stim.draw()
        win_pol.flip()
        win_lum.flip()
        keys = event.getKeys()
        if keys:
            if keys[0] == "a":
                stim_pos = [stim_pos[0] - increment, stim_pos[1]]
            elif keys[0] == "d":
                stim_pos = [stim_pos[0] + increment, stim_pos[1]]
            elif keys[0] == "s":
                stim_pos = [stim_pos[0], stim_pos[1] - increment]
            elif keys[0] == "w":
                stim_pos = [stim_pos[0], stim_pos[1] + increment]
            elif keys[0] == "j":
                stim_size = [stim_size[0] - increment, stim_size[1]]
            elif keys[0] == "l":
                stim_size = [stim_size[0] + increment, stim_size[1]]
            elif keys[0] == "i":
                stim_size = [stim_size[0], stim_size[1] + increment]
            elif keys[0] == "k":
                stim_size = [stim_size[0], stim_size[1] - increment]
            elif keys[0] in ['q','escape']:
                break
            print(stim_pos, stim_size)
    win_lum.close()
    win_pol.close()
