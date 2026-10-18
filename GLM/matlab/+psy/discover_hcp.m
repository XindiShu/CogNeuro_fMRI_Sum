function runs = discover_hcp(cfg)
%DISCOVER_HCP Find raw HCP runs in merged or per-package extraction trees.
% Official derivatives cannot match the /unprocessed/3T/ path requirement.
files = dir(fullfile(cfg.dataRoot,'**','*.nii.gz'));
files = [files; dir(fullfile(cfg.dataRoot,'**','*.nii'))];
runs = struct('subject',{},'name',{},'bold',{},'t1',{},'sbref',{},'ev',{});
for i = 1:numel(files)
    file = fullfile(files(i).folder,files(i).name);
    normalized = strrep(file,'\','/');
    tok = regexp(normalized,'/([0-9]{6})/unprocessed/3T/([^/]+)/\1_3T_\2\.nii(?:\.gz)?$','tokens','once');
    if isempty(tok) || ~ismember(tok{2},cfg.runNames), continue; end
    if ~isempty(cfg.subjects) && ~ismember(tok{1},cfg.subjects), continue; end
    if any(strcmp({runs.subject},tok{1}) & strcmp({runs.name},tok{2}))
        error('psy:DuplicateRun','Duplicate raw input for %s %s. Keep one input tree.',tok{:});
    end
    t1s = {};
    for j = 1:numel(files)
        candidate = strrep(fullfile(files(j).folder,files(j).name),'\','/');
        pattern = ['/' tok{1} '/unprocessed/3T/T1w_MPR[0-9]+/' tok{1} '_3T_T1w_MPR[0-9]+\.nii(?:\.gz)?$'];
        if ~isempty(regexp(candidate,pattern,'once')), t1s{end+1}=candidate; end %#ok<AGROW>
    end
    if numel(t1s) ~= 1
        error('psy:T1Selection','%s has %d primary T1 candidates; resolve explicitly before processing.',tok{1},numel(t1s));
    end
    sbref = fullfile(files(i).folder,[tok{1} '_3T_' tok{2} '_SBRef.nii.gz']);
    if ~isfile(sbref), sbref = erase(sbref,'.gz'); end
    runs(end+1) = struct('subject',tok{1},'name',tok{2},'bold',file, ...
        't1',t1s{1},'sbref',sbref,'ev',fullfile(files(i).folder,'LINKED_DATA','EPRIME','EVs')); %#ok<AGROW>
end
if isempty(runs), error('psy:NoRuns','No raw HCP runs found in %s',cfg.dataRoot); end
% HCP 专属条件在适配器声明；通用检查函数不根据名称猜测任务。
for k=1:numel(runs)
    runs(k).session=''; runs(k).eventFormat='none'; runs(k).conditions={};
    if startsWith(runs(k).name,'tfMRI_LANGUAGE')
        runs(k).eventFormat='hcp_ev'; runs(k).conditions={'story','math'};
    end
end
[~,order]=sort(strcat({runs.subject},{runs.name})); runs=runs(order);
end
