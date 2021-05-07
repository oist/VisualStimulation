classdef VS_rectGridTremorInteractive < VStim
    properties (SetAccess=public)
        rectLuminosity = 255; %(L_high-L_low)/L_low
        rectGridSize = 4;
        tilingRatio = 1;
        rotation = 0;
        tremorPixels = 2;
        tremorFreq = 5;
    end
    properties (Constant)
        rectLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        rectGridSizeTxt='The size (N x N) of the rectangular grid';
        rotationTxt='The angle for visual field rotation (clockwise)';
        tilingRatioTxt='The ratio (0-1) beween the total tile length and field length (e.g. if 0.5 tiles are half the size require for complete tiling)';
        tremorPixelsTxt='number of moving pixels';
        tremorFreqTxt='frequency of movement [Hz]';
        remarks={'Categories in Flash stimuli are:'};
    end
    properties (SetAccess=protected)
        pos2X
        pos2Y
        switchTimes
        nSwitchTimes
        pValidRect
    end
    properties (Hidden, SetAccess=protected)
        X1
        X2
        X3
        X4
        Y1
        Y2
        Y3
        Y4
    end
    methods
        function obj=run(obj)
            %calculate the coordinates for the rectangles that fit into the visual space
            centerX=obj.actualVFieldDiameter/2;
            centerY=obj.actualVFieldDiameter/2;
            
            %calculate the coordinates for the rectangles that fit into the visual space
            rectSpacing=floor(obj.actualVFieldDiameter/obj.rectGridSize)-1;
            rectSide=rectSpacing*obj.tilingRatio;
            edges=floor((rectSpacing-rectSide)/2):rectSpacing:(obj.actualVFieldDiameter-rectSide);
            edges=floor(edges+((obj.actualVFieldDiameter-(edges(end)+rectSide))-edges(1))/2);
            [obj.X1,obj.Y1]=meshgrid(edges,edges);
            obj.X1=obj.X1;
            obj.Y1=obj.Y1;
            obj.X2=obj.X1+rectSide-1;
            obj.Y2=obj.Y1;
            obj.X3=obj.X1+rectSide-1;
            obj.Y3=obj.Y1+rectSide-1;
            obj.X4=obj.X1;
            obj.Y4=obj.Y1+rectSide-1;
            obj.pValidRect=find( sqrt((obj.X1-centerX).^2+(obj.Y1-centerY).^2)<(obj.actualVFieldDiameter/2) &...
                sqrt((obj.X2-centerX).^2+(obj.Y2-centerY).^2)<(obj.actualVFieldDiameter/2) &...
                sqrt((obj.X3-centerX).^2+(obj.Y3-centerY).^2)<(obj.actualVFieldDiameter/2) &...
                sqrt((obj.X4-centerX).^2+(obj.Y4-centerY).^2)<(obj.actualVFieldDiameter/2));
                        
            %calculate X and Y position for the valid places
            obj.pos2X=rem(obj.pValidRect,obj.rectGridSize);
            obj.pos2X(obj.pos2X==0)=obj.rectGridSize;
            
            obj.pos2Y=ceil((obj.pValidRect-0.5)/obj.rectGridSize);
            
            obj.pos2X=obj.pos2X-min(obj.pos2X)+1;
            obj.pos2Y=obj.pos2Y-min(obj.pos2Y)+1;
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.visualFieldBackgroundLuminance=obj.visualFieldBackgroundLuminance;
            
            obj.switchTimes=0:(1/obj.tremorFreq/2):obj.stimDuration;
            obj.nSwitchTimes=numel(obj.switchTimes);
            
            %create interactive GUI
            hGrid=uix.Grid('Parent',obj.hInteractiveGUI);
            pushButtonOrder=zeros(obj.rectGridSize);
            pushButtonOrder(:)=1:(obj.rectGridSize^2);
            pushButtonOrder=pushButtonOrder';
            for i=pushButtonOrder(:)'
                p=find(i==obj.pValidRect);
                if ~isempty(p)
                    uicontrol('Parent', hGrid, 'Style','push','String',[num2str(p) ')' num2str(obj.pos2X(p)) ',' num2str(obj.pos2Y(p))],'Callback',{@obj.pushStim,i});
                else
                    uicontrol('Parent', hGrid, 'Style','push','String','-');
                end
            end
            set(hGrid,'Widths',-1*ones(1,obj.rectGridSize),'Heights',-1*ones(1,obj.rectGridSize));
            disp('Session starting');
                
            %delete(hGrid);
            %disp('Session ended');
        end
        
        function pushStim(obj,hObj,event,stimPosition)
            %start the session
            I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
            I(obj.X1(stimPosition):obj.X3(stimPosition),obj.Y1(stimPosition):obj.Y3(stimPosition))=obj.rectLuminosity;
            imgTex(1)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
            
            I=ones(obj.visualFieldRect(3)-obj.visualFieldRect(1),obj.visualFieldRect(4)-obj.visualFieldRect(2)).*obj.visualFieldBackgroundLuminance;
            I((obj.X1(stimPosition)+obj.tremorPixels):(obj.X3(stimPosition)+obj.tremorPixels),...
                (obj.Y1(stimPosition)+obj.tremorPixels):(obj.Y3(stimPosition)+obj.tremorPixels))=obj.rectLuminosity;
            imgTex(2)=Screen('MakeTexture', obj.PTB_win,I,obj.rotation);
            
            tremorPos=1;
            obj.syncMarkerOn = false;
            Screen('DrawTexture',obj.PTB_win,imgTex(tremorPos+1),[],obj.visualFieldRect,obj.rotation);
            obj.applyBackgound; %apply final mask and note that drawing finished
            
            obj.sendTTL(2,true);     
            
            t0=GetSecs;
            for j=1:numel(obj.switchTimes)
                Screen('Flip',obj.PTB_win,t0+obj.switchTimes(j));
                obj.sendTTL(2,false);     
                tremorPos=~tremorPos;
                
                Screen('DrawTexture',obj.PTB_win,imgTex(tremorPos+1),[],obj.visualFieldRect,obj.rotation);
                obj.applyBackgound; %apply final mask and note that drawing finished
                
            end
            
            Screen('FillOval',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            obj.applyBackgound;
            
            Screen('Flip',obj.PTB_win,t0+obj.stimDuration);
            obj.sendTTL(2,false);     
            
            Screen('Close',imgTex);
        end
        
        function outStats=getLastStimStatistics(obj,hFigure)
            outStats=[];
        end
        
        %class constractor
        function obj=VS_rectGridTremorInteractive(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
            obj.hInteractiveGUI=h;
        end
    end
end %EOF