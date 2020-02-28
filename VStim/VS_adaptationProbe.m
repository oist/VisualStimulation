classdef VS_adaptationProbe < VStim
    properties
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        %test
        meanLuminosity = 128;
        contrast = 1;
        rectNum=8
        %numberOfFrames=100
        frameRate=45;
        sparsity=30;
        minIti=1;
        maxIti=30;
        itiStep=1;
        minDur= 0.2;
        maxDur = 5;
        durStep =0.1;
    end
    properties (Hidden,Constant)
        defaultTrialsPerCategory=250; %number of trials to present
        defaultBackground=128;
        meanLuminosityTxt='luminance value for grey pixels';
        contrastTxt='% of dynamic range to use';
        rectNumTxt='How many rectangles to put onto each spatial dimension (not counting the mask)';
       % numberOfFramesTxt='number of stimuli delivered'
        frameRateTxt='frequency in Hz';
        sparsityTxt='%of non grey squares';
        minItiTxt='min inter trial interval (s)';
        maxItiTxt='max inter trial interval (s)';
        itiStepTxt='inter trial interval step size(s)';
        minDurTxt='min duration (s)';
        maxDurTxt='max duration (s)';
        durStepTxt='duration step(s)';
        
        remarks={''};
    end
    properties (Hidden)
        stim
        itiSelection
        numFrames
        stimOnset
        flipOffsetTimeStamp
        flipMiss
        flipOnsetTimeStamp
    end
    methods
        function obj=run(obj)
            
            itiDist=obj.minIti:obj.itiStep:obj.maxIti;
            durDist=obj.minDur:obj.durStep:obj.maxDur;
            
            obj.itiSelection=itiDist(ceil(rand(obj.trialsPerCategory,1)*length(itiDist)));
            durSelection=durDist(ceil(rand(obj.trialsPerCategory,1)*length(durDist)));
            obj.numFrames=durSelection*obj.frameRate;
            
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
%            obj.stim=zeros(actRectNum,actRectNum,obj.trialsPerCategory,obj.numberOfFrames);
            obj.stim=cell(obj.trialsPerCategory,1);
            for t=1:obj.trialsPerCategory
                tempStim=[];
                for x=1:obj.numFrames(t)
                    intensity=rand(actRectNum^2,1);
                    w=(intensity<0.01*obj.sparsity/2);
                    b=(intensity>=0.01*obj.sparsity/2);
                    g=intensity>2*(0.01*obj.sparsity/2);
                    intensity(w)=whiteVal;
                    intensity(b)=blackVal;
                    intensity(g)=greyVal;
                    intensity(toInclude==0)=greyVal;
                    rectPos=reshape(intensity,size(intensity,1)^0.5,size(intensity,1)^0.5);
                   tempStim(:,:,x)=rectPos;
                    tex{t,x}=Screen('MakeTexture', obj.PTB_win, rectPos);
                end
                obj.stim{t}=tempStim;
            end
            
            
            %initialize for post hoc monitering of stimuuls timing
             obj.flipOnsetTimeStamp=cell(obj.trialsPerCategory, max(obj.numFrames)); %when the flip happened
            obj.stimOnset=cell(obj.trialsPerCategory, max(obj.numFrames));       %estimate of stim onset
            obj.flipOffsetTimeStamp=cell(obj.trialsPerCategory, max(obj.numFrames));  %flip done
            obj.flipMiss=cell(obj.trialsPerCategory, max(obj.numFrames));            %positive for missed stim
           
            
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
                pp(uint8(obj.trigChNames(2)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                
                disp(['Trial ' num2str(i) '/' num2str(obj.trialsPerCategory)]);
                objRect = SetRect(0,0, obj.rectNum, obj.rectNum);
                dstRect = ArrangeRects(1, objRect, winRect);
                count = 1;
                
                while count <= obj.numFrames(i)
                    
                    Screen('DrawTexture', obj.PTB_win, tex{i,count}, [], dstRect, [], 0);
                    Screen('DrawTexture',obj.PTB_win,obj.masktex);
                    pp(uint8(obj.trigChNames(3)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    [obj.flipOnsetTimeStamp{i,count},obj.stimOnset{i,count},obj.flipOffsetTimeStamp{i,count},obj.flipMiss{i,count}]=Screen('Flip',obj.PTB_win);
                    pp(uint8(obj.trigChNames(3)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                     WaitSecs(1/obj.frameRate);
                    count = count + 1;
                    
                end
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.trialsPerCategory=i;
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                     Screen('DrawTexture',obj.PTB_win,obj.masktex);
                    Screen('Flip',obj.PTB_win);
                    pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    WaitSecs(obj.itiSelection(i));
                    disp('Trial ended early');
                    
                    return
                end
                
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
               Screen('Flip',obj.PTB_win);
                pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                WaitSecs(obj.itiSelection(i));
                disp('Trial ended');
                
            end
            
            pp(uint8(obj.trigChNames(1)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
            WaitSecs(obj.postSessionDelay);
            disp('Session ended');
            
        end
        
        
        %class constractor
        function obj=VS_adaptationProbe(w,h)
            obj = obj@VStim(w); %ca
            %get the visual stimulation methods
            obj.trialsPerCategory=obj.defaultTrialsPerCategory;
            obj.visualFieldBackgroundLuminance=obj.defaultBackground;
        end
        
    end
end %EOF