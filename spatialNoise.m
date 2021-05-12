numImages=100;
imgSize=[1360,2304];
squareSize=100;
saveFolder='C:\Users\sther\Pictures\noiseStim';

numSquares=floor(imgSize/squareSize);
sqCount=numSquares(1)*numSquares(2);
squarePosX=1:squareSize:(squareSize*numSquares(2));
squarePosY=1:squareSize:(squareSize*numSquares(1));
xSq=repmat(squarePosX,[numSquares(1),1]);
ySq=repmat(squarePosY,[numSquares(2),1])';
sqLoc=[ySq(:) xSq(:)];

for i=1:numImages
    whiteSq=randperm(sqCount);
    whiteSq=sqLoc(whiteSq(1:round(sqCount/2)),:);
    
    img=uint8(zeros(imgSize));
    for x=1:size(whiteSq,1)
        img(whiteSq(x,1):(whiteSq(x,1)+squareSize-1),whiteSq(x,2):(whiteSq(x,2)+squareSize-1))=255;
    end
    
    filename=[saveFolder filesep 'noise_' num2str(i) '_' num2str(squareSize) '.png'];
    imwrite(img,filename)
    
end