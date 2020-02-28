classdef VS_image < VStim
    properties (SetAccess=public)
        randomizeOrder = true;
        selectedScreen = 1;
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
        imgTex
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
    end
    
    methods
        
        function obj=run(obj)
            
            nScreens=numel(obj.selectedScreen);

            nImages=numel(obj.imgNames);
            obj.nTotTrials=obj.trialsPerCategory*nImages;
            obj.imgSequence=repmat(1:nImages,1,obj.trialsPerCategory);

            if obj.randomizeOrder
                obj.order=randperm(obj.nTotTrials);
            else
                obj.order=1:obj.nTotTrials;
            end
            obj.order=[obj.order obj.order(1)]; %always add another stimulation which will never be shown
            
            %check if to you a mode in which images switch without a blank screen in between
            if obj.interTrialDelay==0
                noTimeGapBetweenImages=true;
                wait2NextFrame=obj.actualStimDuration(obj.selectedScreen);
            else
                noTimeGapBetweenImages=false;
                wait2NextFrame=obj.interTrialDelay;
            end
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            for i=1:nScreens
                Screen('FillRect',obj.PTB_win(obj.selectedScreen(i)),obj.visualFieldBackgroundLuminance);
                Screen('DrawTexture',obj.PTB_win(obj.selectedScreen(i)),obj.masktexOff(obj.selectedScreen(i)));
                Screen('Flip',obj.PTB_win(obj.selectedScreen(i)));
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
            for j=1:nScreens
                Screen('DrawTexture',obj.PTB_win(obj.selectedScreen(j)),obj.imgTex(obj.imgSequence(obj.order(1)),j),[],obj.visualFieldRect,obj.rotation);
            end
            obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                for j=1:nScreens
                    [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win(obj.selectedScreen(j)));
                end
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                               
                if ~noTimeGapBetweenImages %if there is a black screen between consecutive images
                    % Update display
                    for j=1:nScreens
                        Screen('FillOval',obj.PTB_win(obj.selectedScreen(j)),obj.visualFieldBackgroundLuminance,obj.visualFieldRect);
                    end
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                    for j=1:nScreens
                        [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win(obj.selectedScreen(j)),obj.on_Flip(i)+obj.actualStimDuration(obj.selectedScreen(j))-0.5*obj.ifi(obj.selectedScreen(j)));
                    end
                    WaitSecs(0.1);
                    obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                elseif i<obj.nTotTrials
                    obj.off_Flip(i)=obj.on_Flip(i);
                    obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                else
                    for j=1:nScreens
                        Screen('FillOval',obj.PTB_win(obj.selectedScreen(j)),obj.visualFieldBackgroundLuminance,obj.visualFieldRect);
                    end
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                    
                    for j=1:nScreens
                        [obj.on_Flip(i+1),obj.on_Stim(i+1),obj.on_FlipEnd(i+1),obj.on_Miss(i+1)]=Screen('Flip',obj.PTB_win(obj.selectedScreen(j)),obj.on_Flip(i)+obj.actualStimDuration(obj.selectedScreen(j))-0.5*obj.ifi(obj.selectedScreen(j)));
                    end
                    obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                    obj.off_Flip(i+1)=obj.on_Flip(i+1);
                end
                % Update image buffer for the next trial
                for j=1:nScreens
                    Screen('DrawTexture',obj.PTB_win(obj.selectedScreen(j)),obj.imgTex(obj.imgSequence(obj.order(i+1)),j),[],obj.visualFieldRect,obj.rotation);
                end
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(wait2NextFrame-(GetSecs-obj.off_Flip(i)));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger 
            disp('Session Ended');
            
            obj.order=obj.order(1:end-1); %remove the last (never shown stimulus from the list)
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            if nargin==2
                if obj.interTrialDelay~=0
                    intervals=-1e-1:2e-4:1e-1;
                    intCenter=(intervals(1:end-1)+intervals(2:end))/2;
                    stimDurationShifts=(obj.off_Flip-obj.on_Flip)-obj.actualStimDuration(obj.selectedScreen);
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
                    stimDurationShifts=(obj.on_Flip(2:end)-obj.on_Flip(1:end-1))-obj.actualStimDuration(obj.selectedScreen);
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
        
        function obj=calculateImageTextures(obj,event,metaProp)
            disp(['preparing textures with rotation ' num2str(obj.rotation) ' !!!!']);
            nImages=numel(obj.imgNames);
            nScreens=numel(obj.selectedScreen);
            
            %clear previous textures
            obj.cleanUp
            
            % Create textures for all images
            for i=1:nImages
                I=imread([obj.imagesDir obj.fSep obj.imgNames{i}]);
                [M,N,l]=size(I);
                if N>=M
                    cutPixels=round((N-M)/2);
                    for j=1:nScreens
                        obj.imgTex(i,j)=Screen('MakeTexture', obj.PTB_win(obj.selectedScreen(j)),I(:,(cutPixels+1):(end-cutPixels),:),obj.rotation);
                    end
                else
                    cutPixels=round((M-N)/2);
                    for j=1:nScreens
                        obj.imgTex(i,j)=Screen('MakeTexture', obj.PTB_win(obj.selectedScreen(j)),I((cutPixels+1):(end-cutPixels),:,:),obj.rotation);
                    end
                end
            end
            
            disp('Done preparing movie textures');
        end
        
        %class constractor
        function obj=VS_image(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            addlistener(obj,'rotation','PostSet',@obj.calculateImageTextures); %add a listener to rotation, after its changed the textures should be updated
        end
    end
end %EOF