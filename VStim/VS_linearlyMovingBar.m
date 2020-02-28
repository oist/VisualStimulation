classdef VS_linearlyMovingBar < VStim
    properties (SetAccess=public)
        barLuminosity = 255; %(L_high-L_low)/L_low
        barWidth = 10; %pixels
        barLength = 1024;
        numberOfDirections = 8;
        parallelsOffset = 0;
        skipFrames=0;
        randomize = true;
        speed = 500; %pixel per second
        rotation = 0;
    end
    properties (Hidden,Constant)
        barLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        barWidthTxt='The width of the moving bar [pixels] - parallel to motion direction (<10)';
        barLengthTxt='The length of the moving bar [pixels] - perpendicular to motion direction (<number of pixels in the smaller screen axis)';
        numberOfDirectionsTxt='The number of directions to test (directions will be distributed uniformly over 360 degrees)';
        randomizeTxt='Randomize the order of different trials';
        speedTxt='The speed of the moving object [pixels/sec]';
        parallelsOffsetTxt='the offset [pixels] of parallel propagation paths'
        skipFramesTxt='if to only show a subset of frames';
        remarks={'Categories in stimuli are: speed, offset'};
    end
    properties (SetAccess=protected)
        speeds
        directions
        offsets
        barTrajectories1X
        barTrajectories2X
        barTrajectories1Y
        barTrajectories2Y
        nFrames
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
            phi=(0:(obj.numberOfDirections-1))*(2.*pi/obj.numberOfDirections)+obj.rotation/180*pi;
            nSpeeds=numel(obj.speed);
            nOffsets=numel(obj.parallelsOffset);
            obj.nTotTrials=obj.trialsPerCategory*nSpeeds*nOffsets*obj.numberOfDirections;
            
            D0=obj.actualVFieldDiameter+obj.barWidth; %half a ball on each side
            r0=D0/2;
            obj.stimDuration=D0./mean(obj.speed);
            
            %calculate sequece of positions and times
            obj.speeds=nan(1,obj.nTotTrials);
            obj.directions=nan(1,obj.nTotTrials);
            obj.offsets=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nSpeeds
                for j=1:nOffsets
                    for k=1:obj.numberOfDirections
                        obj.speeds( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.speed(i);
                        obj.offsets( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.parallelsOffset(j);
                        obj.directions( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=phi(k);
                        c=c+1;
                    end
                end
            end
            
            %randomize
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.speeds=obj.speeds(randomPermutation);
                obj.offsets=obj.offsets(randomPermutation);
                obj.directions=obj.directions(randomPermutation);
            end
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            obj.syncMarkerOn = false; %initialize sync signal
            
            mainBarCoordinates=[0 0;-obj.barLength/2 obj.barLength/2];
            rotationMatrix=@(x) [cos(x) -sin(x);sin(x) cos(x)];
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            maxFrames=ceil(D0./min(obj.speed)/obj.ifi+1);
            obj.flip=nan(obj.nTotTrials,maxFrames);
            obj.stim=nan(obj.nTotTrials,maxFrames);
            obj.flipEnd=nan(obj.nTotTrials,maxFrames);
            obj.miss=nan(obj.nTotTrials,maxFrames);
            
            disp('preparing all trajectories');
            maximalNumberOfFrames=ceil(max(D0./obj.speed)./obj.ifi);
            obj.barTrajectories1X=nan(nSpeeds,nOffsets,obj.numberOfDirections,maximalNumberOfFrames);
            obj.barTrajectories2X=nan(nSpeeds,nOffsets,obj.numberOfDirections,maximalNumberOfFrames);
            obj.barTrajectories1Y=nan(nSpeeds,nOffsets,obj.numberOfDirections,maximalNumberOfFrames);
            obj.barTrajectories2Y=nan(nSpeeds,nOffsets,obj.numberOfDirections,maximalNumberOfFrames);
            for i=1:nSpeeds
                for j=1:nOffsets
                    for k=1:obj.numberOfDirections
                        tmpSpeed=obj.speed(i);
                        tmpOffset=obj.parallelsOffset(j);
                        tmpPhi=phi(k);
                        x0=r0*sin(tmpPhi)+obj.centerX+tmpOffset(j)*cos(tmpPhi);
                        y0=r0*cos(tmpPhi)+obj.centerY-tmpOffset(j)*sin(tmpPhi);
                        xV=tmpSpeed*sin(tmpPhi+pi); %direction speed always opposite from start point (180 degees change)
                        yV=tmpSpeed*cos(tmpPhi+pi); %direction speed always opposite from start point (180 degees change)
                        movementDuration(i,j,k)=D0/tmpSpeed;
                        t=(0:obj.ifi:movementDuration(i,j,k))';
                        t=t((1/2+obj.skipFrames/2):(1+obj.skipFrames):end);
                        obj.nFrames(i,j,k)=numel(t);
                        x=x0+xV.*t;
                        y=y0+yV.*t;
                        
                        rotatedCoord=rotationMatrix(2*pi-tmpPhi+pi/2)*mainBarCoordinates;
                        tmp=ones(obj.nFrames(i,j,k),1) * rotatedCoord(:,1)' + [x y];
                        obj.barTrajectories1X(i,j,k,1:obj.nFrames(i,j,k))=tmp(:,1);
                        obj.barTrajectories1Y(i,j,k,1:obj.nFrames(i,j,k))=tmp(:,2);
                        
                        tmp=ones(obj.nFrames(i,j,k),1) * rotatedCoord(:,2)' + [x y];
                        obj.barTrajectories2X(i,j,k,1:obj.nFrames(i,j,k))=tmp(:,1);
                        obj.barTrajectories2Y(i,j,k,1:obj.nFrames(i,j,k))=tmp(:,2);
                        
                        %{
                        plot(squeeze(obj.barTrajectories1X(i,j,k,:)),squeeze(obj.barTrajectories1Y(i,j,k,:)),'.');hold on;
                        plot(squeeze(obj.barTrajectories2Y(i,j,k,:)),squeeze(obj.barTrajectories2Y(i,j,k,:)),'.r');
                        %}
                    
                    end
                end
            end
            
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');

            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                pTmpSpeed=find(obj.speed==obj.speeds(i));
                pTmpOffset=find(obj.parallelsOffset==obj.offsets(i));
                pTmpPhi=find(phi==obj.directions(i));
                
                %figure;plot(p1(:,1),p1(:,2),'.r');hold on;plot(p2(:,1),p2(:,2),'.');
                t=(0:((1+obj.skipFrames)*obj.ifi):movementDuration(pTmpSpeed,pTmpOffset,pTmpPhi))';
                tTmp=t+GetSecs;
                
                obj.sendTTL(2,true);
                for j=1:obj.nFrames(pTmpSpeed,pTmpOffset,pTmpPhi)
                    % Update display
                    Screen('DrawLine', obj.PTB_win, obj.barLuminosity,obj.barTrajectories1X(pTmpSpeed,pTmpOffset,pTmpPhi,j),...
                        obj.barTrajectories1Y(pTmpSpeed,pTmpOffset,pTmpPhi,j),...
                        obj.barTrajectories2X(pTmpSpeed,pTmpOffset,pTmpPhi,j),...
                        obj.barTrajectories2Y(pTmpSpeed,pTmpOffset,pTmpPhi,j), obj.barWidth);
                    
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                    
                    obj.sendTTL(3,true); %session start trigger (also triggers the recording start)
                    %[obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,tTmp(j));
                    Screen('Flip',obj.PTB_win,tTmp(j));
                    obj.sendTTL(3,false); %session start trigger (also triggers the recording start)
                end
                obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)

                [endSessionTime]=Screen('Flip',obj.PTB_win);
                % Start wait: Code here is run during the waiting for the new session
                
                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-endSessionTime));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
            disp('Session ended');
        end

        function outStats=getLastStimStatistics(obj,hFigure)
           outStats.props=obj.getProperties;
            %{
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
           %}
        end
        %class constractor
        function obj=VS_linearlyMovingBar(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
        end
    end
end %EOF