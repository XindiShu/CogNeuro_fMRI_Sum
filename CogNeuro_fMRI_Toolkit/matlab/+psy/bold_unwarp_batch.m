function rows=bold_unwarp_batch(specs,cfg)
%BOLD_UNWARP_BATCH 多被试/session/run 调度，逐 run 独立输出与记录错误。
rows=struct('subject',{},'session',{},'run',{},'status',{},'message',{});
for k=1:numel(specs)
    s=specs(k);
    row=struct('subject',s.subject,'session',s.session,'run',s.run,'status','','message','');
    try
        result=psy.bold_unwarp_run(s,cfg);row.status=result.status;
    catch err
        row.status='failed';row.message=getReport(err,'basic','hyperlinks','off');
    end
    rows(end+1)=row; %#ok<AGROW>
end
end
