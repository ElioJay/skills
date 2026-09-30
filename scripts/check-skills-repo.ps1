# check-skills-repo.ps1
# 用途：校验本仓库技能库的契约、登记表与实际文件是否一致。CI 与本地共用。
# 输入：无必需参数。以脚本所在目录的上一级为仓库根。
#       -Strict 把提醒（WARN）也视为失败，用于 CI 锁住"零提醒"的现状。
# 输出：WARN / FAIL 逐条列出，最后给通过或失败摘要。
# 退出码：0 = 通过；1 = 存在 FAIL（-Strict 下 WARN 也计为失败）。

[CmdletBinding()]
param(
    # description 字符数允许区间。低于下限说明触发信息不足，高于上限会挤占上下文。
    [int] $MinDescriptionChars = 40,
    [int] $MaxDescriptionChars = 1200,
    # CI 用：提醒即失败，避免新债悄悄进来。
    [switch] $Strict
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
# 路径一律用正斜杠书写：PowerShell 在 Windows 与 Linux 上都接受，反斜杠在 Linux 上不是分隔符。
$registryPath = Join-Path $repoRoot 'skills/registry/skills.json'
$readmePath = Join-Path $repoRoot 'README.md'
$docsRoot = Join-Path $repoRoot '.docs'
$sourceOfTruth = Join-Path $repoRoot 'skills/skills'

$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Failure { param([string] $Message) $script:failures.Add($Message) }
function Add-Warning { param([string] $Message) $script:warnings.Add($Message) }

function ConvertTo-NativePath {
    <#
      把登记表里以正斜杠书写的目录转成本机路径形式。
      Windows 上 Join-Path 能直接处理正斜杠并输出反斜杠，无需额外处理。
    #>
    param([string] $Path)

    if ([System.IO.Path]::DirectorySeparatorChar -eq '/') { return $Path }
    return ($Path -replace '/', '\')
}

function Get-SkillMeta {
    <#
      读取 SKILL.md 的 YAML frontmatter，返回 HasFrontmatter / Name / Description / Keys。
      只解析 name 与 description；支持 >- 折叠块与引号值。
    #>
    param([string] $SkillMdPath)

    $raw = Get-Content -LiteralPath $SkillMdPath -Raw -Encoding UTF8
    $match = [regex]::Match($raw, '(?s)\A---\s*\r?\n(.*?)\r?\n---')
    if (-not $match.Success) {
        return [pscustomobject]@{ HasFrontmatter = $false; Name = ''; Description = ''; Keys = @() }
    }

    $frontmatter = $match.Groups[1].Value
    $keys = @([regex]::Matches($frontmatter, '(?m)^([A-Za-z_][A-Za-z0-9_-]*):') | ForEach-Object { $_.Groups[1].Value })

    $nameMatch = [regex]::Match($frontmatter, '(?m)^name\s*:\s*(.+?)\s*$')
    $name = if ($nameMatch.Success) { $nameMatch.Groups[1].Value.Trim().Trim('"').Trim("'") } else { '' }

    $descMatch = [regex]::Match($frontmatter, '(?ms)^description\s*:\s*(>-|>|\|)?\s*(.*?)(?=\r?\n[A-Za-z_][A-Za-z0-9_-]*:|\z)')
    $description = if ($descMatch.Success) { ($descMatch.Groups[2].Value -replace '\s+', ' ').Trim().Trim('"').Trim("'") } else { '' }

    return [pscustomobject]@{
        HasFrontmatter = $true
        Name           = $name
        Description    = $description
        Keys           = $keys
    }
}

function Get-RelativeFileSet {
    <#
      返回技能目录下所有文件的相对路径集合（相对技能目录）。
      evals/ 与 evaluation/ 属评测产物，不计入双宿主契约比对。
    #>
    param([string] $SkillDir)

    if (-not (Test-Path -LiteralPath $SkillDir -PathType Container)) { return @() }

    Get-ChildItem -LiteralPath $SkillDir -Recurse -File |
        ForEach-Object { $_.FullName.Substring($SkillDir.Length).TrimStart('\', '/') -replace '\\', '/' } |
        Where-Object { $_ -notmatch '^(evals|evaluation)/' } |
        Sort-Object
}

function Test-SameFileContent {
    param([string] $Left, [string] $Right)

    if (-not (Test-Path -LiteralPath $Left -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $Right -PathType Leaf)) { return $false }

    $leftBytes = [System.IO.File]::ReadAllBytes($Left)
    $rightBytes = [System.IO.File]::ReadAllBytes($Right)

    if ($leftBytes.Length -ne $rightBytes.Length) { return $false }
    for ($i = 0; $i -lt $leftBytes.Length; $i++) {
        if ($leftBytes[$i] -ne $rightBytes[$i]) { return $false }
    }
    return $true
}

# ---------------------------------------------------------------- 1. 登记表

$registry = $null
if (-not (Test-Path -LiteralPath $registryPath -PathType Leaf)) {
    Add-Failure '缺技能登记表：skills/registry/skills.json'
}
else {
    try {
        $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }
    catch {
        Add-Failure "登记表不是合法 JSON：$($_.Exception.Message)"
    }
}

$registryNames = @()
if ($registry) { $registryNames = @($registry.skills | ForEach-Object { $_.name }) }

# ---------------------------------------------------------------- 2. 目录存在性

$hostDirs = @()
if ($registry) {
    foreach ($property in $registry.hosts.PSObject.Properties) {
        $hostDirs += [pscustomobject]@{ Host = $property.Name; Path = Join-Path $repoRoot (ConvertTo-NativePath $property.Value) }
    }
}

foreach ($hostDir in $hostDirs) {
    if (-not (Test-Path -LiteralPath $hostDir.Path -PathType Container)) {
        Add-Failure "宿主目录不存在：$($hostDir.Host) -> $($hostDir.Path)"
    }
}

if (-not (Test-Path -LiteralPath $sourceOfTruth -PathType Container)) {
    Add-Failure '单一真源目录不存在：skills/skills'
}

# ---------------------------------------------------------------- 3. 真源逐技能契约

$sourceSkillNames = @()
if (Test-Path -LiteralPath $sourceOfTruth -PathType Container) {
    $sourceSkillNames = @(Get-ChildItem -LiteralPath $sourceOfTruth -Directory | Select-Object -ExpandProperty Name | Sort-Object)

    foreach ($name in $sourceSkillNames) {
        $skillDir = Join-Path $sourceOfTruth $name
        $skillMd = Join-Path $skillDir 'SKILL.md'

        if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
            Add-Failure "[$name] 缺 SKILL.md"
            continue
        }

        $meta = Get-SkillMeta -SkillMdPath $skillMd

        if (-not $meta.HasFrontmatter) {
            Add-Failure "[$name] SKILL.md 缺 YAML frontmatter"
            continue
        }

        if ($meta.Name -ne $name) {
            Add-Failure "[$name] frontmatter name='$($meta.Name)' 与目录名不一致"
        }
        if ($meta.Name -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
            Add-Failure "[$name] name 不是 kebab-case：'$($meta.Name)'"
        }

        $unexpectedKeys = @($meta.Keys | Where-Object { $_ -ne 'name' -and $_ -ne 'description' })
        if ($unexpectedKeys.Count -gt 0) {
            Add-Failure "[$name] frontmatter 含未支持的键：$($unexpectedKeys -join ', ')"
        }

        $descLength = $meta.Description.Length
        if ($descLength -lt $MinDescriptionChars) {
            Add-Failure "[$name] description 仅 $descLength 字符（下限 $MinDescriptionChars），触发信息不足"
        }
        elseif ($descLength -gt $MaxDescriptionChars) {
            Add-Failure "[$name] description $descLength 字符（上限 $MaxDescriptionChars），会挤占上下文"
        }

        if ($meta.Description -notmatch 'not for|do not use|不要用于|不要触发|不适用') {
            Add-Failure "[$name] description 未写明不适用边界（not for / 不要用于 等）"
        }

        if ($registry -and ($name -notin $registryNames)) {
            Add-Failure "[$name] 未登记在 skills/registry/skills.json"
        }

        if (Test-Path -LiteralPath (Join-Path $skillDir 'evaluation') -PathType Container) {
            Add-Warning "[$name] 存在 evaluation/ 历史目录，评测产出建议归入 evals/ 并由 .docs/00-AI开发/04-评测记录 归档"
        }
    }

    # 宿主定制技能只存在于镜像，因此其契约检查在镜像上执行
    if ($registry) {
        foreach ($entry in $registry.skills | Where-Object { $_.hostSpecific }) {
            foreach ($hostDir in $hostDirs) {
                $hostSkillDir = Join-Path $hostDir.Path $entry.name
                $skillMd = Join-Path $hostSkillDir 'SKILL.md'
                if (-not (Test-Path -LiteralPath $skillMd -PathType Leaf)) {
                    Add-Failure "[$($entry.name)] $($hostDir.Host) 缺 SKILL.md"
                    continue
                }

                $meta = Get-SkillMeta -SkillMdPath $skillMd

                if ($meta.Name -ne $entry.name) {
                    Add-Failure "[$($entry.name)] $($hostDir.Host) frontmatter name='$($meta.Name)' 与目录名不一致"
                }
                if ($meta.Description.Length -lt $MinDescriptionChars) {
                    Add-Failure "[$($entry.name)] $($hostDir.Host) description 仅 $($meta.Description.Length) 字符，触发信息不足"
                }
                elseif ($meta.Description.Length -gt $MaxDescriptionChars) {
                    Add-Failure "[$($entry.name)] $($hostDir.Host) description $($meta.Description.Length) 字符，超出上限 $MaxDescriptionChars"
                }
                if ($meta.Description -notmatch 'not for|do not use|不要用于|不要触发|不适用') {
                    Add-Failure "[$($entry.name)] $($hostDir.Host) description 未写明不适用边界"
                }
            }
        }
    }

    if ($registry) {
        foreach ($entry in $registry.skills) {
            if ($entry.name -notin $sourceSkillNames) {
                # 宿主定制技能的正文本就按宿主不同，允许只存在于镜像。
                if (-not $entry.hostSpecific) {
                    Add-Failure "[$($entry.name)] 登记表有条目但真源目录不存在"
                }
            }
            elseif ($entry.hostSpecific) {
                Add-Failure "[$($entry.name)] 标记为 hostSpecific 却出现在真源：真源只应收敛宿主中立的内容"
            }
        }
    }
}

# ---------------------------------------------------------------- 4. 登记表条目完备性

<#
  这里刻意不做"summary 是否忠实于 description"的自动判定。
  摘要与触发描述本来就不同源，且本仓技能存在中英文表述并存的情况，
  任何基于字面或关键词重叠的启发式都会大量误报，最终只会被团队整体忽略。
  因此只做确定性检查：summary 存在、长度足以说明用途；
  "描述改了要同步摘要"作为评审项写进 CONTRIBUTING.md，由人和 PR 评审负责。
#>
$minSummaryChars = 12

if ($registry) {
    foreach ($entry in $registry.skills) {
        if (-not $entry.summary) {
            Add-Failure "[$($entry.name)] 登记表条目缺 summary"
            continue
        }
        if ($entry.summary.Length -lt $minSummaryChars) {
            Add-Failure "[$($entry.name)] 登记表 summary 仅 $($entry.summary.Length) 字符，不足以说明用途"
        }
        if (-not $entry.lifecycle -or @($entry.lifecycle).Count -eq 0) {
            Add-Failure "[$($entry.name)] 登记表条目缺 lifecycle 落点"
        }
        if (-not $entry.maturity) {
            Add-Failure "[$($entry.name)] 登记表条目缺 maturity"
        }
        elseif ($entry.maturity -notin @('stub', 'beta', 'stable')) {
            Add-Failure "[$($entry.name)] maturity 取值非法：$($entry.maturity)（应为 stub / beta / stable）"
        }
    }

    # planned 区块只登记尚未实现的计划项，不应混入已有技能
    if ($registry.PSObject.Properties['planned']) {
        foreach ($planned in $registry.planned) {
            if ($planned.name -in $sourceSkillNames) {
                Add-Failure "[$($planned.name)] 被登记在 planned，但真源里已存在该技能，应移入 skills"
            }
        }
    }
}

# ---------------------------------------------------------------- 5. 双宿主与真源一致

if ($hostDirs.Count -ge 1 -and (Test-Path -LiteralPath $sourceOfTruth -PathType Container)) {
    foreach ($name in $sourceSkillNames) {
        $sourceDir = Join-Path $sourceOfTruth $name
        $sourceFiles = Get-RelativeFileSet -SkillDir $sourceDir

        foreach ($hostDir in $hostDirs) {
            $mirrorDir = Join-Path $hostDir.Path $name
            if (-not (Test-Path -LiteralPath $mirrorDir -PathType Container)) {
                Add-Failure "[$name] $($hostDir.Host) 缺该技能目录"
                continue
            }

            $mirrorFiles = Get-RelativeFileSet -SkillDir $mirrorDir

            foreach ($file in @($sourceFiles | Where-Object { $_ -notin $mirrorFiles })) {
                Add-Failure "[$name] 真源有而 $($hostDir.Host) 缺：$file"
            }
            foreach ($file in @($mirrorFiles | Where-Object { $_ -notin $sourceFiles })) {
                Add-Failure "[$name] $($hostDir.Host) 多出真源没有的文件：$file"
            }

            # 同名文件必须内容一致（evals/evaluation 已排除）；
            # 宿主定制技能只校验文件集合，不校验正文。
            $entryMeta = if ($registry) { $registry.skills | Where-Object { $_.name -eq $name } } else { $null }
            if ($entryMeta -and $entryMeta.hostSpecific) { continue }

            foreach ($file in @($sourceFiles | Where-Object { $_ -in $mirrorFiles })) {
                $left = Join-Path $sourceDir $file
                $right = Join-Path $mirrorDir $file
                if (-not (Test-SameFileContent -Left $left -Right $right)) {
                    Add-Failure "[$name] $($hostDir.Host) 与真源内容不一致：$file"
                }
            }
        }
    }

    # 镜像里多出的技能必须是登记为宿主定制的，否则说明真源缺了它
    foreach ($hostDir in $hostDirs) {
        if (-not (Test-Path -LiteralPath $hostDir.Path -PathType Container)) { continue }
        foreach ($mirror in Get-ChildItem -LiteralPath $hostDir.Path -Directory) {
            if ($mirror.Name -in $sourceSkillNames) { continue }

            $mirrorEntry = if ($registry) { $registry.skills | Where-Object { $_.name -eq $mirror.Name } } else { $null }
            if (-not $mirrorEntry) {
                Add-Failure "[$($mirror.Name)] $($hostDir.Host) 存在但真源没有该技能，且未登记在 skills/registry/skills.json"
            }
            elseif (-not $mirrorEntry.hostSpecific) {
                Add-Failure "[$($mirror.Name)] 只存在于镜像、真源缺失，但未标记 hostSpecific"
            }
        }
    }
}

# ---------------------------------------------------------------- 6. README 登记（提醒级）

if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
    foreach ($name in $registryNames) {
        if ($readme -notmatch [regex]::Escape($name)) {
            Add-Warning "README.md 未登记技能：$name（登记表是权威来源，README 应同步）"
        }
    }
}
else {
    Add-Failure '缺 README.md'
}

# ---------------------------------------------------------------- 7. 生命周期锚点

if (-not (Test-Path -LiteralPath $docsRoot -PathType Container)) {
    Add-Warning '.docs 生命周期文档目录不存在，跳过生命周期锚点校验'
}
else {
    # 生命周期编号指向二级活动目录（如 41-代码编写），因此递归枚举。
    $docDirs = @(Get-ChildItem -LiteralPath $docsRoot -Directory -Recurse | Select-Object -ExpandProperty Name)

    if ($registry) {
        foreach ($entry in $registry.skills) {
            foreach ($code in @($entry.lifecycle)) {
                if (@($docDirs | Where-Object { $_ -like "$code-*" }).Count -eq 0) {
                    Add-Failure "[$($entry.name)] 登记的生命周期编号 $code 在 .docs 下没有对应目录"
                }
            }
        }
    }
}

# ---------------------------------------------------------------- 7.5 技能引用有效性

<#
  技能之间互相指路是主要路由方式，指向不存在的技能会把用户带进死路。
  但反引号里同样会写库名、配置项、错误码（mockito-core、non-fast-forward 等），
  因此不能把"未知名字"一律当问题——那样误报率会高到被整体忽略。
  这里只报两类高置信度问题：与某个真实技能名高度相似（疑似拼错）的引用，
  以及 `用 xxx` / `use xxx` 句式里指向不存在技能的引用。
#>
function Get-EditDistance {
    param([string] $Left, [string] $Right)

    $previous = 0..$Right.Length
    for ($i = 1; $i -le $Left.Length; $i++) {
        $current = @($i) + (New-Object int[] $Right.Length)
        for ($j = 1; $j -le $Right.Length; $j++) {
            $cost = if ($Left[$i - 1] -eq $Right[$j - 1]) { 0 } else { 1 }
            $current[$j] = [Math]::Min([Math]::Min($current[$j - 1] + 1, $previous[$j] + 1), $previous[$j - 1] + $cost)
        }
        $previous = $current
    }
    return $previous[$Right.Length]
}

if (Test-Path -LiteralPath $sourceOfTruth -PathType Container) {
    $registeredSkills = @($sourceSkillNames)

    foreach ($skillFile in Get-ChildItem -LiteralPath $sourceOfTruth -Recurse -File -Filter '*.md') {
        $text = Get-Content -LiteralPath $skillFile.FullName -Raw -Encoding UTF8
        $owner = $skillFile.Directory.Name
        $label = $skillFile.Name

        # 候选一：反引号里的 kebab-case 标识符，且与真实技能名编辑距离 <= 2（疑似拼错）
        $backticked = @([regex]::Matches($text, '`([a-z0-9]+(?:-[a-z0-9]+){1,})`') |
            ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique)

        foreach ($candidate in $backticked) {
            if ($candidate -in $registeredSkills) { continue }
            $nearMiss = $registeredSkills | Where-Object {
                [Math]::Abs($_.Length - $candidate.Length) -le 3 -and
                (Get-EditDistance -Left $_ -Right $candidate) -le 2
            }
            if ($nearMiss) {
                Add-Failure "[$owner/$label] 引用了 '$candidate'，与真实技能名 $($nearMiss -join ' / ') 高度相似，疑似拼错"
            }
        }

        # 候选二：`用 xxx` / `use xxx` 句式里指向不存在的技能
        foreach ($match in [regex]::Matches($text, '(?:用|改用|use)\s+`?([a-z0-9]+(?:-[a-z0-9]+){1,})`?')) {
            $candidate = $match.Groups[1].Value
            if ($candidate -in $registeredSkills) { continue }
            $nearMiss = $registeredSkills | Where-Object {
                [Math]::Abs($_.Length - $candidate.Length) -le 3 -and
                (Get-EditDistance -Left $_ -Right $candidate) -le 2
            }
            if ($nearMiss) {
                Add-Failure "[$owner/$label] '$candidate' 与真实技能名 $($nearMiss -join ' / ') 高度相似，疑似拼错"
            }
        }
    }
}

# ---------------------------------------------------------------- 8. 脚本与 JSON 语法

if (Test-Path -LiteralPath $sourceOfTruth -PathType Container) {
    foreach ($ps1 in Get-ChildItem -LiteralPath $sourceOfTruth -Recurse -File -Filter '*.ps1') {
        $tokens = $null
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($ps1.FullName, [ref] $tokens, [ref] $parseErrors)
        if ($parseErrors.Count -gt 0) {
            Add-Failure "PowerShell 语法错误：$($ps1.FullName) -> $($parseErrors[0].Message)"
        }
    }

    foreach ($jsonFile in Get-ChildItem -LiteralPath $sourceOfTruth -Recurse -File -Include '*.json', '*.jsonl') {
        try {
            if ($jsonFile.Extension -eq '.jsonl') {
                foreach ($line in Get-Content -LiteralPath $jsonFile.FullName -Encoding UTF8) {
                    if ($line.Trim()) { [void]($line | ConvertFrom-Json) }
                }
            }
            else {
                [void](Get-Content -LiteralPath $jsonFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json)
            }
        }
        catch {
            Add-Failure "JSON 语法错误：$($jsonFile.FullName) -> $($_.Exception.Message)"
        }
    }
}

# ---------------------------------------------------------------- 输出

foreach ($message in $warnings) { Write-Output "WARN  $message" }

# -Strict：提醒也计为失败，用于 CI 防止新债进入。
$effectiveFailureCount = $failures.Count
$strictNote = ''
if ($Strict -and $warnings.Count -gt 0) {
    $effectiveFailureCount += $warnings.Count
    $strictNote = "（-Strict：$($warnings.Count) 项提醒计为失败）"
}

if ($effectiveFailureCount -gt 0) {
    Write-Output ''
    foreach ($message in $failures) { Write-Output "FAIL  $message" }
    if ($Strict) {
        foreach ($message in $warnings) { Write-Output "FAIL  [strict] $message" }
    }
    Write-Output ''
    Write-Output "技能库校验失败：$effectiveFailureCount 项$strictNote。"
    exit 1
}

Write-Output ''
Write-Output "技能库校验通过：$($sourceSkillNames.Count) 个技能、$($hostDirs.Count) 个宿主目录、$($warnings.Count) 项提醒。"
exit 0
