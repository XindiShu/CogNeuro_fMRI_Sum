function flags=segment_output_flags(kind,choice)
%SEGMENT_OUTPUT_FLAGS 用原生 SPM 菜单的位序；不是自行实现分割算法。
switch kind
    case 'bias', names={'none','field','corrected','both'};
    case 'native', names={'none','native','dartel','native_dartel'};
    case 'warped', names={'none','unmodulated','modulated','both'};
    otherwise, error('psy:SegmentOutput','未知输出种类');
end
index=find(strcmp(choice,names),1);
if isempty(index), error('psy:SegmentOutput','%s 输出可选: %s',kind,strjoin(names,', ')); end
values={[0 0],[1 0],[0 1],[1 1]};
flags=values{index};
end
