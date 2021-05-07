classdef VS_movie < VStim
    properties (SetAccess=public)
        playAsImgSequence = true;
        randomize = false;
        loops = 1;
        skipFrames = 0;
        initialFrozenFrames = 0;
        nVideos = 1;
    end
    properties (SetObservable, SetAccess=public)
        rotation = 0;
    end
    properties (Constant)
        CMloadMovieTxt='load movie file or sequence of images to be presented as a movie';
        CMsaveVideoAsSingleImagesTxt='save single movie images as presented on the screen';
        
        skipFramesTxt='Show movie in lower temporal resolution than screen refresh by skipping n frames per frame (e.g. use 1 for showing 30Hz movie on 60Hz display)';
        playAsImgSequenceTxt='Play movie using the ptb movie function or as sequence of textures (frames)';
        rotationTxt='The angle for visual field rotation (clockwise)';
        nMoviesTxt='the number of movies to play';
        remarks={'Categories in stimuli are: speed, rotateDots, rotationZoomDirection'};
    end
    properties (SetAccess=protected)
        movieSequence
        movTex
        movPtr
        movDuration
        movFps
        movWidth
        movHeight
        movFrameCount
        movAspectRatio
        movieFileName
        movPathName
    end
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
        syncTime
    end
    
    methods
        
        function obj=run(obj)
            
            obj.nTotTrials=obj.trialsPerCategory*obj.nVideos;
            
            %calculate sequence of positions and times
            obj.movieSequence=reshape(repmat(1:obj.nVideos,obj.trialsPerCategory,1),1,size(repmat(1:obj.nVideos,obj.trialsPerCategory,1),1)*size(repmat(1:obj.nVideos,obj.trialsPerCategory,1),2));
            
            
            %randomize
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.movieSequence=obj.movieSequence(randomPermutation);
            end
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false;
            Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win,obj.masktexOff);
            Screen('Flip',obj.PTB_win);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            obj.flip=nan(obj.nTotTrials,obj.initialFrozenFrames+obj.movFrameCount);
            obj.stim=nan(obj.nTotTrials,obj.initialFrozenFrames+obj.movFrameCount);
            obj.flipEnd=nan(obj.nTotTrials,obj.initialFrozenFrames+obj.movFrameCount);
            obj.miss=nan(obj.nTotTrials,obj.initialFrozenFrames+obj.movFrameCount);
            
            tFrame=( 0 : ((obj.skipFrames+1)*obj.ifi) : (( (obj.skipFrames+1)*obj.ifi)*(obj.initialFrozenFrames+obj.movFrameCount-1)) )';
            frameIdx=[ones(1,obj.initialFrozenFrames) 1:obj.movFrameCount];
            
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
                       
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                currMovie=obj.movieSequence(i);
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                
                frameTTL=true;
                if ~obj.playAsImgSequence
                    [droppedframes] = Screen('PlayMovie', obj.movPtr, 1, obj.loops);
                else
                    for k=1:obj.loops
                        tFrameTmp=tFrame+GetSecs+obj.ifi/2;
                        for j=frameIdx
                            % Update display
                            Screen('DrawTexture',obj.PTB_win,obj.movTex(j,currMovie),[],obj.visualFieldRect,obj.rotation);
                            obj.applyBackgound;
                            
                            [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,tFrameTmp(j));
                            obj.sendTTL(3,frameTTL);
                            frameTTL=~frameTTL;
                        end
                    end
                end
                [endSessionTime]=GetSecs;
                obj.sendTTL(3,false);
                
                % Start wait: Code here is run during the waiting for the new session
                obj.syncMarkerOn = true; %
                
                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;
                Screen('Flip',obj.PTB_win);
                obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                WaitSecs(obj.interTrialDelay-(GetSecs-endSessionTime));
            end
            
            WaitSecs(obj.postSessionDelay);
            
            obj.sendTTL(1,false); %session end trigger

            disp('Session ended');
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats.props=obj.getProperties;
            
            figure;
            text(0.1,0.5,{'Statistics code not written','please add to method!!!'},'FontSize',20);
        end
        
        function cleanUp(obj)
            %clear previous textures
            if ~isempty(obj.movTex)
                Screen('Close',obj.movTex);
                obj.movTex=[];
            end
        end
        
        function obj=CMloadMovie(obj,srcHandle,eventData,hPanel)
            
            for n=1:obj.nVideos
                [obj.movieFileName, obj.movPathName] = uigetfile('*.*','Choose movie files or series of images named *_F001-*_FXXX','MultiSelect','On');
                if iscell(obj.movieFileName)
                    %order images
                    [~,shortNames]=cellfun(@(x) fileparts(x),obj.movieFileName,'UniformOutput',0);
                    [pImg]=cell2mat(cellfun(@(x) str2num(x(end-2:end)),shortNames,'UniformOutput',0));
                    [~,order]=sort(pImg);
                    obj.movieFileName=obj.movieFileName(order);
                end
                
                obj.calculateVideoTextures;
            end
        end
        
        function obj=calculateVideoTextures(obj,event,metaProp)
            disp(['preparing textures with rotation ' num2str(obj.rotation) ' !!!!']);
            if iscell(obj.movieFileName)
                nFiles=numel(obj.movieFileName);
            else
                nFiles=size(obj.movieFileName,1);
            end
            
            if nFiles>0
                %clear previous textures
                if obj.nVideos==1
                    obj.cleanUp;
                end
                
                if nFiles>1 %single frame mode
                    obj.movFrameCount=nFiles;
                    obj.playAsImgSequence=true;
                    
                    for i=1:obj.movFrameCount
                        I=imread([obj.movPathName obj.movieFileName{i}]);
                        [M,N,l]=size(I);
                        
                        if obj.inVivoSettings==1;
                            obj.movTex(i,obj.nVideos)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
                        elseif N>=M
                            cutPixels=round((N-M)/2);
                            obj.movTex(i,obj.nVideos)=Screen('MakeTexture', obj.PTB_win,I(:,(cutPixels+1):(end-cutPixels),:),obj.rotation);
                        else
                            cutPixels=round((M-N)/2);
                            obj.movTex(i,obj.nVideos)=Screen('MakeTexture', obj.PTB_win,I((cutPixels+1):(end-cutPixels),:,:),obj.rotation);
                        end
                        
                        fprintf('%d ',i);
                    end
                else %complete movie mode
                    if obj.playAsImgSequence
                        disp('Uploading video to memory...');
                        readerObj=VideoReader([obj.movPathName obj.movieFileName]);
                        frameRatio=readerObj.FrameRate/(1/obj.ifi);
                        %frameRatio=1;
                        vid=read(readerObj);
                        [M,N,l,numF]=size(vid);
                        
                        obj.movFrameCount=floor(numF./frameRatio);
                        disp('Calculating single frame textures:');
                        for i=1:obj.movFrameCount
                            
                            if obj.inVivoSettings==1;
                                obj.movTex(i,obj.nVideos)=Screen('MakeTexture', obj.PTB_win,squeeze(vid(:,:,:,ceil(i*frameRatio))),obj.rotation);
                            elseif N>=M
                                cutPixels=round((N-M)/2);
                                obj.movTex(i,obj.nVideos)=Screen('MakeTexture', obj.PTB_win,squeeze(vid(:,(cutPixels+1):(end-cutPixels),:,ceil(i*frameRatio))),obj.rotation);
                            else
                                cutPixels=round((M-N)/2);
                                obj.movTex(i,obj.nVideos)=Screen('MakeTexture', obj.PTB_win,squeeze(vid(:,:,(cutPixels+1):(end-cutPixels),ceil(i*frameRatio))),obj.rotation);
                            end
                             fprintf('%d ',i);
                        end
                        delete(readerObj);
                    else
                        [obj.movPtr,obj.movDuration,obj.movFps,obj.movWidth,obj.movHeight,obj.movFrameCount,obj.movAspectRatio]=...
                            Screen('OpenMovie',obj.PTB_win,[obj.movPathName obj.movieFileName]);
                    end
                    
                end
                fprintf('\n');
                disp(['Done preparing movie ' num2str(obj.movFrameCount) ' textures']);
            else
                disp('No video was chosen! Did not calculate textures');
            end
            
        end
        
        function obj=CMsaveVideoAsSingleImages(obj,srcHandle,eventData,hPanel)
            [fileName, pathName] = uiputfile('*.*','Choose file base name');
            
            disp('Exporting movie to single images...');
            frameIdx=[ones(1,obj.initialFrozenFrames) 1:obj.movFrameCount];
            f=figure;
            c=1;
            for j=frameIdx
                fprintf('%d ',j);
                % Update display
                Screen('DrawTexture',obj.PTB_win,obj.movTex(j,1),[],obj.visualFieldRect,obj.rotation);
                obj.applyBackgound;
                
                Screen('Flip',obj.PTB_win);
                WaitSecs(0.1);
                imageArray=Screen('GetImage',obj.PTB_win);
                
                hh=imshow(imageArray);
                print(f,[pathName fileName num2str(c,'%.4d')],'-djpeg','-r200');
                delete(hh);
                c=c+1;
            end
            Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            obj.applyBackgound;
            Screen('Flip',obj.PTB_win);
            WaitSecs(0.1);
            imageArray=Screen('GetImage',obj.PTB_win);
            hh=imshow(imageArray);
            print(f,[pathName fileName num2str(j+1,'%.4d')],'-djpeg','-r200');
        end
        
        %class constractor
        function obj=VS_movie(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            addlistener(obj,'rotation','PostSet',@obj.calculateVideoTextures); %add a listener to rotation, after its changed the textures should be updated
        end
    end
end %EOF