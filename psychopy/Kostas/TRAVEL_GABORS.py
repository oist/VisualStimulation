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


####################
_thisDir=os.path.dirname(os.path.abspath(__file__))
os.chdir(_thisDir)
expName='TRAVEL_GABORS' 
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
#########################


def rescale_value(value, original_min, original_max, new_min, new_max):
    # Rescale the value to the new range
    normalized_value = (value - original_min) / (original_max - original_min)
    rescaled_value = new_min + normalized_value * (new_max - new_min)
    return rescaled_value
    
# Setup stimulus
win=visual.Window(monitor='TI_projector',fullscr=True,size=[1280,720],screen=2,units='pix',color=[0,0,0])
PHOTODIODE=visual.Rect(win,pos=[+640,-350],width=100,height=100,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS=visual.Rect(win,pos=[+640,-350],width=150,height=150,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS.color=[-1,-1,-1] # This needs to be specifiec again, for whatever buggy reason
photodiode_c=0 #To swap photodiode colour
phaseclock=core.Clock() # Will be used to as input to the grating phase
frame_counter=0

PHOTODIODE_BOUNDS.color=[-1,-1,-1] # This needs to be specifiec again, for whatever buggy reason
frame_rate = win.getActualFrameRate()

VIEW_WIDTH=1280
VIEW_HEIGHT=720
SQUID_POS=[0,0] 
offset_x=SQUID_POS[0]
offset_y=SQUID_POS[1]

GABOR_MAT=np.load('TRAVEL_GABOR_SETS/GABOR_LOC_MATRIX.npy',allow_pickle=True) # Loading pre-made sparse noise matrix
GABOR_PARAMS=np.load('TRAVEL_GABOR_SETS/GABOR_PARAMS.npy',allow_pickle=True)
### GABOR_PARAMS are as follows [name_index,ori,dX]
TRAVEL_NAMEs=['UP_0','UP_1','DOWN_0','DOWN_1','LEFT_0','LEFT_1','RIGHT_0','RIGHT_1']

SF=0.02
TF=3.5
deg_pix=12.8
gabor_size=deg_pix*8


GABOR_LOCS=[]
dx_vecs=[]
N_steps_V=[]
for m in range(len(GABOR_MAT)):
    old_Xs=GABOR_MAT[m][:,0]
    old_Ys=GABOR_MAT[m][:,1]
    new_Xs=rescale_value(old_Xs,0,VIEW_WIDTH,-VIEW_WIDTH/2,+VIEW_WIDTH/2)
    new_Ys=rescale_value(old_Ys,0,VIEW_HEIGHT,-VIEW_HEIGHT/2,+VIEW_HEIGHT/2)
    GABOR_LOCS.append(np.column_stack((new_Xs,new_Ys)))
    start_conf=GABOR_PARAMS[m][0]
    dx=GABOR_PARAMS[m][2]
    dx_pix=dx*deg_pix

    if start_conf in [0,1]:
        N_steps=int(56/dx)
        dx_vec=np.asarray([0,-dx_pix])
    elif start_conf in [2,3]:
        N_steps=int(56/dx)
        dx_vec=np.asarray([0,dx_pix])
    elif start_conf in [4,5]:
        N_steps=int(100/dx)
        dx_vec=np.asarray([dx_pix,0])
    elif start_conf in [6,7]:
        N_steps=int(100/dx)
        dx_vec=np.asarray([-dx_pix,0])
    dx_vecs.append(dx_vec)
    N_steps_V.append(N_steps)



frame_c=0
stop_loop=False
photodiode_c=1 #To swap photodiode colour
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
dlp.write(b'Q')
win.flip()
event.waitKeys()
phaseclock.reset()

for trial in range(len(GABOR_LOCS)):
    GABORS=[]
    dx=GABOR_PARAMS[trial][2]
    dx_pix=dx*12.8
    start_conf=GABOR_PARAMS[trial][0]
    L_ori=GABOR_PARAMS[trial][1]

    for g in range(len(GABOR_LOCS[trial])):
        GABORS.append(visual.GratingStim(win,tex='sin',mask='gauss',units='pix',size=gabor_size,sf=SF,ori=L_ori,pos=[GABOR_LOCS[trial][g][0],GABOR_LOCS[trial][g][1]]))
        
    thisExp.addData('frame',frame_c)
    thisExp.addData('time',phaseclock.getTime())   
    photodiode_c+=1
    PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
    if trial%2==0:
        dlp.write(b'1')
    else:
        dlp.write(b'Q')

    for step in range(N_steps_V[trial]):
        for gabor in GABORS:
            gabor.pos=gabor.pos+dx_vecs[trial]
        for frame in range(6):
            for gabor in GABORS:
                gabor.phase=TF*phaseclock.getTime()
                gabor.draw()
                PHOTODIODE_BOUNDS.draw()
                PHOTODIODE.draw()
            win.flip()
            frame_c+=1
        keys=event.getKeys()
        if any(k in ['escape'] for k in keys):
            stop_loop=True
            break
    event.clearEvents()
    thisExp.nextEntry()
    if stop_loop==True:
        break

photodiode_c+=1
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]        
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
if trial%2==0:
    dlp.write(b'Q')
else:
    dlp.write(b'1')
win.flip()
event.waitKeys()
        
        
win.close()

if LOG_DATA==True:
    thisExp.saveAsWideText(filename+'.csv',delim='auto')        
        
        
        
        
        




