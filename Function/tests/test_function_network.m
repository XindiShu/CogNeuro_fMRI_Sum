function tests=test_function_network
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.oldPath=path;root=fileparts(fileparts(mfilename('fullpath')));addpath(root);setup_function;t.TestData.bct='D:/matlab/atoolbox/BCT_function_20261017/2019_03_03_BCT';
end
function teardownOnce(t)
path(t.TestData.oldPath);
end
function testNativeCommunitiesAndDensityTies(t)
w=blkdiag(ones(4)-eye(4),ones(4)-eye(4));c=network_config;o=c.options;o.densities=1;o.nNull=0;o.communityRepeats=4;r=cog.network_analysis(w,o,t.TestData.bct);g=r.levels{1};verifyEqual(t,g.modularity,.5,'AbsTol',1e-12);verifyEqual(t,numel(unique(g.community)),2);verifyEqual(t,g.weightedParticipation,zeros(8,1),'AbsTol',1e-12);verifyEqual(t,g.coassignment(1,2),1);verifyEqual(t,g.actualDensity,12/28,'AbsTol',1e-12);
end
function testBinaryNullDegreeAndStarCannotHang(t)
rng(19);w=double(rand(20)<.25);w=triu(w,1);w=w+w';c=network_config;o=c.options;o.densities=1;o.nNull=4;o.communityRepeats=2;r=cog.network_analysis(w,o,t.TestData.bct);g=r.levels{1};verifyEqual(t,g.nullDegree,repmat(sum(w,2),1,4));verifyGreaterThan(t,min(g.nullSuccessfulRewires),0);star=zeros(6);star(1,2:6)=1;star=star+star';r=cog.network_analysis(star,o,t.TestData.bct);verifyEqual(t,r.levels{1}.nullSuccessfulRewires,zeros(4,1));verifyTrue(t,isnan(r.levels{1}.binarySmallWorldSigma));
end
function testNbsExactSignsAndNativeT(t)
x=[1 2 .2;2 1 -.2;1.4 1.5 .1;1.7 1.8 -.1];m=zeros(4,4,4);edges=[1 2;2 3;1 4];for k=1:3,for s=1:4,m(edges(k,1),edges(k,2),s)=x(s,k);m(edges(k,2),edges(k,1),s)=x(s,k);end,end
c=network_config;o=c.nbs;o.threshold=2;o.exchangeabilityNote='Synthetic independent symmetric errors';r=cog.nbs_onesample(m,string(1:4),o);[~,~,~,stats]=ttest(x);verifyEqual(t,r.t(sub2ind([4 4],edges(:,1),edges(:,2)))',stats.tstat,'AbsTol',1e-12);verifyTrue(t,r.exactEnumeration);verifyEqual(t,r.nSignPatterns,16);verifyEqual(t,r.components(1).statistic,2);verifyEqual(t,r.components(1).pFwe,2/16,'AbsTol',1e-12);verifyError(t,@()cog.nbs_onesample(m,["a" "a" "b" "c"],o),'cog:NBSInput');
end
function testNbsOppositeSignsRemainSeparate(t)
m=zeros(3,3,4);for s=1:4,m(1,2,s)=1+s/10;m(2,1,s)=m(1,2,s);m(2,3,s)=-1-s/10;m(3,2,s)=m(2,3,s);end;c=network_config;o=c.nbs;o.threshold=2;o.exchangeabilityNote='Synthetic';o.componentStatistic='excess_mass';before=rng;r=cog.nbs_onesample(m,string(1:4),o);verifyEqual(t,rng,before);verifyEqual(t,numel(r.components),2);verifyEqual(t,sort([r.components.sign]),[-1 1]);expected=mean(1+(1:4)/10)/(std(1+(1:4)/10)/2)-2;verifyEqual(t,[r.components.statistic],[expected expected],'AbsTol',1e-12);verifyEqual(t,[r.components.pFwe],[2/16 2/16],'AbsTol',1e-12);
end
