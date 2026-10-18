function [values,names,fd]=motion_regressors(rp,radiusMm)
%MOTION_REGRESSORS SPM 六参数、后向差分及二者平方，共 24 列。
% 平移毫米/旋转弧度；首帧差分=0、FD=0，不是已证明首帧无头动。
if size(rp,2)~=6 || size(rp,1)<2 || any(~isfinite(rp),'all') || ...
        ~(isscalar(radiusMm)&&isfinite(radiusMm)&&radiusMm>0)
    error('psy:Motion','Need finite N x 6 SPM motion and positive radius');
end
d=[zeros(1,6);diff(rp,1,1)];
values=[rp,d,rp.^2,d.^2];
base={'trans_x','trans_y','trans_z','rot_x','rot_y','rot_z'};
names=[base,strcat(base,'_derivative1'),strcat(base,'_power2'),strcat(base,'_derivative1_power2')];
fd=sum(abs(d(:,1:3)),2)+radiusMm*sum(abs(d(:,4:6)),2);
end
