classdef VS_CSloomingCircle < VStim
    properties (SetAccess=public)
        circleColor = [255 0 0];
        randomizeCircleColor = true;
        
        initialXYPosition = [0 0];
        
        circleVelocity = 100;
        circleTrueSize = 30;
        circleInitialDistance = 1000;
        time2Collision = 5;
        
        randomizeVelocity = true;
        eye2ScreenDistance = 100;
        
        initialFlashDuration = 1;
        initialFlashPostInterval = 1;
        initialFlashColor = [0 0 255];
        randomizeInitialFlashColor = true;
        
        minimalRealDistance = 5;
        
        displayWidthHeight = [15 10]; %the width and height of the screen in cm [width height]
        
        maxTimeToRemoveLooming=20;
    end
    
    properties (Constant)
        
        circleVelocityTxt = 'The real approaching velocity of the object [cm/s]';
        circleTrueSizeTxt = 'The real size of the approaching object [cm]';
        circleInitialDistanceTxt = 'The initial distance of the object [cm]';
        
        eye2ScreenDistanceTxt = 'The distance between the fish eye and the screen [cm]';
        
        circleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeCircleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        
        initialXYPositionTxt='The initial position of the looming circle center on the screen [cm]';

        randomizeVelocityTxt='Randomize size to speed ratio';
        
        initialFlashDurationTxt='duration of the initial flash';
        initialFlashPostIntervalTxt='the interval after the flash and before looming circle begins';
        initialFlashColorTxt='the color of the initial flash [r g b] (0-1)';
        randomizeInitialFlashColorTxt='Randomize initial flash color';
        
        minimalRealDistanceTxt='the minimal real distance between the approaching object and eye at the end of the stimulation';
        
        maxTimeToRemoveLoomingTxt='the stimulus time until looming is removed if no key is presses';
        remarks={'Categories in stimuli are: speed, offset'};
    end
    
    properties (SetAccess=protected)
        circleColorSequence
        velocitySequence
        initialFlashColorSequence
    end
    
    properties (Hidden, SetAccess=protected)

        flipFlashOn
        stimFlashOn
        flipEndFlashOn
        missFlashOn
        flipFlashOff
        stimFlashOff
        flipEndFlashOff
        missFlashOff
        
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
            nInitialFlashColor=size(obj.initialFlashColor,1);

            obj.nTotTrials=obj.trialsPerCategory*nCircleColor*nVelocities*nInitialFlashColor;
            
            %calculate sequece of positions and times
            obj.circleColorSequence=nan(3,obj.nTotTrials);
            obj.velocitySequence=nan(1,obj.nTotTrials);
            obj.initialFlashColorSequence=nan(3,obj.nTotTrials);
            c=1;
            for i=1:nCircleColor
                for j=1:nVelocities
                    for k=1:nInitialFlashColor
                        obj.circleColorSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.circleColor(i,:))';
                        obj.velocitySequence( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.circleVelocity(j);
                        obj.initialFlashColorSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.initialFlashColor(k,:))';
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
            if obj.randomizeInitialFlashColor
                randomPermutation=randperm(obj.nTotTrials);
                obj.initialFlashColorSequence=obj.initialFlashColorSequence(:,randomPermutation);
            end
            
            %get screen properties
            
            %determine initial position 
            x0=obj.centerX+round(obj.initialXYPosition(1)/obj.displayWidthHeight(1));
            y0=obj.centerY+round(obj.initialXYPosition(2)/obj.displayWidthHeight(2));
            
            maxFrames=ceil(obj.time2Collision/obj.ifi);
            movementDuration=maxFrames*obj.ifi;
            t=(obj.ifi:obj.ifi:movementDuration);
            nFrames=numel(t);
            
            returnKey = KbName('RETURN');
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win,obj.masktexOff);
            Screen('Flip',obj.PTB_win);
            
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
                tmpFlashColor=obj.initialFlashColorSequence(:,i);
                
                r=obj.eye2ScreenDistance*obj.circleTrueSize/tmpVelocity./t(end:-1:1);
                
                ovalCoordinates=round([max(obj.rect(1),x0-r);max(obj.rect(2),y0-r);min(x0+r,obj.rect(3));min(obj.rect(4),y0+r)]);
                
                Screen('FillOval',obj.PTB_win,tmpFlashColor,obj.visualFieldRect);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                [obj.flipFlashOn,obj.stimFlashOn,obj.flipEndFlashOn,obj.missFlashOn]=Screen('Flip',obj.PTB_win);
                obj.sendTTL(4,true);
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;
                WaitSecs(obj.initialFlashDuration-(GetSecs-obj.stimFlashOn));
                
                [obj.flipFlashOff,obj.stimFlashOff,obj.flipEndFlashOff,obj.missFlashOff]=Screen('Flip',obj.PTB_win);
                obj.sendTTL(4,false);
               
                WaitSecs(obj.initialFlashPostInterval);
                
                obj.sendTTL(2,true);

                ttmp=t+GetSecs+obj.ifi;
                for j=1:nFrames
                    % Update display
                    Screen('FillOval',obj.PTB_win,tmpCircleColor,ovalCoordinates(:,j));
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)

                    obj.sendTTL(3,true);
                    [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,ttmp(j));
                    obj.sendTTL(3,false);
                end
                obj.sendTTL(2,false);
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                %Screen('DrawTexture',obj.PTB_win,obj.masktex);
                %[endSessionTime]=Screen('Flip',obj.PTB_win);
                % Start wait: Code here is run during the waiting for the new session
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                %trigger from screen should come here
                t0=GetSecs;
                circleOnScreen=true;
                while circleOnScreen  && GetSecs<(t0+obj.maxTimeToRemoveLooming)
                    [ keyIsDown, seconds, keyCode] = KbCheck;
                    if keyIsDown
                        
                        if keyCode(obj.escapeKeyCode)
                            obj.lastExcecutedTrial=i;
                            return;
                        elseif keyCode(returnKey)
                            [endSessionTime]=Screen('Flip',obj.PTB_win);
                            disp('Looming circle turned off manually');
                            circleOnScreen=false;
                        end
                    end
                end
                if circleOnScreen
                    [endSessionTime]=Screen('Flip',obj.PTB_win);
                    disp('Looming circle turned off automatically');
                end
                
                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                WaitSecs(obj.interTrialDelay-(GetSecs-endSessionTime));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false);
            disp('Session ended');
        end

        function outStats=getLastStimStatistics(obj,hFigure)
           outStats.props=obj.getProperties;
            
            intervals=-1e-1:2e-4:1e-1;
            intCenter=(intervals(1:end-1)+intervals(2:end))/2;
            
            stimOnsetShifts=diff(obj.flip,[],2);
            n1=histc(stimOnsetShifts(:),intervals);
            
            flipDurationShifts=obj.flipEnd-obj.flip;
            n2=histc(flipDurationShifts(:),intervals);
            
            flipToStim=(obj.stim-obj.flip);
            n3=histc(flipToStim(:),intervals);
            
            n4=histc([obj.miss(:)],intervals);
            
            figure(hFigure);
            subplot(2,2,1);
            bar(1e3*intCenter,n1(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([max(1,find(n1>0,1,'first')-3) min(numel(n1),find(n1>0,1,'last')+4)]));
            ylabel('\Delta(Flip)');
            xlabel('Time [ms]');
            line([obj.ifi obj.ifi],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,2);
            bar(1e3*intCenter,n2(1:end-1),'Edgecolor','none');
            xlim([-0.5 1e3*intervals(min(numel(n2),find(n2>0,1,'last')+4))]);
            ylabel('Flip duration');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,3);
            bar(1e3*intCenter,n3(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([max(1,find(n3>0,1,'first')-3) min(numel(n3),find(n3>0,1,'last')+4)]));
            ylabel('Flip 2 Stim');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,4);
            bar(1e3*intCenter,n4(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([max(1,find(n4>0,1,'first')-3) min(numel(n4),find(n4>0,1,'last')+4)]));
            ylabel('Miss stats');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
        end
        %class constractor
        function obj=VS_CSloomingCircle(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
        end
    end
end %EOF