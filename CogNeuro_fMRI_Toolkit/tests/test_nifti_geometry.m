function tests=test_nifti_geometry
tests=functiontests(localfunctions);
end
function testUnsupportedFslIntentFallback(t)
folder=tempname;mkdir(folder);clean=onCleanup(@()rmdir(folder,'s'));
p=fullfile(folder,'field.nii');niftiwrite(ones(4,5,6,'single'),p);
% 测试头必须有合法 sform；niftiwrite 的默认头不保证填写 sform。
fid=fopen(p,'r+','ieee-le');
fseek(fid,68,'bof');fwrite(fid,int16(2018),'int16');
fseek(fid,254,'bof');fwrite(fid,int16(1),'int16');
fseek(fid,280,'bof');fwrite(fid,single([1 0 0 0]),'single');
fseek(fid,296,'bof');fwrite(fid,single([0 1 0 0]),'single');
fseek(fid,312,'bof');fwrite(fid,single([0 0 1 0]),'single');
fclose(fid);
h=psy.nifti_geometry(p);
verifyEqual(t,h.ImageSize,[4 5 6]);
verifyEqual(t,size(h.Transform.T),[4 4]);
clear clean
end
