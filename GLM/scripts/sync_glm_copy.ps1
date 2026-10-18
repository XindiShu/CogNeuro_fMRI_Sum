<#
.SYNOPSIS
  从开发工作区定向同步可复用GLM文件到D:\GLM，并校验目标实际哈希。
.DESCRIPTION
  只处理release_layout.json显式列出的源码/模板/测试/脚本。
  docs中已有Markdown默认保留，缺失Markdown默认不补回；仅本次新建或
  用户明确授权的文档可逐项列入ApprovedDocPaths。正式toolkit_config.m始终保留。
  不复制影像、分析结果、日志或缓存，不删除任何文件。
#>
[CmdletBinding()]
param(
    [string[]]$PublishPaths = @(),
    [string[]]$ApprovedDocPaths = @(),
    [switch]$PlanOnly
)
$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$destinationRoot = [IO.Path]::GetFullPath('D:\GLM')
if ($destinationRoot -ne 'D:\GLM') { throw 'Unexpected GLM destination' }
$layout = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release_layout.json') -Raw | ConvertFrom-Json
$allowed = @($layout.glmExclusivePaths) + @($layout.glmSharedPaths)
$retiredNames = @('PARAMETER_LINES.md','TOOLKIT_GUIDE.md','INPUT_CONTRACT.md')
function Normalize-PathList([string[]]$Paths) {
    foreach ($path in $Paths) {
        $relative = $path.Replace('\','/')
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '[:*?<>|]' -or
            @($relative.Split('/') | Where-Object { $_ -in @('','.','..') }).Count -gt 0 -or
            $relative -notin $allowed -or $relative -in $layout.retiredPaths -or
            (Split-Path -Leaf $relative) -in $retiredNames) { throw "Invalid GLM publication path: $path" }
        $relative
    }
}
$publish = @(Normalize-PathList $PublishPaths)
$approvedDocs = @(Normalize-PathList $ApprovedDocPaths)
if (@($approvedDocs | Where-Object { $_ -notmatch '^docs/.+\.md$' }).Count -gt 0) {
    throw 'ApprovedDocPaths accepts explicit docs Markdown paths only'
}
if ($publish.Count -eq 0) { $publish = @($allowed) }
$plan = @(
    foreach ($relative in ($publish | Sort-Object -Unique)) {
        $source = [IO.Path]::GetFullPath((Join-Path $sourceRoot $relative))
        $target = [IO.Path]::GetFullPath((Join-Path $destinationRoot $relative))
        if (-not $source.StartsWith($sourceRoot + '\',[StringComparison]::OrdinalIgnoreCase) -or
            -not $target.StartsWith($destinationRoot + '\',[StringComparison]::OrdinalIgnoreCase)) { throw 'Path escaped package root' }
        $action = 'publish'
        if ($relative -eq 'config/toolkit_config.m') { $action = 'preserve_finalized_config' }
        if ($relative -match '^docs/.+\.md$' -and $relative -notin $approvedDocs) { $action = 'preserve_document_or_absence' }
        if ($action -eq 'publish' -and -not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing source: $relative" }
        [PSCustomObject]@{path=$relative;source=$source;target=$target;action=$action}
    }
)
$plan | Select-Object path,action | Format-Table -AutoSize | Out-String | Write-Output
if ($PlanOnly) { return }
if (-not (Test-Path -LiteralPath $destinationRoot)) { New-Item -ItemType Directory -Path $destinationRoot | Out-Null }
# Reject redirection in the destination root or any existing ancestor of a target.
foreach ($entry in $plan) {
    $parent = Split-Path -Parent $entry.target
    while ($parent -and $parent.StartsWith($destinationRoot,[StringComparison]::OrdinalIgnoreCase)) {
        if ((Test-Path -LiteralPath $parent) -and ((Get-Item -LiteralPath $parent).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse point: $parent" }
        $parent = Split-Path -Parent $parent
    }
    if ((Test-Path -LiteralPath $entry.target) -and ((Get-Item -LiteralPath $entry.target).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Reparse point: $($entry.target)" }
}
$snapshotRoot = Join-Path $sourceRoot ('tmp/glm_sync_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
$protectedBefore = @(
    foreach ($document in Get-ChildItem -LiteralPath (Join-Path $destinationRoot 'docs') -File -Recurse -Filter '*.md' -ErrorAction SilentlyContinue) {
        $relative = [IO.Path]::GetRelativePath($destinationRoot,$document.FullName).Replace('\','/')
        if ($relative -notin $approvedDocs) {
            [PSCustomObject]@{path=$document.FullName;sha256=(Get-FileHash -LiteralPath $document.FullName).Hash}
        }
    }
    $finalized = Join-Path $destinationRoot 'config/toolkit_config.m'
    if (Test-Path -LiteralPath $finalized) { [PSCustomObject]@{path=$finalized;sha256=(Get-FileHash -LiteralPath $finalized).Hash} }
)
foreach ($entry in $plan) {
    if ($entry.action -ne 'publish') { continue }
    $sourceHash = (Get-FileHash -LiteralPath $entry.source).Hash
    $targetHash = $null
    if (Test-Path -LiteralPath $entry.target) { $targetHash = (Get-FileHash -LiteralPath $entry.target).Hash }
    if ($sourceHash -ne $targetHash) {
        if ($targetHash) {
            $backup = Join-Path $snapshotRoot $entry.path
            New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
            Copy-Item -LiteralPath $entry.target -Destination $backup
        }
        New-Item -ItemType Directory -Path (Split-Path -Parent $entry.target) -Force | Out-Null
        Copy-Item -LiteralPath $entry.source -Destination $entry.target -Force
    }
    if ((Get-FileHash -LiteralPath $entry.target).Hash -ne $sourceHash) { throw "Copy hash mismatch: $($entry.path)" }
}
foreach ($entry in $protectedBefore) {
    if ((Get-FileHash -LiteralPath $entry.path).Hash -ne $entry.sha256) { throw "Protected file changed: $($entry.path)" }
}
# Include all actual package files in the inventory; never copy them back from this inventory.
$manifest = @(
    foreach ($file in Get-ChildItem -LiteralPath $destinationRoot -File -Recurse | Sort-Object FullName) {
        if ($file.FullName -eq (Join-Path $destinationRoot 'FILE_MANIFEST.json')) { continue }
        [PSCustomObject]@{
            path=[IO.Path]::GetRelativePath($destinationRoot,$file.FullName).Replace('\','/')
            bytes=$file.Length
            sha256=(Get-FileHash -LiteralPath $file.FullName).Hash
        }
    }
)
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $destinationRoot 'FILE_MANIFEST.json') -Encoding utf8
foreach ($entry in (Get-Content -LiteralPath (Join-Path $destinationRoot 'FILE_MANIFEST.json') -Raw | ConvertFrom-Json)) {
    $file = Get-Item -LiteralPath (Join-Path $destinationRoot $entry.path)
    if ($file.Length -ne $entry.bytes -or (Get-FileHash -LiteralPath $file.FullName).Hash -ne $entry.sha256) { throw "Manifest mismatch: $($entry.path)" }
}
Write-Output "GLM publication complete: $($manifest.Count) files; hashes and protected files verified. Backup: $snapshotRoot"
