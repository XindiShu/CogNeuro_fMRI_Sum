function result=reho(y,space,neighborhood,minNeighbors)
%REHO 邻域Kendall W，平均秩并校正ties；未平滑BOLD输入由调用层声明。
if ~ismember(neighborhood,[7 19 27])||~isscalar(minNeighbors)||minNeighbors<2||minNeighbors>neighborhood||minNeighbors~=fix(minNeighbors),error('cog:ReHo','Invalid neighborhood/coverage');end
if size(y,2)~=numel(space.indices)||size(y,1)<4||any(~isfinite(y),'all'),error('cog:ReHo','Invalid masked matrix');end
n=size(y,1);nv=size(y,2);ranks=zeros(size(y));tie=zeros(1,nv);
for v=1:nv
    ranks(:,v)=tiedrank(y(:,v));[~,~,g]=unique(y(:,v));counts=accumarray(g,1);tie(v)=sum(counts.^3-counts);
end
lookup=zeros(size(space.mask),'uint32');lookup(space.indices)=uint32(1:nv);
[a,b,c]=ndgrid(-1:1);offsets=[a(:),b(:),c(:)];
if neighborhood==7,offsets=offsets(sum(abs(offsets),2)<=1,:);end
if neighborhood==19,offsets=offsets(sum(abs(offsets),2)<=2,:);end
w=nan(1,nv);coverage=zeros(1,nv);
for v=1:nv
    pos=space.ijk(v,:)+offsets;valid=all(pos>=1 & pos<=size(space.mask),2);pos=pos(valid,:);
    lin=sub2ind(size(space.mask),pos(:,1),pos(:,2),pos(:,3));cols=double(lookup(lin));cols=cols(cols>0);k=numel(cols);coverage(v)=k;
    if k<minNeighbors,continue;end
    denominator=k^2*(n^3-n)-k*sum(tie(cols));
    if denominator<=0,continue;end
    s=sum(ranks(:,cols),2);w(v)=max(0,min(1,12*sum((s-mean(s)).^2)/denominator));
end
result=struct('kendallW',w,'nNeighbors',coverage,'neighborhood',neighborhood,'minNeighbors',minNeighbors,'tieCorrection',true);
end
