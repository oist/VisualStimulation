classdef VS_fullFieldFlash < VStim
    properties (SetAccess=public)
        flashLuminosity = 255; %(L_high-L_low)/L_low
        randomize = true;
    end
    properties (Constant)
        flashLuminosityTxt='The luminocity value for the flash, if array->show all given contrasts';
        randomizeTxt='Randomize stimuli';
        remarks={'Categories in Flash stimuli are:','luminosity, interTrialDelay'};
    end
    properties (SetAccess=protected)
        delays
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
            %calculate time vector for flashes
            nDelays=numel(obj.interTrialDelay);
            nLuminosities=numel(obj.flashLuminosity);
            obj.nTotTrials=obj.trialsPerCategory*nLuminosities*nDelays;
            
            obj.delays=nan(1,obj.nTotTrials);
            obj.luminosities=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nDelays
                for j=1:nLuminosities
                    obj.delays( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.interTrialDelay(i);
                    obj.luminosities( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.flashLuminosity(j);
                    c=c+1;
                end
            end

            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.luminosities=obj.luminosities(randomPermutation);
                obj.delays=obj.delays(randomPermutation);
            end
            obj.luminosities=[obj.luminosities obj.luminosities(1)]; %adding last luminocity value which will never be shown
            
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
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;

            % Update image buffer for the first time
            obj.syncMarkerOn = false; %reset sync marker
            

             Screen('FillRect',obj.PTB_win,obj.luminosities(1));
            obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                        
            %main loop - start the session
           % obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                
                [obj.on_Flip(i),obj.on_Stim(i),obj.on_FlipEnd(i),obj.on_Miss(i)]=Screen('Flip',obj.PTB_win);
               % obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                               
                % Update display
              
                   Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound; %set background mask and finalize drawing (drawing finished)
             
                [obj.off_Flip(i),obj.off_Stim(i),obj.off_FlipEnd(i),obj.off_Miss(i)]=Screen('Flip',obj.PTB_win,obj.on_Flip(i)+obj.actualStimDuration-0.5*obj.ifi);
              %  obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                
                % Update image buffer
           
                Screen('FillRect',obj.PTB_win,obj.luminosities(i+1));
                obj.applyBackgound; %set background mask and finalize drawing (drawing finished)
                
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.delays(i)-(GetSecs-obj.off_Flip(i)));
            end
            WaitSecs(obj.postSessionDelay);
        %    obj.sendTTL(1,false); %session start trigger (also triggers the recording start)
            
            obj.luminosities=obj.luminosities(1:end-1); %removing last dummy luminocity value from array
            disp('Session ended');
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
        function obj=VS_fullFieldFlash(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF