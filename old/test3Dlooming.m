Vx=0;
Vy=0;
Vz=-1;

V=[Vx Vy Vz];

Rball=1;
X0=[1 0 20];

f=600;
xyShift=[960 600]';

t=1:0.05:20;
nPoints=numel(t);

%a=20;
%Xr1=[a a 2*a;-a a 2*a;-a -a 2*a;a -a 2*a;a a 2*a;-a a 2*a;-a -a 2*a;a -a 2*a;-a 0.1 2*a]';
%Xr2=[-a a 2*a;-a -a 2*a;a -a 2*a;a a 2*a;a a 0.1;-a a 0.1;-a -a 0.1;a -a 0.1;a 0.1 2*a]';
%nPointsRoom=size(Xr1,2);

%Xw=[1;2;3]; %position in world coordinate
Xw=X0'*ones(1,nPoints)+V'*t; %position in world coordinate

rw=sqrt(Xw(1,:).^2+Xw(2,:).^2+Xw(3,:).^2);
RballScreen=f*Rball./rw;

pMov=f.*[Xw(1,:)./Xw(3,:);Xw(2,:)./Xw(3,:)]+xyShift*ones(1,nPoints);
%pRoom1=f.*[Xr1(1,:)./Xr1(3,:);Xr1(2,:)./Xr1(3,:)];
%pRoom2=f.*[Xr2(1,:)./Xr2(3,:);Xr2(2,:)./Xr2(3,:)];

[Xsp,Ysp,Zsp] = sphere(6);

ang=0:0.1:(2*pi+0.1);
Xc=cos(ang);
Yc=sin(ang);

hF=figure('Position',[100 100 1500 600]);
h1=subplot(1,2,1);
%line([Xr1(1,:);Xr2(1,:)],[Xr1(2,:);Xr2(2,:)],[Xr1(3,:);Xr2(3,:)],'color','k');hold on;
plot3(0,0,0,'or','LineWidth',10);
xlabel('X');ylabel('Y');zlabel('Z');
axis equal off;
h1.XLimMode='manual';
h1.YLimMode='manual';
h1.ZLimMode='manual';
view(200,45);

h2=subplot(1,2,2);
%line([pRoom1(1,:);pRoom2(1,:)],[pRoom1(2,:);pRoom2(2,:)],'color','k')
h2.XLim=[0 2*xyShift(1)];h2.YLim=[0 2*xyShift(2)];
hold on;axis equal off;
h2.XLimMode='manual';
h2.YLimMode='manual';

s=[];c=[];
for i=1:nPoints
    
    delete(s);
    s=surf(h1,Xw(1,i)+Xsp,Xw(2,i)+Ysp,Xw(3,i)+Zsp);
    
    delete(c);
    c=plot(h2,Xc.*RballScreen(i)+pMov(1,i),Yc.*RballScreen(i)+pMov(2,i));hold on;
    
    drawnow;
end