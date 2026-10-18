function flags = deformation_field_flags(choice)
%DEFORMATION_FIELD_FLAGS 将用户选择转换为 SPM Segment 的 warp.write。
% SPM12: None=[0 0], Inverse=[1 0], Forward=[0 1], Inverse+Forward=[1 1]。
% 第一位控制 iy_ 逆向场；第二位控制 y_ 前向场。
switch choice
    case 'none', flags=[0 0];
    case 'inverse', flags=[1 0];
    case 'forward', flags=[0 1];
    case 'inverse_forward', flags=[1 1];
    otherwise
        error('psy:DeformationFields', ...
            'segment.deformationFields 应为 none/inverse/forward/inverse_forward');
end
end
