function results=topup_batch(specs,cfg)
%TOPUP_BATCH 任意被试/会话/run 的反向 PE 场图批量估计。
% 每个 spec 的路径和采集参数独立填写；一个失败不会覆盖其他 run 的输出。
results=struct('subject',{},'session',{},'run',{},'status',{},'message',{});
for k=1:numel(specs)
    s=specs(k);
    row=struct('subject',s.subject,'session',s.session,'run',s.run,'status','','message','');
    try
        r=psy.topup_run(s,cfg); row.status=r.status;
    catch err
        row.status='failed'; row.message=getReport(err,'basic','hyperlinks','off');
    end
    results(end+1)=row; %#ok<AGROW>
end
end
