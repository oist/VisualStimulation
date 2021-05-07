classdef VS_rectGridTremor < VStim
    properties
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        
        %visualFieldBackgroundLuminance = 128;
        %visualFieldDiameter = 1024; %pixels
        %stimDuration = 1; %superclass VStim
        %interTrialDelay = 20; %superclass VStim
        %trialsPerCategory = 10;
        %preSessionDelay = 10;
        rectLuminosity = 255; %(L_high-L_low)/L_low
        rectGridSize = 4;
        randomize = true;
        tilingRatio = 1;
        rotation = 0;
        tremorPixels = 2;
        tremorFreq = 5;
    end
    properties (Hidden,Constant)
        rectLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeTxt='Randomize stimuli';
        rectGridSizeTxt='The size (N x N) of the rectangular grid';
        rotationTxt='The angle for visual field rotation (clockwise)';
        tilingRatioTxt='The ratio (0-1) beween the total tile length and field length (e.g. if 0.5 tiles are half the size require for complete tiling)';
        tremorPixelsTxt='number of moving pixels';
        tremorFreqTxt='frequency of movement [Hz]';
        remarks={'Categories in Flash stimuli are:'};
    end
    properties (Hidden)
        pos2X
        pos2Y
        pos
        luminosities
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
            obj.nTotTrials=obj.trialsPerCategory*nLuminosities*nPositions;
            
            %calculate sequece of positions and times
            obj.pos=nan(1,obj.nTotTrials);
            obj.luminosities=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nPositions
                for j=1:nLuminosities
                    obj.pos( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=i;
                    obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.rectLuminosity(j);
                    c=c+1;
                end
            end
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.pos=obj.pos(randomPermutation);
                obj.luminosities=obj.luminosities(randomPermutation);
            end
            obj.pos=[obj.pos obj.pos(1)]; %add an additional stimulus that will never be shown

            %calculate X and Y position for the valid places
            obj.pos2X=rem(pValidRect,obj.rectGridSize);
            obj.pos2X(obj.pos2X==0)=obj.rectGridSize;
            
            obj.pos2Y=ceil((pValidRect-0.5)/obj.rectGridSize);
            
            obj.pos2X=obj.pos2X-min(obj.pos2X)+1;
            obj.pos2Y=obj.pos2Y-min(obj.pos2Y)+1;
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            
            % Update image buffer for the first time
            for i=1:nPositions
                I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                I(X1(pValidRect(i)):X3(pValidRect(i)),Y1(pValidRect(i)):Y3(pValidRect(i)))=obj.rectLuminosity;
                imgTex(i,1)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
                
                I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                I((X1(pValidRect(i))+obj.tremorPixels):(X3(pValidRect(i))+obj.tremorPixels),...
                    (Y1(pValidRect(i))+obj.tremorPixels):(Y3(pValidRect(i))+obj.tremorPixels))=obj.rectLuminosity;
                imgTex(i,2)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
            end
            
            switchTimes=0:(1/obj.tremorFreq/2):obj.stimDuration;
            nSwitchTimes=numel(switchTimes);
            
            %Pre allocate memory for variables
            obj.on_Flip=nan(nSwitchTimes,obj.nTotTrials);
            obj.on_Stim=nan(nSwitchTimes,obj.nTotTrials);
            obj.on_FlipEnd=nan(nSwitchTimes,obj.nTotTrials);
            obj.on_Miss=nan(nSwitchTimes,obj.nTotTrials);
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
            
            %main loop - start the session
            pp(uint8(obj.trigChNames(1)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                tremorPos=1;
                Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(i+1),tremorPos+1),[],obj.visualFieldRect,obj.rotation);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                
                pp(uint8(obj.trigChNames(2)),true,false,uint8(0),uint64(32784));
                
                t0=GetSecs;
                for j=1:numel(switchTimes)
                    [obj.on_Flip(j,i),obj.on_Stim(j,i),obj.on_FlipEnd(j,i),obj.on_Miss(j,i)]=Screen('Flip',obj.PTB_win,t0+switchTimes(j));
                    pp(uint8(obj.trigChNames(3)),tremorPos,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    
                    tremorPos=~tremorPos;
                    
                    Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(i+1),tremorPos+1),[],obj.visualFieldRect,obj.rotation);
                    Screen('DrawTexture',obj.PTB_win,obj.masktex);
                    Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                end
                
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                
                
                [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win,t0+obj.stimDuration);
                pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784));
                
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-obj.off_Flip(i)));
            end
            obj.pos(end)=[]; %remove the last stim which is not shown
            
            WaitSecs(obj.postSessionDelay);
            pp(uint8(obj.trigChNames(1)),false,false,uint8(0),uint64(32784)); %session end trigger
            disp('Session ended');
            Screen('Close',imgTex);
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            if nargin==2
                intervals=-1e-1:2e-4:3e-1;
                intCenter=(intervals(1:end-1)+intervals(2:end))/2;
                stimDurationShifts=(obj.off_Flip-obj.on_Flip(1,:))-obj.actualStimDuration;
                n1=histc(stimDurationShifts,intervals);
                
                flipDurationShiftsOn=obj.on_FlipEnd(1,:)-obj.on_Flip(1,:);
                flipDurationShiftsOff=obj.off_FlipEnd-obj.off_Flip;
                n2=histc([flipDurationShiftsOn' flipDurationShiftsOff'],intervals,1);
                
                flipToStimOn=(obj.on_Stim(1,:)-obj.on_Flip(1,:));
                flipToStimOff=(obj.off_Stim-obj.off_Flip);
                n3=histc([flipToStimOn' flipToStimOff'],intervals,1);
                
                tmp=diff(obj.on_Flip);
                n4=histc(tmp(:),intervals,1);
                
                figure(hFigure);
                subplot(2,2,1);
                bar(1e3*intCenter,n1(1:end-1),'Edgecolor','none');
                xlim(1e3*intervals([max(1,find(n1>0,1,'first')-3) min(numel(n1),find(n1>0,1,'last')+4)]));
                ylabel('\Delta(Flip)');
                xlabel('Time [ms]');
                line([obj.ifi obj.ifi],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,2);
                bar(1e3*intCenter,n2(1:end-1,:),'Edgecolor','none');
                xlim([-0.5 1e3*intervals(min(size(n2,1),find(sum(n2,2)>0,1,'last')+4))]);
                ylabel('Flip duration');
                xlabel('Time [ms]');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,3);
                bar(1e3*intCenter,n3(1:end-1,:),'Edgecolor','none');
                xlim(1e3*intervals([max(1,find(n3>0,1,'first')-3) min(size(n3,1),find(sum(n3,2)>0,1,'last')+4)]));
                ylabel('Flip 2 Stim');
                xlabel('Time [ms]');
                line([0 0],ylim,'color','k','LineStyle','--');
                
                subplot(2,2,4);
                bar(1e3*intCenter,n4(1:end-1),'Edgecolor','none');
                xlim(1e3*intervals([max(1,find(n4>0,1,'first')-3) min(numel(n4),find(n4>0,1,'last')+4)]));
                ylabel('Tremor stats');
                xlabel('Time [ms]');
                line([0 0],ylim,'color','k','LineStyle','--');
            end
        end
        %class constractor
        function obj=VS_rectGridTremor(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF