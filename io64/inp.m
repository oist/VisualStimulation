function [byte] = inp(address)

persistent cogent;

byte = io64(cogent.io.ioObj,address);
