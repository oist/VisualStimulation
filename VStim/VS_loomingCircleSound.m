classdef VS_loomingCircleSound < VStim
    properties (SetAccess=public)
        circleColor = [255 0 0];
        randomizeCircleColor = true;
        
        initialXYPosition = [0 0];
        randomizeInitialPositions = true;
        
        circleVelocity = 100;
        randomizeVelocity = true;
        
        circleTrueSize = 30;
        circleInitialDistance = 1000;
        time2Collision = 5;
        
        postLoomTime = 2;
        
        eye2ScreenDistance = 10;
        
        minimalRealDistance = 5;
        
        displayWidthHeight = [4 3]; %the width and height of the screen in cm [width height]
        
        selectedScreen = 1;
        
        soundIntensity = 1;
    end
    
    properties (Constant)
        
        CMloadAudioTxt='load audio files [.wav]';

        circleVelocityTxt = 'The real approaching velocity of the object [cm/s]';
        circleTrueSizeTxt = 'The real size of the approaching object [cm]';
        circleInitialDistanceTxt = 'The initial distance of the object [cm]';
        
        eye2ScreenDistanceTxt = 'The distance between the fish eye and the screen [cm]';
        
        circleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeCircleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        
        initialXYPositionTxt='The initial position of the looming circle center on the screen [cm, 2 x M, M being number of positions] ';

        randomizeVelocityTxt='Randomize size to speed ratio';
        
        minimalRealDistanceTxt='the minimal real distance between the approaching object and eye at the end of the stimulation';
        
        remarks={'Categories in stimuli are: speed, offset'};
    end
    
    properties (SetAccess=protected)
        circleColorSequence
        velocitySequence
        initialPositionSequence
        
        audioFileName
        audioPathName
        soundWF
        soundFs
    end
    
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
    end
    methods
        function obj=run(obj)
            %calculate the angles of directions
            nCircleColor=size(obj.circleColor,1);
            nVelocities=numel(obj.circleVelocity);
            nInitialPositions=size(obj.initialXYPosition,1);

            obj.nTotTrials=obj.trialsPerCategory*nCircleColor*nVelocities*nInitialPositions;
            
            %calculate sequece of positions and times
            obj.circleColorSequence=nan(3,obj.nTotTrials);
            obj.velocitySequence=nan(1,obj.nTotTrials);
            obj.initialPositionSequence=nan(2,obj.nTotTrials);
            c=1;
            for i=1:nCircleColor
                for j=1:nVelocities
                    for k=1:nInitialPositions
                        obj.circleColorSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.circleColor(i,:))';
                        obj.velocitySequence( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.circleVelocity(j);
                        obj.initialPositionSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.initialXYPosition(k,:))';
                        c=c+1;
                    end
                end
            end

            %randomize
            if obj.randomizeCircleColor
                randomPermutation=randperm(obj.nTotTrials);
                obj.circleColorSequence=obj.circleColorSequence(:,randomPermutation);
            end
            if obj.randomizeVelocity
                randomPermutation=randperm(obj.nTotTrials);
                obj.velocitySequence=obj.velocitySequence(randomPermutation);
            end
            if obj.randomizeInitialPositions
                randomPermutation=randperm(obj.nTotTrials);
                obj.initialPositionSequence=obj.initialPositionSequence(:,randomPermutation);
            end
            
            %get screen properties
            if ~isempty(obj.soundWF)
                player = audioplayer(obj.soundWF*obj.soundIntensity,obj.soundFs);
            else
                disp('No sound selected, playing looming without sound');
                player = audioplayer(zeros(1,10),10000);
            end
            
            %determine initial position 
            x0=obj.centerX+obj.initialPositionSequence(1,:).*(obj.rect(obj.selectedScreen,3)/obj.displayWidthHeight(1));
            y0=obj.centerY+obj.initialPositionSequence(2,:).*(obj.rect(obj.selectedScreen,4)/obj.displayWidthHeight(2));
            
            maxFrames=ceil(obj.time2Collision/obj.ifi(obj.selectedScreen));
            movementDuration=maxFrames*obj.ifi(obj.selectedScreen);
            t=(obj.ifi(obj.selectedScreen):obj.ifi(obj.selectedScreen):movementDuration);
            nFrames=numel(t);
                        
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            Screen('FillRect',obj.PTB_win(obj.selectedScreen),obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win(obj.selectedScreen),obj.masktexOff(obj.selectedScreen));
            Screen('Flip',obj.PTB_win(obj.selectedScreen));
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
                        
            obj.flip=nan(obj.nTotTrials,maxFrames);
            obj.stim=nan(obj.nTotTrials,maxFrames);
            obj.flipEnd=nan(obj.nTotTrials,maxFrames);
            obj.miss=nan(obj.nTotTrials,maxFrames);
            
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');

            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                
                tmpCircleColor=obj.circleColorSequence(:,i);
                tmpVelocity=obj.velocitySequence(i);
                
                r=obj.eye2ScreenDistance*obj.circleTrueSize/tmpVelocity./t(end:-1:1);
                
                ovalCoordinates=round([max(obj.rect(obj.selectedScreen,1),x0(i)-r);max(obj.rect(obj.selectedScreen,2),y0(i)-r);min(x0(i)+r,obj.rect(obj.selectedScreen,3));min(obj.rect(obj.selectedScreen,4),y0(i)+r)]);

                ttmp=t+GetSecs+obj.ifi(obj.selectedScreen);
                obj.sendTTL(2,true);
                for j=1:nFrames
                    % Update display
                    Screen('FillOval',obj.PTB_win(obj.selectedScreen),tmpCircleColor,ovalCoordinates(:,j));
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)

                    obj.sendTTL(3,true);
                    [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win(obj.selectedScreen),ttmp(j));
                    obj.sendTTL(3,false);
                end
                play(player);
                endStimTime=GetSecs;
                
                Screen('FillRect',obj.PTB_win(obj.selectedScreen),obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                WaitSecs(obj.postLoomTime-(GetSecs-endStimTime));
                Screen('Flip',obj.PTB_win(obj.selectedScreen));
                obj.sendTTL(2,false);
                endTrialTime=GetSecs;

                %Screen('DrawTexture',obj.PTB_win,obj.masktex);
                %[endSessionTime]=Screen('Flip',obj.PTB_win);
                % Start wait: Code here is run during the waiting for the new session
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end

                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                WaitSecs(obj.interTrialDelay-(GetSecs-endTrialTime));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false);
            disp('Session ended');
        end
        
        function obj=CMloadAudio(obj,srcHandle,eventData,hPanel)
            [obj.audioFileName, obj.audioPathName] = uigetfile('*.*','Choose audio files','MultiSelect','Off');
            for i=1:numel(obj.audioFileName)
                [obj.soundWF,obj.soundFs] = audioread([obj.audioPathName obj.audioFileName]);
            end
            disp([num2str(numel(obj.audioFileName)) ' sounds loaded successfully!']);
        end
        
        
        function outStats=getLastStimStatistics(obj,hFigure)
           outStats.props=obj.getProperties;
            
           
        end
        %class constractor
        function obj=VS_loomingCircleSound(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
        end
    end
end %EOF