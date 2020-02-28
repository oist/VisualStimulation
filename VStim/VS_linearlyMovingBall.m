classdef VS_linearlyMovingBall < VStim
    properties (SetAccess=public)
        ballLuminosity = 255; %(L_high-L_low)/L_low
        ballSize = 100; %pixels
        numberOfDirections = 8;
        parallelsOffset = 0;
        randomize = true;
        speed = 500; %pixel per second
        rotation = 0;
    end
    properties (Constant)
        ballLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        ballSizeTxt='The size of the moving ball [pixels]';
        numberOfDirectionsTxt='The number of directions to test (directions will be distributed uniformly over 360 degrees)';
        randomizeTxt='Randomize the order of different trials';
        speedTxt='The speed of the moving object [pixels/sec]';
        parallelsOffsetTxt='the offset [pixels] of parallel propagation paths'
        rotationTxt='The rotation angle of the images (for alignment to visual streak';
        remarks={'Categories in stimuli are: speed, offset'};
    end
    properties (SetAccess=protected)
        speeds
        directions
        offsets
        ballSizes
        movementDuration
        nFrames
        
        ballTrajectoriesX
        ballTrajectoriesY
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
            nBallSizes=numel(obj.ballSize);
            obj.nTotTrials=obj.trialsPerCategory*nSpeeds*nBallSizes*nOffsets*obj.numberOfDirections;
            
            D0=obj.actualVFieldDiameter+obj.ballSize; %half a ball on each side
            r0=D0/2;
            obj.stimDuration=D0/mean(obj.speed);
            
            %calculate sequece of positions and times
            obj.speeds=nan(1,obj.nTotTrials);
            obj.directions=nan(1,obj.nTotTrials);
            obj.offsets=nan(1,obj.nTotTrials);
            obj.ballSizes=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nSpeeds
                for j=1:nOffsets
                    for k=1:obj.numberOfDirections
                        for l=1:nBallSizes
                            obj.speeds( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.speed(i);
                            obj.offsets( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.parallelsOffset(j);
                            obj.directions( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=phi(k);
                            obj.ballSizes( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.ballSize(l);
                            c=c+1;
                        end
                    end
                end
            end
            
            %randomize
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.speeds=obj.speeds(randomPermutation);
                obj.offsets=obj.offsets(randomPermutation);
                obj.directions=obj.directions(randomPermutation);
                obj.ballSizes=obj.ballSizes(randomPermutation);
            end
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            obj.syncMarkerOn = false; %initialize sync signal
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            maxFrames=ceil(D0./min(obj.speed)/obj.ifi);
            obj.flip=nan(obj.nTotTrials,max(maxFrames));
            obj.stim=nan(obj.nTotTrials,max(maxFrames));
            obj.flipEnd=nan(obj.nTotTrials,max(maxFrames));
            obj.miss=nan(obj.nTotTrials,max(maxFrames));
            
            
            disp('preparing all trajectories');

            maximalNumberOfFrames=ceil(max(D0./obj.speed)./obj.ifi);
            obj.ballTrajectoriesX=nan(nSpeeds,nOffsets,obj.numberOfDirections,maximalNumberOfFrames);
            obj.ballTrajectoriesY=nan(nSpeeds,nOffsets,obj.numberOfDirections,maximalNumberOfFrames);
            for i=1:nSpeeds
                for j=1:nOffsets
                    for k=1:obj.numberOfDirections
                        for l=1:nBallSizes
                            tmpSpeed=obj.speed(i);
                            tmpOffset=obj.parallelsOffset(j);
                            tmpPhi=phi(k);
                            tmpSize=obj.ballSizes(l);
                            
                            x0=r0(l)*sin(tmpPhi)+obj.centerX+tmpOffset*cos(tmpPhi);
                            y0=r0(l)*cos(tmpPhi)+obj.centerY-tmpOffset*sin(tmpPhi);
                            xV=tmpSpeed*sin(tmpPhi+pi); %direction speed always opposite from start point (180 degees change)
                            yV=tmpSpeed*cos(tmpPhi+pi); %direction speed always opposite from start point (180 degees change)
                            movementDuration=D0(l)/tmpSpeed;
                            t=(0:obj.ifi:movementDuration)';
                            obj.nFrames(i,j,k)=numel(t);
  
                            obj.ballTrajectoriesX(i,j,k,1:obj.nFrames(i,j,k))=x0+xV.*t;
                            obj.ballTrajectoriesY(i,j,k,1:obj.nFrames(i,j,k))=y0+yV.*t;
                            
                            %scatter( squeeze(obj.ballTrajectoriesX(i,j,k,1:obj.nFrames(i,j,k))) , squeeze(obj.ballTrajectoriesY(i,j,k,1:obj.nFrames(i,j,k))),[],t)
                        end
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
                
                t=(1:obj.nFrames(pTmpSpeed,pTmpOffset,pTmpPhi))*obj.ifi+GetSecs;
                
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                for j=1:obj.nFrames(pTmpSpeed,pTmpOffset,pTmpPhi)
                    % Update display
                    
                    ballCoordinates=[obj.ballTrajectoriesX(pTmpSpeed,pTmpOffset,pTmpPhi,j)-obj.ballSizes(i)/2,...
                        obj.ballTrajectoriesY(pTmpSpeed,pTmpOffset,pTmpPhi,j)-obj.ballSizes(i)/2,...
                        obj.ballTrajectoriesX(pTmpSpeed,pTmpOffset,pTmpPhi,j)+obj.ballSizes(i)/2,...
                        obj.ballTrajectoriesY(pTmpSpeed,pTmpOffset,pTmpPhi,j)+obj.ballSizes(i)/2];
                    
                    Screen('FillOval',obj.PTB_win,obj.ballLuminosity,ballCoordinates);
                    
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                    
                    obj.sendTTL(3,true); %session start trigger (also triggers the recording start)
                    [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,t(j));
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
        function obj=VS_linearlyMovingBall(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=NaN;
        end
    end
end %EOF