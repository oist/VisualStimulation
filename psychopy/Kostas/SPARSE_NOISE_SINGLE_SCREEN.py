from psychopy import sound, gui, visual, core, data, event, logging, clock
import numpy as np
from serial import Serial
#import matplotlib
#import matplotlib.pyplot as plta
#matplotlib.use('Qt5Agg')  # change this to control the plotting 'back end'
#import pylab
import os
avail_deg=[2,2.4,3,3.4,4.5,5]
deg_size=4.0
Acer_deg_pix=12.8
com_port="COM4"
dlp=Serial(port=com_port,baudrate=115200)
 
 
exp_type='LUM' #either LUM or POL

#if deg_size not in avail_deg: #temporary
#    deg_size=avail_deg[2]
#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
###### Logging Data ######
_thisDir=os.path.dirname(os.path.abspath(__file__))
os.chdir(_thisDir)
expName='SPARSE_NOISE_deg{}_EXP_{}'.format(deg_size,exp_type) 
expInfo={} # If I need to save specific details (e.g. framerate, date, etc) append here as dictionary key-values
saving_name='{}_{}'.format(expName,data.getDateStr()) # Use to create folders+files
_DirToSave='logging_folder/'+saving_name     # Replace when changing computer!    
LOG_DATA=True   #### Switch if you want output file with variables logged
if LOG_DATA==True:
    os.mkdir(_DirToSave)
filename=_DirToSave+'/'+saving_name # To be used in the psychopy's experiment handler
thisExp=data.ExperimentHandler(name=expName,version='',extraInfo=expInfo,runtimeInfo=None,dataFileName=filename,saveWideText=False,savePickle=False)  # Data handler. Psychopy tool to store logging data. 
if LOG_DATA==True:
    logFile = logging.LogFile(filename+'.log', level=logging.EXP)
    
    
if exp_type=='LUM':
    PH_x_LOC=+640
    MONITOR='TI_projector'
elif exp_type=='POL':
    PH_x_LOC=-640
    MONITOR='LCD_pol_screen'

win=visual.Window(monitor=MONITOR,fullscr=True,screen=0,units='pix',color=[0,0,0],allowGUI=True, waitBlanking=True)
NOISE=visual.NoiseStim(win=win,noiseType='binary',size=[1280,720],pos=[0,0],noiseElementSize=Acer_deg_pix*deg_size,contrast=1,units='pix')
PHOTODIODE=visual.Rect(win,pos=[PH_x_LOC,-350],width=100,height=100,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS=visual.Rect(win,pos=[PH_x_LOC,-350],width=150,height=150,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS.color=[-1,-1,-1] # This needs to be specifiec again, for whatever buggy reason
SN_MAT=np.load('SPARSE_NOISE_SETS/PROJECTOR_SN_SET_4DEG.npy'.format(deg_size)) # Loading pre-made sparse noise matrix
frame_rate = win.getActualFrameRate()
##### Exp Parameters #### ## # 
condition_clock=core.Clock() # Will be used as counter for trials
expclock=core.Clock() # To log time
ITER_T=0.1       # seconds ##### This can result in incosistent times (eg sometimes ~0.2, sometimes ~0.215). Should probably request this stimulus in frames rather than in ms. (Holds true for all stimuli, modify if required)

iter_frames=int(np.round(frame_rate*ITER_T))
##### Initiate Stimulus #######

#### Start wait state
photodiode_c=1 #To swap photodiode colour
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
win.flip()
dlp.write(b'Q')
event.waitKeys()
#####
frame_counter=0
expclock.reset()
mat=0
for count in range(int(len(SN_MAT))):
    NOISE.tex=SN_MAT[mat]
    thisExp.addData('frame',frame_counter)
    thisExp.addData('time',expclock.getTime())
    thisExp.addData('noise_index',mat)
    condition_clock.reset()
    photodiode_c+=1
    PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
    mat+=1
    if count%2==0:
        dlp.write(b'1')
    else:
        dlp.write(b'Q')
    for f in range(iter_frames):     
        NOISE.draw()
        PHOTODIODE_BOUNDS.draw()
        PHOTODIODE.draw()
        win.flip()
        frame_counter+=1
    keys=event.getKeys()
    if any(k in ['escape'] for k in keys):
        stop_loop=True
        break


    event.clearEvents()
    thisExp.nextEntry()
###### End waiting state
photodiode_c+=1
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]        
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
dlp.write(b'1')
win.flip()
event.waitKeys()
#####
win.close()
if LOG_DATA==True:
    thisExp.saveAsWideText(filename+'.csv',delim='auto')
    