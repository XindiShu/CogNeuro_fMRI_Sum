<# 发布新分析包到D:\Function；不删除、不过滤恢复用户删除的文档，不带入影像/结果/缓存。 #>
[CmdletBinding()]
param([string[]]$ApprovedDocPaths=@(),[hashtable]$ApprovedDocBaseHashes=@{},[switch]$VerifyOnly)
$ErrorActionPreference='Stop'
$source=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destination=[IO.Path]::GetFullPath('D:\Function')
if($destination -ne 'D:\Function'){throw 'Unexpected destination'}
if(-not(Test-Path -LiteralPath $destination)){New-Item -ItemType Directory -Path $destination | Out-Null}
if((Get-Item -LiteralPath $destination).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Destination cannot be a reparse point'}
$manifestFile=Join-Path $destination 'FILE_MANIFEST.json'
if($VerifyOnly){
    $m=Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json
    foreach($f in $m.files){
        $path=Join-Path $destination $f.path
        if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $f.sha256){throw "Hash mismatch: $($f.path)"}
    }
    $actual=@(Get-ChildItem -LiteralPath $destination -File -Recurse | Where-Object FullName -ne $manifestFile)
    if($actual.Count -ne $m.files.Count){throw 'Unexpected/missing destination files'}
    Write-Output "Verified $($m.files.Count) destination file hashes";return
}
$previous=@{};if(Test-Path -LiteralPath $manifestFile){$m=Get-Content -LiteralPath $manifestFile -Raw | ConvertFrom-Json;foreach($f in $m.files){$previous[$f.path]=$f}}
$approved=@($ApprovedDocPaths|ForEach-Object{
    $p=$_.Replace('\','/');if($p -notmatch '^docs/[^:]*\.md$' -or $p.Split('/') -contains '..'){throw 'Explicit docs-relative Markdown paths required'};$p
})
$roots=@('matlab','config','tests','examples','docs','scripts');$rootNames=@('README.md','DEPENDENCIES.tsv','METHOD_STATUS.tsv','setup_function.m','run_function.m','run_roi_patterns.m','run_ppi.m','run_ppi_batch.m','run_background_fc.m','run_dcm.m','run_dcm_group.m','run_ica.m','run_searchlight.m','run_gradients.m','run_prediction.m','run_dynamic_fc.m','run_states.m','run_pcm.m','run_encoding.m','run_behavior.m','run_naturalistic.m','run_multivariate.m','run_rest_extended.m','run_network.m','run_transfer.m','run_reliability.m','run_regularized_fc.m','run_linear_decode.m','run_rsa_ceiling.m','run_prepare_inputs.m')
$allowed=@('.m','.md','.tsv','.json','.py','.ps1','.txt');$sources=@()
foreach($name in $rootNames){$p=Join-Path $source $name;if(Test-Path -LiteralPath $p -PathType Leaf){$sources+=Get-Item -LiteralPath $p}}
foreach($name in $roots){$p=Join-Path $source $name;if(Test-Path -LiteralPath $p){$sources+=Get-ChildItem -LiteralPath $p -File -Recurse | Where-Object Extension -in $allowed}}
$sourceHashes=@{};$actions=@{}
foreach($f in $sources){
    if($f.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Source cannot be a reparse point'}
    $rel=[IO.Path]::GetRelativePath($source,$f.FullName).Replace('\','/');$target=Join-Path $destination $rel
    $hash=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash;$sourceHashes[$rel]=$hash
    $exists=Test-Path -LiteralPath $target -PathType Leaf;$copy=$true
    $authorizedDoc=($rel -like 'docs/*.md' -and $rel -in $approved)
    if($exists -and $authorizedDoc){
        $actualDocHash=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if(-not $ApprovedDocBaseHashes.ContainsKey($rel) -or $ApprovedDocBaseHashes[$rel] -ne $actualDocHash){throw "Approved existing doc needs the exact current destination base hash: $rel"}
    }
    if($rel -like 'docs/*.md' -and $rel -notin $approved){$copy=$false;$actions[$rel]='preserved_docs_policy'}
    if($exists -and $rel -like 'config/*'){$copy=$false;$actions[$rel]='preserved_configuration'}
    if($exists -and $previous.ContainsKey($rel)){
        $actual=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        if($actual -ne $previous[$rel].sourceSha256 -and -not $authorizedDoc){$copy=$false;$actions[$rel]='preserved_destination_change'}
    }elseif($exists -and -not $authorizedDoc){$copy=$false;$actions[$rel]='preserved_preexisting_file'}
    if($copy){
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $f.FullName -Destination $target
        if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $hash){throw "Copy mismatch: $rel"};$actions[$rel]='published'
    }
}
$files=@(foreach($f in Get-ChildItem -LiteralPath $destination -File -Recurse | Where-Object FullName -ne $manifestFile){
    $rel=[IO.Path]::GetRelativePath($destination,$f.FullName).Replace('\','/')
    [ordered]@{path=$rel;bytes=$f.Length;sha256=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash;sourceSha256=$sourceHashes[$rel];action=$actions[$rel]}
})
[ordered]@{schemaVersion=1;sourceRoot=$source;destinationRoot=$destination;generatedAt=[DateTimeOffset]::Now.ToString('o');files=$files}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $manifestFile -Encoding utf8NoBOM
Write-Output "Published/recorded $($files.Count) files. Existing configurations, edited destination files and unapproved docs preserved."
