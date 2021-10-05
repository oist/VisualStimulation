classdef VS_driftingGrating < VStim
    properties
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        angles=12;
        minFreq=.1;
        maxFreq=2;
        freqStep=.3;
        minSpatialFreq=.01;
        maxSpatialFreq=.5;
        spatialFreqStep=0.05;
        contrast = .5;
    end
    properties (Hidden,Constant)
        defaultStimDuration=5; %stim duration in [sec] of each grating
        defaultVisualFieldBackgroundLuminance=0;
        defaultTrialsPerCategory=50; %number of gratings to present
        screenSizeCm=[52 32];
        stimRadiousTxt='radious of stimulus';
        contrastTxt='% of dynamic range to use';
        anglesTxt='Number of tilt angles of the grating';
        minFreqTxt='min temp freq (Hz)';
        maxFreqTxt='max temp freq (Hz)';
        freqStepTxt='step stize for temp freq';
        minSpatialFreqTxt='min spatial freq (cycles/cm) screen size in cm is a paramter below';
        maxSpatialFreqTxt='max spatial freq (cycles/cm) screen size in cm is a paramter below';
        spatialFreqStepTxt='step stize for spatial freq';
        
        remarks={''};
        
    end
    properties (Hidden, SetAccess=protected)
        tempFreq
        spatialFreq
        angleOrder
        stimOnset
        flipOffsetTimeStamp
        flipMiss
        flipOnsetTimeStamp
        centerXs
        centerYs
        
    end
    methods
        function obj=run(obj)
            screenProps=Screen('Resolution',obj.PTB_win(1));
            ifi = Screen('GetFlipInterval', obj.PTB_win(1));
            pixPerCm=screenProps.width/obj.screenSizeCm(1)
            
            % Initial stimulus parameters for the grating patch:
            
            rotateMode = kPsychUseTextureMatrixForRotation;
            
            % res is the total size of the patch in x- and y- direction, i.e., the
            % width and height of the mathematical support.
            res = [screenProps.width screenProps.height];
            amplitude=0.5*obj.contrast; %halve it to make it compatible with demo
            
            % Retrieve video redraw interval for later control of our animation timing:
            ifi = Screen('GetFlipInterval', obj.PTB_win(1));
            
            % Phase is the phase shift in degrees (0-360 etc.)applied to the sine grating:
            phase = 0;
            
            % Build a procedural sine grating texture for a grating with a support of
            % res(1) x res(2) pixels and a RGB color offset of 0.5 -- a 50%
            % gray. Change it's center to the user defined location 
            
            %do it blue for the cephs to avoid weird rainbow striping from the monitor
            for j=1:obj.nPTBScreens
                [gratingtex(j)] = CreateProceduralSineGrating(obj.PTB_win(j), res(1), res(2), [0 0 0.5 1.0],[],0.5); 
                
             
            end
            
            obj.spatialFreq=[];
            %load up the range of parameters that are going to be presented
            anglesToPresent=[0:round(360/obj.angles):360]; %nice to have it divisible by 360
            cyclespersecond=obj.minFreq:obj.freqStep:obj.maxFreq;
            spatialFreq=(obj.minSpatialFreq:obj.spatialFreqStep:obj.maxSpatialFreq)/ pixPerCm;
            
            obj.tempFreq=cyclespersecond(ceil(rand(obj.trialsPerCategory,1)*length(cyclespersecond)));
            obj.angleOrder=anglesToPresent(ceil(rand(obj.trialsPerCategory,1)*length(anglesToPresent)));
            spatialFreq=spatialFreq(ceil(rand(obj.trialsPerCategory,1)*length(spatialFreq)));
            obj.spatialFreq=spatialFreq*pixPerCm;
            
            % Compute increment of phase shift per redraw:
            phaseincrement = (obj.tempFreq * 360) * ifi;
            vbl = Screen('Flip', obj.PTB_win(1));
            
            %make sure there are an even number of frames for led syncing
            numFrames=round(1/ifi*obj.stimDuration);
            if mod(numFrames,2) == 1
                numFrames=numFrames-1;
            end
            
            %Pre allocate memory for variables
            %  obj.stim_onset=nan(obj.trialsPerCategory,obj.numberOfFrames+1);
            obj.flipOnsetTimeStamp=nan(obj.trialsPerCategory,numFrames); %when the flip happened
            obj.stimOnset=nan(obj.trialsPerCategory,numFrames);          %estimate of stim onset
            obj.flipOffsetTimeStamp=nan(obj.trialsPerCategory,numFrames);  %flip done
            obj.flipMiss=nan(obj.trialsPerCategory,numFrames);
            
            WaitSecs(obj.preSessionDelay);
          
            
            % Animation loop
            for i=1:obj.trialsPerCategory
                disp(['Trial ' num2str(i) '/' num2str(obj.trialsPerCategory)]);
                
                obj.sendTTL(1,true);
               % Screen('FillOval',obj.PTB_win(1),obj.visualFieldBackgroundLuminance);
                
                for frame= 1: numFrames
                    phase = phase + phaseincrement(i);
                    for j=1:obj.nPTBScreens
                        Screen('DrawTexture', obj.PTB_win(j), gratingtex(j), [], [], obj.angleOrder(i), [], [], [], [], rotateMode, [phase, spatialFreq(i), amplitude, 0]);
                    end
                    obj.applyBackgound;
                    obj.sendTTL(2,true);
                    for j=1:obj.nPTBScreens
                        [obj.flipOnsetTimeStamp(i,frame),obj.stimOnset(i,frame),obj.flipOffsetTimeStamp(i,frame),obj.flipMiss(i,frame)]=Screen('Flip',obj.PTB_win(j), vbl + 0.5 * ifi);
                    end
                    obj.sendTTL(2,false);
                    Screen('DrawingFinished', obj.PTB_win(1)); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                end
                
           
                for j=1:obj.nPTBScreens
                    Screen('FillRect',obj.PTB_win(j),[0,0,obj.visualFieldBackgroundLuminance]);
                end
                obj.applyBackgound;
                for j=1:obj.nPTBScreens
                    Screen('Flip',obj.PTB_win(j));
                end
                
               % WaitSecs(obj.interTrialDelay);  
                obj.sendTTL(1,false);
                WaitSecs(obj.interTrialDelay);
                disp('Trial ended');
            end
         
            WaitSecs(obj.postSessionDelay);
            disp('Session ended');
            
        end
        
        %class constractor
        function obj=VS_driftingGrating(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=obj.defaultStimDuration;
            obj.visualFieldBackgroundLuminance=obj.defaultVisualFieldBackgroundLuminance;
            obj.trialsPerCategory=obj.defaultTrialsPerCategory;
            %obj.hInteractiveGUI=h;
        end
        
    end
end %EOF