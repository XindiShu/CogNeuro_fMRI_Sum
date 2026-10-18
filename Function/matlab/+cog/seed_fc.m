function r=seed_fc(seed,y)
%SEED_FC 多种子到体素Pearson相关；不计算错误的独立时间点p值。
if size(seed,1)~=size(y,1)||size(y,1)<4||any(~isfinite(seed),'all')||any(~isfinite(y),'all'),error('cog:FC','Invalid seed/target matrices');end
a=double(seed)-mean(double(seed),1);b=double(y)-mean(double(y),1);
da=sqrt(sum(a.^2));db=sqrt(sum(b.^2));if any(da==0)||any(db==0),error('cog:Constant','Constant seed or target');end
r=(a'*b)./(da'*db);r=max(-1,min(1,r));
end
