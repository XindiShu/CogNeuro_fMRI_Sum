<#
.SYNOPSIS
  为已有 MATLAB/SPM12 安装固定的官方 CAT12.9，并核验下载包 SHA256。
.DESCRIPTION
  不覆盖已有 cat12；安装位置在 SPM 的 toolbox 下，不在工具包精简发布目录。
  MATLAB 调用时由 psy.cat12_environment 添加路径，不需要修改用户 startup.m。
#>
[CmdletBinding()]
param([string]$SpmPath='D:\matlab\atoolbox\spm12')
$ErrorActionPreference='Stop'
$spmFull=[IO.Path]::GetFullPath($SpmPath)
if (-not (Test-Path -LiteralPath (Join-Path $spmFull 'spm.m') -PathType Leaf)) { throw 'SpmPath 不包含 spm.m' }
$catTarget=[IO.Path]::GetFullPath((Join-Path $spmFull 'toolbox\cat12'))
if (-not $catTarget.StartsWith($spmFull+'\',[StringComparison]::OrdinalIgnoreCase)) { throw '安装目录越界' }
if (Test-Path -LiteralPath $catTarget) { throw "已有 CAT 目录，不覆盖：$catTarget" }
$url='https://github.com/ChristianGaser/cat12/releases/download/12.9/cat12.9.zip'
$expectedHash='EF6C1071A5B47D3A34BAF19FF90B90C6CC101CB30E57CACD76E263CDB3925EF2'
$zip=Join-Path $env:TEMP ('psy_cat12_9_'+[guid]::NewGuid().ToString('N')+'.zip')
$ProgressPreference='SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $zip
$actual=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
if ($actual -ne $expectedHash) { throw "官方包与已验证版本不一致，停止安装。实际 SHA256：$actual" }
# 先检查归档路径；不接受超出预定 cat12 子目录的 zip 条目。
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {
    foreach ($entry in $archive.Entries) {
        $relative=$entry.FullName.Replace('/','\')
        $resolved=[IO.Path]::GetFullPath((Join-Path (Join-Path $spmFull 'toolbox') $relative))
        if ($resolved -ne $catTarget -and -not $resolved.StartsWith($catTarget+'\',[StringComparison]::OrdinalIgnoreCase)) {
            throw "归档条目越界：$relative"
        }
    }
} finally { $archive.Dispose() }
Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $spmFull 'toolbox')
$record=[ordered]@{release='CAT12.9';revision='2577';url=$url;archiveSha256=$actual;installedUtc=[DateTime]::UtcNow.ToString('o');path=$catTarget}
$record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $catTarget 'psy_installation.json') -Encoding utf8
Write-Output "已安装 CAT12.9：$catTarget"
Write-Output 'MATLAB 示例：addpath(安装目录); cat_defaults; cat_get_defaults(''extopts.send_info'',0); cat_version'
