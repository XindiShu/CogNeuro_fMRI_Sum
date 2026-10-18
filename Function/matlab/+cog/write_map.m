function write_map(file,values,space,description)
%WRITE_MAP 掩膜外NaN、float32，源affine保持；仅写不存在的新文件。
if isfile(file),error('cog:Exists','Output already exists');end
if numel(values)~=numel(space.indices),error('cog:Map','Value/mask mismatch');end
d=nan(space.reference.dim);d(space.indices)=values;
v=space.reference;v.fname=file;v.dt=[16 0];v.pinfo=[1;0;0];v.n=[1 1];v.descrip=description;spm_write_vol(v,d);
end
