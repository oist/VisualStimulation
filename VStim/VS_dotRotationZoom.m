classdef VS_dotRotationZoom < VStim
    properties (SetAccess=public)
        dotLuminosity = 255; %(L_high-L_low)/L_low
        randomize = true;
        speed = 100; %pixel per second
        nDots= 1000 % number of dots
        dotSize= 5 % width of dot (pixels)
        rotateDots = 1; %rotate (or zoom)
        rotationZoomDirection = 1; %the direction of rotations/zoom
    end
    properties (Constant)
        dotLuminosityTxt='The luminocity value for the rectangles, if array->show all given contrasts';
        dotSizeTxt='The size of the dots [pixels]';
        rotateDotsTxt='True/false/[true false] - whether to rotate, zoom or both';
        randomizeTxt='Randomize the order of different trials';
        nDotsTxt='The number of dots to be shown';
        speedTxt='The speed of the moving dots [pixels/sec]';
        rotationZoomDirectionTxt='[1/-1] the direction of rotation/zoom'
        remarks={'Categories in stimuli are: speed, rotateDots, rotationZoomDirection'};
    end
    properties (SetAccess=protected)
        speeds
        rotateZoom
        directions
        f_kill=0.05;
    end
    properties (Hidden, SetAccess=protected)
        flip
        stim
        flipEnd
        miss
    end
    
    methods
        
        function obj=run(obj)
            %calculate the angles of directions
            nSpeeds=numel(obj.speed);
            nRotationZoomModes=numel(obj.rotateDots);
            nDirections=numel(obj.rotationZoomDirection);
            
            obj.nTotTrials=obj.trialsPerCategory*nSpeeds*nRotationZoomModes*nDirections;
            
            D0=obj.actualVFieldDiameter; %half a ball on each side
            r0=D0/2;
            
            %calculate sequece of positions and times
            obj.speeds=nan(1,obj.nTotTrials);
            obj.rotateZoom=nan(1,obj.nTotTrials);
            obj.directions=nan(1,obj.nTotTrials);
            c=1;
            for i=1:nSpeeds
                for j=1:nRotationZoomModes
                    for k=1:nDirections
                        obj.speeds( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.speed(i);
                        obj.rotateZoom( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.rotateDots(j);
                        obj.directions( ((c-1)*obj.trialsPerCategory+1):(c*obj.trialsPerCategory) )=obj.rotationZoomDirection(k);
                        c=c+1;
                    end
                end
            end
            %randomize
            if obj.randomize
                randomPermutation=randperm(obj.nTotTrials);
                obj.speeds=obj.speeds(randomPermutation);
                obj.rotateZoom=obj.rotateZoom(randomPermutation);
                obj.directions=obj.directions(randomPermutation);
            end
            
            %run test Flip (usually this first flip is slow and so it is not included in the anlysis
            obj.syncMarkerOn = false; %initialize sync signal
            Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
            Screen('DrawTexture',obj.PTB_win,obj.masktexOff);
            Screen('Flip',obj.PTB_win);
            
            if obj.simulationMode
                disp('Simulation mode finished running');
                return;
            end
            
            nFrames = ceil(obj.stimDuration/obj.ifi); % number of animation frames in loop
            obj.flip=nan(obj.nTotTrials,nFrames);
            obj.stim=nan(obj.nTotTrials,nFrames);
            obj.flipEnd=nan(obj.nTotTrials,nFrames);
            obj.miss=nan(obj.nTotTrials,nFrames);
            
            tFrame=(0:obj.ifi:(obj.stimDuration+obj.ifi))';
            
            save tmpVSFile obj; %temporarily save object in case of a crash
            disp('Session starting');
            
            %main loop - start the session
            obj.sendTTL(1,true); %session start trigger (also triggers the recording start)
            WaitSecs(obj.preSessionDelay); %pre session wait time
            for i=1:obj.nTotTrials
                tmpSpeed=obj.speeds(i);
                tmpDir=obj.directions(i);
                tmpRotZoom=obj.rotateZoom(i);
                
                mdir = tmpDir*ones(obj.nDots,1);
                pfs = tmpSpeed * obj.ifi;                            % dot speed (pixels/frame)
                
                % ---------------------------------------
                % initialize dot positions and velocities
                % ---------------------------------------
                
                rmax = r0; %max distance from center [pixels]
                rmin = 20; %min distance from center [pixels]
                r = rmax * sqrt(rand(obj.nDots,1));	% r
                r(r<rmin) = rmin;
                t = 2*pi*rand(obj.nDots,1);                     % theta polar coordinate
                cs = [cos(t), sin(t)];
                xy = [r r] .* cs;   % dot positions in Cartesian coordinates (pixels from center)
                
                if tmpRotZoom
                    dt = pfs * mdir ./ r;                       % change in theta per frame (radians)
                else
                    dr = pfs * mdir;                            % change in radius per frame (pixels)
                    dxdy = [dr dr] .* cs;                       % change in x and y per frame (pixels)
                end
                
                xymatrix = transpose(xy); %try to remove the above
                
                tFrameTmp=tFrame+GetSecs+obj.ifi;
                
                obj.sendTTL(2,true); %session start trigger (also triggers the recording start)
                
                for j=1:nFrames
                    % Update display
                    Screen('DrawDots', obj.PTB_win, xymatrix, obj.dotSize, obj.dotLuminosity, [obj.centerX,obj.centerY] ,1);  % change 1 to 0 to draw square dots
                    obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                    
                    if tmpRotZoom
                        t = t + dt;                         % update theta
                        xy = [r r] .* [cos(t), sin(t)];     % compute new positions
                    else
                        xy = xy + dxdy;						% move dots
                        r = r + dr;							% update polar coordinates too
                    end
                    
                    % check to see which dots have gone beyond the borders of the annuli
                    r_out = find(r > rmax | r < rmin | rand(obj.nDots,1) < obj.f_kill);	% dots to reposition
                    nout = length(r_out);
                    
                    if nout
                        % choose new coordinates
                        r(r_out) = rmax * sqrt(rand(nout,1));
                        r(r<rmin) = rmin;
                        t(r_out) = 2*pi*(rand(nout,1));
                        
                        % now convert the polar coordinates to Cartesian
                        cs(r_out,:) = [cos(t(r_out)), sin(t(r_out))];
                        xy(r_out,:) = [r(r_out) r(r_out)] .* cs(r_out,:);
                        
                        % compute the new cartesian velocities
                        if tmpRotZoom
                            dt(r_out) = pfs * mdir(r_out) ./ r(r_out);
                        else
                            dxdy(r_out,:) = [dr(r_out) dr(r_out)] .* cs(r_out,:);
                        end
                        
                    end;
                    xymatrix = transpose(xy);

                    obj.sendTTL(3,true); %session start trigger (also triggers the recording start)
                    [obj.flip(i,j),obj.stim(i,j),obj.flipEnd(i,j),obj.miss(i,j)]=Screen('Flip',obj.PTB_win,tFrameTmp(j));
                    obj.sendTTL(3,false); %session start trigger (also triggers the recording start)
                end
                obj.sendTTL(2,false); %session start trigger (also triggers the recording start)
                
                Screen('FillRect',obj.PTB_win,obj.visualFieldBackgroundLuminance);
                obj.applyBackgound;  %set background mask and finalize drawing (drawing finished)
                
                [endSessionTime]=Screen('Flip',obj.PTB_win);
                % Start wait: Code here is run during the waiting for the new session
                
                % End wait
                disp(['Trial ' num2str(i) '/' num2str(obj.nTotTrials)]);
                
                %check if stimulation session was stopped by the user
                [keyIsDown, ~, keyCode] = KbCheck;
                if keyCode(obj.escapeKeyCode)
                    obj.lastExcecutedTrial=i;
                    return;
                end
                
                WaitSecs(obj.interTrialDelay-(GetSecs-endSessionTime));
            end
            WaitSecs(obj.postSessionDelay);
            obj.sendTTL(1,false); %session end trigger
            disp('Session ended');
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
        %class constractor
        function obj=VS_dotRotationZoom(w,h)
            %get the visual stimulation methods
            obj = obj@VStim(w); %calling superclass constructor
        end
    end
end %EOF