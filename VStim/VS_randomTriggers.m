classdef VS_randomTriggers < VStim
    properties (SetAccess=public)
        randomizeOrder = true;
        jitterTime = 10;
        triggersNumber = 1;
        trigDuration = 1;
    end
    
    properties (SetObservable, SetAccess=public)
    end
    
    properties (Constant)
        CMloadImagesTxt='load movie file or sequence of images to be presented as a movie';
        
        rotationTxt='The rotation angle of the images (for alignment to visual streak';
        randomizeOrderTxt = 'To randomize order of image appearance';
        remarks='If interTrialDelay==0 switches between images without off phase';
    end
    properties (SetAccess=protected)
        order
        durationSequence
        finalStimIntervals
    end
    properties (Hidden, SetAccess=protected)

    end
    
    methods
        
        function obj=run(obj)
            
            nDurations=numel(obj.trigDuration);
            obj.nTotTrials=obj.trialsPerCategory*nDurations;
            
            obj.durationSequence=nan(1,obj.nTotTrials);

            c=1;
            for i=1:nDurationLightawa 
                s
                obj.durationSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.trigDuration(i))';
                c=c+1;
            end
            
            if obj.randomizeOrder
                obj.order=randperm(obj.nTotTrials);
            else
                obj.order=1:obj.nTotTrials;
            end
            obj.durationSequence=obj.durationSequence(obj.order);

            stimTimes=(1:obj.nTotTrials)*obj.interTrialDelay;
            finalStimTimes=stimTimes+randn(1,obj.nTotTrials)*obj.jitterTime; %add jitter to all trials
            obj.finalStimIntervals=abs([diff(finalStimTimes) 0]);
             GLL316
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
              
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                WaitSecs(obj.durationSequence(i));
                obj.sendTTL(2,false); %session start trigger (also triggers the recording start)

                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.finalStimIntervals(i));
            end
            
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger 
            disp('Session Ended');
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
        end
        
        function obj=CMloadImages(obj,srcHandle,eventData,hPanel)
            obj.imagesDir = uigetdir('','Choose directory containing images (tif/jpg)');
            
            dTif=dir([obj.imagesDir obj.fSep '*.tif']);
            dJpg=dir([obj.imagesDir obj.fSep '*.jpg']);
            d=[dTif;dJpg];
            
            obj.imgNames={d.name};
            nImages=numel(obj.imgNames);
            
            if nImages==0
                error('No images were selected');
            end
            
            obj.calculateImageTextures;
        end
     
        
        %class constractor
        function obj=VS_randomTriggers(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF