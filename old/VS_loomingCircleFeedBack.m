classdef VS_loomingCircleFeedBack < VStim
    properties (SetAccess=public)
        
        CSDuration = 1;
        preCSCameraTrigger = 300;
        
        circleColor = [255 0 0];
        randomizeCircleColor = true;
        
        initialXYPosition = [0 0];
        randomizeInitialPositions = true;
        
        circleVelocity = 30;
        randomizeVelocity = true;
        
        circleTrueSize = 30;
        circleInitialDistance = 300;
        time2Collision = 5;
        
        postLoomTime = 2;
        
        realTimeFeedback = false;
        
        eye2ScreenDistance = 10;
        
        minimalRealDistance = 5;
        
        displayWidthHeight = [4 3]; %the width and height of the screen in cm [width height]
        
        puffDuration = 1000;
        
        folderSceenCaptureMode = cd;
        
        CaptureScreenMode=false;
        
    end
    
    properties (Constant)
        CSDurationTxt = 'The duration of CS [s]';
        
        circleVelocityTxt = 'The real approaching velocity of the object [cm/s]';
        circleTrueSizeTxt = 'The real size of the approaching object [cm]';
        circleInitialDistanceTxt = 'The initial distance of the object [cm]';
        
        eye2ScreenDistanceTxt = 'The distance between the fish eye and the screen [cm]';
        
        circleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        randomizeCircleColorTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        
        initialXYPositionTxt='The initial position of the looming circle center on the screen [cm, 2 x M, M being number of positions] ';

        randomizeVelocityTxt='Randomize size to speed ratio';
        
        minimalRealDistanceTxt='the minimal real distance between the approaching object and eye at the end of the stimulation';
        
        CMMarkROITxt='load movie file or sequence of images to be presented as a movie';
        CMloadCSImageTxt='load an image to be used as conditional stimulus';
        CMChooseDataFolderTxt='Choose folder for saving sync files';
        
        realTimeFeedbackTxt='[0/1] - use camera interface for realtime feedback';
        
        dataFolderTxt = 'Folder for saving the files';
        
        preCSCameraTriggerTxt = 'Camera start trigger before CS [ms]';
        remarks={'Categories in stimuli are: , '};
    end
    
    properties (SetAccess=protected)
        circleColorSequence
        velocitySequence
        initialPositionSequence
        
        hROITail
        ROICenterTailMask
        
        ROIMean
        ROIStd
        ROIThresh
        ROIPosition
        
        CSImageTex
        currentTrial
        daqSession
        listen2DAQ
        dataFolder = [];
        
        NIDAQ_samplingRate = 5000;
    end
    
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
        
        cam
        camProps
        imageSize
    end
    methods
        function obj=run(obj)
            safetyPostTrialPeriod=5; %time after the estimated trial end that the national instruments card continues to get data
            
            if isempty(obj.cam) || isempty(obj.ROICenterTailMask)
                disp('No ROI was selected or no camera connected');
            else
                disp('Initialzing Visual stimulation');
            end
            
            if isempty(obj.CSImageTex)
                error('No conditional stimulation image selected');
            end
            
            if isempty(obj.dataFolder)
                obj.dataFolder=cd;
            end
            %calculate the angles of directions
            nCircleColor=size(obj.circleColor,1);
            nVelocities=numel(obj.circleVelocity);
            nInitialPositions=size(obj.initialXYPosition,1);

            obj.nTotTrials=obj.trialsPerCategory*nCircleColor*nVelocities*nInitialPositions;
            
            %calculate sequece of positions and times
            obj.circleColorSequence=nan(3,obj.nTotTrials);
            obj.velocitySequence=nan(1,obj.nTotTrials);
            obj.initialPositionSequence=nan(2,obj.nTotTrials);
            c=1;
            for i=1:nCircleColor
                for j=1:nVelocities
                    for k=1:nInitialPositions
                        obj.circleColorSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.circleColor(i,:))';
                        obj.velocitySequence( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.circleVelocity(j);
                        obj.initialPositionSequence(: , ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory))=(ones(obj.trialsPerCategory,1)*obj.initialXYPosition(k,:))';
                        c=c+1;
                    end
                end
            end
            
            %randomize
            if obj.randomizeCircleColor
                randomPermutation=randperm(obj.nTotTrials);
                obj.circleColorSequence=obj.circleColorSequence(:,randomPermutation);
            end
            if obj.randomizeVelocity
                randomPermutation=randperm(obj.nTotTrials);
                obj.velocitySequence=obj.velocitySequence(randomPermutation);
            end
            if obj.randomizeInitialPositions
                randomPermutation=randperm(obj.nTotTrials);
                obj.initialPositionSequence=obj.initialPositionSequence(:,randomPermutation);
            end
            
            %get screen properties
            
            %determine initial position 
            x0=obj.centerX+obj.initialPositionSequence(1,:).*(obj.rect(3)/obj.displayWidthHeight(1));
            y0=obj.centerY+obj.initialPositionSequence(2,:).*(obj.rect(4)/obj.displayWidthHeight(2));
            
            maxFrames=ceil(obj.time2Collision/obj.ifi);
            movementDuration=maxFrames*obj.ifi;
            t=(obj.ifi:obj.ifi:movementDuration);
            nFrames=numel(t);
                        
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win,obj.masktexOff);
            Screen('Flip',obj.PTB_win);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
                        
            obj.flip=nan(obj.nTotTrials,maxFrames);
            obj.stim=nan(obj.nTotTrials,maxFrames);
            obj.flipEnd=nan(obj.nTotTrials,maxFrames);
            obj.miss=nan(obj.nTotTrials,maxFrames);
            
            VSMetaData=obj.getProperties;
            save tmpVSFile VSMetaData; %temporarily save object in case of a crash
            disp('Session starting');

            disp('initializing NIDAQ session');
            daqreset; %delete all data acquisition objects
            %devices = daq.getDevices;
            obj.daqSession = daq.createSession('ni');
            ch=obj.daqSession.addAnalogInputChannel('Dev2', {'ai0','ai1','ai2','ai3'}, 'Voltage');
            %chOut=obj.daqSession.addAnalogOutputChannel('Dev2',{'ao0'},'Voltage');
            ch(1).TerminalConfig='Differential';%'Differential', 'SingleEnded', 'SingleEndedNonReferenced','PseudoDifferential'
            ch(2).TerminalConfig='Differential';%
            ch(3).TerminalConfig='Differential';
            ch(4).TerminalConfig='Differential';
            ch(1).Range=[-5 5];
            ch(2).Range=[-5 5];
            ch(3).Range=[-5 5];
            ch(4).Range=[-5 5];
            
            obj.daqSession.DurationInSeconds=obj.CSDuration+obj.preCSCameraTrigger/1000+obj.time2Collision+obj.postLoomTime+obj.puffDuration/1000+safetyPostTrialPeriod; %sec
            obj.daqSession.IsContinuous=false;
            obj.daqSession.Rate=obj.NIDAQ_samplingRate; %Hz
            obj.daqSession.IsNotifyWhenDataAvailableExceedsAuto=true;
            obj.daqSession.NotifyWhenDataAvailableExceeds = obj.daqSession.Rate*obj.daqSession.DurationInSeconds;
            obj.listen2DAQ=obj.daqSession.addlistener('DataAvailable',@obj.getTimeStamps);
            prepare(obj.daqSession);
            disp('NIDAQ session initialized');
            
            %obj.daqSession.IsNotifyWhenScansQueuedBelowAuto=false;

            %configure output triggers
            %outPutCameraPulses=zeros(5,10000);
            %outPutCameraPulses(:,1:10:end)=1;
            %outPutCameraPulses=outPutCameraPulses(:)';
            
            %main loop - start the session
            obj.sendTTL([1 2 3 4],[true false false false]); %session start trigger (also triggers the recording start)
            
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                
                if obj.CaptureScreenMode
                    videoFWriter = vision.VideoFileWriter([obj.folderSceenCaptureMode filesep 'loomingStim_Trial' num2str(i) '.avi'],'FrameRate',60);
                    imageArray=Screen('GetImage', obj.PTB_win);
                    step(videoFWriter, imageArray);
                end
                
                obj.currentTrial=i;
                tmpCircleColor=obj.circleColorSequence(:,i);
                tmpVelocity=obj.velocitySequence(i);
                
                r=obj.eye2ScreenDistance*obj.circleTrueSize/tmpVelocity./t(end:-1:1);
                
                ovalCoordinates=round([max(obj.rect(1),x0(i)-r);max(obj.rect(2),y0(i)-r);min(x0(i)+r,obj.rect(3));min(obj.rect(4),y0(i)+r)]);
                
                if obj.realTimeFeedback
                    img=zeros(obj.imageSize(1),obj.imageSize(2),nFrames);
                    start(obj.cam);
                else
                    obj.daqSession.startBackground; %initiate background acquisition
                    WaitSecs(0.1);
                    obj.sendTTL(2,true);
                    %outputSingleScan(obj.daqSession,[outPutCameraPulses;outPutCameraPulses]);
                    WaitSecs(obj.preCSCameraTrigger/1000);
                end
                
                % Update image buffer for the first time
                Screen('DrawTexture',obj.PTB_win,obj.CSImageTex,[],obj.visualFieldRect);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                frameTTL=false;
                Screen('Flip',obj.PTB_win);
                obj.sendTTL(3,true);
                tStartSession=GetSecs;
                
                if ~obj.CaptureScreenMode % regular mode
                    
                    ttmp=t-obj.ifi+tStartSession+obj.CSDuration;
                    frameTTL=false;
                    for j=1:nFrames
                        % Update display
                        Screen('FillOval',obj.PTB_win,tmpCircleColor,ovalCoordinates(:,j));
                        obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                        
                        [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,ttmp(j));
                        obj.sendTTL(3,frameTTL);
                        frameTTL=~frameTTL;
                        
                        %real time feedback, currently not active
                        %{
                    if obj.realTimeFeedback
                        img(:,:,j) = getsnapshot(obj.cam);
                        if mean(img(obj.ROICenterTailMask))<obj.ROIThresh;
                            break
                        end
                        %obj.cam.flushdata;
                    end
                        %}
                    end
                    
                else %to save the output of every screen in simulation mode
                    imageArray=Screen('GetImage', obj.PTB_win);
                    step(videoFWriter, imageArray);
                    
                    ttmp=t*2+tStartSession+obj.ifi+obj.CSDuration; %to allow enough time to save images
                    for j=1:nFrames
                        % Update display
                        Screen('FillOval',obj.PTB_win,tmpCircleColor,ovalCoordinates(:,j));
                        obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                        
                        [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,ttmp(j));
                        
                        imageArray=Screen('GetImage', obj.PTB_win);
                        
                        step(videoFWriter, imageArray);
                        
                    end
                    release(videoFWriter);
                end
                
                obj.sendTTL(4,true);
                WaitSecs(obj.puffDuration/1000);
                obj.sendTTL(4,false);
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                endStimTime=GetSecs;
                
                %{
                if obj.realTimeFeedback
                    stop(obj.cam);
                    save(['Trial' num2str(i) 'Images'],'img');
                    %figure;for i=1:100,subaxis(10,10,i,'S',0.001,'M',0.001);imagesc(squeeze(img(:,:,i)));set(gca,'XTickLabel',[],'YTickLabel');end
                else
                    wait(obj.daqSession)
                end
                %}
                
                WaitSecs(obj.postLoomTime-(GetSecs-endStimTime));
                Screen('Flip',obj.PTB_win);
                obj.sendTTL([2 3],[false frameTTL]);
                endTrialTime=GetSecs;
                
                wait(obj.daqSession)
                
                %Screen('DrawTexture',obj.PTB_win,obj.masktex);
                %[endSessionTime]=Screen('Flip',obj.PTB_win);
                % Start wait: Code here is run during the waiting for the new session
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end

                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                WaitSecs(obj.interTrialDelay-(GetSecs-endTrialTime));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false);
            disp('Session ended');
            
            delete(obj.daqSession);obj.daqSession=[]; %data acquisition object can not be saved to a file and should be deleted from VS object before exit
        end

        function getTimeStamps(obj,src,event)
            data=event.Data;
            timeStamps=event.TimeStamps;
            save([obj.dataFolder obj.fSep 'Trial' num2str(obj.currentTrial)],'data','timeStamps');
            
            tFrames_timeLaps_ms=1000*timeStamps(find( data(1:end-1,3)<2 & data(2:end,3)>=2 ));
            disp([num2str(numel(tFrames_timeLaps_ms)) ' frames collected']);
            %figure;h(1)=subplot(3,1,1);plot(timeStamps,data(:,1));h(2)=subplot(3,1,2);plot(timeStamps,data(:,2));linkaxes(h,'x');h(3)=subplot(3,1,3);plot(timeStamps,data(:,3));linkaxes(h,'x');
            %obj.upTimeStampsCamera=event.TimeStamps(find(event.Data(1:end)<Th & event.Data(2:end-1)>Th));
            %obj.downTimeStampsCamera=event.TimeStamps(find(event.Data(1:end)>Th & event.Data(2:end-1)<Th));
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
        
        function obj=CMloadCSImage(obj,srcHandle,eventData,hPanel)
            [FileName,PathName] = uigetfile({'*.jpg';'*.jpeg';'*.tif';'*.tiff'},'Please select conditional stimulus image');
            CSimage=imread([PathName obj.fSep FileName]);
            [M,N,l]=size(CSimage);
            if N>=M
                cutPixels=round((N-M)/2);
                obj.CSImageTex=Screen('MakeTexture', obj.PTB_win,CSimage(:,(cutPixels+1):(end-cutPixels),:));
            else
                cutPixels=round((M-N)/2);
                obj.CSImageTex=Screen('MakeTexture', obj.PTB_win,CSimage((cutPixels+1):(end-cutPixels),:,:));
            end
            disp('image texture created');
        end
        
        function obj=CMChooseDataFolder(obj,srcHandle,eventData,hPanel)
            obj.dataFolder = uigetdir(cd,'Please choose directory for saving sync files');
        end
        
        function obj=initializeCamera(obj)
            disp('Initialzing Photon focus camera');
            %initiating camera object
            
            %for gigecam interface - did not yet achieve triggered acquisition speed
            %{
            if isempty(obj.cam)
                obj.cam = gigecam('022200017231','Timeout',10,'ExposureTime',2000); %when initiating properties that are later read-only can be defined
            end
            %setting double rate to true requires image demodulation which can be performed with the pfDoubleRate library but I can not load it
            obj.cam.DoubleRate_Enable='False';
            
            obj.cam.ExposureTime = 2000; %us
            
            obj.cam.Window_W=640; %min 544
            obj.cam.Width=640; %min 544
            obj.cam.Height=320;
            
            %get camera properties
            Fs=obj.cam.AcquisitionFrameRateMax; %need to set acquisition mode to max rate
            
            %obj.cam.AcquisitionFrameRateEnable='True';
            %obj.cam.AcquisitionFrameRate=obj.cam.AcquisitionFrameRateMax;
            obj.cam.Trigger_Interleave='True';
            
            disp(['Camera ready! Effective camera frame rate is: ' num2str(Fs) ' Hz']);
            
            hCamIn=axes('Parent',obj.hInteractiveGUI);
            
            %T=zeros(1,300);for i=1:300,img = snapshot(obj.cam);T(i)=GetSecs;end;
            
            img = snapshot(obj.cam);
            imshow(img','Parent',hCamIn);
            
            delete(obj.hROITail)
            %}
            
            imaqreset; %delete all image acquisition objects
            
            %for generic camera interface
            obj.cam = videoinput('gige', 1, 'Mono8');
            
            %get camera control object
            obj.camProps = getselectedsource(obj.cam);
            
            %set camera properties
            obj.camProps.Window_W=544;
            obj.camProps.ExposureTime=2000;
            obj.camProps.DoubleRate_Enable='False';
            obj.camProps.AcquisitionFrameRateEnable='True';
            obj.camProps.AcquisitionFrameRate=obj.camProps.AcquisitionFrameRateMax;
            obj.camProps.Trigger_Interleave='True';
            
            triggerconfig(obj.cam, 'manual');
            
            %get camera properties
            Fs=obj.camProps.AcquisitionFrameRate;

            %obj.cam.VideoResolution=[272 100];
            %obj.cam.ROIPosition=[352     0   284   100];

            disp(['Camera ready! Effective camera frame rate is: ' num2str(Fs) ' Hz']);
        end
        
        function obj=CMMarkROI(obj,srcHandle,eventData,hPanel)
            
            obj=obj.initializeCamera;
            
            hCamIn=axes('Parent',obj.hInteractiveGUI);
            
            %T=zeros(1,300);for i=1:300,img = snapshot(obj.cam);T(i)=GetSecs;end;
            
            %obj.cam.flushdata;
            
            %take a single image
            start(obj.cam);
            img = getsnapshot(obj.cam);
            stop(obj.cam);
            
            imshow(img','Parent',hCamIn);
            
            obj.imageSize=size(img);
            
            %creates ROI
            delete(obj.hROITail);
            obj.hROITail = imrect(hCamIn);
            fcn = makeConstrainToRectFcn('imrect',get(hCamIn,'XLim'),get(hCamIn,'YLim'));
            setPositionConstraintFcn(obj.hROITail,fcn);
            position = wait(obj.hROITail);
            obj.ROICenterTailMask=obj.hROITail.createMask;
            
            obj.ROIMean=mean(img(obj.ROICenterTailMask));
            obj.ROIStd=std(double(img(obj.ROICenterTailMask)));
            obj.ROIThresh=obj.ROIMean-obj.ROIStd;
            
            %obj.hROITail.setColor('r');
            delete(obj.hROITail);
            obj.hROITail=[];
            
            obj.hROITail=rectangle('Position',round(position),'Parent',hCamIn);
        end
        
        function delete(obj)
            delete(obj.cam);
            delete(obj.daqSession);
            delete(obj.listen2DAQ);
            daqreset; %delete all data acquisition objects
            imaqreset; %delete all image acquisition objects
        end
        
        %class constractor
        function obj=VS_loomingCircleFeedBack(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w,h); %calling superclass constructor
            obj.stimDuration=NaN;
            daqreset; %delete all data acquisition objects
            imaqreset; %delete all image acquisition objects
        end
    end
end %EOF