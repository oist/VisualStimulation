from psychopy import visual, event, core
import numpy as np

if __name__ == "__main__":
    """
    This is a simple function to calibrate the positions of the image stimuli on the LCD screen.
    """
    ###### PARAMETERS BEGIN ######
    increment = 2
    win_pos = [70, 325]
    win_size = [647, 368]
    ###### PARAMETERS END ########

    win_lum = visual.Window(monitor='test', size=[1280,720],
                            fullscr=True, screen=2,
                            units='pix', color=[1,1,1], allowGUI=False, waitBlanking=True)
    win_pol = visual.Window(monitor='test', size=win_size, pos=win_pos,
                            fullscr=False, screen=1,
                            units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)

    # draw white full screen rectangle on lum screen
    rect = visual.rect.Rect(win=win_lum, pos=[0,0], size=[1280, 720], fillColor=[1,1,1])
    rect.draw()
    rect2 = visual.rect.Rect(win=win_pol, size=[600, 700], fillColor=[1,1,1])
    rect2.draw()
    win_lum.flip()
    win_pol.flip()

    while True:
        keys = event.getKeys()
        if keys:
            if keys[0] == "a":
                win_pos = [win_pos[0] - increment, win_pos[1]]
            elif keys[0] == "d":
                win_pos = [win_pos[0] + increment, win_pos[1]]
            elif keys[0] == "s":
                win_pos = [win_pos[0], win_pos[1] - increment]
            elif keys[0] == "w":
                win_pos = [win_pos[0], win_pos[1] + increment]
            elif keys[0] == "j":
                win_size = [win_size[0] - increment, win_size[1]]
            elif keys[0] == "l":
                win_size = [win_size[0] + increment, win_size[1]]
            elif keys[0] == "i":
                win_size = [win_size[0], win_size[1] + increment]
            elif keys[0] == "k":
                win_size = [win_size[0], win_size[1] - increment]
            elif keys[0] in ['q','escape']:
                break
            win_pol.close()
            win_pol = visual.Window(monitor='test', size=win_size, pos=win_pos,
                                    fullscr=False, screen=1,
                                    units='pix', color=[-1,-1,-1], allowGUI=False, waitBlanking=True)
            rect2 = visual.rect.Rect(win=win_pol, size=[2000, 2000], fillColor=[1,1,1])
            rect2.draw()
            win_pol.flip()
            core.wait(0.1)
            print(win_pos, win_size)

    win_lum.close()
    win_pol.close()
