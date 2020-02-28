classdef VS_spatialNoise < VStim
    properties
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        %test
        meanLuminosity = 128;
        contrast = 1;
        rectNum=10;
        numberOfFrames=450
        frameRate=45;
        sparsity=30;
        
    end
    properties (Hidden,Constant)
        defaultTrialsPerCategory=500; %number of gratings to present
        defaultBackground=128;
         defaultITI=0;
        meanLuminosityTxt='luminance value for grey pixels';
        contrastTxt='% of dynamic range to use';
        rectNumTxt='How many rectangles to put onto each spatial dimension (not counting the mask)';
        numberOfFramesTxt='number of stimuli delivered'
        frameRateTxt='frequency in Hz';
        sparsityTxt='%of non grey squares';
        remarks={''};
    end
    properties (Hidden)
        stim
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
            obj.stim=cell(obj.trialsPerCategory,obj.numberOfFrames);
            for t=1:obj.trialsPerCategory
                for x=1:obj.numberOfFrames
                    
                    intensity=rand(actRectNum^2,1);
                    w=(intensity<0.01*obj.sparsity/2);
                    b=(intensity>=0.01*obj.sparsity/2);
                    g=intensity>2*(0.01*obj.sparsity/2);
                    intensity(w)=whiteVal;
                    intensity(b)=blackVal;
                    intensity(g)=greyVal;
                    intensity(toInclude==0)=greyVal;
                    rectPos=reshape(intensity,size(intensity,1)^0.5,size(intensity,1)^0.5);
                    obj.stim{t,x}=rectPos;
                    tex(t,x)=Screen('MakeTexture', obj.PTB_win, rectPos);
                end
            end
            
            
            %initialize for post hoc monitering of stimuuls timing
            obj.flipOnsetTimeStamp=nan(obj.trialsPerCategory,obj.numberOfFrames+1); %when the flip happened
            obj.stimOnset=nan(obj.trialsPerCategory,obj.numberOfFrames+1);          %estimate of stim onset
            obj.flipOffsetTimeStamp=nan(obj.trialsPerCategory,obj.numberOfFrames+1);  %flip done
            obj.flipMiss=nan(obj.trialsPerCategory,obj.numberOfFrames+1);              %positive for missed stim
            
            
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
                
                while count <= obj.numberOfFrames
                    
                      
                    Screen('DrawTexture', obj.PTB_win, tex(i,count), [], dstRect, [], 0);
                    Screen('DrawTexture',obj.PTB_win,obj.masktex);
                    WaitSecs(1/obj.frameRate);
                     pp(uint8(obj.trigChNames(3)),true,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    [obj.flipOnsetTimeStamp(i,count),obj.stimOnset(i,count),obj.flipOffsetTimeStamp(i,count),obj.flipMiss(i,count)]=Screen('Flip',obj.PTB_win);
                    pp(uint8(obj.trigChNames(3)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    Screen('DrawingFinished', obj.PTB_win); % Tell PTB that no further drawing commands will follow before Screen('Flip')
                    count = count + 1;
                    
                end
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    i=obj.trialsPerCategory;
                    Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                    Screen('DrawTexture',obj.PTB_win,obj.masktex);
                    [obj.flipOnsetTimeStamp(i,count),obj.stimOnset(i,count),obj.flipOffsetTimeStamp(i,count),obj.flipMiss(i,count)]=Screen('Flip',obj.PTB_win);
                    pp(uint8(obj.trigChNames(2)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    WaitSecs(obj.interTrialDelay);
                    disp('Trial ended early');
                    pp(uint8(obj.trigChNames(1)),false,false,uint8(0),uint64(32784)); %session start trigger (also triggers the recording start)
                    WaitSecs(obj.postSessionDelay);
                    disp('Session ended');
                    
                    return
                end
                
                Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                Screen('DrawTexture',obj.PTB_win,obj.masktex);
                [obj.flipOnsetTimeStamp(i,count),obj.stimOnset(i,count),obj.flipOffsetTimeStamp(i,count),obj.flipMiss(i,count)]=Screen('Flip',obj.PTB_win);
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
        function obj=VS_spatialNoise(w,h)
            obj = obj@VStim(w); %ca
            %get the visual stimulation methods
            obj.trialsPerCategory=obj.defaultTrialsPerCategory;
            obj.visualFieldBackgroundLuminance=obj.defaultBackground;
              obj.interTrialDelay=obj.defaultITI;
        end
        
    end
end %EOF