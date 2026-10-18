<#
.SYNOPSIS
  将本工作区的可复用 fMRI 工具包同步到 D:\CogNeuro_fMRI_Toolkit。
.DESCRIPTION
  只复制源码、配置模板、正式文档、示例和测试；不复制 derivatives、
  下载数据、论文、日志、缓存或废弃的审计/计划文件。
  覆盖同名托管文件之前先检查目标路径，并逐文件核对 SHA256。
  docs 中所有已有 Markdown 默认保留目标原字节；缺失的文档不自动补回。
  仅本轮新建或用户明确授权的文档，才可通过 ApprovedDocPaths 逐项发布。
  不删除 D 盘既有文件；若以后删掉源码文件，会报告旧副本供人工检查。
.PARAMETER ApprovedDocPaths
  当次允许发布的 docs/*.md 相对路径列表。已有文档须获用户针对该内容的
  明确授权，先以目标最新内容为底稿核对局部差异；不得借此整体覆盖用户修改。
.PARAMETER PublishPaths
  可选：只发布列出的明确相对路径；其余文件记录目标现有哈希，不补回缺失文件。
  仅整理文档时使用，避免恢复用户已删除的无关代码或覆盖其他本机修改。
#>
[CmdletBinding()]
param(
    [string[]]$ApprovedDocPaths = @(),
    [string[]]$PublishPaths = @()
)

$ErrorActionPreference = 'Stop'
$sourceRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$layout = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'release_layout.json') -Raw | ConvertFrom-Json
$excludedReleasePaths = @($layout.glmExclusivePaths) + @($layout.retiredPaths)
$handFinalizedDocs = @('docs/RUN_MANIFEST_GUIDE.md','docs/FILE_CATALOG_AND_ENVIRONMENT.md')
$publishOnly = @($PublishPaths | ForEach-Object {
    $normalized = $_.Replace('\','/')
    if ([IO.Path]::IsPathRooted($normalized) -or $normalized -match '[:*?<>|]' -or
        @($normalized.Split('/') | Where-Object { $_ -in @('','.','..') }).Count -gt 0) {
        throw "发布范围必须是明确的相对文件路径：$_"
    }
    if ($normalized -in $excludedReleasePaths) { throw "已迁移或停用路径不得发布：$normalized" }
    if (-not (Test-Path -LiteralPath (Join-Path $sourceRoot $normalized) -PathType Leaf)) {
        throw "待发布文件不存在：$normalized"
    }
    $normalized
})
$approvedDocs = @($ApprovedDocPaths | ForEach-Object {
    $normalized = $_.Replace('\','/')
    if ($normalized -notmatch '^docs/(?:[^/]+/)*[^/]+\.md$' -or
        @($normalized.Split('/') | Where-Object { $_ -in @('.','..') }).Count -gt 0 -or
        $normalized -match '[:*?<>|]') {
        throw "文档发布范围必须是 docs 内的明确 Markdown 相对路径：$_"
    }
    if ($normalized -in $excludedReleasePaths -or (Split-Path -Leaf $normalized) -in @('TOOLKIT_GUIDE.md','INPUT_CONTRACT.md')) {
        throw "已停用文档不得重新发布：$normalized"
    }
    if ($normalized -in $handFinalizedDocs) {
        throw "手工定稿文档不接受整份同步覆盖；须有用户针对该文档的明确局部修改授权：$normalized"
    }
    $sourceDocument = Join-Path $sourceRoot $normalized
    if (-not (Test-Path -LiteralPath $sourceDocument -PathType Leaf)) {
        throw "待发布文档不存在：$normalized"
    }
    $normalized
})
$destinationRoot = 'D:\CogNeuro_fMRI_Toolkit'
$destinationFull = [IO.Path]::GetFullPath($destinationRoot).TrimEnd('\')
if ($destinationFull -ne 'D:\CogNeuro_fMRI_Toolkit') {
    throw "发布路径异常：$destinationFull"
}
if (-not (Test-Path -LiteralPath $destinationFull)) {
    New-Item -ItemType Directory -Path $destinationFull | Out-Null
}
$destinationItem = Get-Item -LiteralPath $destinationFull
if ($destinationItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw '发布目录不能是符号链接或其他重解析点。'
}

$managedFiles = [System.Collections.Generic.List[IO.FileInfo]]::new()
$rootFiles = @('README.md','AGENTS.md') + @(
    Get-ChildItem -LiteralPath $sourceRoot -File -Filter '*.m' | ForEach-Object Name
)
foreach ($name in $rootFiles) {
    if ($name -in $excludedReleasePaths) { continue }
    $path = Join-Path $sourceRoot $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $managedFiles.Add((Get-Item -LiteralPath $path))
    }
}

$subdirs = @('config','docs','examples','matlab','scripts','tests')
$allowedExtensions = @('.m','.md','.tsv','.json','.py','.ps1','.sh','.png','.svg')
# 正式配置继续保护；docs 全部 Markdown 在下方按当次授权单独处理。
# 新配置只能另存 F 盘 toolkit_config_zanshi.m，清单记录 D 盘实际哈希。
$protectedRelativePaths = @(
    'config/toolkit_config.m'
)
$excludedDocs = @(
    'DISTORTION_CORRECTION_PLAN.md',
    'GENERALITY_AUDIT.md',
    'PREPROCESSING_INTERFACE_AUDIT.md',
    'input_audit_100206.json',
    'TOOLKIT_GUIDE.md',
    'INPUT_CONTRACT.md'
)
foreach ($subdir in $subdirs) {
    $folder = Join-Path $sourceRoot $subdir
    foreach ($file in Get-ChildItem -LiteralPath $folder -File -Recurse) {
        $releaseRelative = [IO.Path]::GetRelativePath($sourceRoot,$file.FullName).Replace('\','/')
        if ($releaseRelative -in $excludedReleasePaths) { continue }
        if ($file.Extension -notin $allowedExtensions) { continue }
        # 流程图属于正式文档资产；不把其他目录中的 QC/调试图像作为发布资产。
        if ($file.Extension -in @('.png','.svg') -and $subdir -ne 'docs') { continue }
        if ($subdir -eq 'docs' -and $file.Name -in $excludedDocs) { continue }
        if ($subdir -eq 'config' -and $file.Name -in @('runs.tsv','toolkit_config_zanshi.m')) { continue }
        $managedFiles.Add($file)
    }
}

$manifest = foreach ($file in ($managedFiles | Sort-Object FullName -Unique)) {
    $relative = [IO.Path]::GetRelativePath($sourceRoot,$file.FullName)
    $relativeNormalized = $relative.Replace('\','/')
    $target = [IO.Path]::GetFullPath((Join-Path $destinationFull $relative))
    if (-not $target.StartsWith($destinationFull + '\',[StringComparison]::OrdinalIgnoreCase)) {
        throw "文件越过发布目录：$relative"
    }
    $isDocumentation = $relativeNormalized.StartsWith('docs/',[StringComparison]::OrdinalIgnoreCase) -and $file.Extension -eq '.md'
    if ($publishOnly.Count -gt 0 -and $relativeNormalized -notin $publishOnly) {
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $existingItem = Get-Item -LiteralPath $target
            [PSCustomObject]@{
                path = $relativeNormalized
                bytes = $existingItem.Length
                sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            }
        }
        continue
    }
    if ($isDocumentation -and $relativeNormalized -notin $approvedDocs) {
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            $documentItem = Get-Item -LiteralPath $target
            [PSCustomObject]@{
                path = $relativeNormalized
                bytes = $documentItem.Length
                sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            }
        } else {
            Write-Warning "未发布未列入当次文档授权的文件，保留其缺失状态：$relativeNormalized"
        }
        continue
    }
    $parent = Split-Path -Parent $target
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if ($relative.Replace('\','/') -in $protectedRelativePaths) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            throw "用户定稿文件缺失，不能用工作区版本替代：$relative"
        }
        $protectedItem = Get-Item -LiteralPath $target
        [PSCustomObject]@{
            path = $relative.Replace('\','/')
            bytes = $protectedItem.Length
            sha256 = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        }
        continue
    }
    $sourceHash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $targetHash = $null
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    }
    # 已一致的托管文件无需再覆盖：也避免打开中的编辑器锁住无关文件。
    if ($targetHash -ne $sourceHash) {
        Copy-Item -LiteralPath $file.FullName -Destination $target -Force
        $targetHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
    }
    if ($sourceHash -ne $targetHash) { throw "复制校验失败：$relative" }
    [PSCustomObject]@{
        path = $relative.Replace('\','/')
        bytes = $file.Length
        sha256 = $sourceHash
    }
}

# 用户可在 D 盘自行新建文档；即使工作区没有同名文件，也纳入实际哈希清单。
$recordedPaths = @($manifest | ForEach-Object path)
$destinationDocs = Join-Path $destinationFull 'docs'
if (Test-Path -LiteralPath $destinationDocs -PathType Container) {
    foreach ($document in Get-ChildItem -LiteralPath $destinationDocs -File -Recurse -Filter '*.md') {
        $documentRelative = [IO.Path]::GetRelativePath($destinationFull,$document.FullName).Replace('\','/')
        if ($documentRelative -in $recordedPaths -or $document.Name -in $excludedDocs -or $documentRelative -in $excludedReleasePaths) { continue }
        $manifest = @($manifest) + [PSCustomObject]@{
            path = $documentRelative
            bytes = $document.Length
            sha256 = (Get-FileHash -LiteralPath $document.FullName -Algorithm SHA256).Hash
        }
    }
}

$manifestPath = Join-Path $destinationFull 'FILE_MANIFEST.json'
if (Test-Path -LiteralPath $manifestPath) {
    $old = @(Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json)
    $currentPaths = @($manifest | ForEach-Object path)
    $stale = @($old | Where-Object { $_.path -notin $currentPaths })
    if ($stale.Count -gt 0) {
        Write-Warning "有 $($stale.Count) 个上次清单路径本次未发布；缺失文件未补回，既有文件未删除。"
        $stale | ForEach-Object { Write-Warning "旧文件：$($_.path)" }
    }
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Output "发布完成：$destinationFull"
Write-Output "文件数：$($manifest.Count)；总字节数：$(($manifest | Measure-Object -Property bytes -Sum).Sum)；逐文件 SHA256 已核对。"
