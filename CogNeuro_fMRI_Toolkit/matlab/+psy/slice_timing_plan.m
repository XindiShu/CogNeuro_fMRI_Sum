function plan = slice_timing_plan(run,info,cfg)
%SLICE_TIMING_PLAN 仅生成 SPM Slice Timing 参数，不自行重采样 BOLD。
% cfg.sliceTiming.mode 是用户修改的入口；SPM 接受采集顺序编号或逐层毫秒时间。
% 对多带扫描，必须使用采集记录中的逐层时间；TR 和层数无法推出同时采集的层组。
n=double(info.size(3)); tr=double(info.trSeconds);
st=cfg.sliceTiming;
mode=char(string(st.mode));
if strcmp(mode,'off') && isfield(st,'enabled') && st.enabled
    mode='explicit_seconds'; % 兼容早期 cfg.sliceTiming.enabled + seconds 配置。
end
t=double(st.microtimeResolution);
if ~isscalar(t) || ~isfinite(t) || t~=floor(t) || t<1
    error('psy:SliceTimingConfig','microtimeResolution 必须为正整数');
end
plan=struct('enabled',false,'mode',mode,'nslices',n,'trSeconds',tr, ...
    'taSeconds',0,'sliceSeconds',[],'referenceSeconds',[], ...
    'microtimeResolution',t,'microtimeOnset',max(1,round(t/2)));
if strcmp(mode,'off'), return; end
switch mode
    case 'metadata'
        if ~isfield(run,'metadata') || isempty(run.metadata) || ~isfile(run.metadata)
            error('psy:SliceTimingMetadata','metadata 模式要求逐 run 的采集 JSON');
        end
        m=jsondecode(fileread(run.metadata));
        if ~isfield(m,'SliceTiming')
            error('psy:SliceTimingMetadata','采集 JSON 缺少 SliceTiming 秒数组');
        end
        times=double(m.SliceTiming(:)');
    case 'explicit_seconds'
        times=double(st.seconds(:)');
    case {'ascending','descending','interleaved_midtop', ...
            'interleaved_bottomup','interleaved_topdown'}
        % SPM spm_cfg_st.m 帮助中的五类顺序。这里只生成 SPM 所需时间向量。
        % 标准单带默认 TA=TR-TR/n；协议提供实测 TA 时只改集中配置。
        % 多带同时采集多个层，不能用这个单带 TA 模型，请用 metadata。
        ta=tr-tr/n;
        if isfield(st,'acquisitionTimeSeconds') && ~isempty(st.acquisitionTimeSeconds)
            ta=double(st.acquisitionTimeSeconds);
            if ~isscalar(ta) || ~isfinite(ta) || ta<=0 || ta>=tr
                error('psy:SliceTimingTA','标准单带顺序的 TA 必须在 (0,TR) 秒内');
            end
        end
        switch mode
            case 'ascending', order=1:n;
            case 'descending', order=n:-1:1;
            case 'interleaved_bottomup', order=[1:2:n 2:2:n];
            case 'interleaved_topdown', order=[n:-2:1 n-1:-2:1];
            case 'interleaved_midtop'
                k=1:n;
                order=round((n-k)/2 + (mod(n-k,2)*(n-1)/2))+1;
        end
        if ~isequal(sort(order),1:n)
            error('psy:SliceTimingOrder','生成的 SPM 顺序不是 1..n 的排列');
        end
        times=zeros(1,n);
        times(order)=(0:n-1)*(ta/(n-1));
        plan.taSeconds=ta; % SPM 使用逐层毫秒向量运行，TA 在此记录实测/默认来源。
    otherwise
        error('psy:SliceTimingMode','不支持的 STC 模式: %s',mode);
end
if numel(times)~=n || any(~isfinite(times)) || any(times<0) || any(times>=tr)
    error('psy:SliceTimingValues','逐层秒数须与 z 层数相同，且各项在 [0,TR)');
end
reference=char(string(st.reference));
switch reference
    case 'middle_time'
        [~,ix]=min(abs(times-tr/2)); ref=times(ix);
    case 'first', ref=min(times);
    case 'last', ref=max(times);
    case 'seconds', ref=double(st.referenceSeconds);
    otherwise, error('psy:SliceTimingReference','reference 应为 middle_time/first/last/seconds');
end
if ~isscalar(ref) || ~isfinite(ref) || ref<0 || ref>=tr
    error('psy:SliceTimingReference','STC 参考时间须在 [0,TR)，单位秒');
end
plan.enabled=true;
plan.sliceSeconds=times;
plan.referenceSeconds=ref;
% SPM 的 fmri_t0 属于后续一级模型，而非 STC batch。这里仅保存建议值。
% 第一微时间箱对应当前 TR 的起始，因此 ref/TR 映射到 1..fmri_t。
plan.microtimeOnset=min(t,max(1,round(ref/tr*t)+1));
end
