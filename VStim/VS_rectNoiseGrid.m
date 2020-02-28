classdef VS_rectNoiseGrid < VStim
    properties (SetAccess=public)
        rectLuminosity = [0 128 255]; %(L_high-L_low)/L_low
        rectGridSize = 4;
        tilingRatio = 1;
        rotation = 0;
    end
    properties (Constant)
        rectLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        rectGridSizeTxt='The size (N x N) of the rectangular grid';
        rotationTxt='The angle for visual field rotation (clockwise)';
        tilingRatioTxt='The ratio (0-1) beween the total tile length and field length (e.g. if 0.5 tiles are half the size require for complete tiling)';
        remarks={'Categories in Flash stimuli are: Luminocity'};
    end
    properties (SetAccess=protected)
        stimSequence
        pos2X
        pos2Y    
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
            %calculate the coordinates for the rectangles that fit into the visual space
            centerX=obj.actualVFieldDiameter/2;
            centerY=obj.actualVFieldDiameter/2;
            
            %calculate the coordinates for the rectangles that fit into the visual space
            rectSpacing=floor(obj.actualVFieldDiameter/obj.rectGridSize)-1;
            rectSide=rectSpacing*obj.tilingRatio;
            edges=floor((rectSpacing-rectSide)/2):rectSpacing:(obj.actualVFieldDiameter-rectSide);
            edges=floor(edges+((obj.actualVFieldDiameter-(edges(end)+rectSide))-edges(1))/2);
            [X1,Y1]=meshgrid(edges,edges);
            X1=X1;
            Y1=Y1;
            X2=X1+rectSide-1;
            Y2=Y1;
            X3=X1+rectSide-1;
            Y3=Y1+rectSide-1;
            X4=X1;
            Y4=Y1+rectSide-1;
            pValidRect=find( sqrt((X1-centerX).^2+(Y1-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                sqrt((X2-centerX).^2+(Y2-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                sqrt((X3-centerX).^2+(Y3-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                sqrt((X4-centerX).^2+(Y4-centerY).^2)<=(obj.actualVFieldDiameter/2));
            
            nPositions=numel(pValidRect);
            nLuminosities=numel(obj.rectLuminosity);
            obj.nTotTrials=obj.trialsPerCategory*nLuminosities;
            
            %calculate X and Y position for the valid places
            obj.pos2X=rem(pValidRect,obj.rectGridSize);
            obj.pos2X(obj.pos2X==0)=obj.rectGridSize;
            
            obj.pos2Y=ceil((pValidRect-0.5)/obj.rectGridSize);
            
            obj.pos2X=obj.pos2X-min(obj.pos2X)+1;
            obj.pos2Y=obj.pos2Y-min(obj.pos2Y)+1;
            
            %prepare stimulation sequence
            obj.stimSequence=ones(nPositions,1)*reshape(ones(obj.trialsPerCategory,1)*obj.rectLuminosity,[1 obj.nTotTrials]);
            for i=1:nPositions
                obj.stimSequence(i,:)=obj.stimSequence(i,randperm(obj.nTotTrials));
            end
            %add dummy stimuli that will never be shown
            obj.stimSequence(:,obj.nTotTrials+1)=obj.stimSequence(:,1);
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false;
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            
            % Update image buffer for the first time
            I=zeros(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2),nPositions);
            IBackground=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2))*obj.visualFieldBackgroundLuminance;
            pRectIndX=cell(1,nPositions);
            pRectIndY=cell(1,nPositions);
            for i=1:nPositions
                pRectIndX{i}=X1(pValidRect(i)):X3(pValidRect(i));
                pRectIndY{i}=Y1(pValidRect(i)):Y3(pValidRect(i));
                I(pRectIndX{i},pRectIndY{i},i)=1;
                IBackground(pRectIndX{i},pRectIndY{i})=0;
            end
            %Pre allocate memory for variables
            obj.on_Flip=nan(1,obj.nTotTrials+1);
            obj.on_Stim=nan(1,obj.nTotTrials+1);
            obj.on_FlipEnd=nan(1,obj.nTotTrials+1);
            obj.on_Miss=nan(1,obj.nTotTrials+1);
            obj.off_Flip=nan(1,obj.nTotTrials+1);
            obj.off_Stim=nan(1,obj.nTotTrials+1);
            obj.off_FlipEnd=nan(1,obj.nTotTrials+1);
            obj.off_Miss=nan(1,obj.nTotTrials+1);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            % Update image buffer for the first time
            imgTex=Screen('MakeTexture', obj.PTB_win,IBackground+sum(bsxfun(@times,shiftdim(obj.stimSequence(:,1),-2),I),3),obj.rotation);
            Screen('DrawTexture',obj.PTB_win,imgTex,[],obj.visualFieldRect,obj.rotation);
            obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)

            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win);
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                
                if obj.interTrialDelay>0
                    % Update display
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                    
                    [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win,obj.on_Flip(i)+obj.actualStimDuration-0.5*obj.ifi);
                    obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                else
                    obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                    obj.off_Flip(i)=0;
                    obj.off_Stim(i)=0;
                    obj.off_FlipEnd(i)=0;
                    obj.off_Miss(i)=0;
                end
                % Update image buffer
                imgTex=Screen('MakeTexture', obj.PTB_win,IBackground+sum(bsxfun(@times,shiftdim(obj.stimSequence(:,i+1),-2),I),3),obj.rotation);
                Screen('DrawTexture',obj.PTB_win,imgTex,[],obj.visualFieldRect,obj.rotation);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)

                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                if obj.interTrialDelay>0
                    WaitSecs(obj.interTrialDelay-(GetSecs-obj.off_Flip(i)));
                else
                    WaitSecs(obj.stimDuration-(GetSecs-obj.on_Stim(i)));
                end
            end
            obj.stimSequence(:,obj.nTotTrials+1)=[]; %remove the last dummy stimuli
            
            Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)

            [obj.on_Flip(i+1),obj.on_Stim(i+1),obj.on_FlipEnd(i+1),obj.on_Miss(i+1)]=Screen('Flip',obj.PTB_win);
            
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
            disp('Session ended');
            Screen('Close',imgTex);
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            if nargin==2
                intervals=-1e-1:2e-4:1e-1;
                intCenter=(intervals(1:end-1)+intervals(2:end))/2;
                if obj.interTrialDelay>0
                    stimDurationShifts=(obj.off_Flip(1:end-1)-obj.on_Flip(1:end-1))-obj.actualStimDuration;
                else
                    stimDurationShifts=(obj.on_Flip(2:end)-obj.on_Flip(1:end-1))-obj.actualStimDuration;
                end
                n1=histc(stimDurationShifts,intervals);
                
                flipDurationShiftsOn=obj.on_FlipEnd-obj.on_Flip;
                flipDurationShiftsOff=obj.off_FlipEnd-obj.off_Flip;
                n2=histc([flipDurationShiftsOn' flipDurationShiftsOff'],intervals,1);
                
                flipToStimOn=(obj.on_Stim-obj.on_Flip);
                flipToStimOff=(obj.off_Stim-obj.off_Flip);
                n3=histc([flipToStimOn' flipToStimOff'],intervals,1);
                
                n4=histc([obj.on_Miss' obj.on_Miss'],intervals,1);
                
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
        %class constractor
        function obj=VS_rectNoiseGrid(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.interTrialDelay=0;
            obj.visualFieldBackgroundLuminance=128;
        end
    end
end %EOF