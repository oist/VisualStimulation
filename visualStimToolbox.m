function []=visualStimToolbox(varargin)
%% Default params
simulationModel=false;
initialVStim='VS_testStim';

%% Output list of default variables
%print out default arguments and values if no inputs are given
%{
if nargin==0
    defaultArguments=who;
    for k=1:numel(defaultArguments)
        eval(['defaultArgumentValue=' defaultArguments{k} ';']);
        if numel(defaultArgumentValue)==1
            disp([defaultArguments{k} ' = ' num2str(defaultArgumentValue)]);
        else
            fprintf([defaultArguments{k} ' = ']);
            disp(defaultArgumentValue);
        end
    end
    return;
end
%}
%% Collects all input variables
for k=1:2:nargin
    eval([varargin{k} '=' 'varargin{k+1};']);
end

%% %%%%%%%%%%%%%%%% Parameter definitions  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
VS.hand.hMainFigure=figure; %initialize GUI figure
VS.par.NSKToolBoxMainDir=fileparts(which('identifierOfMainDir4NSKToolBox'));
VS.par.dirSep=filesep; %choose file/dir separator according to platform

%collect all visual stimulation patterns
VS.par.VSDirectory=[VS.par.NSKToolBoxMainDir VS.par.dirSep 'VisualStimulation'];
VS.par.VSObjDir=[VS.par.VSDirectory VS.par.dirSep 'VStim'];
VS.par.PCspecificFilesDir=[VS.par.NSKToolBoxMainDir VS.par.dirSep 'PCspecificFiles'];
VS.par.VSMethods=dir([VS.par.VSObjDir VS.par.dirSep 'VS_*.m']);
VS.par.VSMethods={VS.par.VSMethods.name};
VS.par.VSMethods=cellfun(@(x) x(1:end-2),VS.par.VSMethods,'UniformOutput',0);
VS.par.VSObjNames=cellfun(@(x) x(4:end),VS.par.VSMethods,'UniformOutput',0);

%check Matlab version for using uiextras of uix gui layout support
matlabVer=strsplit(version,'.');
if str2num(matlabVer{1})>=8
    VS.par.useNewUIX=true;
else
    VS.par.useNewUIX=false;
end

%reseed random number generator
rng('shuffle');

%initial configuration
VS.par.currentVSO=find(strcmp(VS.par.VSMethods,initialVStim)); %the default visual stim (first on the list)
VS.par.currentGUIScreen=1; %the default monitor to display GUI
VS.par.currentPTBScreen=2; %the default monitor to display the visual stimulation

%initialize Psychophysics toolbox screens
VS.par.PTB_win=[];
initializeScreens(simulationModel);

% Create the main GUI of the visual stimulation toolbox
createVSGUI;

% Switch to realtime:
priorityLevel=MaxPriority(VS.par.PTB_win);
Priority(priorityLevel); %%priority is set back to regular after GUI closes

%initialize current visual stimulation object
initializeVisualStim;
%% %%%%%%%%%%%%%%%% Nested functions (only header) %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% %%%%%%%%%%%%%%%%%%%%%%%%%% Initialize PTB Screen %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function initializeScreens(simulationModel)
        if nargin==0
            simulationModel=0;
        end
        Screen('CloseAll');
        VS.par.screens=Screen('Screens');
        set(0,'Units','Pixels')
        VS.par.screenPositionsMatlab=get(0,'MonitorPositions');
        
        if isunix %for visual stimulation setup
            %for working with two graphic cards on linux
            Screen('Preference', 'ScreenToHead', 0,0,0);
            Screen('Preference', 'ScreenToHead', 1,0,0);
            PsychTweak('UseGPUIndex',1);
        elseif ispc % this option is actually generic to situations of dual monitors on one graphics card
            if numel(VS.par.screens)>size(VS.par.screenPositionsMatlab,1)
                VS.par.screens=VS.par.screens(2:end);
            end
        end
        VS.par.nScreens=numel(VS.par.screens);
        
        if VS.par.nScreens==1
            VS.par.currentPTBScreen=1;
            VS.par.currentGUIScreen=1;
        end
        
        for i=1:numel(VS.par.screens)
            screenProps=Screen('Resolution', VS.par.screens(i));
            VS.par.ScreenWindowWidth(i)=screenProps.width;
            VS.par.ScreenWindowHeight(i)=screenProps.height;
            VS.par.ScreenFrameRate(i)=screenProps.hz;
            VS.par.ScreenPixelSize(i)=screenProps.pixelSize;
        end
        scrnPos=VS.par.screenPositionsMatlab(VS.par.currentGUIScreen,:);
        VS.par.GUIPosition=[scrnPos(1)+(scrnPos(3)-scrnPos(1))*0.01 scrnPos(2)+(scrnPos(4)-scrnPos(2))*0.07 (scrnPos(3)-scrnPos(1))*0.4 (scrnPos(4)-scrnPos(2))*0.8];
        set(VS.hand.hMainFigure,'position',VS.par.GUIPosition);
        
        if ~simulationModel
            try
                if VS.par.nScreens>1
                    [VS.par.PTB_win] = Screen('OpenWindow',VS.par.screens(VS.par.currentPTBScreen));
                else
                    PTBScreenPosition=round([VS.par.GUIPosition(1)+VS.par.GUIPosition(3)+30 scrnPos(4)-sum(VS.par.GUIPosition([2 4]))-30 scrnPos(3)-30 scrnPos(4)-VS.par.GUIPosition(2)]);
                    [VS.par.PTB_win] = Screen('OpenWindow',VS.par.screens(VS.par.currentPTBScreen),[],PTBScreenPosition);
                end
            catch
                disp('Please notice: Monitor test in PTB failed, use only for simulation mode!!!!');
                Screen('Preference','SkipSyncTests', 1);
                if VS.par.nScreens>1
                    [VS.par.PTB_win] = Screen('OpenWindow',VS.par.screens(VS.par.currentPTBScreen));
                else
                    PTBScreenPosition=round([VS.par.GUIPosition(1)+VS.par.GUIPosition(3)+30 scrnPos(4)-sum(VS.par.GUIPosition([2 4]))-30 scrnPos(3)-30 scrnPos(4)-VS.par.GUIPosition(2)]);
                    [VS.par.PTB_win] = Screen('OpenWindow',VS.par.screens(VS.par.currentPTBScreen),[],PTBScreenPosition);
                end
            end
        else
            Screen('Preference','SkipSyncTests', 1);
            PTBScreenPosition=round([scrnPos(3)-150 scrnPos(4)-410 scrnPos(3)-50 scrnPos(4)-310]);
            [VS.par.PTB_win] = Screen('OpenWindow',VS.par.screens(VS.par.currentPTBScreen),[],PTBScreenPosition);
        end
    end
%% %%%%%%%%%%%%%%%%%%%%%%%%%% Initialize VS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function initializeVisualStim()
        
        childrenOfInteractivePanel=get(VS.hand.GenealBox.hInteractiveGUIparent,'Children');
        delete(childrenOfInteractivePanel);
        
        if isfield(VS.par,'VSO')
            VS.par.VSO.cleanUp; %clean old Vstim object
        end
        eval(['VS.par.VSO=' VS.par.VSMethods{VS.par.currentVSO} '(VS.par.PTB_win,VS.hand.GenealBox.hInteractiveGUIparent);']);
        
        %get properties of visual stimulation object
        VSControlMethods=VS.par.VSO.getVSControlMethods;
        VS.par.VSOMethod=VSControlMethods.methodName;
        VS.par.VSOMethodDescription=VSControlMethods.methodDescription;
        VS.par.nVSOMethods=numel(VS.par.VSOMethod);
        
        %get methods of visual stimulation object
        props=VS.par.VSO.getProperties;
        VS.par.VSOProp=props.publicPropName;
        VS.par.VSOPropDescription=props.publicPropDescription;
        VS.par.nProps=numel(VS.par.VSOProp);
        
        updateVisualStimBoxGUI;

    end
%% %%%%%%%%%%%%%%%%%%%%%%%%%% Callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function changeSaveDirectory(hObj,event)
        [VS.par.saveDataFileName,VS.par.saveDataPath] = uiputfile('*.mat','Please choose a filename for saving VS metadata','VSData_XXX');
        set(VS.hand.GenealBox.hChangeDirEdit,'string',[VS.par.saveDataPath VS.par.saveDataFileName])
    end

    function CallbackRunVSPush(hObj,event)
        %prepare save file
        saveFile=get(VS.hand.GenealBox.hChangeDirEdit,'string');
        if strcmp(saveFile,'Default dir')
            currentTime=clock;
            timeString=[];
            for i=1:numel(currentTime)-1
                timeString=[timeString num2str(currentTime(i)) '_'];
            end
            sec_ms=num2str(currentTime(6));
            sec_ms(find(sec_ms=='.'))='_';
            timeString=[timeString sec_ms];
            saveFile=[VS.par.VSDirectory '\stats\' VS.par.VSObjNames{VS.par.currentVSO} '_' timeString];
        end
        
        %run visual stimulation        
        VS.par.VSO=VS.par.VSO.run;

        VSMetaData=VS.par.VSO.getProperties; %get properties
        
        if get(VS.hand.GenealBox.hSaveStats,'value')
            save (saveFile,'VSMetaData');
            set(VS.hand.GenealBox.hChangeDirEdit,'string','Default dir'); %to prevent saving again on the same file name after running
            disp('Stimulation parameters saved!');
        end
        
        %prepare figure
        if VS.par.VSO.lastExcecutedTrial~=0
            VS.hand.stimulationStatisticsFigure=figure('Position',[VS.par.GUIPosition([1 2]) 800 600]);
            set(VS.hand.stimulationStatisticsFigure,'PaperPositionMode','auto');
            
            VSMetaData=VS.par.VSO.getLastStimStatistics(VS.hand.stimulationStatisticsFigure); %if a figure handle is added as input object plots
            print(saveFile(1:end-4),'-djpeg','-r300');
        end
    end

    function CallbackEstimateStimDurationPush(hObj,event)
        estimatedTime=VS.par.VSO.estimateProtocolDuration;
        if isnan(estimatedTime)
            disp(['Estimation method non functional']);
            return;
        end
        currentTime=clock;
        outputTimeStr={['Current time: ' datestr(now)]...
            ['Estimated visual stimulation duration: ' num2str(estimatedTime/3600) ' hours'],...
            ['Estimated stimulation end: ' datestr(datenum(now)+datenum([0 0 0 0 0 estimatedTime]))]};
        disp(outputTimeStr(:));
        h=msgbox(outputTimeStr,'VS estimated duration','help','replace');
        set(h,'Position',[VS.par.GUIPosition([1 2]) 350 80]);
    end
    function CallbackInitializeTriggersPush(hObj,event)
        VS.par.VSO.initializeTTL;
        disp('Triggers initialized');
    end

    function CallbackInitializeScreenPush(hObj,event)
        initializeScreens;
        initializeVisualStim;
    end
    function CallbackTestVSPush(hObj,event)
    end
    function CallbackChangeMonitorConfiguration(hObj,event,currentPTBScreen,currentGUIScreen)
        if currentPTBScreen>0
            VS.par.currentPTBScreen=currentPTBScreen;
        elseif currentGUIScreen>0
            VS.par.currentGUIScreen=currentGUIScreen;
        end
        
        for i=1:VS.par.nScreens
            set(VS.hand.GenealBox.ScreenbuttonPTB(i),'value',0);
            set(VS.hand.GenealBox.ScreenbuttonGUI(i),'value',0);
        end
        set(VS.hand.GenealBox.ScreenbuttonPTB(VS.par.currentPTBScreen),'value',1);
        set(VS.hand.GenealBox.ScreenbuttonGUI(VS.par.currentGUIScreen),'value',1);
        
        disp('Press initialize to update the configuration');
    end
%% %%%%%%%%%%%%%%%%%%%%%%%%%% Properties callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function CallbackChangePropertyValue(hObj,event,propertyType,propertyNumber)
        %propertyType==1->logical,2->numeric,3->string
        switch propertyType
            case 1 %logical
                VS.par.VSO.(VS.par.VSOProp{propertyNumber})=get(hObj,'value');
            case 2 %numeric
                tmpValue=str2num(get(hObj,'string'));
                if isempty(tmpValue) %for the case that the value entered is a string, not a numeric
                    h=msgbox('The format of the property is not correct, please re-enter','Attention','error','replace');
                    set(h,'Position',[VS.par.GUIPosition([1 2]) 350 80]);
                    set(hObj,'string',num2str(VS.par.VSO.(VS.par.VSOProp{propertyNumber})));
                else
                    VS.par.VSO.(VS.par.VSOProp{propertyNumber})=str2num(get(hObj,'string'));
                end
            case 3 %string
                VS.par.VSO.(VS.par.VSOProp{propertyNumber})=get(hObj,'string');
        end
    end
%% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Menu callbacks %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function CallbackChangeVisualStim(hObj,event,selectedVSO)
        set(VS.hand.visualStimMenu.([VS.par.VSMethods{VS.par.currentVSO}]),'Checked','off');
        set(VS.hand.visualStimMenu.([VS.par.VSMethods{selectedVSO}]),'Checked','on'); %select one of the stims
        VS.par.currentVSO=selectedVSO;
        
        initializeVisualStim;
    end

    function CallbackFileMenuLoadParams(hObj,event)
        [FileName,PathName,FilterIndex] = uigetfile('*.mat','Choose VS properties file',VS.par.PCspecificFilesDir);
        props=load([PathName FileName]);
        if strcmp(props.VS_class,class(VS.par.VSO))
            for i=1:size(props.props,1)
                if isprop(VS.par.VSO,props.props{i,1})
                    VS.par.VSO.(props.props{i,1})=props.props{i,2}; %update object
                else
                    disp(['The loaded property : ' props.props{1,i} 'does not exist in the current visual stim Class']);
                end
            end
            updateVisualStimBoxGUI;
        else
            errordlg({'The class of the loaded configuration is different than the current class','please change to the appropriate class and reload configuration'},'VS toolbox error')
        end
    end

    function CallbackFileMenuSaveParams(hObj,event)
        VS_class=class(VS.par.VSO);
        defaultFileName=['VSConf' VS_class(3:end)];
        [FileName,PathName,FilterIndex] = uiputfile('*.mat','Choose VS properties file',[VS.par.PCspecificFilesDir filesep defaultFileName]);
        tmpProp=VS.par.VSO.getProperties;
        props(:,1)=tmpProp.publicPropName;
        props(:,2)=tmpProp.publicPropVal;
        save([PathName FileName],'props','VS_class');
    end
%% %%%%%%%%%%%%%%%%%%%%%%%%%% Create VS GUI %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function createVSGUI()
        % Construct main GUI screen
        
        %% Open a window and add some menus
        set(VS.hand.hMainFigure,'Position',VS.par.GUIPosition,'Name','Visual Stimulation Toolbox',...
            'NumberTitle','off', 'MenuBar','none', 'Toolbar','none', 'HandleVisibility','off','CloseRequestFcn',@closeMainGUIFigure);
        
        % define zoom options
        VS.hand.hMainFigureZoom = zoom(VS.hand.hMainFigure); %get zoom handle
        set(VS.hand.hMainFigureZoom,'Enable','on','Motion','Both','RightClickAction','PostContextMenu');
        
        % set file menus
        VS.hand.hFileMenu = uimenu(VS.hand.hMainFigure, 'Label', 'File' );
        VS.hand.hFileMenuLoadStimParams=uimenu(VS.hand.hFileMenu,'Label','Load stimulation parameter','Callback', @CallbackFileMenuLoadParams);
        VS.hand.hFileMenuSaveStimParams=uimenu(VS.hand.hFileMenu,'Label','Save stimulation parameter','Callback', @CallbackFileMenuSaveParams);
        
        % set visual stimulation menu
        VS.hand.hVisualStimMenu = uimenu(VS.hand.hMainFigure, 'Label', 'Visual stimulation' );
        for i=1:length(VS.par.VSMethods)
            VS.hand.visualStimMenu.([VS.par.VSMethods{i}])=uimenu(VS.hand.hVisualStimMenu,...
                'Label', VS.par.VSObjNames{i}, 'Checked','off', 'Callback', {@CallbackChangeVisualStim,i});
        end
        set(VS.hand.visualStimMenu.([VS.par.VSMethods{VS.par.currentVSO}]),'Checked','on'); %select one of the stims
        
        if VS.par.useNewUIX %use uix for GUI layouts

            % Arrange the main interface windows
            VS.hand.hMainWindow = uix.HBoxFlex('Parent',VS.hand.hMainFigure, 'Spacing',8);
            VS.hand.hGenealBox = uix.VBox('Parent',VS.hand.hMainWindow, 'Spacing',4, 'Padding',4);
            VS.hand.hPropertyBox = uix.VBox('Parent',VS.hand.hMainWindow, 'Spacing',4, 'Padding',4);
            set(VS.hand.hMainWindow, 'Widths',[-1 -1]);
            
            % Set left box
            VS.hand.GenealBox.hGeneralBoxPanel = uix.Panel('Parent',VS.hand.hGenealBox, 'Title','General');
            VS.hand.GenealBox.hMainVBox = uix.VBox('Parent',VS.hand.GenealBox.hGeneralBoxPanel, 'Spacing',4, 'Padding',4);
            
            VS.hand.GenealBox.hRunPush=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Run VS (press Esc continuously to abort)','Callback',@CallbackRunVSPush);
            %VS.hand.GenealBox.hRunTest=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Run & Test VS','Callback',@CallbackTestVSPush);
            VS.hand.GenealBox.hSaveStats=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','checkbox', 'String','Save stats to file','value',1);
            
            VS.hand.GenealBox.hChDirHBox=uix.HBox('Parent',VS.hand.GenealBox.hMainVBox, 'Spacing',4, 'Padding',4);
            VS.hand.GenealBox.hChangeDirPush=uicontrol('Parent', VS.hand.GenealBox.hChDirHBox, 'Style','push','String','Ch Dir','Callback',@changeSaveDirectory);
            VS.hand.GenealBox.hChangeDirEdit=uicontrol('Parent', VS.hand.GenealBox.hChDirHBox, 'Style','edit','string','Default dir');
            set(VS.hand.GenealBox.hChDirHBox, 'Widths',[-1 -7]);
            
            VS.hand.GenealBox.hEstimateStimDurationPush=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Estimate stim duration','Callback',@CallbackEstimateStimDurationPush);
            
            VS.hand.GenealBox.hInitializeTriggers=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Init triggers','Callback',@CallbackInitializeTriggersPush);
            
            VS.hand.GenealBox.hScreensPanel = uix.Panel('Parent',VS.hand.GenealBox.hMainVBox, 'Title','PTB Screens');
            VS.hand.GenealBox.hScreenVBox=uix.VBox('Parent',VS.hand.GenealBox.hScreensPanel, 'Spacing',4, 'Padding',4);
            VS.hand.GenealBox.hInitializeScreensPush=uicontrol('Parent', VS.hand.GenealBox.hScreenVBox, 'Style','push', 'String','initialize screen','Callback',@CallbackInitializeScreenPush);
            
            VS.hand.GenealBox.hPTBScreenPanel = uipanel('Parent', VS.hand.GenealBox.hScreenVBox,'Title','PTB monitor');
            VS.hand.GenealBox.hPTBScreenButtongroup = uix.HButtonBox('Parent', VS.hand.GenealBox.hPTBScreenPanel);
            for i=1:numel(VS.par.screens)
                VS.hand.GenealBox.ScreenbuttonPTB(i) = uicontrol('Parent',VS.hand.GenealBox.hPTBScreenButtongroup,...
                    'Style','radiobutton','String',num2str(VS.par.screens(i)),'Callback',{@CallbackChangeMonitorConfiguration,i,0});
            end
            set(VS.hand.GenealBox.ScreenbuttonPTB(VS.par.currentPTBScreen),'value',1);
            
            VS.hand.GenealBox.hGUIScreenPanel = uipanel('Parent', VS.hand.GenealBox.hScreenVBox,'Title','GUI monitor');
            VS.hand.GenealBox.hGUIScreenButtongroup = uix.HButtonBox('Parent', VS.hand.GenealBox.hGUIScreenPanel);
            for i=1:numel(VS.par.screens)
                VS.hand.GenealBox.ScreenbuttonGUI(i) = uicontrol('Parent',VS.hand.GenealBox.hGUIScreenButtongroup,...
                    'Style','radiobutton','String',num2str(VS.par.screens(i)),'Callback',{@CallbackChangeMonitorConfiguration,0,i});
            end
            set(VS.hand.GenealBox.ScreenbuttonGUI(VS.par.currentGUIScreen),'value',1);
            
            VS.hand.GenealBox.hInteractiveGUIparent = uipanel('Parent', VS.hand.GenealBox.hScreenVBox,'Title','VS interactive panel');
            
            set(VS.hand.GenealBox.hScreenVBox, 'Heights',[30 40 40 -1]);
            
            set(VS.hand.GenealBox.hMainVBox, 'Heights',[50 30 30 30 30 -1]);
            
        else %use uiextras and not uix
            
            % Arrange the main interface windows
            VS.hand.hMainWindow = uiextras.HBoxFlex('Parent',VS.hand.hMainFigure, 'Spacing',8);
            VS.hand.hGenealBox = uiextras.VBox('Parent',VS.hand.hMainWindow, 'Spacing',4, 'Padding',4);
            VS.hand.hPropertyBox = uiextras.VBox('Parent',VS.hand.hMainWindow, 'Spacing',4, 'Padding',4);
            set(VS.hand.hMainWindow, 'Sizes',[-1 -1]);
            
            % Set left box
            VS.hand.GenealBox.hGeneralBoxPanel = uiextras.Panel('Parent',VS.hand.hGenealBox, 'Title','General');
            VS.hand.GenealBox.hMainVBox = uiextras.VBox('Parent',VS.hand.GenealBox.hGeneralBoxPanel, 'Spacing',4, 'Padding',4);
            
            VS.hand.GenealBox.hRunPush=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Run VS (press Esc continuously to abort)','Callback',@CallbackRunVSPush);
            %VS.hand.GenealBox.hRunTest=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Run & Test VS','Callback',@CallbackTestVSPush);
            VS.hand.GenealBox.hSaveStats=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','checkbox', 'String','Save stats to file','value',1);
            
            VS.hand.GenealBox.hChDirHBox=uiextras.HBox('Parent',VS.hand.GenealBox.hMainVBox, 'Spacing',4, 'Padding',4);
            VS.hand.GenealBox.hChangeDirPush=uicontrol('Parent', VS.hand.GenealBox.hChDirHBox, 'Style','push','String','Ch Dir','Callback',@changeSaveDirectory);
            VS.hand.GenealBox.hChangeDirEdit=uicontrol('Parent', VS.hand.GenealBox.hChDirHBox, 'Style','edit','string','Default dir');
            set(VS.hand.GenealBox.hChDirHBox, 'Sizes',[-1 -7]);
            
            VS.hand.GenealBox.hEstimateStimDurationPush=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Estimate stim duration','Callback',@CallbackEstimateStimDurationPush);
            
            VS.hand.GenealBox.hInitializeTriggers=uicontrol('Parent', VS.hand.GenealBox.hMainVBox, 'Style','push', 'String','Init triggers','Callback',@CallbackInitializeTriggersPush);
            
            
            VS.hand.GenealBox.hScreensPanel = uiextras.Panel('Parent',VS.hand.GenealBox.hMainVBox, 'Title','PTB Screens');
            VS.hand.GenealBox.hScreenVBox=uiextras.VBox('Parent',VS.hand.GenealBox.hScreensPanel, 'Spacing',4, 'Padding',4);
            VS.hand.GenealBox.hInitializeScreensPush=uicontrol('Parent', VS.hand.GenealBox.hScreenVBox, 'Style','push', 'String','initialize screen','Callback',@CallbackInitializeScreenPush);
            
            VS.hand.GenealBox.hPTBScreenPanel = uipanel('Parent', VS.hand.GenealBox.hScreenVBox,'Title','PTB monitor');
            VS.hand.GenealBox.hPTBScreenButtongroup = uiextras.HButtonBox('Parent', VS.hand.GenealBox.hPTBScreenPanel);
            for i=1:numel(VS.par.screens)
                VS.hand.GenealBox.ScreenbuttonPTB(i) = uicontrol('Parent',VS.hand.GenealBox.hPTBScreenButtongroup,...
                    'Style','radiobutton','String',num2str(VS.par.screens(i)),'Callback',{@CallbackChangeMonitorConfiguration,i,0});
            end
            set(VS.hand.GenealBox.ScreenbuttonPTB(VS.par.currentPTBScreen),'value',1);
            
            VS.hand.GenealBox.hGUIScreenPanel = uipanel('Parent', VS.hand.GenealBox.hScreenVBox,'Title','GUI monitor');
            VS.hand.GenealBox.hGUIScreenButtongroup = uiextras.HButtonBox('Parent', VS.hand.GenealBox.hGUIScreenPanel);
            for i=1:numel(VS.par.screens)
                VS.hand.GenealBox.ScreenbuttonGUI(i) = uicontrol('Parent',VS.hand.GenealBox.hGUIScreenButtongroup,...
                    'Style','radiobutton','String',num2str(VS.par.screens(i)),'Callback',{@CallbackChangeMonitorConfiguration,0,i});
            end
            set(VS.hand.GenealBox.ScreenbuttonGUI(VS.par.currentGUIScreen),'value',1);
            
            VS.hand.GenealBox.hInteractiveGUIparent = uipanel('Parent', VS.hand.GenealBox.hScreenVBox,'Title','VS interactive panel');
            
            set(VS.hand.GenealBox.hScreenVBox, 'Sizes',[30 40 40 -1]);
            
            set(VS.hand.GenealBox.hMainVBox, 'Sizes',[50 30 30 30 30 -1]);
        end
        
    end %createGUI

    function updateVisualStimBoxGUI()
        childrenOfVisualStimBox=get(VS.hand.hPropertyBox,'Children');
        delete(childrenOfVisualStimBox);
        
        if VS.par.useNewUIX %use uix for GUI layouts
            
            VS.hand.PropertyBox.hPropertyBoxPanel = uix.Panel('Parent',VS.hand.hPropertyBox, 'Title','Visual stimlation object');
            VS.hand.PropertyBox.hPropertyVBox = uix.VBox('Parent', VS.hand.PropertyBox.hPropertyBoxPanel, 'Padding', 2, 'Spacing', 5);
            
            %set VS methods box
            VS.hand.PropertyBox.hMethodsGrid=uix.Grid('Parent', VS.hand.PropertyBox.hPropertyVBox, 'Padding', 5, 'Spacing', 5);
            
            VSOcopy=VS.par.VSO; %For some reason, it is not possible to send a object that is part of a structure as callback
            if VS.par.nVSOMethods>0
                for i=1:VS.par.nVSOMethods
                    if numel(VS.par.VSOMethodDescription)<i
                        VS.par.VSOMethodDescription{i}='';
                        disp('Some methods do not contain a description field');
                    end
                    VS.hand.PropertyBox.(['h' VS.par.VSOMethod{i} 'Push'])=uicontrol('Parent', VS.hand.PropertyBox.hMethodsGrid, 'Style','push',...
                        'String',VS.par.VSOMethod{i}(3:end),'TooltipString',VS.par.VSOMethodDescription{i},'HorizontalAlignment','Left');
                    eval(['set(VS.hand.PropertyBox.h' VS.par.VSOMethod{i} 'Push,''Callback'',@(src,event)' VS.par.VSOMethod{i} '(VSOcopy,src,event,VS.hand.GenealBox.hInteractiveGUIparent));']);
                end
                set(VS.hand.PropertyBox.hMethodsGrid,'Widths',-1,'Heights',25*ones(1,ceil(VS.par.nVSOMethods/2)));
            end
            
            %set VS methods box
            VS.hand.PropertyBox.hPropertyGrid=uix.Grid('Parent', VS.hand.PropertyBox.hPropertyVBox, 'Padding', 5, 'Spacing', 5);
            
            for i=1:VS.par.nProps
                VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Txt'])=uicontrol('Parent', VS.hand.PropertyBox.hPropertyGrid, 'Style','text',...
                    'String',VS.par.VSOProp{i},'TooltipString',VS.par.VSOPropDescription{i},'HorizontalAlignment','Left');
            end
            VS.hand.PropertyBox.remarksEdit=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                'Style','text','String',VS.par.VSO.remarks); %add the remarks text
            
            VS.par.VSOPropVal=cell(VS.par.nProps,1);
            for i=1:VS.par.nProps
                VS.par.VSOPropVal{i}=VS.par.VSO.(VS.par.VSOProp{i});
                if isa(VS.par.VSOPropVal{i},'logical')
                    VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Check'])=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                        'Style','checkbox','value',VS.par.VSOPropVal{i},'Callback',{@CallbackChangePropertyValue,1,i});
                elseif isa(VS.par.VSOPropVal{i},'numeric')
                    VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Edit'])=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                        'Style','edit','String',num2str(VS.par.VSOPropVal{i}),'Callback',{@CallbackChangePropertyValue,2,i});
                elseif ischar(VS.par.VSOPropVal{i})
                    VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Edit'])=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                        'Style','edit','String',VS.par.VSOPropVal{i},'Callback',{@CallbackChangePropertyValue,3,i});
                else
                    error('One of the fields in the visual stimulation object is not a numeric, logical or string');
                end
            end
            set(VS.hand.PropertyBox.hPropertyGrid,'Widths',[-2 -1],'Heights',[25*ones(1,VS.par.nProps) 50]);
            
            set(VS.hand.PropertyBox.hPropertyVBox,'Heights',[-ceil(VS.par.nVSOMethods/2) -VS.par.nProps]);
            
        else %use uiextras and not uix
            
            VS.hand.PropertyBox.hPropertyBoxPanel = uiextras.Panel('Parent',VS.hand.hPropertyBox, 'Title','Visual stimlation object');
            VS.hand.PropertyBox.hPropertyVBox = uiextras.VBox('Parent', VS.hand.PropertyBox.hPropertyBoxPanel, 'Padding', 2, 'Spacing', 5);
            
            %set VS methods box
            VS.hand.PropertyBox.hMethodsGrid=uiextras.Grid('Parent', VS.hand.PropertyBox.hPropertyVBox, 'Padding', 5, 'Spacing', 5);
            
            VSOcopy=VS.par.VSO; %For some reason, it is not possible to send a object that is part of a structure as callback
            
            if VS.par.nVSOMethods>0
                for i=1:VS.par.nVSOMethods
                    VS.hand.PropertyBox.(['h' VS.par.VSOMethod{i} 'Push'])=uicontrol('Parent', VS.hand.PropertyBox.hMethodsGrid, 'Style','push',...
                        'String',VS.par.VSOMethod{i}(3:end),'TooltipString',VS.par.VSOMethodDescription{i},'HorizontalAlignment','Left');
                    eval(['set(VS.hand.PropertyBox.h' VS.par.VSOMethod{i} 'Push,''Callback'',@(src,event)' VS.par.VSOMethod{i} '(VSOcopy,src,event,VS.hand.GenealBox.hInteractiveGUIparent));']);
                end
                set(VS.hand.PropertyBox.hMethodsGrid,'ColumnSizes',[-1 -1],'RowSizes',25*ones(1,ceil(VS.par.nVSOMethods/2)));
            end
            
            %set VS methods box
            VS.hand.PropertyBox.hPropertyGrid=uiextras.Grid('Parent', VS.hand.PropertyBox.hPropertyVBox, 'Padding', 5, 'Spacing', 5);
            
            for i=1:VS.par.nProps
                VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Txt'])=uicontrol('Parent', VS.hand.PropertyBox.hPropertyGrid, 'Style','text',...
                    'String',VS.par.VSOProp{i},'TooltipString',VS.par.VSOPropDescription{i},'HorizontalAlignment','Left');
            end
            VS.hand.PropertyBox.remarksEdit=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                'Style','text','String',VS.par.VSO.remarks); %add the remarks text
            
            VS.par.VSOPropVal=cell(VS.par.nProps,1);
            for i=1:VS.par.nProps
                VS.par.VSOPropVal{i}=VS.par.VSO.(VS.par.VSOProp{i});
                if isa(VS.par.VSOPropVal{i},'logical')
                    VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Check'])=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                        'Style','checkbox','value',VS.par.VSOPropVal{i},'Callback',{@CallbackChangePropertyValue,1,i});
                elseif isa(VS.par.VSOPropVal{i},'numeric')
                    VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Edit'])=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                        'Style','edit','String',num2str(VS.par.VSOPropVal{i}),'Callback',{@CallbackChangePropertyValue,2,i});
                elseif ischar(VS.par.VSOPropVal{i})
                    VS.hand.PropertyBox.(['h' VS.par.VSOProp{i} 'Edit'])=uicontrol('Parent',VS.hand.PropertyBox.hPropertyGrid, ...
                        'Style','edit','String',VS.par.VSOPropVal{i},'Callback',{@CallbackChangePropertyValue,3,i});
                else
                    error('One of the fields in the visual stimulation object is not a numeric, logical or string');
                end
            end
            set(VS.hand.PropertyBox.hPropertyGrid,'ColumnSizes',[-2 -1],'RowSizes',[25*ones(1,VS.par.nProps) 50]);
            
            set(VS.hand.PropertyBox.hPropertyVBox,'Sizes',[-ceil(VS.par.nVSOMethods/2) -VS.par.nProps]);
        end
    end

    function closeMainGUIFigure(hObj,event)
        Screen('CloseAll');
        clear VS;
        Priority(0);
        delete(hObj);
    end
end