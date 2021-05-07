% function oneOverF_3D

% produces 1/f^beta Films, which are circular, i.e. they can be looped
% without a jump.

% random matrix (phases and power)
% fft to freq space (phases and power)
% scale the power and phases in the Fourier Space with the power law
% back fft

beta = 4; % power spectrum = power law with beta/2
n = 512;  % nxn pixel
t = 256;  % number of frames
nc = 1; %gray scale levels (1 for binary)

% make 1/f filter
BB = zeros(n,n,t,'single');
for c1=1:n/2,
    for c2 = 1:n/2
        BB(c1,c2,1:t/2) = ((sqrt(c1.^2+c2.^2)-32 ).^2);
    end
end

BB(1:n/2,n/2+1:end,1:t/2) = flipdim(BB(1:n/2, 1:n/2,1:t/2),2);
BB(n/2+1:end, :,1:t/2) = flipdim(BB(1:n/2, :,1:t/2),1);
BB(:,:,t/2+1:end) = flipdim(BB(:,:,1:t/2),3);

%BB = fftshift(BB);

BB = BB.* exp(1i*2*pi*rand(n,n,t));  % random phases
%BB = BB.* permute(repmat(exp(1i*2*pi*rand(n,t)),[1 1 n]),[1 3 2]);  % random phases

BBI = ifftn(BB,'symmetric');

%%
writeVideo=0;
if writeVideo
    writerObj = VideoWriter('OneOverFBinaryFourierPower.avi');
    open(writerObj);
end

f=figure('color','white');colormap(jet(64));h=axes;
set(h,'nextplot','replacechildren');
set(f,'Renderer','zbuffer');
axis image;axis off;

% plot

%colormap(gray(nc));

% BB = BB(2:end,2:end,:);
mi = min(min(min(BBI)));
ma = max(max(max(BBI)));
% sum(sum(sum(imag(BB))))
BBI = ((BBI)-mi)/(ma-mi);
% tic; tx = zeros(t,1);
tic;
for kk=1 %number of repeats
    for k=1:t
        %     t1=double(toc);
        %image((nc+2)*BB(:,:,k)),  pause(0.001)
        imagesc(squeeze(BBI(:,:,k)),[0 1]),  pause(0.001)
        %     t2=double(toc); tx(k) =t2-t1;
        if writeVideo
            frame = getframe;
            writeVideo(writerObj,frame);
        end
    end
end
close(writerObj);

toc; disp(toc)