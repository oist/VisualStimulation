minPort=2;
maxPort=5;
ports=minPort:maxPort;
for i=1:1000
    for j=ports
        pp(uint8(j),true,false,uint8(0),uint64(32784));
        WaitSecs(0.2);
    end
    WaitSecs(1);
    for j=ports
        pp(uint8(j),false,false,uint8(0),uint64(32784));
        WaitSecs(0.2);
    end
    WaitSecs(1);
end