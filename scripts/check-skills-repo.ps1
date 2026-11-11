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

if (-not (Test-Path -LiteralPath $sourceOfTruth -PathType Container)) {
    Add-Failure '单一真源目录不存在：skills/skills'
}

# 宿主目录只保留空壳：技能一律放真源，放回这里就又回到了两套各自维护
foreach ($hostDir in @('.claude/skills', '.codex/skills')) {
    $hostPath = Join-Path $repoRoot $hostDir
    if (-not (Test-Path -LiteralPath $hostPath -PathType Container)) { continue }
    foreach ($item in Get-ChildItem -LiteralPath $hostPath -Force) {
        if ($item.Name -ne '.gitkeep') {
            Add-Failure "$hostDir 应为空目录（只留 .gitkeep），技能请放 skills/skills：发现 $($item.Name)"
        }
    }
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

        # argument-hint 与 disable-model-invocation 只有 Claude Code 认，Codex 加载时会忽略，因此允许出现
        $allowedKeys = @('name', 'description', 'argument-hint', 'disable-model-invocation')
        $unexpectedKeys = @($meta.Keys | Where-Object { $_ -notin $allowedKeys })
        if ($unexpectedKeys.Count -gt 0) {
            Add-Failure "[$name] frontmatter 含未支持的键：$($unexpectedKeys -join ', ')"
        }

        # 仅手动调用必须两个宿主一起关：Claude 看 frontmatter，Codex 看 agents/openai.yaml
        $frontmatter = [regex]::Match((Get-Content -LiteralPath $skillMd -Raw -Encoding UTF8), '(?s)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
        $claudeManual = $frontmatter -match '(?m)^disable-model-invocation:\s*true\s*$'
        $openaiYaml = Join-Path $skillDir 'agents/openai.yaml'
        $codexManual = (Test-Path -LiteralPath $openaiYaml -PathType Leaf) -and
            ((Get-Content -LiteralPath $openaiYaml -Raw -Encoding UTF8) -match '(?m)^\s*allow_implicit_invocation:\s*false\s*$')
        if ($claudeManual -and -not $codexManual) {
            Add-Failure "[$name] 有 disable-model-invocation: true，但 agents/openai.yaml 没设 allow_implicit_invocation: false，Codex 仍会自动触发"
        }
        elseif ($codexManual -and -not $claudeManual) {
            Add-Failure "[$name] agents/openai.yaml 关了自动触发，但 frontmatter 没有 disable-model-invocation: true，Claude Code 仍会自动触发"
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

    if ($registry) {
        foreach ($entry in $registry.skills) {
            if ($entry.name -notin $sourceSkillNames) {
                Add-Failure "[$($entry.name)] 登记表有条目但真源目录不存在"
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

    # 登记表声明的契约测试必须真实存在。
    # CI 是按 tests/check-*-skill.ps1 自动发现的，两者不一致时这个字段就会变成误导性文档。
    $declaredTests = @($registry.skills | Where-Object { $_.PSObject.Properties['tests'] } | ForEach-Object { $_.tests })
    foreach ($declared in $declaredTests) {
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $declared) -PathType Leaf)) {
            Add-Failure "登记表声明的契约测试不存在：$declared"
        }
    }

    # 反向：存在契约测试却没被任何技能登记，说明登记字段漏填
    $testsDir = Join-Path $repoRoot 'tests'
    if (Test-Path -LiteralPath $testsDir -PathType Container) {
        foreach ($testFile in Get-ChildItem -LiteralPath $testsDir -File -Filter 'check-*-skill.ps1') {
            $relative = "tests/$($testFile.Name)"
            if ($relative -notin $declaredTests) {
                Add-Warning "契约测试 $relative 存在，但没有任何技能在登记表 tests 字段中引用它"
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
Write-Output "技能库校验通过：$($sourceSkillNames.Count) 个技能、$($warnings.Count) 项提醒。"
exit 0
