classdef VS_StaticBar < VStim
    properties (SetAccess=public)
        barLuminosity = 255; %(L_high-L_low)/L_low
        barWidth = 10; %pixels
        barLength = 1024;
        numberOfDirections = 8;
        parallelsOffset = 0;
        randomize = true;
        rotation = 0;
    end
    properties (Hidden,Constant)
        barLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        barWidthTxt='The width of the moving bar [pixels] - parallel to motion direction (<10)';
        barLengthTxt='The length of the moving bar [pixels] - perpendicular to motion direction (<number of pixels in the smaller screen axis)';
        numberOfDirectionsTxt='The number of directions to test (directions will be distributed uniformly over 360 degrees)';
        randomizeTxt='Randomize the order of different trials';
        parallelsOffsetTxt='the offset [pixels] of parallel propagation paths'
        remarks={'Categories in stimuli are: speed, offset'};
    end 
    properties (SetAccess=protected)
        directions
        offsets
        barTrajectories1X
        barTrajectories2X
        barTrajectories1Y
        barTrajectories2Y
        nFrames
        luminosities
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
            nLuminosities=numel(obj.barLuminosity);
            nOffsets=numel(obj.parallelsOffset);
            obj.nTotTrials=obj.trialsPerCategory*nLuminosities*nOffsets*obj.numberOfDirections;
            
            %calculate sequece of positions and times
            obj.luminosities=nan(1,obj.nTotTrials);
            obj.directions=nan(1,obj.nTotTrials);
            obj.offsets=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nLuminosities
                for j=1:nOffsets
                    for k=1:obj.numberOfDirections
                        obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.barLuminosity(i);
                        obj.offsets( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.parallelsOffset(j);
                        obj.directions( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=phi(k);
                        c=c+1;
                    end
                end
            end
            
            %randomize
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.luminosities=obj.luminosities(randomPermutation);
                obj.offsets=obj.offsets(randomPermutation);
                obj.directions=obj.directions(randomPermutation);
            end
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            obj.syncMarkerOn = false; %initialize sync signal
            
            mainBarCoordinates=[-obj.barLength/2 obj.barLength/2;0 0];
            rotationMatrix=@(x) [cos(x) -sin(x);sin(x) cos(x)];
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            obj.flip=nan(obj.nTotTrials,2);
            obj.stim=nan(obj.nTotTrials,2);
            obj.flipEnd=nan(obj.nTotTrials,2);
            obj.miss=nan(obj.nTotTrials,2);
            
            disp('preparing all trajectories');
            obj.barTrajectories1X=nan(nOffsets,obj.numberOfDirections);
            obj.barTrajectories2X=nan(nOffsets,obj.numberOfDirections);
            obj.barTrajectories1Y=nan(nOffsets,obj.numberOfDirections);
            obj.barTrajectories2Y=nan(nOffsets,obj.numberOfDirections);
            
            for j=1:nOffsets
                for k=1:obj.numberOfDirections
                    tmpOffset=obj.parallelsOffset(j);
                    tmpPhi=phi(k);
                    x0=obj.centerX+tmpOffset*cos(tmpPhi);
                    y0=obj.centerY-tmpOffset*sin(tmpPhi);
                    
                    rotatedCoord=rotationMatrix(2*pi-tmpPhi+pi/2)*mainBarCoordinates; %rotates counter clockwise but is important for offsets
                    tmp=rotatedCoord(:,1)' + [x0 y0];
                    obj.barTrajectories1X(j,k)=tmp(:,1);
                    obj.barTrajectories1Y(j,k)=tmp(:,2);
                    
                    tmp=rotatedCoord(:,2)' + [x0 y0];
                    obj.barTrajectories2X(j,k)=tmp(:,1);
                    obj.barTrajectories2Y(j,k)=tmp(:,2);
                end
            end
            %{
            line(mainBarCoordinates([1 3])',mainBarCoordinates([2 4])');
            line([obj.barTrajectories1X' obj.barTrajectories2X']',[obj.barTrajectories1Y' obj.barTrajectories2Y']');
            %}
            
            %-obj.barLength/2 obj.barLength/2
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');

            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                pTmpOffset=find(obj.parallelsOffset==obj.offsets(i));
                pTmpPhi=find(phi==obj.directions(i));
                                
                obj.sendTTL(2,true);
                
                Screen('DrawLine', obj.PTB_win, obj.luminosities(i),...
                    obj.barTrajectories1X(pTmpOffset,pTmpPhi),...
                    obj.barTrajectories1Y(pTmpOffset,pTmpPhi),...
                    obj.barTrajectories2X(pTmpOffset,pTmpPhi),...
                    obj.barTrajectories2Y(pTmpOffset,pTmpPhi), obj.barWidth);
                
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                [obj.flip(i,1),obj.stim(i,1),obj.flipEnd(i,1),obj.miss(i,1)]=Screen('Flip',obj.PTB_win);
                WaitSecs(obj.stimDuration);
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                [obj.flip(i,2),obj.stim(i,2),obj.flipEnd(i,2),obj.miss(i,2)]=Screen('Flip',obj.PTB_win);
                obj.sendTTL(2,false); %session start trigger (also triggers the recording start)

                % Start wait: Code here is run during the waiting for the new session
                
                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-obj.flip(i,2)));
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
        function obj=VS_StaticBar(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.visualFieldBackgroundLuminance=0;
        end
    end
end %EOF