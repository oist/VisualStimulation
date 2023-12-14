##### MOVIE_CLIP_REPEAT

from psychopy import sound, gui, visual, core, data, event, logging, clock
import numpy as np
import os
from serial import Serial

com_port="COM4"
dlp=Serial(port=com_port,baudrate=115200)

###### Logging Data ######
_thisDir=os.path.dirname(os.path.abspath(__file__))
os.chdir(_thisDir)
expName='MOVIE_CLIP' 
expInfo={} # If I need to save specific details (e.g. framerate, date, etc) append here as dictionary key-values
saving_name='{}_{}'.format(expName,data.getDateStr()) # Use to create folders+files
_DirToSave='logging_folder/'+saving_name     # Replace when changing computer
LOG_DATA=True #### Switch if you want output file with variables logged
if LOG_DATA==True:
    os.mkdir(_DirToSave)
filename=_DirToSave+'/'+saving_name # To be used in the psychopy's experiment handler
thisExp=data.ExperimentHandler(name=expName,version='',extraInfo=expInfo,runtimeInfo=None,dataFileName=filename,saveWideText=False,savePickle=False)  # Data handler. Psychopy tool to store logging data.
if LOG_DATA==True:
    logFile = logging.LogFile(filename+'.log', level=logging.EXP)



win=visual.Window(monitor='TI_projector',fullscr=True,screen=1,units='pix',color=[0,0,0],allowGUI=False, waitBlanking=True)
PHOTODIODE=visual.Rect(win,pos=[640,-350],width=150,height=150,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS=visual.Rect(win,pos=[640,-350],width=250,height=250,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS.color=[-1,-1,-1] # This needs to be specifiec again, for whatever buggy reason
phaseclock=core.Clock() # Will be used to as input to the grating phase
SQUID_POS=[0,0] 



# Define the folder path containing your PNG frames
folder_path = "output_frames/"
frame_files = sorted([file for file in os.listdir(folder_path) if file.endswith('.png')])
image = visual.ImageStim(win=win, pos=[SQUID_POS[0],SQUID_POS[1]], size=[1280,720],units='pix')
frame_duration = 1.0 / 30.0  # 30 Hz
frames_per_frame = round(frame_duration * 60)  # Assuming a 60 Hz monitor
frame_counter=0

# Loop through frames
photodiode_c=1 #To swap photodiode colour
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
dlp.write(b'Q')
win.flip()
event.waitKeys()
stop_loop=False
for repeat in range(30):
    photodiode_c+=1
    PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
    dlp.write(b'1')
    for frame_file in frame_files:
        image.image = os.path.join(folder_path, frame_file)
        thisExp.addData('frame',frame_counter)
        thisExp.addData('frame_time',phaseclock.getTime()) # Keep track of your clocks, don't forget to swap if needed
        # Present the frame for the specified number of frames
        for _ in range(frames_per_frame):
            image.draw()
            PHOTODIODE_BOUNDS.draw()
            PHOTODIODE.draw()
            win.flip()
            frame_counter+=1
    photodiode_c+=1
    PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
    dlp.write(b'Q')
    for frame in range(15):
        PHOTODIODE_BOUNDS.draw()
        PHOTODIODE.draw()
        win.flip()
        keys=event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
            break
        event.clearEvents()
            #####
    #        thisExp.nextEntry() # Forget to add this line if you want to lose your conditions!
    thisExp.nextEntry() # Forget to add this line if you want to lose your conditions!
    if stop_loop==True:
        break

photodiode_c+=1
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]        
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
dlp.write(b'1')
win.flip()
event.waitKeys()

# Close the PsychoPy window at the end
win.close()

if LOG_DATA==True:
    thisExp.saveAsWideText(filename+'.csv',delim='auto')
