function outp(address,byte)

persistent cogent;

%test for correct number of input arguments
if(nargin ~= 2)
    disp('usage: outp(address,data)');
end

io64(cogent.io.ioObj,address,byte);
