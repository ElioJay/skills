# sync-skills.ps1
# 用途：把技能内容的单一真源 skills/skills/<name>/ 同步到各宿主镜像目录（.claude/skills、.codex/skills）。
# 输入：-Name 只同步指定技能（可多个）；省略则同步真源里的全部技能。
#       -WhatIf 只列出将要改动的文件，不落盘。
# 输出：每个技能的新增/更新/删除文件清单与汇总。
# 退出码：0 = 同步完成；1 = 参数或登记表有问题。

[CmdletBinding(SupportsShouldProcess)]
param(
    [string[]] $Name
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
# 路径一律用正斜杠书写：PowerShell 在 Windows 与 Linux 上都接受，反斜杠在 Linux 上不是分隔符。
$registryPath = Join-Path $repoRoot 'skills/registry/skills.json'
$sourceOfTruth = Join-Path $repoRoot 'skills/skills'

if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    Write-Error "缺技能登记表：$registryPath"
    exit 1
}

$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json

function ConvertTo-NativePath {
    param([string] $Path)

    if ([System.IO.Path]::DirectorySeparatorChar -eq '/') { return $Path }
    return ($Path -replace '/', '\')
}

# 真源自身不参与镜像；evaluation 是历史评测产出，同样不进镜像。
# evals/ 属技能契约的一部分（触发样例与质量用例），需随技能一起同步。
$excludedPrefixes = @('skills/', 'evaluation/')

function Test-Excluded {
    param([string] $RelativePath)

    foreach ($prefix in $excludedPrefixes) {
        if ($RelativePath.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Get-SyncableFiles {
    <#
      返回技能目录下需要同步的文件相对路径，统一用正斜杠，
      以便 Windows 与 Linux 上得到同一份清单、同一个排序。
    #>
    param([string] $SkillDir)

    if (-not (Test-Path -LiteralPath $SkillDir -PathType Container)) { return @() }

    Get-ChildItem -LiteralPath $SkillDir -Recurse -File |
        ForEach-Object { $_.FullName.Substring($SkillDir.Length).TrimStart('\', '/') -replace '\\', '/' } |
        Where-Object { -not (Test-Excluded -RelativePath $_) } |
        Sort-Object
}

$targets = @($registry.hosts.PSObject.Properties | ForEach-Object {
    [pscustomobject]@{ Host = $_.Name; Path = Join-Path $repoRoot (ConvertTo-NativePath $_.Value) }
})

$skillsToSync = if ($Name) { $Name } else { @(Get-ChildItem -LiteralPath $sourceOfTruth -Directory | Select-Object -ExpandProperty Name | Sort-Object) }

$added = 0
$updated = 0
$removed = 0

foreach ($skillName in $skillsToSync) {
    $sourceDir = Join-Path $sourceOfTruth $skillName
    if (-not (Test-Path -LiteralPath $sourceDir -PathType Container)) {
        Write-Error "真源中不存在技能：$skillName"
        exit 1
    }

    $sourceFiles = Get-SyncableFiles -SkillDir $sourceDir

    # 宿主定制技能（registry 里标了 hostSpecific）正文按宿主不同，同步只保证文件集合一致，不覆盖正文。
    $entry = $registry.skills | Where-Object { $_.name -eq $skillName }
    $isHostSpecific = [bool]($entry -and $entry.hostSpecific)

    foreach ($target in $targets) {
        $mirrorDir = Join-Path $target.Path $skillName

        foreach ($relativePath in $sourceFiles) {
            $sourceFile = Join-Path $sourceDir $relativePath
            $mirrorFile = Join-Path $mirrorDir $relativePath
            $mirrorParent = Split-Path -Parent $mirrorFile

            if (-not (Test-Path -LiteralPath $mirrorFile -PathType Leaf)) {
                Write-Output "ADD   $($target.Host)/$skillName/$relativePath"
                if ($PSCmdlet.ShouldProcess($mirrorFile, 'Copy')) {
                    if (-not (Test-Path -LiteralPath $mirrorParent -PathType Container)) {
                        New-Item -ItemType Directory -Path $mirrorParent -Force | Out-Null
                    }
                    Copy-Item -LiteralPath $sourceFile -Destination $mirrorFile -Force
                }
                $added++
                continue
            }

            if ($isHostSpecific) { continue }

            $sourceHash = (Get-FileHash -LiteralPath $sourceFile -Algorithm SHA256).Hash
            $mirrorHash = (Get-FileHash -LiteralPath $mirrorFile -Algorithm SHA256).Hash
            if ($sourceHash -ne $mirrorHash) {
                Write-Output "UPDATE $($target.Host)/$skillName/$relativePath"
                if ($PSCmdlet.ShouldProcess($mirrorFile, 'Copy')) {
                    Copy-Item -LiteralPath $sourceFile -Destination $mirrorFile -Force
                }
                $updated++
            }
        }

        # 镜像里多出的、真源没有的文件：镜像必须与真源一致，因此删除。
        foreach ($relativePath in @(Get-SyncableFiles -SkillDir $mirrorDir)) {
            if ($relativePath -notin $sourceFiles) {
                $mirrorFile = Join-Path $mirrorDir $relativePath
                Write-Output "DELETE $($target.Host)/$skillName/$relativePath"
                if ($PSCmdlet.ShouldProcess($mirrorFile, 'Remove')) {
                    Remove-Item -LiteralPath $mirrorFile -Force
                }
                $removed++
            }
        }
    }
}

Write-Output ''
Write-Output "同步完成：新增 $added、更新 $updated、删除 $removed。真源：skills/skills"
