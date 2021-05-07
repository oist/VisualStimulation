classdef VS_loomingCircle3D < VStim
    
    properties (SetAccess=public)
        ballLuminocity = 0;        
        initialXYZPosition = [0.5 0.5 100];
        randomizeInitialPositions = true;
        
        circleVelocityXYZ = [0 0 -20];
        randomizeCircleVelocity = true;
        pairVelocityPosition = false;
        
        BallRadius = 0.5;
        randomizeBallRadius = true;
        
        skyLuminocity = 200;
        
        flyTime = 0;
        lastFrameDwell = 2;
        
        rotation = 0;
    end
    
    properties (Constant)
        circleColorTxt='The luminocity value for the rectangles [R GB B]';
        
        initialXYZPositionTxt='The initial position of ball center in world coord. [M x 3, M being number of positions] ';
        randomizeInitialPositionsTxt='Randomize initial position parameter';
        
        circleVelocityXYZTxt = 'The approaching in world coord [M x 3, M being number of velocities]';
        randomizeCircleVelocityTxt='Randomize circle velocity';
        
        BallRadiusTxt = 'The size of the approaching ball';
        randomizeBallRadiusTxt='Randomize ball radius';
        
        skyLuminocityTxt = 'The luminocity of the upper part of the screen (lower is always 128)';
        
        flyTimeTxt = 'The duration of the fly, if==0 calculates time to crossing the Z=0 plane ';
        
        lastFrameDwellTxt = 'Time spent in the last frame of VS';
        
        remarks={'Categories in stimuli are: initialXYZPosition, circleVelocity'};
    end
    
    properties (SetAccess=protected)
        velocitySequence
        initialPositionSequence
        radiusSequence
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
            nBallRadius=numel(obj.BallRadius);
            nVelocities=size(obj.circleVelocityXYZ,1);
            nInitialPositions=size(obj.initialXYZPosition,1);
            
            if obj.pairVelocityPosition
                if nVelocities~=nInitialPositions
                    error('In pairVelocityPosition mode, size of circleVelocityXYZ should be equal to initialXYZPosition');
                end
                obj.nTotTrials=obj.trialsPerCategory*nBallRadius*nVelocities;
            else
                obj.nTotTrials=obj.trialsPerCategory*nBallRadius*nVelocities*nInitialPositions;
            end
            
            %calculate sequece of positions and times
            obj.radiusSequence=nan(1,obj.nTotTrials);
            obj.velocitySequence=nan(3,obj.nTotTrials);
            obj.initialPositionSequence=nan(3,obj.nTotTrials);
            c=1;
            for i=1:nBallRadius
                for j=1:nVelocities
                    if obj.pairVelocityPosition
                        obj.radiusSequence(((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=obj.BallRadius(i);
                        obj.velocitySequence(:, ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=(ones(obj.trialsPerCategory,1)*obj.circleVelocityXYZ(j,:))';
                        obj.initialPositionSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.initialXYZPosition(j,:))';
                        c=c+1;
                    else
                        for k=1:nInitialPositions
                            obj.radiusSequence(((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=obj.BallRadius(i);
                            obj.velocitySequence(:, ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=(ones(obj.trialsPerCategory,1)*obj.circleVelocityXYZ(j,:))';
                            obj.initialPositionSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.initialXYZPosition(k,:))';
                            c=c+1;
                        end
                    end
                end
            end
            
            %randomize
            if obj.randomizeBallRadius
                randomPermutation=randperm(obj.nTotTrials);
                obj.radiusSequence=obj.radiusSequence(:,randomPermutation);
            end
            if obj.randomizeCircleVelocity
                randomPermutation=randperm(obj.nTotTrials);
                obj.velocitySequence=obj.velocitySequence(:,randomPermutation);
                if obj.pairVelocityPosition
                    obj.initialPositionSequence=obj.initialPositionSequence(:,randomPermutation);
                end
            end
            if obj.randomizeInitialPositions & ~obj.pairVelocityPosition
                randomPermutation=randperm(obj.nTotTrials);
                obj.initialPositionSequence=obj.initialPositionSequence(:,randomPermutation);
            end
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win,obj.masktexOff);
            Screen('Flip',obj.PTB_win);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            maxFrames=ceil((max(obj.initialPositionSequence(3,:))/-max(obj.velocitySequence(3,:)))/obj.ifi);
            obj.flip=nan(obj.nTotTrials,maxFrames);
            obj.stim=nan(obj.nTotTrials,maxFrames);
            obj.flipEnd=nan(obj.nTotTrials,maxFrames);
            obj.miss=nan(obj.nTotTrials,maxFrames);
            
            rotationMatrix=[cos(-obj.rotation/180*pi) -sin(-obj.rotation/180*pi);sin(-obj.rotation/180*pi) cos(-obj.rotation/180*pi)];
            
            edges=[obj.visualFieldRect(1) obj.visualFieldRect(2);obj.visualFieldRect(1) obj.visualFieldRect(4)/2;obj.visualFieldRect(3) obj.visualFieldRect(4)/2;obj.visualFieldRect(3) obj.visualFieldRect(2)];
            rotEdges=round((edges-ones(4,1)*[obj.centerX obj.centerY])*rotationMatrix)+ones(4,1)*[obj.centerX obj.centerY];
                        
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            
            %set background
            Screen('FillPoly', obj.PTB_win ,obj.skyLuminocity, rotEdges ,1);
            obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
            Screen('Flip', obj.PTB_win);
            
            
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                
                tmpCircleRadius=obj.radiusSequence(i);
                tmpVelocity=obj.velocitySequence(:,i);
                tmpInitialPosition=obj.initialPositionSequence(:,i);
                
                if obj.flyTime==0
                    movementDuration=(tmpInitialPosition(3)-0)/-tmpVelocity(3);
                else
                    movementDuration=obj.flyTime;
                end
                
                t=(obj.ifi:obj.ifi:movementDuration);
                nPoints=numel(t);
                
                f=obj.actualVFieldDiameter/2;
                Xw=tmpInitialPosition*ones(1,nPoints)+tmpVelocity*t; %position in world coordinate
                rw=sqrt(Xw(1,:).^2+Xw(2,:).^2+Xw(3,:).^2); %distance from origin in world coord
                r=round(f*tmpCircleRadius./rw);
                xy=(f*[Xw(1,:)./Xw(3,:);Xw(2,:)./Xw(3,:)]'*rotationMatrix)'+[obj.centerX;obj.centerY]*ones(1,nPoints);
                ovalCoordinates=round([xy(1,:)-r;xy(2,:)-r;xy(1,:)+r;xy(2,:)+r]);

                ttmp=t+GetSecs+obj.ifi;
                obj.sendTTL(2,true);
                for j=1:nPoints
                    % Update display
                    Screen('FillPoly', obj.PTB_win ,obj.skyLuminocity, rotEdges ,1);
                    Screen('FillOval',obj.PTB_win,obj.ballLuminocity,ovalCoordinates(:,j));
                    obj.applyBackgound; %set background mask and finalize drawing (drawing finished)

                    obj.sendTTL(3,true);
                    [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,ttmp(j));
                    obj.sendTTL(3,false);
                end
                endStimTime=GetSecs;
                
                Screen('FillPoly', obj.PTB_win ,obj.skyLuminocity, rotEdges ,1);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                WaitSecs(obj.lastFrameDwell-(GetSecs-endStimTime));
                Screen('Flip',obj.PTB_win);
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
            
            obj.initializeBackground;
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
        function obj=VS_loomingCircle3D(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
        end
    end
end %EOF