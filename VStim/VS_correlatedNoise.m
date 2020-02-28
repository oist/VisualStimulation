classdef VS_correlatedNoise < VStim
    properties
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        %test
        meanLuminosity = 128;
        contrast = 1;
        rectNum=10;
        minDelay=1;
        maxDelay=16;
        delayStep=1;
        
        sparsity=50;
        ratioOfMatchVsRandom=20
    end
    properties (Hidden,Constant)
        defaultTrialsPerCategory=500; %number of gratings to present
        defaultBackground=128;
        defaultITI=16;
        defaultStimDuration=1;
        meanLuminosityTxt='luminance value for grey pixels';
        contrastTxt='% of dynamic range to use';
        rectNumTxt='How many rectangles to put onto each spatial dimension (not counting the mask)';
        numberOfFramesTxt='number of stimuli delivered'
        ratioOfMatchVsRandomTxt='fraction of trials that will be probe stim-stim vs probe stim-random';
        frameRateTxt='frequency in Hz';
        sparsityTxt='%of non grey squares';
        minDelayTxt='min inter trial interval (s)';
        maxDelayTxt='max inter trial interval (s)';
        delayStepTxt='inter trial interval step size(s)';
        remarks={''};
    end
    properties (Hidden)
        trialType
        probeStim
        testStim
        delaySelection
        stimOnset
        flipOffsetTimeStamp
        flipMiss
        flipOnsetTimeStamp
        
    end
    methods
        function obj=run(obj)
            
            %make a certain number of squares occur at random places on
            %screen. Make sure no rectangles extend past the visual mask
            
            %find how many pixels per square fit
            rectSpacing=floor(obj.actualVFieldDiameter/(obj.rectNum));
            edges=floor(1:rectSpacing:obj.actualVFieldDiameter);
            edges(end)=[];
            edges=floor(edges+(obj.actualVFieldDiameter-edges(end))/2);
            edges(end)=[];
            actRectNum=length(edges);
            
            %find pixels that can be presented through the optics
            screenProps=Screen('Resolution',obj.PTB_win);
            stimRadious=obj.actualVFieldDiameter/2-rectSpacing;
            [pixY,pixX] = meshgrid(1:screenProps.width,1:screenProps.height);
            goodPix=(screenProps.width/2-pixY).^2+(screenProps.height/2-pixX).^2<stimRadious^2;
            whDiff=(screenProps.width-screenProps.height)/2;
            
            %see whether the different rectangle positions overlap with the
            %non-good pixels
            for x=1:length(edges)
                for y=1:length(edges)
                    toInclude(x,y)=min(min(goodPix(edges(y):(edges(y)+rectSpacing),(edges(x)+whDiff):(edges(x)+rectSpacing+whDiff))));
                end
            end
            toInclude=reshape(toInclude,size(toInclude,1)*size(toInclude,2),1);
            
            
            %what pixel value for each
            whiteVal=round(obj.meanLuminosity-obj.contrast*obj.meanLuminosity)+1;
            blackVal=round(obj.meanLuminosity+obj.contrast*obj.meanLuminosity)-1;
            greyVal=obj. meanLuminosity;
            
            %generate stimulus
            rectPos=zeros(screenProps.height,screenProps.width);
            obj.probeStim=cell(1,obj.trialsPerCategory);
            obj.testStim=cell(1,obj.trialsPerCategory);
            
            %which type of trial? 1 is stim, 2 is inverse, 3 is random
            trialType=rand(obj.trialsPerCategory,1);
            ps=trialType<(obj.ratioOfMatchVsRandom/2);
            psInv=trialType>( obj.ratioOfMatchVsRandom/2);
            randStim=trialType>(obj.ratioOfMatchVsRandom);
            trialType(ps)=1;
            trialType(psInv)=2;
            trialType(randStim)=3;
            obj.trialType=trialType;
            
            for x=1:obj.trialsPerCategory
                
                %the probe stimulus
                intensity=rand(actRectNum^2,1);
                w=(intensity<0.01*obj.sparsity/2);
                b=(intensity>=0.01*obj.sparsity/2);
                g=intensity>2*(0.01*obj.sparsity/2);
                intensity(w)=whiteVal;
                intensity(b)=blackVal;
                intensity(g)=greyVal;
                intensity(toInclude==0)=greyVal;
                rectPos=reshape(intensity,size(intensity,1)^0.5,size(intensity,1)^0.5);
                obj.probeStim{x}=rectPos;
                probeTex(x)=Screen('MakeTexture', obj.PTB_win, rectPos);
                
                %generate test stimulus depending on trial type
                if trialType(x)==1;
                    obj.testStim{x}=rectPos;
                    testTex(x)=Screen('MakeTexture', obj.PTB_win, rectPos);
                    
                elseif trialType(x)==2;
                    psInverse=rectPos;
                    psInverse(find( rectPos==whiteVal))=blackVal;
                    psInverse(find( rectPos==blackVal))=whiteVal;
                    obj.testStim{x}=psInverse
                    testTex(x)=Screen('MakeTexture', obj.PTB_win, psInverse);
                    
                else
                    
                    %flip white to black squares. Flip a number of squares pulled
                    %from a uniform distribution, randomly select which of these
                    %number to flip
                    
                    numberOfSquares=length(find(rectPos~=greyVal))
                    sqLoc=find(rectPos~=greyVal)
                    sqVal=rectPos(find(rectPos~=greyVal))
                    invVal=sqVal;
                    invVal(sqVal==whiteVal)=blackVal;
                    invVal(sqVal==blackVal)=whiteVal;
                    
                    coorelatedImg=rectPos;
                    numToFlip=round(numberOfSquares*rand(1,1));
                    [randSelect, order]=sort(rand(numberOfSquares,1))
                    rectToFlip=sqLoc(order(1:numToFlip));
                    coorelatedImg(rectToFlip)=invVal(toFlip);
                    obj.testStim{x}=coorelatedImg
                    testTex(x)=Screen('MakeTexture', obj.PTB_win, coorelatedImg);
                end
            end
            
            
            
            delayDist=obj.minDelay:obj.delayStep:obj.maxDelay;
            obj.delaySelection=delayDist(ceil(rand(obj.trialsPerCategory,1)*length(delayDist)));
            
            
            
            %initialize for post hoc monitering of stimuuls timing
            obj.flipOnsetTimeStamp=nan(obj.trialsPerCategory,4); %when the flip happened
            obj.stimOnset=nan(obj.trialsPerCategory,4);          %estimate of stim onset
            obj.flipOffsetTimeStamp=nan(obj.trialsPerCategory,4);  %flip done
            obj.flipMiss=nan(obj.trialsPerCategory,4);              %positive for missed stim
            
            
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %run test Flip (sometimes this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            winRect=[round(screenProps.width/2)-round(screenProps.height/2) 0 screenProps.height+round(screenProps.width/2)-round(screenProps.height/2) screenProps.height];  %change this!
            
            %main loop - start the session
            %pp(uint8(obj.trigChNames(1)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            pp(uint8(obj.trigChNames(1)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
            
            for i=1:obj.trialsPerCategory
                %  pp(uint8(obj.trigChNames(2)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                
                disp(['Trial ' num2str(i) '/' num2str(obj.trialsPerCategory)]);
                objRect = SetRect(0,0, obj.rectNum, obj.rectNum);
                dstRect = ArrangeRects(1, objRect, winRect);
                count = 1;
                
                %draw stim
                Screen('DrawTexture', obj.PTB_win, probeTex(i), [], dstRect, [], 0);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                pp(uint8(obj.trigChNames(2)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                [obj.flipOnsetTimeStamp(i,1),obj.stimOnset(i,1),obj.flipOffsetTimeStamp(i,1),obj.flipMiss(i,1)]=Screen('Flip',obj.PTB_win);
                Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                
                
                %wait stim duration, grey screen, wait delay, flip the
                %inverse stim
                WaitSecs(obj.stimDuration);
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                [obj.flipOnsetTimeStamp(i,2),obj.stimOnset(i,2),obj.flipOffsetTimeStamp(i,2),obj.flipMiss(i,2)]=Screen('Flip',obj.PTB_win);
                % pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                WaitSecs(obj.delaySelection(i));
                
                Screen('DrawTexture', obj.PTB_win,  testTex(i), [], dstRect, [], 0);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                pp(uint8(obj.trigChNames(2)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                [obj.flipOnsetTimeStamp(i,3),obj.stimOnset(i,3),obj.flipOffsetTimeStamp(i,3),obj.flipMiss(i,3)]=Screen('Flip',obj.PTB_win);
                Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                WaitSecs(obj.stimDuration);
                
                
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    i=obj.trialsPerCategory;
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                    Screen('DrawTexture',obj.PTB_win,obj.masktex);
                    [obj.flipOnsetTimeStamp(i,4),obj.stimOnset(i,4),obj.flipOffsetTimeStamp(i,4),obj.flipMiss(i,4)]=Screen('Flip',obj.PTB_win);
                    pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    WaitSecs(obj.interTrialDelay);
                    disp('Trial ended early');
                    pp(uint8(obj.trigChNames(1)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                    WaitSecs(obj.postSessionDelay);
                    disp('Session ended');
                    
                    return
                end
                
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                [obj.flipOnsetTimeStamp(i,4),obj.stimOnset(i,4),obj.flipOffsetTimeStamp(i,4),obj.flipMiss(i,4)]=Screen('Flip',obj.PTB_win);
                pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                WaitSecs(obj.interTrialDelay);
                disp('Trial ended');
                
            end
            
            Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win,obj.masktex);
            Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
            pp(uint8(obj.trigChNames(1)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
            WaitSecs(obj.postSessionDelay);
            
            disp('Session ended');
            
        end
        
        
        %class constractor
        function obj=VS_correlatedNoise(w,h)
            obj = obj@VStim(w); %ca
            %get the visual stimulation methods
            obj.trialsPerCategory=obj.defaultTrialsPerCategory;
            obj.visualFieldBackgroundLuminance=obj.defaultBackground;
            obj.interTrialDelay=obj.defaultITI;
            obj.stimDuration=obj.defaultStimDuration;
        end
        
    end
end %EOF