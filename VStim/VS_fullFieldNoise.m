classdef VS_fullFieldNoise < VStim
    properties
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        
        %visualFieldBackgroundLuminance = 128;
        %visualFieldDiameter = 1024; %pixels
        %stimDuration = 1; %superclass VStim
        %interTrialDelay = 20; %superclass VStim
        %trialsPerCategory = 10;
        %preSessionDelay = 10;
        meanLuminosity = 128;
        stdLuminosity = round(128/3);
        relaxationTime = 0.5;
        randRelaxationTime = true;
        %frozenNoise = true; %not implemented frozen noise is true
    end
    properties (Hidden,Constant)
        timeStepPerFrame=4; %the number of time steps per ifi unit
        defaultStimDuration=2*60; %stim duration in [sec]
        meanLuminosityTxt='The mean luminosity value (also the initial conditions)';
        stdLuminosityTxt='The standard deviation of luminosity';
        relaxationTimeTxt='The relaxation coefficient [1/s]';
        diffusionConstantTxt='The diffusion constant in ornstein-uhlenbeck process';
        randRelaxationTimeTxt='Randomize relax time over sessions, noise profile stays constant';
        remarks={'Properties with possible multiple values: relaxationTime'};
    end
    properties (Hidden)
        OUtimeSeries
        relaxationOrder
        flip
        stim
        flipEnd
        miss
    end
    methods
        function obj=run(obj)
            %calculate time vector for flashes
            nRelaxationTimes=numel(obj.relaxationTime);
            obj.nTotTrials=obj.trialsPerCategory*nRelaxationTimes;
            
            %Time
            dT=obj.ifi/obj.timeStepPerFrame;
            T=0:dT:obj.stimDuration;
            nT=numel(T);
            r=randn(1,numel(T));
            
            %compute OU process
            obj.OUtimeSeries=nan(nRelaxationTimes,numel(T));
            obj.OUtimeSeries(:,1) = 0;
            for i=2:nT
                obj.OUtimeSeries(:,i) = obj.OUtimeSeries(:,i-1).*exp(-dT./obj.randRelaxationTime) + ...
                    sqrt((obj.stdLuminosity.^2.*obj.randRelaxationTime.*0.5).*(1-(exp(-dT./obj.randRelaxationTime)).^2)).*r(i);
                obj.OUtimeSeries(obj.OUtimeSeries(:,i)>128,i)=128;
                obj.OUtimeSeries(obj.OUtimeSeries(:,i)<-128,i)=-128;
            end
            obj.OUtimeSeries=round(obj.OUtimeSeries+obj.meanLuminosity);
            
            obj.relaxationOrder=nan(1,obj.nTotTrials);
            
            for i=1:nRelaxationTimes
                obj.relaxationOrder( ((i-1)*obj.trialsPerCategory+1):(i*obj.trialsPerCategory) )=i;
            end
            if obj.randRelaxationTime
                obj.relaxationOrder=obj.relaxationOrder(randperm(obj.nTotTrials));
            end
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            
            %main loop - start the session
            pp(uint8(obj.trigChNames(1)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            
            for i=1:obj.nTotTrials
                % Update image buffer for the first time
                Screen('FillOval',obj.PTB_win,obj.OUtimeSeries(obj.relaxationOrder(i),1),obj.visualFieldRect);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')

                obj.flip=nan(1,ceil(nT/obj.timeStepPerFrame));
                obj.stim=nan(1,ceil(nT/obj.timeStepPerFrame));
                obj.flipEnd=nan(1,ceil(nT/obj.timeStepPerFrame));
                obj.miss=nan(1,ceil(nT/obj.timeStepPerFrame));
                
                T0=GetSecs;
                nextTime=T0+0.5*obj.ifi;
                pp(uint8(obj.trigChNames(2)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                while (nextTime-T0+obj.ifi)<obj.stimDuration
                    % Update display
                    nextPlace=round((nextTime-T0)/dT);
                    nextFrame=round(nextPlace/obj.timeStepPerFrame);
                    
                    Screen('FillOval',obj.PTB_win,obj.OUtimeSeries(obj.relaxationOrder(i),nextPlace),obj.visualFieldRect);
                    Screen('DrawTexture',obj.PTB_win,obj.masktex);
                    Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                    
                    %%%% Flip output should be corrected below!!! currently does not look into different trials so output can be removed
                    pp(uint8(obj.trigChNames(3)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    [obj.flip(nextFrame),obj.stim(nextFrame),obj.flipEnd(nextFrame),obj.miss(nextFrame)]=Screen('Flip',obj.PTB_win,nextTime);
                    pp(uint8(obj.trigChNames(3)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    
                    % Update image buffer for the first time
                    nextTime=obj.flip(nextFrame)+0.5*obj.ifi;
                end
                
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance,obj.visualFieldRect);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                Screen('Flip',obj.PTB_win,nextTime);
                pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                WaitSecs(obj.interTrialDelay-(GetSecs-obj.flip(nextFrame)));
            end
            
            %check if stimulation session was stopped by the user
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyCode(obj.escapeKeyCode)
                obj.lastExcecutedTrial=i;
                return;
            end
            
            WaitSecs(obj.postSessionDelay);
            disp('Session ended');
            pp(uint8(obj.trigChNames(1)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            
            intervals=-1e-1:2e-4:1e-1;
            intCenter=(intervals(1:end-1)+intervals(2:end))/2;
            
            stimOnsetShifts=diff(obj.flip(~isnan(obj.flip)));
            n1=histc(stimOnsetShifts,intervals);
            
            flipDurationShifts=obj.flipEnd-obj.flip;
            n2=histc(flipDurationShifts,intervals);
            
            flipToStim=(obj.stim-obj.flip);
            n3=histc(flipToStim,intervals);
            
            n4=histc([obj.miss obj.miss],intervals);
            
            figure(hFigure);
            subplot(2,2,1);
            bar(1e3*intCenter,n1(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([find(n1>0,1,'first')-3 find(n1>0,1,'last')+4]));
            ylabel('\Delta(Flip)');
            xlabel('Time [ms]');
            line([obj.ifi obj.ifi],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,2);
            bar(1e3*intCenter,n2(1:end-1),'Edgecolor','none');
            xlim([-0.5 1e3*intervals(find(n2>0,1,'last')+4)]);
            ylabel('Flip duration');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,3);
            bar(1e3*intCenter,n3(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([find(n3>0,1,'first')-3 find(n3>0,1,'last')+4]));
            ylabel('Flip 2 Stim');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
            
            subplot(2,2,4);
            bar(1e3*intCenter,n4(1:end-1),'Edgecolor','none');
            xlim(1e3*intervals([find(n4>0,1,'first')-3 find(n4>0,1,'last')+4]));
            ylabel('Miss stats');
            xlabel('Time [ms]');
            line([0 0],ylim,'color','k','LineStyle','--');
        end
        %class constractor
        function obj=VS_fullFieldNoise(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.stimDuration=obj.defaultStimDuration;
        end
    end
end %EOF