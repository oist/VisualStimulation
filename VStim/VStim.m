classdef (Abstract) VStim < handle

    properties (SetObservable, AbortSet = true, SetAccess=public)
        visualFieldBackgroundLuminance = 64;
        trialsPerCategory = 20;
        preSessionDelay = 1;
        postSessionDelay = 0;   
        stimDuration = 1;
        interTrialDelay = [0]; %sec
        trialStartTrig = 'MC=2,Intan=6';
        screenLayout=[2,3,1]
    end
    properties (Constant)
       % backgroudLuminance = 0;
      %  maxTriggers=4;
        
        visualFieldBackgroundLuminanceTxt = 'The luminance of the circular visual field that is projected to the retina';
      %  visualFieldDiameterTxt = 'The diameter of the circular visual field that is projected to the retina [pixels], 0 takes maximal value';
        stimDurationTxt='The duration of the visual stimuls [s]';
        interTrialDelayTxt='The delay between trial end and new trial start [s], if vector->goes over all delays';
        trialsPerCategoryTxt='The number of repetitions shown per category of stimuli';
        preSessionDelayTxt='The delay before the begining of a recording session [s]';
        postSessionDelayTxt='The delay after the ending of a recording session [s]';
        backgroundMaskSteepnessTxt='The steepness of the border on the visual field main mask [0 1]';
        screenLayoutTxt='order of the screens around the chamber'
        
    end
    properties (SetAccess=protected)
        mainDir %main directory of visual stimulation toolbox
        rect %the coordinates of the screen [pixels]: (left, top, right, bottom)
        fps %monitor frames per second
        ifi %inter flip interval for monitor
        actualStimDuration % the actual stim duration as an integer number of frames
        centerX %the X coordinate of the visual field center
        centerY %the Y coordinate of the visual field center
      %  actualVFieldDiameter % the actual diameter of the visual field
        nTotTrials = []; %the total number of trials in a stimulatin session
        nPTBScreens=[];
        hInteractiveGUI %in case GUI is needed to interact with visual stimulation
        dioSession
    end
    
    properties (Hidden, SetAccess=protected)
        fSep = '\';
        escapeKeyCode = []; %the key code for ESCAPE
        dirSep=filesep; %choose file/dir separator according to platform
        
        currentBinState = [false, false]; 
        PTB_win %Pointer to PTB window
        whiteIdx %black index for screen
        blackIdx %black index for screen
        visualFieldRect % the coordinates of the rectanle of visual field [pixel]
        masktexOn %the mask texture for visual field with on rectangle on bottom left corner
        masktexOff %the mask texture for visual field with on rectangle on bottom left corner
        visualFieldBackgroundTex %the background texture (circle) for visual field
        errorMsg=[]; %The message the object returns in case of an error
        simulationMode = false; %a switch that is used to prepare visual stimulation without applying the stimulation itself
        lastExcecutedTrial = 0; %parameter that keeps the number of the last excecuted trial
        syncSquareSizePix = 700; % the size of the the corder square for syncing stims
        syncSquareLuminosity=255; % The luminocity of the square used for syncing 
            syncMarkerOn = false;   
     end
    
    properties (Hidden)
        trigChNames=[[2;3;4;5] [6;7;8;9]]; %the channel order for triggering in parallel port (first channel will be one)
    end
    
    methods
        %class constractor
        function obj=VStim(PTB_WindowPointer,interactiveGUIhandle)
            addlistener(obj,'visualFieldBackgroundLuminance','PostSet',@obj.initializeBackground); %add a listener to visualFieldBackgroundLuminance, after its changed its size is updated in the changedDataEvent method
            addlistener(obj,'stimDuration','PostSet',@obj.updateActualStimDuration); %add a listener to stimDuration, after its changed its size is updated in the changedDataEvent method
            obj.nPTBScreens=numel(PTB_WindowPointer);
            
            if nargin==2
                obj.hInteractiveGUI=interactiveGUIhandle;
            end
            obj.fSep=filesep; %get the file separater according to opperating system
            
            % Enable alpha blending with proper blend-function.
            AssertOpenGL;
            
            %define the key code for escape for KbCheck
            KbName('UnifyKeyNames');
            obj.escapeKeyCode = KbName('ESCAPE');
            if nargin==0
                error('PTB window pointer is required to construct VStim object');
            end
            obj.PTB_win=PTB_WindowPointer;
            for i=1:obj.nPTBScreens
                Screen('BlendFunction', obj.PTB_win(i), GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
            end
            %get the visual stimulation methods
            tmpDir=which('VStim'); %identify main folder
            [obj.mainDir, name, ext] = fileparts(tmpDir);
            
            %initialized TTL signalling
            NSKToolBoxMainDir=fileparts(which('identifierOfMainDir4NSKToolBox'));
            configFile=[NSKToolBoxMainDir filesep 'PCspecificFiles' filesep 'VSConfig.txt'];
            
            if exist(configFile,'file')
                fid=fopen(configFile);
                configData = textscan(fid,'%s = %s');
                fclose(fid);
                for i=1:numel(configData{1})
                    obj.(configData{1}{i})=str2num(configData{2}{i});
                end
            end
            
            obj.initializeTTL;

            obj.whiteIdx=WhiteIndex(obj.PTB_win(1));
            obj.blackIdx=BlackIndex(obj.PTB_win(1));
            if obj.visualFieldBackgroundLuminance<obj.blackIdx || obj.visualFieldBackgroundLuminance>obj.whiteIdx
                disp('Visual field luminance is not within the possible range of values, please change...');
                return;
            end
            
            %get general information
            for i=1:obj.nPTBScreens
                obj.rect(i,:)=Screen('Rect', obj.PTB_win(i));
                obj.fps(i)=Screen('FrameRate',obj.PTB_win(i));      % frames per second
                obj.ifi(i)=Screen('GetFlipInterval', obj.PTB_win(i)); %inter flip interval
            end
            %calculate optimal stim duration (as an integer number of frames)
            obj=updateActualStimDuration(obj);
            
            %set background luminance
            obj.initializeBackground;

        end
        
        function estimatedTime=estimateProtocolDuration(obj)
            %estimated time is given is seconds
            obj.simulationMode=true;
            obj=obj.run;
            estimatedTime=obj.nTotTrials*(mean(obj.actualStimDuration)+mean(obj.interTrialDelay))+obj.preSessionDelay+obj.postSessionDelay;
            obj.simulationMode=false;
        end
        
        function applyBackgound(obj) %apply background and change the synchrony marker state (on/off)
            obj.syncMarkerOn=~obj.syncMarkerOn;
            if obj.syncMarkerOn
                for i=1:obj.nPTBScreens
                    Screen('DrawTexture',obj.PTB_win(i),obj.masktexOn(i));
                end
            else
                for i=1:obj.nPTBScreens
                    Screen('DrawTexture',obj.PTB_win(i),obj.masktexOff(i));
                end
            end
            for i=1:obj.nPTBScreens
                Screen('DrawingFinished', obj.PTB_win(i)); % Tell PTB that no further drawing commands will follow before Screen('Flip')
            end
        end
        
        function distributeToScreens(obj,img,idx) %apply background and change the synchrony marker state (on/off)
            
            imgRect=[obj.rect(1,3) sum(obj.rect(:,4))];
            img=flipud(img);
            resizedImg=imresize(img,[imgRect(1) imgRect(2)]);
            imgColumns=[1; cumsum(obj.rect(:,4))];
            
            for j=1:obj.nPTBScreens
                currImg=resizedImg(:,imgColumns(j):imgColumns(j+1),:);
                currImg=imrotate(currImg,90);
                obj.imgTex(idx,j)=Screen('MakeTexture', obj.PTB_win(obj.screenLayout(j)),currImg);
            end
            
        end
        
        function initializeBackground(obj,event,metaProp)

            obj.centerX=(obj.rect(1,3)+obj.rect(1,1))/2;
            obj.centerY=(obj.rect(1,4)+obj.rect(1,2))/2;
     
                maskblobOff=ones(obj.rect(1,4)-obj.rect(1,2),obj.rect(1,3)-obj.rect(1,1),2) * obj.blackIdx;
                maskblobOff(:,:,1)=obj.blackIdx;

            
            maskblobOn=maskblobOff; %make on mask addition
            maskblobOn(1:obj.syncSquareSizePix,(obj.rect(1,3)-obj.syncSquareSizePix):end,:)=obj.syncSquareLuminosity;
            maskblobOff(1:obj.syncSquareSizePix,(obj.rect(1,3)-obj.syncSquareSizePix):end,2)=obj.syncSquareLuminosity;
            
            % Build a single transparency mask texture:
            for i=1:obj.nPTBScreens
                obj.masktexOn(i)=Screen('MakeTexture', obj.PTB_win(i), maskblobOn);
                obj.masktexOff(i)=Screen('MakeTexture', obj.PTB_win(i), maskblobOff);
            end
            
            for i=1:obj.nPTBScreens
                Screen('FillRect',obj.PTB_win(i),obj.visualFieldBackgroundLuminance);
                obj.syncMarkerOn = false;
                Screen('DrawTexture',obj.PTB_win(i),obj.masktexOff(i));
                Screen('Flip',obj.PTB_win(i));
            end
        end
        
        function [props]=getProperties(obj)
            props.metaClassData=metaclass(obj);
            props.allPropName={props.metaClassData.PropertyList.Name}';
            props.allPropSetAccess={props.metaClassData.PropertyList.SetAccess}';
            props.allPropHidden={props.metaClassData.PropertyList.Hidden}';
            props.publicPropName=props.allPropName(find(strcmp(props.allPropSetAccess, 'public') & ~cell2mat(props.allPropHidden)));
            for i=1:numel(props.publicPropName)
                if isprop(obj,[props.publicPropName{i} 'Txt']);
                    props.publicPropDescription{i,1}=obj.([props.publicPropName{i} 'Txt']);
                else
                    props.publicPropDescription{i,1}='description missing (add a property to the VStim object with the same name as the property but with Txt in the end)';
                end
                props.publicPropVal{i,1}=obj.(props.publicPropName{i});
            end
            %collect all prop values
            for i=1:numel(props.allPropName)
                props.allPropVal{i,1}=obj.(props.allPropName{i});
            end
        end
        
        function [VSMethods]=getVSControlMethods(obj)
            VSMethods.methodName=methods(obj);
            VSMethods.methodDescription={};
            pControlMethods=cellfun(@(x) sum(x(1:2)=='CM')==2,VSMethods.methodName);
            VSMethods.methodName=VSMethods.methodName(pControlMethods);
            for i=1:numel(VSMethods.methodName)
                if isprop(obj,[VSMethods.methodName{i} 'Txt']);
                    VSMethods.methodDescription{i,1}=obj.([VSMethods.methodName{i} 'Txt']);
                else
                    VSMethods.publicPropDescription{i,1}='description missing (add a property to the VStim object with the same name as the method but with Txt in the end)';
                end
                
                VSMethods.methodName{i,1}=VSMethods.methodName{i};
            end
        end
        
        function initializeTTL(obj)
            if ~isempty(obj.dioSession)
            release(obj.dioSession);
            end
            obj.dioSession=daq.createSession('ni');
            addDigitalChannel(obj.dioSession,'dev1','port1/line0','OutputOnly');
            addDigitalChannel(obj.dioSession,'dev1','port1/line1','OutputOnly');
            outputSingleScan(obj.dioSession,obj.currentBinState);
        end
        
        function sendTTL(obj,chan,val)
            obj.currentBinState(chan)=val;
            outputSingleScan(obj.dioSession,obj.currentBinState);
        end
        
        
        
        function obj=updateActualStimDuration(obj,event,metaProp)
            %calculate optimal stim duration (as an integer number of frames)
            for i=1:obj.nPTBScreens
            obj.actualStimDuration(i)=round(obj.stimDuration/obj.ifi(i))*obj.ifi(i);
            end
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
        end
        
        function outPar=run(obj)
        end
        
        function cleanUp(obj)
            release(obj.dioSession);
        end
        
    end
end %EOF