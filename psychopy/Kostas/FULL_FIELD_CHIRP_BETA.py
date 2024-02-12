#### FULL-FIELD-CHIRP #### Baden et al. 2016, Sibille et al 2022


from psychopy import sound, gui, visual, core, data, event, logging, clock
import numpy as np
#import matplotlib
#matplotlib.use('Qt5Agg')  # change this to control the plotting 'back end'
#import pylab
import os

#############################################################################################################################
#############################################################################################################################
#############################################################################################################################
###### Logging Data ######
_thisDir=os.path.dirname(os.path.abspath(__file__))
os.chdir(_thisDir)
expName='FULL_FIELD_CHIRP' 
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
##### Create Window/Stimulus
win=visual.Window(monitor='Dell_ephys_monitor',size=[2560,1440],fullscr=True,screen=1,units='pix',color=[0,0,0],allowGUI=False, waitBlanking=True) # Will try performing the updates on the window or on a rectangle and assess performance
FF_GRAT=visual.GratingStim(win=win,pos=[0,0],units='pix',size=[4000,4000],sf=1) 
exp_clock=core.Clock()
shift_clock=core.Clock()

##### Stimulus parameters ####
PHASE_1_TIMES=[5,2.18,3.28,3.28,2.18]
PHASE_1_VALUES=[0,-1,1,-1,0]
TF_RANGE=np.linspace(0.5,11,26)
CONTRAST_RANGE=np.linspace(0,1,30)
PHASE_3_TF=4
PHASE_2_CON=1
REPEATS=10
exp_clock.reset()
stop_loop=False
frame_c=0

### Initiate Stimulus
event.waitKeys()
exp_clock.reset()
for rep in range(REPEATS):
    thisExp.addData('Repeat_start_time',exp_clock.getTime())
    thisExp.addData('frame',frame_c)
    ### PHASE 1: Full contrast swaps
    shift_clock.reset()
    for i in range(len(PHASE_1_TIMES)):
        shift_clock.reset()
        win.color=[PHASE_1_VALUES[i],PHASE_1_VALUES[i],PHASE_1_VALUES[i]]
        while shift_clock.getTime()<PHASE_1_TIMES[i]:
            win.flip()
            frame_c+=1
        keys=event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
            break
        event.clearEvents()
        #####
    if stop_loop==True:
        break

    #### PHASE 2 : Temporal Frequency modulations at Full Contrast #####
    FF_GRAT.contrast=PHASE_2_CON
    for tf in TF_RANGE:
        shift_clock.reset()
        while shift_clock.getTime()<1/tf:
            FF_GRAT.phase=tf*shift_clock.getTime()
            FF_GRAT.draw()
            win.flip()
            frame_c+=1
        keys=event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
            break
        event.clearEvents()
        #####
    if stop_loop==True:
        break
    ## PHASE 3 : Contrast modulations at Steady Temporal Frequency 0.4 Hz
    for con in CONTRAST_RANGE:
        FF_GRAT.contrast=con
        shift_clock.reset()
        while shift_clock.getTime()<1/PHASE_3_TF:
            FF_GRAT.phase=PHASE_3_TF*shift_clock.getTime()
            FF_GRAT.draw()
            win.flip()
            frame_c+=1
        keys=event.getKeys()
        if any(k in ['q','escape'] for k in keys):
            stop_loop=True
            break
        event.clearEvents()
        #####
    thisExp.nextEntry() # Forget to add this line if you want to lose your conditions!
    if stop_loop==True:
        break
win.close()
if LOG_DATA==True:
    thisExp.saveAsWideText(filename+'.csv',delim='auto')