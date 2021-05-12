imgSize=[3000 3000];
freq=[12,25,50,100,250]; %pixels
angleIncrement=30; %degrees
saveFolder='C:\Users\sther\Pictures\gratings';


for f=1:numel(freq)
    currFreq=freq(f);
    whiteIndices=1:currFreq/2:imgSize(2);
    whiteIndices=whiteIndices(1:2:end);
    whiteOn=whiteIndices(1:2:end);
    whiteOff=whiteIndices(2:2:end);
    
    if length(whiteOn)>length(whiteOff)
        whiteOff(end+1)=imgSize(2);
    end
    
    img=uint8(zeros(imgSize));
    for bar=1:length(whiteOn)
        img(:,whiteOn(bar):whiteOff(bar))=255;
    end
    
    for angle=angleIncrement:angleIncrement:180
        
        imgR = imrotate(img,angle,'crop') ;
        %imshow(imgR(1000:2000,1000:2000))
        filename=[saveFolder filesep 'grating_' num2str(angle) '_' num2str(currFreq) '.png'];
        imwrite(imgR(1000:2000,1000:2000),filename)
    end
end