classdef VS_manualDynamicCircles < VStim
    properties (SetAccess=public)
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        
        %visualFieldBackgroundLuminance = 128;
        %visualFieldDiameter = 1024; %pixels
        %stimDuration = 1; %superclass VStim
        %interTrialDelay = 20; %superclass VStim
        %trialsPerCategory = 10;
        %preSessionDelay = 10;
        oscillationFrequency=12; %Hz
        osciallationPhase=0; %deg
        maxIntensity = 100;
        cycles=10;
        repeatSequence=1;
        randomizeOrder = true;
        
        circleDiameter = 100;
        circlePositionsX = 600;
        circlePositionsY = 400;

        rotation = 0;
        nPlanesPerFrame = 1;
    end
    properties (Hidden,Constant)
        CMgetCirclePositionTxt='get the positions of the circle in real space (left click to choose, right click to end)';
        CMloadLuminanceDynamicsTxt='load file with dynamic luminance profile (dynamics[1xN] - mat file)';
        CMMakeTexturesTxt='precalculate textures for stimulation';
        CMClearLuminanceDynamicsTxt = 'To clear any previously loaded dynamics (if empty, parameter based dynamics will be used';
        
        rotationTxt='The rotation angle of the images (for alignment to visual streak';
        imagesDirTxt='The directory containing the images to show';
        randomizeOrderTxt = 'To randomize order of image appearance';
        nPlanesPerFrameTxt = 'for Light crafter applications this parameter defines the reduction in bit depth and increase in termporal resolution';
        cyclesTxt = 'The number of cycles to be converted to textures';
        oscillationFrequencyTxt = 'The oscillation frequency of each circle';
        osciallationPhaseTxt = 'The phase [deg] of each circle';
        repeatSequenceTxt = 'The number of times to repeat the sequence within one trial';
        maxIntensityTxt = 'The max intensity of each of the oscillating circles';
        remarks={'Categories in Flash stimuli are:',''};
    end
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
        
        luminocityDynamics
        order=[];
        hScatter=[];
        hAxes=[];
        hMainHBox=[];
        stimulationTextures
        nFrames
    end
    methods
        %new
        function obj=run(obj)
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.applyBackgound;
            
            obj.nTotTrials=obj.trialsPerCategory;
            
            %Pre allocate memory for variables
            tFrame=(0:obj.ifi:((obj.nFrames-1)*obj.ifi))';
            maxFrames=numel(tFrame);
            %obj.flip=nan(obj.nTotTrials,maxFrames);
            %obj.stim=nan(obj.nTotTrials,maxFrames);
            %obj.flipEnd=nan(obj.nTotTrials,maxFrames);
            %obj.miss=nan(obj.nTotTrials,maxFrames);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            save([obj.mainDir(1:end-5) 'stats' filesep 'tmpVSFile']); %temporarily save object in case of a crash
            disp('Session starting');
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            Screen('Flip',obj.PTB_win);
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                
                for k=1:obj.repeatSequence
                    tFrameTmp=tFrame+GetSecs+obj.ifi/2;
                    for j=1:obj.nFrames
                        % Update display
                        Screen('DrawTexture',obj.PTB_win,obj.stimulationTextures(j));
                        obj.applyBackgound;
                        
                        obj.sendTTL(3,true); %session start trigger (also triggers the recording start)
                        Screen('Flip',obj.PTB_win,tFrameTmp(j));
                        obj.sendTTL(3,false); %session start trigger (also triggers the recording start)
                    end
                end
                
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance,obj.visualFieldRect);    
                obj.applyBackgound;
                Screen('Flip',obj.PTB_win);
                
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
                
                WaitSecs(obj.interTrialDelay);
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session start trigger (also triggers the recording start)

            disp('Session ended');
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            if nargin==2
                if obj.interTrialDelay~=0
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
                else %for the case that images are just switch so there is no interval between consecutive images
                    intervals=-1e-1:2e-4:1e-1;
                    intCenter=(intervals(1:end-1)+intervals(2:end))/2;
                    stimDurationShifts=(obj.on_Flip(2:end)-obj.on_Flip(1:end-1))-obj.actualStimDuration;
                    n1=histc(stimDurationShifts,intervals);
                    
                    flipDurationShiftsOn=obj.on_FlipEnd-obj.on_Flip;
                    flipDurationShiftsOff=flipDurationShiftsOn;
                    n2=histc([flipDurationShiftsOn' flipDurationShiftsOff'],intervals,1);
                    
                    flipToStimOn=(obj.on_Stim-obj.on_Flip);
                    flipToStimOff=flipToStimOn;
                    n3=histc([flipToStimOn' flipToStimOff'],intervals,1);
                    
                    n4=histc([obj.on_Miss' obj.on_Miss'],intervals,1);
                end
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
                xlabenl('Time [ms]');
                leged('On','Off');
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

        %control methods
        function obj=CMgetCirclePosition(obj,srcHandle,eventData,hPanel)
            obj.hMainHBox=uix.VBox('Parent',hPanel, 'Padding', 10, 'Spacing', 10);
            hVBox=uix.HBox('Parent',obj.hMainHBox, 'Padding', 10, 'Spacing', 10);
            
            hClearAllPush=uicontrol('Parent', hVBox, 'Style','push','String','Clear all','HorizontalAlignment','Left','Callback',@obj.clearAllPushCallback);
            hFinishPush=uicontrol('Parent', hVBox, 'Style','push','String','Finish','HorizontalAlignment','Left','Callback',@obj.finishPushCallback);
            hAddPositions=uicontrol('Parent', hVBox, 'Style','push','String','Add positions','HorizontalAlignment','Left','Callback',@obj.addPositionsCallback);
            
            obj.hAxes=axes('Parent',obj.hMainHBox);
            set(obj.hMainHBox,'Heights',[-1 -5]);
            axis(obj.hAxes,'equal');
            
            xlim(obj.hAxes,[obj.rect(1) obj.rect(3)]);
            ylim(obj.hAxes,[obj.rect(2) obj.rect(4)]);
            set(obj.hAxes,'color','k');
            hold(obj.hAxes,'on');
            
            obj.hScatter=TransparentCircle(obj.circlePositionsX,obj.circlePositionsY,obj.circleDiameter/2,[1 1 1],1,32,obj.hAxes);
        end
        
        function obj=CMMakeTextures(obj,srcHandle,eventData,hPanel)
            if ~isempty(obj.stimulationTextures)
                Screen('Close',obj.stimulationTextures);
                obj.stimulationTextures=[];
            end
            
            nCircles=numel(obj.circlePositionsY);
            if numel(obj.circleDiameter)==1 & nCircles>1
                obj.circleDiameter=obj.circleDiameter*ones(1,nCircles);
                disp('Taking the same diameter of all circles');
            end
            
            automaticDynamics=false;
            if isempty(obj.luminocityDynamics) %use dynamics of two circles accroding to parameters
                automaticDynamics=true;
                minF=min(obj.oscillationFrequency);
                if numel(obj.oscillationFrequency)~=nCircles || numel(obj.osciallationPhase)~=nCircles || numel(obj.maxIntensity)~=nCircles
                    error('The number of circles needs to be equal to the number of frequency parameters');
                end
                
                t=obj.ifi:obj.ifi:(obj.cycles*1/minF);
                for i=1:nCircles
                    obj.luminocityDynamics(i,:)=(sin(2*pi*obj.oscillationFrequency(i)*t+obj.osciallationPhase(i)/180*pi)+1)/2*obj.maxIntensity(i);
                end
                
            end
            
            if size(obj.luminocityDynamics,1)==1 & nCircles>1
                obj.luminocityDynamics=ones(nCircles,1)*obj.luminocityDynamics;
                disp('Taking the same dynamics of all circles');
            end
            
            % Create texture masks
            I=cell(1,nCircles);
            [xMesh,yMesh]=meshgrid(1:obj.rect(3),1:obj.rect(4));
            for i=1:nCircles
                Itmp=zeros(obj.rect(4),obj.rect(3));
                p=find(((xMesh-obj.circlePositionsX(i)).^2+(yMesh-obj.circlePositionsY(i)).^2) <= round((obj.circleDiameter(i)/2)).^2);
                Itmp(p)=true;
                I{i}=Itmp;
            end
            
            nTimeStamps=size(obj.luminocityDynamics,2);
            obj.nFrames=ceil(nTimeStamps/obj.nPlanesPerFrame);
            obj.stimDuration=obj.nFrames*obj.ifi;
            fprintf('preparing texture (/%d):...',obj.nFrames);
            for i=1:obj.nFrames
                fprintf('%d,',i);
                Itmp=zeros(obj.rect(4),obj.rect(3),obj.nPlanesPerFrame);
                if obj.nPlanesPerFrame==1
                    for j=1:nCircles
                        Itmp=Itmp+bsxfun(@times,I{j},obj.luminocityDynamics(j,i));
                    end
                    obj.stimulationTextures(i)=Screen('MakeTexture', obj.PTB_win, Itmp, obj.rotation);
                else
                    for j=1:nCircles
                        tmpDynamics(1,1,1:obj.nPlanesPerFrame)=obj.luminocityDynamics(j,((i-1)*obj.nPlanesPerFrame+1):min(obj.nPlanesPerFrame*i,nTimeStamps));
                        Itmp=Itmp+bsxfun(@times,I{j},tmpDynamics);
                    end
                    Itmp(Itmp>1)=1;
                    [rgbFrame]=LC_bin2rgb(Itmp);
                    %subplot(1,3,1);imagesc(squeeze(rgbFrame(:,:,1)),[0 255]);subplot(1,3,2);imagesc(squeeze(rgbFrame(:,:,2)),[0 255]);subplot(1,3,3);imagesc(squeeze(rgbFrame(:,:,3)),[0 255]);
                    obj.stimulationTextures(i)=Screen('MakeTexture', obj.PTB_win, rgbFrame, obj.rotation);
                    %plot(squeeze(tmpDynamics));pause;
                end
            end
            if automaticDynamics %so that dynamics is recalculated if parameters are changed again.
                obj.luminocityDynamics=[]; 
            end
                
            fprintf('Done!\n');
        end
        
        function obj=addPositionsCallback(obj,srcHandle,eventData)
            title(obj.hAxes,'Position centers (enter to finish, backspace to remove)','FontSize',8);
            [obj.circlePositionsX,obj.circlePositionsY] = getpts(obj.hAxes);
            if ishandle(obj.hScatter)
                delete(obj.hScatter);
            end
            obj.hScatter=TransparentCircle(obj.circlePositionsX',obj.circlePositionsY',obj.circleDiameter/2,[1 1 1],1,32,obj.hAxes);
        end
        
        function obj=clearAllPushCallback(obj,srcHandle,eventData)
            obj.circlePositionsX=[];
            obj.circlePositionsY=[];
            if ishandle(obj.hScatter)
                delete(obj.hScatter);
            end
        end
        
        function obj=finishPushCallback(obj,srcHandle,eventData)
            delete(obj.hMainHBox);
        end
        
        function obj=CMloadLuminanceDynamics(obj,srcHandle,eventData,hPanel)
            [FileName,PathName]=uigetfile('*.mat');
            loadedData=load([PathName FileName]);
            fieldNames=fields(loadedData);
            obj.luminocityDynamics=loadedData.(fieldNames{1});
            obj.stimDuration=ceil(size(obj.luminocityDynamics,2)/obj.nPlanesPerFrame)*obj.ifi;
        end
        
        function obj=CMClearLuminanceDynamics(obj,srcHandle,eventData,hPanel)
            obj.luminocityDynamics=[];
        end
        
        function delete(obj)
            if ~isempty(obj.stimulationTextures)
                Screen('Close',obj.stimulationTextures);
                obj.stimulationTextures=[];
            end
            delete@VStim(obj);
        end
        
        %class constractor
        function obj=VS_manualDynamicCircles(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.visualFieldBackgroundLuminance=0;
            obj.stimDuration=NaN;
        end
        
    end
end %EOF