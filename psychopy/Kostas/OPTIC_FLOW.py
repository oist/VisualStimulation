 #### OPTIC FLOW FINAL ####
# Will do everything in pixels for now, until we have a 100% completely setup display-tank system

from psychopy import visual, core, data, event, logging, sound, gui
from psychopy.tools.coordinatetools import pol2cart, cart2pol
import numpy as np
import os



#####
_thisDir=os.path.dirname(os.path.abspath(__file__))
os.chdir(_thisDir)
expName='OPTIC_FLOW' 
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
####


b_color=0 # -1,0,1 for black/gray/white respectively
dot_color=1 #as above
win=visual.Window(monitor='TI_projector',fullscr=True,screen=1,units='pix',color=[b_color,b_color,b_color],allowGUI=False, waitBlanking=True)
frame_rate = win.getActualFrameRate()


dotN=120 # Number of dots in display at any given time
dotSize=10 # Depends on unit, can be pixels/cm/visual degrees. Make sure to set appropriately
fieldSize=450 #This is basically half the length of the used optic flow field (ie the radius of circle for the angle-related movements
translate_fixation=np.asarray([0,0]) ### To adjust position on the screen. Must be added as to ALL conditions

DOTS=visual.ElementArrayStim(win=win,units='pix',nElements=dotN,sizes=dotSize,colors=[dot_color,dot_color,dot_color],fieldSize=fieldSize,elementMask='circle',elementTex=np.ones([48,48])) 
FIXATION = visual.GratingStim(win, size=5, pos=[0,0], sf=0,color = 'red')
PHOTODIODE=visual.Rect(win,pos=[+640,-350],width=150,height=150,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS=visual.Rect(win,pos=[+640,-350],width=200,height=200,units='pix',color=[-1,-1,-1],colorSpace='rgb')
PHOTODIODE_BOUNDS.color=[-1,-1,-1] # This needs to be specifiec again, for whatever buggy reason
FIXATION.pos=translate_fixation
MOVEMENTS=['X','Y','Z','CLOCK']
SPEEDS=[1,2,4,6,8,10,12] # Unit/frame adjust accordingly
FLOW_COLOR=[-1,1]
RL_PRIOR=[-1,1] #Silly way to swap between +-SPEED between movement orientation repeats
COND_LIST=[[mov,speed,prior,flow_c] for mov in MOVEMENTS for speed in SPEEDS for prior in RL_PRIOR for flow_c in FLOW_COLOR]
N_REPEATS=20
ITER_T=2.0 # seconds 
iter_frames=int(np.round(frame_rate*ITER_T))
STIM_CLOCK=core.Clock() #Use to swap between variables
EXP_CLOCK=core.Clock() #Keep track of experiment time
print(len(COND_LIST))



            
dotsXs=np.random.uniform(-fieldSize,fieldSize,dotN)
dotsYs=np.random.uniform(-fieldSize,fieldSize,dotN)
dotsTHETA=np.random.rand(dotN)*360 #pol2cart function uses degrees as a default, IF you want to use radians change on both locations. NOTE: numpy uses RADIANS as default, don't get confused
dotsRADIUS=np.random.rand(dotN)*fieldSize


#dot_contrast=-1
#win_contrast=1
stop_loop=False
frame_c=0

photodiode_c=1 #To swap photodiode colour
PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
PHOTODIODE_BOUNDS.draw()
PHOTODIODE.draw()
win.flip()
#### Initiate Stimulus ###
event.waitKeys()
EXP_CLOCK.reset()

for rep in range(N_REPEATS):
    #win.color=[(-1)**win_contrast,(-1)**win_contrast,(-1)**win_contrast]
    #DOTS.colors=[(-1)**dot_contrast,(-1)**dot_contrast,(-1)**dot_contrast]
    np.random.shuffle(COND_LIST)
    STIM_CLOCK.reset()
    for cond in COND_LIST:
        photodiode_c+=1
        PHOTODIODE.color=[(-1)**photodiode_c,(-1)**photodiode_c,(-1)**photodiode_c]
        dotsXs=np.random.uniform(-fieldSize,fieldSize,dotN)
        dotsYs=np.random.uniform(-fieldSize,fieldSize,dotN)
        dotsTHETA=np.random.rand(dotN)*360 #pol2cart function uses degrees as a default, IF you want to use radians change on both locations. NOTE: numpy uses RADIANS as default, don't get confused
        dotsRADIUS=np.random.rand(dotN)*fieldSize
        DOTS.colors=[cond[-1],cond[-1],cond[-1]]
        thisExp.addData('movement',cond[0])
        thisExp.addData('velocity',cond[1]*cond[2])
        thisExp.addData('frame_n',frame_c)
        thisExp.addData('frame_time',EXP_CLOCK.getTime())
        thisExp.addData('flow_color',cond[-1])
        STIM_CLOCK.reset()
        
        if cond[0]=='X':
            for frame in range(iter_frames):
                #DEATH_SCORE=np.random.rand(dotN)
                #DEATH_DOTS=(DEATH_SCORE<0.01) #threshold for removing dots
                dotsXs+=cond[1]*cond[2] #Speed*direction
                OUTSIDE_X=(np.abs(dotsXs)>fieldSize) #dots move out of field bounds
                #dotsXs[OUTSIDE_X]=np.random.uniform(-fieldSize,fieldSize,np.sum(OUTSIDE_X)) #replot out of field dots
                dotsXs[OUTSIDE_X]=-dotsXs[OUTSIDE_X] #This will place them at the beginning
                #dotsXs[DEATH_DOTS]=np.random.uniform(-fieldSize,fieldSize,np.sum(DEATH_DOTS)) #replot dead dots
                DOTS.xys=np.array([dotsXs,dotsYs]).T
                DOTS.xys=DOTS.xys+translate_fixation #Adjusts location on the screen
                DOTS.draw()
                FIXATION.draw()
                PHOTODIODE_BOUNDS.draw()
                PHOTODIODE.draw()
                win.flip()
                frame_c+=1
                
                

        if cond[0]=='Y':
            for frame in range(iter_frames):
                #DEATH_SCORE=np.random.rand(dotN)
                #DEATH_DOTS=(DEATH_SCORE<0.01) 
                dotsYs+=cond[1]*cond[2] 
                OUTSIDE_Y=(np.abs(dotsYs)>fieldSize) 
                #dotsYs[OUTSIDE_Y]=np.random.uniform(-fieldSize,fieldSize,np.sum(OUTSIDE_Y)) # This will place them at random locations across the axis of movement 
                dotsYs[OUTSIDE_Y]=-dotsYs[OUTSIDE_Y] #This will place them at the beginning
                #dotsYs[DEATH_DOTS]=np.random.uniform(-fieldSize,fieldSize,np.sum(DEATH_DOTS)) 
                DOTS.xys=np.array([dotsXs,dotsYs]).T
                DOTS.xys=DOTS.xys+translate_fixation
                DOTS.draw()
                FIXATION.draw()
                PHOTODIODE_BOUNDS.draw()
                PHOTODIODE.draw()
                win.flip()
                frame_c+=1
                
                

        if cond[0]=='Z':
            for frame in range(iter_frames):
                #DEATH_SCORE=np.random.rand(dotN)
                #DEATH_DOTS=(DEATH_SCORE<0.01) 
                dotsRADIUS+=cond[1]*cond[2]
                OUTSIDE_RADIUS=(dotsRADIUS>fieldSize) if cond[2]>0 else (dotsRADIUS<5) # Unit threshold of visual field centre
                dotsRADIUS[OUTSIDE_RADIUS]=np.random.rand(sum(OUTSIDE_RADIUS))*fieldSize
                #dotsRADIUS[DEATH_DOTS]=np.random.rand(np.sum(DEATH_DOTS))*fieldSize
                dotsXs,dotsYs=pol2cart(dotsTHETA,dotsRADIUS)
                DOTS.xys=np.array([dotsXs,dotsYs]).T
                DOTS.xys=DOTS.xys+translate_fixation
                DOTS.sizes=(1/50)*dotsRADIUS+5
                DOTS.draw()
                FIXATION.draw()
                PHOTODIODE_BOUNDS.draw()
                PHOTODIODE.draw()
                win.flip()
                frame_c+=1
            DOTS.sizes=dotSize
                
                

        if cond[0]=='CLOCK':
            for frame in range(iter_frames):
                #DEATH_SCORE=np.random.rand(dotN)
                #DEATH_DOTS=(DEATH_SCORE<0.01) 
                dotsTHETA+=cond[1]*cond[2]
                #dotsTHETA[DEATH_DOTS]=np.random.uniform(-fieldSize,fieldSize,np.sum(DEATH_DOTS))
                dotsXs,dotsYs=pol2cart(dotsTHETA,dotsRADIUS)
                DOTS.xys=np.array([dotsXs,dotsYs]).T
                DOTS.xys=DOTS.xys+translate_fixation
                DOTS.sizes=(1/50)*dotsRADIUS+5
                DOTS.draw()
                FIXATION.draw()
                PHOTODIODE_BOUNDS.draw()
                PHOTODIODE.draw()
                win.flip()
                frame_c+=1
            DOTS.sizes=dotSize
                
                
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
win.flip()
event.waitKeys()        
win.close()

        
if LOG_DATA==True:
    thisExp.saveAsWideText(filename+'.csv',delim='auto')        
        
        
    
    
 