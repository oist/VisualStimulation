classdef VS_image < VStim
    properties (SetAccess=public)
        randomizeOrder = true;
     
    end
    properties (SetObservable, SetAccess=public)
        rotation = 0;
     
    end
    properties (Constant)
        CMloadImagesTxt='load movie file or sequence of images to be presented as a movie';
        rotationTxt='The rotation angle of the images (for alignment to visual streak';
        randomizeOrderTxt = 'To randomize order of image appearance';
        remarks='If interTrialDelay==0 switches between images without off phase';
    end
    properties (SetAccess=protected)
        order
        nImages = 0;
        imgNames
        imgSequence
        imagesDir = [];
        
    end
    properties (Hidden, SetAccess=protected)
        on_Flip
        on_Stim
        on_FlipEnd
        on_Miss
        off_Flip
        off_Stim
        off_FlipEnd
        off_Miss
        movieFileName
        movPathName
        duration = 0;
    end
    properties (Hidden)
        imgTex
    end
    
    methods
        
        function obj=run(obj)
            
            selectedScreen=obj.screenLayout;
            
            
         
            
            if obj.randomizeOrder
                obj.order=randperm(obj.nImages); 
            else
                obj.order=1:obj.nImages;
            end
            obj.imgSequence=repmat(obj.order,1,obj.trialsPerCategory);
            
           
            
            %check if to you a mode in which images switch without a blank screen in between
            if obj.interTrialDelay(1)==0
                noTimeGapBetweenImages=true;
                wait2NextFrame=repmat(obj.actualStimDuration(1),[1,obj.nTotTrials]);
            else
                noTimeGapBetweenImages=false;   %do delays between stim, possibly random durations
                possibleDelays=obj.interTrialDelay(1):obj.interTrialDelay(2):obj.interTrialDelay(3)
                wait2NextFrame=possibleDelays(Randi(numel(possibleDelays),[obj.nTotTrials,1]));
            end
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            for i=1:obj.nPTBScreens
                Screen('FillRect',obj.PTB_win(selectedScreen(i)),obj.visualFieldBackgroundLuminance);
                Screen('DrawTexture',obj.PTB_win(selectedScreen(i)),obj.masktexOff(selectedScreen(i)));
                Screen('Flip',obj.PTB_win(selectedScreen(i)));
            end
            
            %Pre allocate memory for variables
            obj.on_Flip=nan(1,obj.nTotTrials);
            obj.on_Stim=nan(1,obj.nTotTrials);
            obj.on_FlipEnd=nan(1,obj.nTotTrials);
            obj.on_Miss=nan(1,obj.nTotTrials);
            obj.off_Flip=nan(1,obj.nTotTrials);
            obj.off_Stim=nan(1,obj.nTotTrials);
            obj.off_FlipEnd=nan(1,obj.nTotTrials);
            obj.off_Miss=nan(1,obj.nTotTrials);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            % Update image buffer for the first time
            for j=1:obj.nPTBScreens
                Screen('DrawTexture',obj.PTB_win(selectedScreen(j)),obj.imgTex(obj.imgSequence(1)),[],[],obj.rotation);
            end
            obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
            
            %main loop - start the session
            
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
             tic
            for i=1:obj.nTotTrials
               
                % Update image buffer for the next trial
                for j=1:obj.nPTBScreens
                    Screen('DrawTexture',obj.PTB_win(selectedScreen(j)),obj.imgTex(obj.imgSequence(i),j),[],[],obj.rotation);
                end
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
               
                for j=1:obj.nPTBScreens
                    [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win(selectedScreen(j)));
                end
                
                obj.sendTTL(2,true);
                WaitSecs(obj.stimDuration-(GetSecs-obj.on_Flip(i))); %display the stim
                
                if ~noTimeGapBetweenImages %if blank between images 
                    for j=1:obj.nPTBScreens
                        Screen('FillRect',obj.PTB_win(selectedScreen(j)),obj.visualFieldBackgroundLuminance);
                    end
                    obj.applyBackgound;
                    for j=1:obj.nPTBScreens
                         [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win(selectedScreen(j)));
                    end
                    
                end
                
              %  WaitSecs(wait2NextFrame(i)); %wait according to the inter-trial delay
                obj.sendTTL(2,false);
              
                disp(i)
            end
              toc
            
            for j=1:obj.nPTBScreens
                Screen('FillRect',obj.PTB_win(selectedScreen(j)),obj.visualFieldBackgroundLuminance);
            end
            
            obj.applyBackgound;
            
            for j=1:obj.nPTBScreens
                Screen('Flip',obj.PTB_win(selectedScreen(j)),obj.on_Flip(i)+obj.actualStimDuration(selectedScreen(j))-0.5*obj.ifi(selectedScreen(j)));
            end
            
            disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
            
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
            disp('Session Ended');
            release(obj.dioSession);
            obj.order=obj.order(1:end-1); %remove the last (never shown stimulus from the list)
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            if nargin==2
                if obj.interTrialDelay~=0
                    intervals=-1e-1:2e-4:1e-1;
                    intCenter=(intervals(1:end-1)+intervals(2:end))/2;
                    stimDurationShifts=(obj.off_Flip-obj.on_Flip)-obj.actualStimDuration(selectedScreen);
                    n1=histc(stimDurationShifts,intervals);
                    
                    flipDurationShiftsOn=obj.on_FlipEnd-obj.on_Flip;
                    flipDurationShiftsOff=obj.off_FlipEnd-obj.off_Flip;
                    n2=histc([flipDurationShiftsOn' flipDurationShiftsOff'],intervals,1);
                    
                    flipToStimOn=(obj.on_Stim-obj.on_Flip);
                    flipToStimOff=(obj.off_Stim-obj.off_Flip);
                    n3=histc([flipToStimOn' flipToStimOff'],intervals,1);
                    
                    n4=histc([obj.on_Miss' obj.on_Miss'],intervals,1);
                else %for the case that images are just switch so there is no interval between consecutive images
                    intervals=-1e-1:2e-4:1e-1;
                    intCenter=(intervals(1:end-1)+intervals(2:end))/2;
                    stimDurationShifts=(obj.on_Flip(2:end)-obj.on_Flip(1:end-1))-obj.actualStimDuration(selectedScreen);
                    n1=histc(stimDurationShifts,intervals);
                    
                    flipDurationShiftsOn=obj.on_FlipEnd-obj.on_Flip;
                    flipDurationShiftsOff=flipDurationShiftsOn;
                    n2=histc([flipDurationShiftsOn' flipDurationShiftsOff'],intervals,1);
                    
                    flipToStimOn=(obj.on_Stim-obj.on_Flip);
                    flipToStimOff=flipToStimOn;
                    n3=histc([flipToStimOn' flipToStimOff'],intervals,1);
                    
                    n4=histc([obj.on_Miss' obj.on_Miss'],intervals,1);
                end
                figure(hFigure);
                subplot(2,2,1);
                bar(1e3*intCenter,n1(1:end-1),'Edgecolor','none');
                xlim(1e3*intervals([find(n1>0,1,'first')-3 find(n1>0,1,'last')+4]));
                ylabel('\Delta(Stim duration)');
                xlabel('Time [ms]');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,2);
                bar(1e3*intCenter,n2(1:end-1,:),'Edgecolor','none');
                xlim([-0.5 1e3*intervals(find(sum(n2,2)>0,1,'last')+4)]);
                ylabel('Flip duration');
                xlabel('Time [ms]');
                legend('On','Off');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,3);
                bar(1e3*intCenter,n3(1:end-1,:),'Edgecolor','none');
                xlim(1e3*intervals([find(sum(n3,2)>0,1,'first')-3 find(sum(n3,2)>0,1,'last')+4]));
                ylabel('Flip 2 Stim');
                xlabel('Time [ms]');
                legend('On','Off');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,4);
                bar(1e3*intCenter,n4(1:end-1,:),'Edgecolor','none');
                xlim(1e3*intervals([find(sum(n4,2)>0,1,'first')-3 find(sum(n4,2)>0,1,'last')+4]));
                ylabel('Miss stats');
                xlabel('Time [ms]');
                legend('On','Off');
                line([0 0],ylim,'color','k','LineStyle','--');
            end
        end
        
        function cleanUp(obj)
            %clear previous textures
            if ~isempty(obj.imgTex)
                Screen('Close',obj.imgTex);
                obj.imgTex=[];
            end
        end
        
        function obj=CMloadImages(obj,srcHandle,eventData,hPanel)
            obj.imagesDir = uigetdir('','Choose directory containing images (tif/jpg)');
            
            dTif=dir([obj.imagesDir obj.fSep '*.png']);
            dJpg=dir([obj.imagesDir obj.fSep '*.jpg']);
            d=[dTif;dJpg];
            
            obj.imgNames={d.name};
            nImages=numel(obj.imgNames);
            
            if nImages==0
                error('No images were selected');
            end
            
            obj.calculateImageTextures;
            obj.nImages=numel(obj.imgNames);
            obj.nTotTrials=obj.trialsPerCategory*obj.nImages;
            obj.duration=(obj.nTotTrials*obj.stimDuration+obj.interTrialDelay*obj.nTotTrials+obj.preSessionDelay+ obj.postSessionDelay)/60;
            disp(['the experiment will take ' num2str(obj.duration) ' minutes!!!'])
               
               
        end
        function obj=CMloadMovie(obj,srcHandle,eventData,hPanel)
            
            [obj.movieFileName, obj.movPathName] = uigetfile('*.*','Choose movie files or series of images named *_F001-*_FXXX','MultiSelect','On');
            
            
            obj.calculateVideoTextures;
            
        end
        
        
        
        function obj=calculateImageTextures(obj,event,metaProp)
            disp(['preparing textures with rotation ' num2str(obj.rotation) ' !!!!']);
            nImages=numel(obj.imgNames);
            
            
            %clear previous textures
            obj.cleanUp
            
            % Create textures for all images
            for i=1:nImages
                I=imread([obj.imagesDir obj.fSep obj.imgNames{i}]);
                distributeToScreens(obj,I,i)
            end
            
            disp('Done preparing image textures');
        end
        
        function obj=calculateVideoTextures(obj,event,metaProp)
            readerObj=VideoReader([obj.movPathName obj.movieFileName]);
            obj.cleanUp
            idx=1;
            while hasFrame(readerObj)
                frame = readFrame(readerObj);
                
                distributeToScreens(obj,frame,idx)
                idx=idx+1
            end
            obj.imgNames=1:(idx-1);
            obj.nImages=numel(obj.imgNames);
            obj.nTotTrials=obj.trialsPerCategory*obj.nImages;
            obj.duration=(obj.nTotTrials*obj.stimDuration+obj.interTrialDelay*obj.nTotTrials+obj.preSessionDelay+ obj.postSessionDelay)/60;
            disp(['the experiment will take ' num2str(obj.duration) ' minutes!!!'])
            disp('Done preparing movie textures');
        end
        
        
        %class constractor
        function obj=VS_image(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
          %  addlistener(obj,'rotation','PostSet',@obj.calculateImageTextures); %add a listener to rotation, after its changed the textures should be updated
           % addlistener(obj,'duration','PostSet',@obj.CMloadImages); %add a listener to rotation, after its changed the textures should be updated
          %  addlistener(obj,'duration','PostSet',@obj.calculateVideoTextures); %add a listener to rotation, after its changed the textures should be updated
        end
    end
end %EOF