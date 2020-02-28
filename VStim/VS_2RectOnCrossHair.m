classdef VS_2RectOnCrossHair < VStim
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
        randomize = true;
        rectGridElements = 7;
        rotation = 0;
        pairStim = true;
    end
    properties (Hidden,Constant)
        rectLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeTxt='Randomize stimuli';
        rectGridElementsTxt='The size (N x N) of the rectangular grid';
        rotationTxt='The angle for visual field rotation (clockwise)';
        pairStimTxt='Whether to stimulate single + pairs of rectangles (or just single)';
        remarks={'Categories in Flash stimuli are:'};
    end
    properties (Hidden)
        pos2X
        pos2Y
        pos
        luminosities
        rectSide
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
            if round(obj.rectGridElements/2)==obj.rectGridElements/2
                obj.errorMsg='The number of grid elements must be odd';
                return;
            end
            %calculate the coordinates for the rectangles that fit into the visual space
            centerX=obj.actualVFieldDiameter/2;
            centerY=obj.actualVFieldDiameter/2;
            
            %Calculate vertical rectangles (bottom left point)
            rectSide=floor(2*(obj.actualVFieldDiameter/2)/sqrt(obj.rectGridElements^2+4));
            tmpX1=ones(1,obj.rectGridElements)*(centerY-rectSide/2);
            tmpY1=centerX+(-0.5+ceil(-obj.rectGridElements/2):floor(obj.rectGridElements/2))*rectSide;
            tmpY1(ceil(obj.rectGridElements/2))=[];
            
            %Add horizontal rectangles (bottom left point)
            X1=round([tmpX1 tmpY1]);
            Y1=round([tmpY1 tmpX1]);           
            
            %calculate all other points
            X2=X1+rectSide-1;
            Y2=Y1;
            X3=X1+rectSide-1;
            Y3=Y1+rectSide-1;
            X4=X1;
            Y4=Y1+rectSide-1;

            nSinglePositions=numel(X1);
            if obj.pairStim
                tmpPos2X=round(X1/rectSide)+1;
                tmpPos2Y=round(Y1/rectSide)+1;
                [X,Y]=meshgrid(1:nSinglePositions,1:nSinglePositions);
                lowerDiagonalPlaces=find(tril(ones(nSinglePositions),0)>0);
                X=tril(X(lowerDiagonalPlaces));
                Y=tril(Y(lowerDiagonalPlaces));
                obj.pos2X=[tmpPos2X(X);tmpPos2X(Y)];
                obj.pos2Y=[tmpPos2Y(X);tmpPos2Y(Y)];
                nPositions=numel(X);
            else
                nPositions=numel(X1);
                tmpPos2X=round(X1/rectSide)+1;
                tmpPos2Y=round(Y1/rectSide)+1;
                obj.pos2X=[tmpPos2X;tmpPos2X];
                obj.pos2Y=[tmpPos2Y;tmpPos2Y];
            end
            posNum=zeros(obj.rectGridElements);
            posNum(sub2ind([obj.rectGridElements,obj.rectGridElements], tmpPos2X, tmpPos2Y))=1:nSinglePositions;
            
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
            
            % Update image buffer for the first time
            for i=1:nPositions
                I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
                I( X1(posNum(obj.pos2X(1,i),obj.pos2Y(1,i))):X3(posNum(obj.pos2X(1,i),obj.pos2Y(1,i))) , ...
                    Y1(posNum(obj.pos2X(1,i),obj.pos2Y(1,i))):Y3(posNum(obj.pos2X(1,i),obj.pos2Y(1,i))))=obj.rectLuminosity;
                I( X1(posNum(obj.pos2X(2,i),obj.pos2Y(2,i))):X3(posNum(obj.pos2X(2,i),obj.pos2Y(2,i))) , ...
                    Y1(posNum(obj.pos2X(2,i),obj.pos2Y(2,i))):Y3(posNum(obj.pos2X(2,i),obj.pos2Y(2,i))))=obj.rectLuminosity;
                imgTex(i)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
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
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance,obj.visualFieldRect);
            Screen('DrawTexture',obj.PTB_win,obj.masktex);
            Screen('Flip',obj.PTB_win);
            
            Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(1)),[],obj.visualFieldRect,obj.rotation);
            Screen('DrawTexture',obj.PTB_win,obj.masktex);
            
            %main loop - start the session
            pp(uint8(obj.trigChNames(1)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win);
                pp(uint8(obj.trigChNames(2)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                
                % Update display
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance,obj.visualFieldRect);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                
                
                [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win,obj.on_Flip(i)+obj.actualStimDuration-0.5*obj.ifi);
                pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                
                % Update image buffer for the first time
                Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(i+1)),[],obj.visualFieldRect,obj.rotation);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')

                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-obj.off_Flip(i)));
            end
            pp(uint8(obj.trigChNames(1)),false,false,uint8(0),uint64(32784)); %session end trigger
            WaitSecs(obj.postSessionDelay);
            
            obj.pos(end)=[]; %remove the last stim which is not shown
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
        function obj=VS_2RectOnCrossHair(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF