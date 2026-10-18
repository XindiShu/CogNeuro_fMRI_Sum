function result=state_metrics(labels,segments,trSeconds,nStates)
%STATE_METRICS 硬路径，0为未分配；不跨段/未分配帧计算转移或连接停留。
labels=double(labels(:));n=numel(labels);
if isempty(labels)||any(~isfinite(labels)|labels<0|labels>nStates|labels~=fix(labels))||~isscalar(nStates)||nStates<2||nStates~=fix(nStates)||~isscalar(trSeconds)||~isfinite(trSeconds)||trSeconds<=0||size(segments,2)~=2||any(~isfinite(segments),'all')||any(segments~=fix(segments),'all')||any(segments(:,1)<1|segments(:,2)>n|segments(:,1)>segments(:,2))||any(segments(2:end,1)<=segments(1:end-1,2)),error('cog:StateMetrics','Explicit hard labels, disjoint ordered segments, K and seconds TR required');end
coverage=false(n,1);for s=1:size(segments,1),coverage(segments(s,1):segments(s,2))=true;end;if any(~coverage),error('cog:StateMetrics','Segments must cover every supplied row');end
counts=accumarray(labels(labels>0),1,[nStates 1]);transitions=zeros(nStates);episodes=table;eligiblePairs=0;
for s=1:size(segments,1)
    start=segments(s,1);last=segments(s,2);a=labels(start:last);
    for i=1:numel(a)-1,if a(i)>0&&a(i+1)>0,transitions(a(i),a(i+1))=transitions(a(i),a(i+1))+1;eligiblePairs=eligiblePairs+1;end,end
    i=start;while i<=last
        if labels(i)==0,i=i+1;continue;end
        j=i;while j<last&&labels(j+1)==labels(i),j=j+1;end
        left=i==start||labels(i-1)==0;right=j==last||labels(j+1)==0;
        row=table(labels(i),i,j,j-i+1,(j-i+1)*trSeconds,left,right,'VariableNames',{'state','startRow','endRow','nFrames','durationSeconds','leftBoundaryCensored','rightBoundaryCensored'});episodes=[episodes;row];i=j+1; %#ok<AGROW>
    end
end
visits=zeros(nStates,1);meanDwell=nan(nStates,1);meanCompleteDwell=meanDwell;
if ~isempty(episodes),for k=1:nStates,use=episodes.state==k;visits(k)=nnz(use);if any(use),meanDwell(k)=mean(episodes.durationSeconds(use));end;complete=use&~episodes.leftBoundaryCensored&~episodes.rightBoundaryCensored;if any(complete),meanCompleteDwell(k)=mean(episodes.durationSeconds(complete));end,end,end
conditional=counts/max(1,sum(counts));if ~any(counts),conditional(:)=NaN;end
rate=NaN;if eligiblePairs>0,rate=(sum(transitions,'all')-trace(transitions))/(eligiblePairs*trSeconds);end
result=struct('fractionalOccupancyAllObservedFrames',counts/n,'fractionalOccupancyAssignedFrames',conditional,'nAssignedFrames',sum(counts),'nObservedFrames',n,'nVisits',visits,'meanDwellSecondsIncludingCensored',meanDwell,'meanDwellSecondsCompleteEpisodes',meanCompleteDwell,'episodes',episodes,'transitionCounts',transitions,'transitionProbability',transitions./sum(transitions,2),'nEligibleAdjacentPairs',eligiblePairs,'switchingPerEligibleSecond',rate,'note','Hard-path descriptive metrics. CAP selection/Hilbert trims/unassigned frames are zero and break episodes/transitions; observed-frame occupancy includes them. Boundary-truncated lifetimes are explicitly censored.');
end
