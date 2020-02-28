classdef VS_ellipse < VStim
    properties (SetAccess=public)
        ellipseLuminocity = 255; %(L_high-L_low)/L_low
        numberEllipses=10;
        eccentricity=0;
        randomize = true;
        tilingRatio = 1;
        rotation = 0;
    end
    properties (Constant)
        ellipseLuminocityTxt='The luminocity value for the ellipse, if array->shows all';
        numberEllipsesTxt='Number of ellipses';
        eccentricityTxt='Ellipse eccentricity (0-1), if 0 ellipse is a circle';
        randomizeTxt='Randimize ellipses';
        tilingRatioTxt='The ratio (0-1) beween the total tile length and field length (e.g. if 0.5 tiles are half the size require for complete tiling)';
        remarks={'Multivalue catergories are: eccentricity'};
    end
    properties (SetAccess=protected)
        pos
        luminosities
        eccentricities
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
            visualFieldDiameter=round(obj.actualVFieldDiameter/2);
            ellipseSpacing=floor(visualFieldDiameter/obj.numberEllipses)-1;
            ellipseWidth=ellipseSpacing*obj.tilingRatio;
            
            edges=floor((ellipseSpacing-ellipseWidth)/2):ellipseSpacing:(visualFieldDiameter-ellipseWidth);
            
            nEccentricities=numel(obj.eccentricity);
            obj.nTotTrials=obj.trialsPerCategory*obj.numberEllipses*nEccentricities;
            
            %calculate sequece of positions and times
            obj.pos=nan(1,obj.nTotTrials);
            obj.eccentricities=nan(1,obj.nTotTrials);
            
            c=1;
            for i=1:nEccentricities
                for j=1:obj.numberEllipses
                    obj.eccentricities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=i;
                    obj.pos( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=j;
                    c=c+1;
                end
            end
            
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.pos=obj.pos(randomPermutation);
                obj.eccentricities=obj.eccentricities(randomPermutation);
            end
            
            obj.pos=[obj.pos obj.pos(1)]; %add an additional stimulus that will never be shown
            obj.eccentricities=[obj.eccentricities obj.eccentricities(1)]; %add an additional stimulus that will never be shown
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            
            a=1;
            b=a.*sqrt(1-obj.eccentricity.^2);
   
            % Update image buffer for the first time
            [X,Y]=meshgrid(1:(obj.visualFieldRect(3)-obj.visualFieldRect(1)),1:(obj.visualFieldRect(4)-obj.visualFieldRect(2)));
            for i=1:obj.numberEllipses
                for j=1:nEccentricities
                    I=ones(size(X)).*obj.visualFieldBackgroundLuminance;
                    
                    p=find(  (((X-visualFieldDiameter).^2)./(a^2)+((Y-visualFieldDiameter).^2)./(b(j)^2))  <  (edges(i)+ellipseWidth).^2 ...
                        &   (((X-visualFieldDiameter).^2)./(a^2)+((Y-visualFieldDiameter).^2)./(b(j)^2))  >  (edges(i)).^2  );
                    
                    I(p)=obj.ellipseLuminocity;
                    
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
            
            Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(1),obj.eccentricities(1)),[],obj.visualFieldRect,obj.rotation);
            obj.applyBackgound;
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win);
                
                sendTTL(obj,2,true);
                               
                % Update display
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;

                [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win,obj.on_Flip(i)+obj.actualStimDuration-0.5*obj.ifi);
                sendTTL(obj,2,false);
                
                % Update image buffer for the first time
                Screen('DrawTexture',obj.PTB_win,imgTex(obj.pos(i+1),obj.eccentricities(i+1)),[],obj.visualFieldRect,obj.rotation);
                obj.applyBackgound;

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
            obj.eccentricities(end)=[];
            
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
        function obj=VS_ellipse(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF