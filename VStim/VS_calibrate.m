classdef VS_calibrate < VStim
    properties (SetAccess=public)
        
        
    end
    properties (SetObservable, SetAccess=public)
        
    end
    properties (Constant)
        remarks='';
    end
    
    properties (Hidden, SetAccess=protected)
        
        
    end
    properties (Hidden)
        pixelList
    end
    
    methods
        
        function obj=run(obj)
            
            
            save tmpVSFile obj; %temporarily save object in case of a crash
            selectedScreen=1;
            sqSize=10;
            obj.pixelList=[];
            
            imgRect=[obj.rect(1,4) sum(obj.rect(:,3))];
            [X,Y] = meshgrid((sqSize+1):10:(imgRect(2)-sqSize),(sqSize+1):10:(imgRect(1)-sqSize));
            pixLocations=[Y(:),X(:)];
            KbName('UnifyKeyNames')
            activeKeys = [KbName('LeftArrow') KbName('RightArrow') KbName('UpArrow') KbName('DownArrow') KbName('Return') KbName('ESCAPE')];
            %codes [37 39 38 40 13 27]
            
            
            currPos=[sqSize+1,sqSize+1];
            dispCalImg(obj,imgRect,sqSize,currPos,selectedScreen);
            
            RestrictKeysForKbCheck(activeKeys);
            %   ListenChar(2);
            timedout = false;
            while ~timedout
                [ keyIsDown, keyTime, keyCode ] = KbCheck;
                
                if keyCode(37) %left
                    if currPos(1)>(sqSize+1)
                        currPos(1)=currPos(1)-1;
                        dispCalImg(obj,imgRect,sqSize,currPos,selectedScreen);
                    end
                end
                
                if keyCode(39) %right
                    if currPos(1)<imgRect(1)-sqSize
                        currPos(1)=currPos(1)+1;
                        dispCalImg(obj,imgRect,sqSize,currPos,selectedScreen);
                    end
                end
                
                if keyCode(38) %up
                    if currPos(2)<imgRect(2)-sqSize
                        currPos(2)=currPos(2)+1;
                        dispCalImg(obj,imgRect,sqSize,currPos,selectedScreen);
                    end
                end
                
                if keyCode(40) %down
                    if currPos(2)>(sqSize+1)
                        currPos(2)=currPos(2)-1;
                        dispCalImg(obj,imgRect,sqSize,currPos,selectedScreen);
                    end
                end
                
                if keyCode(13) %save coordinates on enter
                    
                    if isempty(obj.pixelList)
                        obj.pixelList=[obj.pixelList; currPos]; 
                        disp(obj.pixelList)
                    elseif obj.pixelList(end,1)~=currPos(1)||obj.pixelList(end,2)~=currPos(2)
                        obj.pixelList=[obj.pixelList; currPos];
                        disp(obj.pixelList)
                    end
                   
                end
                
                
                if keyCode(27) %break on esc
                    timedout=true;
                    disp(obj.pixelList)
                    pixelList=obj.pixelList
                    save('calibCoords','pixelList')
                end
                
                
            end
            
            RestrictKeysForKbCheck;
            ListenChar(1)
        
            
        end
        
        function obj=dispCalImg(obj,imgRect,sqSize,currPos,selectedScreen)
            Screen('Close',obj.PTB_win(selectedScreen)); %testing
            img=uint8(zeros(imgRect));
            img((currPos(1)-sqSize):(currPos(1)+sqSize),(currPos(2)-sqSize):(currPos(2)+sqSize))=255;
            img((currPos(1)-round(sqSize/5)):(currPos(1)+round(sqSize/5)),(currPos(2)-round(sqSize/5)):(currPos(2)+round(sqSize/5)))=0;
            imgTex=Screen('MakeTexture', obj.PTB_win(selectedScreen),img);
            Screen('DrawTexture',obj.PTB_win(selectedScreen),imgTex,[],[],[]);
            Screen('Flip',obj.PTB_win(selectedScreen));
            
        end
        
        %class constractor
        function obj=VS_calibrate(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF