classdef VS_testStimGrid < VStim
    properties
        %all these properties are modifiable by user and will appear in visual stim GUI
        %Place all other variables in hidden properties
        
        %visualFieldBackgroundLuminance = 128;
        %visualFieldDiameter = 1024; %pixels
        %stimDuration = 1; %superclass VStim
        %interTrialDelay = 20; %superclass VStim
        %trialsPerCategory = 10;
        %preSessionDelay = 10;
        luminosity = 255; %(L_high-L_low)/L_low
        pixelsInBand = 100;
        lineWidth = 10;
        rotation = 0;
    end
    properties (Hidden,Constant)
        luminosityTxt='The luminocity value for the stim';
        numberOfBandsTxt='the distance between band centers [pixels]';
        lineWidthTxt='The width of the line in test image [pixels]';
        rotationTxt='The rotation angle of the images (for alignment to visual streak';
        
        remarks={'Categories in stimuli are:'};
    end
    properties (Hidden)
        
    end
    methods
        function obj=run(obj)
            %draw cross hair
            T=ones(obj.rect([4 3]))*obj.visualFieldBackgroundLuminance;
            T(round(obj.centerY-obj.lineWidth/2):round(obj.centerY+obj.lineWidth/2),:)=obj.luminosity;
            T(:,round(obj.centerX-obj.lineWidth/2):round(obj.centerX+obj.lineWidth/2))=obj.luminosity;
            %allignment mark
            T(1:(obj.rect(4))/6,1:obj.lineWidth)=obj.luminosity;
            T(1:obj.lineWidth,1:(obj.rect(3))/6)=obj.luminosity;
            
            [X,Y]=meshgrid(1:obj.rect(3),1:obj.rect(4));
            
            for i=obj.pixelsInBand:obj.pixelsInBand:obj.rect(3)
                p=find(abs(X-obj.centerX)==i);
                T(p)=obj.luminosity;
                
                p=find(abs(Y-obj.centerY)==i);
                T(p)=obj.luminosity;
            end
           
            if obj.simulationMode
                disp('No stimulation mode exists for this stimulation');
                return;
            end
            for i=1:obj.nPTBScreens
                imgTex=Screen('MakeTexture',obj.PTB_win(i),T,obj.rotation);
                Screen('DrawTexture',obj.PTB_win(i),imgTex,[],obj.visualFieldRect,obj.rotation);
                Screen('Flip',obj.PTB_win(i));
            end

            while 1
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance; %rest the stimulation screen
                    for i=1:obj.nPTBScreens
                        Screen('Flip',obj.PTB_win(i));
                    end
                    return;
                end
            end
            
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats=[];
        end
        %class constractor
        function obj=VS_testStimGrid(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.visualFieldBackgroundLuminance=0;
            obj.stimDuration=NaN;
            obj.interTrialDelay = NaN;
        	obj.trialsPerCategory = NaN;
        	obj.preSessionDelay = NaN;
            obj.postSessionDelay = NaN;
        end
    end
end %EOF