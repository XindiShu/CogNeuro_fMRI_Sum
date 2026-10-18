function report=manual_topup_handoff(outputRoot,fslConfig)
%MANUAL_TOPUP_HANDOFF 实际调用 WSL/FSL，验证两个合成被试的 TOPUP→BOLD 交接。
% 用法：addpath('matlab','config','tests'); report=manual_topup_handoff(新输出目录);
% 可选第二参使用 topup_config 返回的结构，便于替换 WSL/FSL 安装路径。
% 所有影像均在新目录生成，不读取 HCP，不覆盖已有数据，不运行整套空间预处理。
% 这里的短迭代配置仅用于接口测试，不是科研数据推荐的 TOPUP 参数。
if nargin<1,outputRoot=fullfile(tempdir,['psy_topup_handoff_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);end
if nargin<2,fslConfig=topup_config;end
if isfolder(outputRoot),error('psy:TestExisting','测试输出目录必须是新目录');end
mkdir(outputRoot);
cnf=fullfile(outputRoot,'phantom_topup.cnf');
lines={'--warpres=20','--subsamp=1','--fwhm=0','--miter=2', ...
    '--lambda=0.005','--ssqlambda=0','--regmod=bending_energy','--estmov=0', ...
    '--minmet=0','--splineorder=3','--numprec=double','--interp=spline','--scale=1'};
fid=fopen(cnf,'w');assert(fid>=0,'Cannot create test cnf');
fprintf(fid,'%s\n',lines{:});fclose(fid);

[x,y,z]=ndgrid(linspace(-1,1,24));
image=single(1000*exp(-3*(x.^2+1.3*y.^2+1.7*z.^2))+ ...
    250*exp(-18*((x-.3).^2+(y+.2).^2+(z-.1).^2)));
subjects={'phantomA','phantomB'};inputFiles={};specs=struct([]);
for k=1:numel(subjects)
    input=fullfile(outputRoot,'inputs',subjects{k});mkdir(input);
    s=struct('subject',subjects{k},'session','baseline','run','task', ...
        'negative',fullfile(input,'se_negative.nii'), ...
        'positive',fullfile(input,'se_positive.nii'), ...
        'negativeDirection','j-','positiveDirection','j', ...
        'negativeReadoutSeconds',0.05,'positiveReadoutSeconds',0.05);
    writeImage(image,s.negative);writeImage(image,s.positive);
    writeImage(image,fullfile(input,'sbref.nii'));
    writeImage(cat(4,image,image*1.01,image*0.99),fullfile(input,'bold.nii'));
    if k==1,specs=s;else,specs(k)=s;end
    inputFiles=[inputFiles,{s.negative,s.positive,fullfile(input,'sbref.nii'), ...
        fullfile(input,'bold.nii')}]; %#ok<AGROW>
end
hashesBefore=cellfun(@psy.file_sha256,inputFiles,'UniformOutput',false);
tc=fslConfig;tc.outputRoot=fullfile(outputRoot,'topup');
tc.fslConfig=linuxPath(cnf);tc.threads=1;tc.execute=true;tc.applyToBold=false;
topupRows=psy.topup_batch(specs,tc);
save(fullfile(outputRoot,'topup_results.mat'),'topupRows');
assert(all(strcmp({topupRows.status},'topup_estimated')), ...
    'TOPUP failed; inspect topup_results.mat and each fsl.log');

boldSpecs=struct([]);
for k=1:numel(specs)
    s=specs(k);r=struct('subject',s.subject,'session',s.session,'name',s.run);
    out=psy.run_output_dir(tc.outputRoot,r);
    marker=jsondecode(fileread(fullfile(out,'TOPUP_COMPLETE.json')));
    reference=fullfile(out,'se_unwarped_mean.nii.gz');
    assert(isfile(reference)&&any(strcmp(marker.outputs,reference)),'Mean missing from completion record');
    info=niftiinfo(reference);assert(isequal(info.ImageSize,[24 24 24])&&strcmp(info.Datatype,'single'));
    input=fileparts(s.negative);
    b=struct('subject',s.subject,'session',s.session,'run',s.run,'topupDir',out, ...
        'sbref',fullfile(input,'sbref.nii'),'bold',fullfile(input,'bold.nii'), ...
        'boldDirection','j-','boldReadoutSeconds',0.05);
    if k==1,boldSpecs=b;else,boldSpecs(k)=b;end
end
bc=bold_unwarp_config;bc.outputRoot=fullfile(outputRoot,'bold');
bc.wslDistro=tc.wslDistro;bc.fslRoot=tc.fslRoot;bc.execute=true;
boldRows=psy.bold_unwarp_batch(boldSpecs,bc);
save(fullfile(outputRoot,'bold_results.mat'),'boldRows');
assert(all(strcmp({boldRows.status},'bold_susceptibility_unwarped_pre_motion')), ...
    'BOLD correction failed; inspect bold_results.mat and each fsl.log');
hashesAfter=cellfun(@psy.file_sha256,inputFiles,'UniformOutput',false);
assert(isequal(hashesBefore,hashesAfter),'A test input was modified');
report=struct('status','passed_two_synthetic_subjects','topup',topupRows,'bold',boldRows, ...
    'inputFilesUnchanged',true,'outputRoot',outputRoot, ...
    'scope','Real FSL calls with synthetic images; not a full HCP or downstream SPM validation');
save(fullfile(outputRoot,'handoff_report.mat'),'report');
end

function p=linuxPath(w)
w=char(java.io.File(w).getCanonicalPath());
assert(numel(w)>2&&w(2)==':','Test requires a local Windows drive path');
p=['/mnt/' lower(w(1)) strrep(w(3:end),'\','/')];
end

function writeImage(data,path)
% 合成数据明确使用合法的 1 mm sform；MATLAB 默认头未必设置空间代码。
niftiwrite(data,path);
fid=fopen(path,'r+','ieee-le');assert(fid>=0,'Cannot set fixture geometry');
closeFile=onCleanup(@()fclose(fid));
fseek(fid,254,'bof');fwrite(fid,int16(1),'int16');
fseek(fid,280,'bof');fwrite(fid,single([1 0 0 0]),'single');
fseek(fid,296,'bof');fwrite(fid,single([0 1 0 0]),'single');
fseek(fid,312,'bof');fwrite(fid,single([0 0 1 0]),'single');
clear closeFile
end
