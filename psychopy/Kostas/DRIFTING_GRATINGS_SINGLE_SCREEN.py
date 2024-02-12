 #### Script for generating drifting gratings of various temporal fr, spatial fr, and orientation for ephys experiments ####


from psychopy import sound, gui, visual, core, data, event, logging, clock
import numpy as np
#import matplotlib
#import matplotlib.pyplot as plt
#matplotlib.use('Qt5Agg')  # change this to control the plotting 'back end' 
#import pylab
import os
from serial import Serial
com_port="COM4"
dlp=Serial(port=com_port,baudrate=115200)

exp_type='LUM' #either LUM or POL


#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
###### Logging Data ######
_thisDir=os.path.dirname(os.path.abspath(__file__))
os.chdir(_thisDir)
expName='DRIFTING_GRATINGS_EXP_{}'.format(exp_type) 
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
#############################################################################################################################
#############################################################################################################################
#############################################################################################################################


if exp_type=='LUM':
    PH_x_LOC=+640
    MONITOR='TI_projector'
elif exp_type=='POL':
    PH_x_LOC=-640
    MONITOR='LCD_pol_screen'



win=visual.Window(monitor=MONITOR,fullscr=True,screen=0,units='pix',color=[0,0,0],allowGUI=True, waitBlanking=False)
PHOTODIODE=visual.Rect(win,pos=[PH_x_LOC,-350],width=100,height=100,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS=visual.Rect(win,pos=[PH_x_LOC,-350],width=150,height=150,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS.color=[-1,-1,-1] # This needs to be specifiec again, for whatever buggy reason
GRAT_1=visual.GratingStim(win=win,pos=[0,-0],units='pix',size=[3000,3000],phase=(0.5,0.5)) 
phaseclock=core.Clock() # Will be used to as input to the grating phase
condition_clock=core.Clock() # Will be used as counter for trials
frame_rate = win.getActualFrameRate()


##### Exp Parameters ###### # DEFINING TEST VALUES for spatial frequency (SF), temporal frequency(phase*** check psychopy doc), and orientation (degrees)
SFs=[0.005,0.015,0.03,0.07,0.1]
TFs=[0,1.5,3,7]
ORIs=[0,45,90,135,180,225,270,315]
N_REPEATS=15 # Number of all combinations of conditions to be displayed
TRIAL_T=1.0    # seconds ##### This can result in incosistent times (eg sometimes ~0.2, sometimes ~0.215). Should probably request this stimulus in frames rather than in ms. (Holds true for all stimuli, modify if required)
MEAN_LUM_T=0.0 # seconds
CONDITION_LIST=[[i,j,k] for i in SFs for j in TFs for k in ORIs]
trial_frames=int(np.round(frame_rate*TRIAL_T))
gray_frames=int(np.round(frame_rate*MEAN_LUM_T))
initial_phase=(1/2)*2*np.pi #This is to ensure that that static gratings of 0 SF (if it exists) is gray

###### Initiate Stimulus ########
photodiode_c=1 #To swap photodiode colour
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
win.flip()
dlp.write(b'Q')
event.waitKeys()
frame_counter=0
stop_loop=False
cond_counter=0    
phaseclock.reset()
condition_clock.reset()

for REP in range(N_REPEATS):
    np.random.shuffle(CONDITION_LIST) # Randomise order of conditions
    cond_counter=0    
    for c in range(int(len(CONDITION_LIST))):
        GRAT_1.sf=CONDITION_LIST[cond_counter][0]
        GRAT_1.ori=CONDITION_LIST[cond_counter][2]
        photodiode_c+=1
        PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
        thisExp.addData('SF',CONDITION_LIST[cond_counter][0])
        thisExp.addData('TF',CONDITION_LIST[cond_counter][1])
        thisExp.addData('Ori',CONDITION_LIST[cond_counter][2])
        thisExp.addData('frame',frame_counter)
        thisExp.addData('frame_time',phaseclock.getTime()) # Keep track of your clocks, don't forget to swap if needed
       
        condition_clock.reset()
        if c%2==0:
            dlp.write(b'1')
        else:
            dlp.write(b'Q')
        for frame in range(trial_frames):
            GRAT_1.phase=initial_phase+CONDITION_LIST[cond_counter][1]*phaseclock.getTime()
            GRAT_1.draw()
            PHOTODIODE_BOUNDS.draw()
            PHOTODIODE.draw()
            win.flip()

            frame_counter+=1
        cond_counter+=1
        condition_clock.reset()
            
        ##### Don't place this elsewhere, will not break loop properly
        keys=event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
            break
        event.clearEvents()
        #####
        thisExp.nextEntry() # Forget to add this line if you want to lose your conditions!
    if stop_loop==True:
        break

        
photodiode_c+=1
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]        
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
if c%2==0:
    dlp.write(b'Q')
else:
    dlp.write(b'1')
win.flip()
event.waitKeys()



if LOG_DATA==True:
    thisExp.saveAsWideText(filename+'.csv',delim='auto')
