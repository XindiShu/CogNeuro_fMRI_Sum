function contrasts=glm_model_contrasts(columns,cfg,x,minDF,nRuns)
%GLM_MODEL_CONTRASTS 从语义标签生成T/F权重；跨run始终平均相同效应。
if nargin<5,nRuns=1;end
contrasts=struct('name',{},'stat',{},'weights',{},'sourceContrast',{},'kind',{},'bin',{});
isFir=isfield(cfg,'hrf')&&strcmp(cfg.hrf.type,'fir');
if ~isFir
    w=psy.glm_contrasts(columns,cfg.conditions,cfg.contrastWeights,x,minDF,nRuns);
    for k=1:size(w,1),add(cfg.contrastNames{k},'T',w(k,:),k,'base',0);end
else
    f=cfg.hrf.fir;bins=f.summaryBins;if isempty(bins),bins=1:f.nBins;end
    for k=1:numel(cfg.contrastNames)
        allBins=zeros(f.nBins,size(x,2));
        for bin=1:f.nBins
            allBins(bin,:)=psy.glm_contrasts(columns,cfg.conditions,cfg.contrastWeights(k,:),x,minDF,nRuns,bin);
            add(sprintf('%s_bin_%03d',cfg.contrastNames{k},bin),'T',allBins(bin,:),k,'fir_bin',bin);
        end
        add([cfg.contrastNames{k} '_window_mean'],'T',mean(allBins(bins,:),1),k,'fir_mean',0);
        if f.includeOmnibus,add([cfg.contrastNames{k} '_all_bins'],'F',allBins,k,'fir_omnibus',0);end
    end
end
if isfield(cfg,'pmod')&&cfg.pmod.enabled
    for k=1:numel(cfg.pmod.modulators)
        m=cfg.pmod.modulators(k);
        for power=1:m.poly
            label=sprintf('%sx%s^%d',m.condition,m.name,power);
            w=psy.glm_contrasts(columns,{label},1,x,minDF,nRuns);
            add(sprintf('pmod_%s_%s_power_%d',m.condition,m.name,power),'T',w,0,'pmod',0);
        end
    end
end
if numel(unique(string({contrasts.name})))~=numel(contrasts)
    error('psy:GLMContrast','Generated contrast names collide; rename configured contrasts/modulators');
end

    function add(name,stat,weights,source,kind,bin)
        contrasts(end+1)=struct('name',char(name),'stat',stat,'weights',weights, ...
            'sourceContrast',source,'kind',kind,'bin',bin);
    end
end
