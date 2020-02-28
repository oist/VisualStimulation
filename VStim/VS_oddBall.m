classdef VS_oddBall < VStim
    properties (SetAccess=public)
        rectLuminosity = [0 128 255]; %(L_high-L_low)/L_low
        rectGridSize = 10;
        tilingRatio = 1;
        rotation = 0;
        adaptRepeats = 5;
        probeRepeats = 5;
        afterRepeats = 5;
        oddBallPercent=20;
        randomize = true;
        interStimulusDelay=.5;
    end
    properties (Constant)
        rectLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        rectGridSizeTxt='The size (N x N) of the rectangular grid';
        rotationTxt='The angle for visual field rotation (clockwise)';
        adaptRepeatsTxt='the number of repeated stimuli at the start of trial';
        probeRepeatsTxt='the number of stimuli after the adaptation';
        oddBallPercentTxt='the percent of oddBall presentations in probe repeats';
        tilingRatioTxt='The ratio (0-1) beween the total tile length and field length (e.g. if 0.5 tiles are half the size require for complete tiling)';
        interStimulusDelayTxt='seconds between stimulus presentations in a trial';
        remarks={'Categories in Flash stimuli are: Luminocity'};
    end
    properties (SetAccess=protected)
        stimSequence
        pos2X
        pos2Y
        luminosities
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
            
            if obj.inVivoSettings~=1
                pValidRect=find( sqrt((X1-centerX).^2+(Y1-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                    sqrt((X2-centerX).^2+(Y2-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                    sqrt((X3-centerX).^2+(Y3-centerY).^2)<=(obj.actualVFieldDiameter/2) &...
                    sqrt((X4-centerX).^2+(Y4-centerY).^2)<=(obj.actualVFieldDiameter/2));
                
            else
                pValidRect=1:numel(X1);
            end
            
            
            nPositions=numel(pValidRect);
            nLuminosities=numel(obj.rectLuminosity);
            obj.nTotTrials=obj.trialsPerCategory*nLuminosities;
            
            %calculate sequece of positions and times
            obj.stimSequence=nan(1,nLuminosities*nPositions*obj.trialsPerCategory);
            obj.luminosities=nan(1,nLuminosities*nPositions*obj.trialsPerCategory);
            c=1;
            for i=1:nPositions
                for j=1:nLuminosities
                    obj.stimSequence( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=i;
                    obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.rectLuminosity(j);
                    c=c+1;
                end
            end
            
            for x=1:numel(obj.luminosities);
                lumIndices(x)=find(obj.luminosities(x)==obj.rectLuminosity);
            end
            
            if obj.randomize
                randomPermutation=randperm(nLuminosities*nPositions*obj.trialsPerCategory);
                obj.stimSequence=obj.stimSequence(randomPermutation);
                obj.luminosities=obj.luminosities(randomPermutation);
                randomPermutation2=randperm(nLuminosities*nPositions*obj.trialsPerCategory);
                stimSequence2=obj.stimSequence(randomPermutation2);
            end
            
            %make stimSequence of adaptation stim
            obj.stimSequence=repmat(obj.stimSequence,(obj.adaptRepeats+obj.probeRepeats+obj.afterRepeats),1);
            stimSequence2=repmat(stimSequence2,(obj.adaptRepeats+obj.probeRepeats+obj.afterRepeats),1);
            %figure out which stimuli will be oddball
            numOddBall=ceil(obj.probeRepeats*(obj.oddBallPercent/100));
         
            %make the same number of oddball stimuli to happen every trial
            oddBallLoc=zeros(obj.probeRepeats,size(obj.stimSequence,2));
            for x=1:size(oddBallLoc,2)
                ob=randperm(obj.probeRepeats);
                ob=ob(1:numOddBall);
              oddBallLoc(ob,x)=ones(1,numel(ob));
            end
            
            oddballStim=[zeros(obj.adaptRepeats,size(obj.stimSequence,2)); oddBallLoc; zeros(obj.afterRepeats,size(obj.stimSequence,2))];
            oddballStim=find(oddballStim==1);
            obj.stimSequence(oddballStim)=stimSequence2(oddballStim);
           
            obj.stimSequence=[obj.stimSequence ;obj.stimSequence(1,:)]; %add an additional stimulus that will never be shown
            %calculate X and Y position for the valid places
            obj.pos2X=rem(pValidRect,obj.rectGridSize);
            obj.pos2X(obj.pos2X==0)=obj.rectGridSize;
            
            obj.pos2Y=ceil((pValidRect-0.5)/obj.rectGridSize);
            
            obj.pos2X=obj.pos2X-min(obj.pos2X)+1;
            obj.pos2Y=obj.pos2Y-min(obj.pos2Y)+1;
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            
            % Update image buffer for the first time
            for i=1:nPositions
                for j=1:nLuminosities
                    I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                    I(X1(pValidRect(i)):X3(pValidRect(i)),Y1(pValidRect(i)):Y3(pValidRect(i)))=obj.rectLuminosity(j)*ones(numel(X1(pValidRect(i)):X3(pValidRect(i))),...
                        numel(Y1(pValidRect(i)):Y3(pValidRect(i))));
                    imgTex(i,j)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
                end
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
            save tmpVSFile obj; %temporarily save object in case of a system crash
            disp('Session starting');
            
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            
            for i=1:size(obj.stimSequence,2)
                disp(['Trial ' num2str(i) '/' num2str(size(obj.stimSequence,2))]);
                Screen('DrawTexture',obj.PTB_win,imgTex(obj.stimSequence(1,i),lumIndices(i)),[],obj.visualFieldRect,obj.rotation);
                
                for j=1:size(obj.stimSequence,1)-1
                    obj.sendTTL(2,true);
                    obj.applyBackgound;
                    [obj.on_Flip(j,i),obj.on_Stim(j,i),obj.on_FlipEnd(j,i),obj.on_Miss(j,i)]=Screen('Flip',obj.PTB_win);
                    obj.sendTTL(3,true);
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                    obj.applyBackgound;
                    [obj.off_Flip(j,i),obj.off_Stim(j,i),obj.off_FlipEnd(j,i),obj.off_Miss(j,i)]=Screen('Flip',obj.PTB_win,obj.on_Flip(j,i)+obj.actualStimDuration-0.5*obj.ifi);
                    obj.sendTTL(3,false);
                    % Update image buffer for the first time
                    Screen('DrawTexture',obj.PTB_win,imgTex(obj.stimSequence(j+1,i),lumIndices(i)),[],obj.visualFieldRect,obj.rotation);
                    WaitSecs(obj.interStimulusDelay-(GetSecs-obj.off_Flip(j,i)));
                end
                obj.sendTTL(2,false);
                
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-obj.off_Flip(j,i)));
            end
           obj.stimSequence(end,:)=[]; %remove the last stim which is not shown
            
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
                stimDurationShifts=(obj.off_Flip-obj.on_Flip)-obj.actualStimDuration;
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
        function obj=VS_oddBall(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF