function [ppOut matlab64Out win64Out b64Out] = getPP
persistent noPP;
if isempty(noPP)
    [~,b] = getMACaddress;
    noPP = ismember(b,{...
        '08002700F8DC',... % erik's dev machine has no pp :(
        '08002700D40D' ... % sue's vaio
        });
end

ppOut = ~noPP;

persistent matlab64;
persistent win64;
persistent b64;

if any(cellfun(@isempty,{matlab64 win64 b64}))
    
    matlab64 = false;
    win64 = false;
    b64 = nan;
    
    if IsWin
        % from http://stackoverflow.com/questions/7519321/determine-if-running-x64-or-x86-operating-system-in-matlab
        
        [a b] = dos('set PROCESSOR_ARCHITECTURE');
        if a==0
            c = textscan(b,'PROCESSOR_ARCHITECTURE=%s');
            if length(c)==1 && length(c{1})==1
                switch c{1}{1}
                    case 'x86'
                        matlab64 = false;
                        
                        [a b] = dos('set PROCESSOR_ARCHITEW6432');
                        if a==0
                            c = textscan(b,'PROCESSOR_ARCHITEW6432=%s');
                            if length(c)==1 && length(c{1})==1
                                
                                switch c{1}{1}
                                    case 'AMD64'
                                        win64 = true;
                                    otherwise
                                        a
                                        b
                                        c{:}
                                        error('unexpected')
                                end
                                
                            else
                                a
                                b
                                c{:}
                                error('couldn''t PROCESSOR_ARCHITEW6432')
                            end
                        else
                            a
                            b
                            win64 = false;
                        end
                        
                    case 'AMD64'
                        matlab64 = true;
                        win64 = true;
                    otherwise
                        a
                        b
                        c{:}
                        error('unexpected')
                end
            else
                a
                b
                c{:}
                error('couldn''t PROCESSOR_ARCHITECTURE')
            end
        else
            a
            b
            error('couldn''t PROCESSOR_ARCHITECTURE')
        end
        
        %temporary hack to get 2p station running
        if ppOut && win64
            if ~matlab64
                b64 = io32;
                status = io32(b64);
                if status~=0
                    status
                    'driver installation not successful'
                    'trying to install io32 for you'
                    
                    [success,message,messageid] = copyfile(fullfile(fileparts(which('io32')),'inpout32a.dll'),'C:\Windows\SysWOW64');
                    if success~=1
                        success
                        message
                        messageid
                        
                        'follow instructions at http://people.usd.edu/~schieber/psyc770/IO32on64.html'
                        'io32.mexw32 is already here'
                        which('io32')
                        error('couldn''t install io32 automatically')
                    else
                        b64 = io32;
                        status = io32(b64);
                        if status ~= 0
                            status
                            'driver installation not successful'
                            'follow instructions at http://people.usd.edu/~schieber/psyc770/IO32on64.html'
                            'io32.mexw32 is already here'
                            which('io32')
                            error('couldn''t install io32 automatically')
                        end
                    end
                end
            else
                error('ptb isn''t going to work on matlab64 on win')
            end
        end
    end
    
    if matlab64
        if ~strcmp(computer,'PCWIN64')
            error('mismatch')
        end
    else
        if ~strcmp(computer,'PCWIN')
            error('mismatch')
        end
    end
    
    %     matlab64
    %     win64
    %     b64
end

matlab64Out = matlab64;
win64Out = win64;
b64Out = b64;