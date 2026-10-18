function output = stage_image(source, directory)
%STAGE_IMAGE Work on copies only; never change downloaded image headers.
if ~isfolder(directory), mkdir(directory); end
[~,name,ext]=fileparts(source);
if strcmp(ext,'.gz')
    output=fullfile(directory,name);
else
    output=fullfile(directory,[name ext]);
end
if isfile(output)
    error('psy:ExistingStage','Unexpected existing staged image: %s',output);
end
if strcmp(ext,'.gz'), gunzip(source,directory); else, copyfile(source,output); end
end
