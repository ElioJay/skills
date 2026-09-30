# check-release-readiness-skill.ps1
# 用途：校验 release-readiness 技能的契约——frontmatter、支撑文件、关键安全约束是否齐全。
# 输入：无。以脚本所在目录的上一级为仓库根。
# 输出：逐条断言结果；全部通过时输出通过信息并以 0 退出，否则列出失败项并以 1 退出。
# 退出码：0 = 通过；1 = 存在失败项。

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
# 路径用正斜杠：PowerShell 在 Windows 与 Linux 上都接受，CI 在 ubuntu 上运行。
$skillRoot = Join-Path $repoRoot 'skills/skills/release-readiness'
$skillPath = Join-Path $skillRoot 'SKILL.md'
$checklistPath = Join-Path $skillRoot 'references/release-checklist.md'
$rollbackPath = Join-Path $skillRoot 'references/rollback-and-sequencing.md'
$reportTemplatePath = Join-Path $skillRoot 'assets/release-readiness-report.md'
$evalsPath = Join-Path $skillRoot 'evals/evals.json'
$triggerEvalPath = Join-Path $skillRoot 'evals/trigger-eval.json'
$registryPath = Join-Path $repoRoot 'skills/registry/skills.json'
$readmePath = Join-Path $repoRoot 'README.md'

$failures = New-Object System.Collections.Generic.List[string]

function Assert-FileExists {
    param([string] $Path, [string] $Label)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $script:failures.Add("Missing $Label at $Path")
    }
}

function Assert-Contains {
    param([string] $Text, [string] $Pattern, [string] $Label)

    if ($Text -notmatch $Pattern) {
        $script:failures.Add("Missing content: $Label")
    }
}

# ---------------------------------------------------------------- 文件齐备

Assert-FileExists -Path $skillPath -Label 'SKILL.md'
Assert-FileExists -Path $checklistPath -Label 'release checklist reference'
Assert-FileExists -Path $rollbackPath -Label 'rollback and sequencing reference'
Assert-FileExists -Path $reportTemplatePath -Label 'readiness report template'
Assert-FileExists -Path $evalsPath -Label 'quality evals'
Assert-FileExists -Path $triggerEvalPath -Label 'trigger evals'

# ---------------------------------------------------------------- SKILL.md 契约

if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
    $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8

    Assert-Contains -Text $skill -Pattern '(?m)^name:\s*release-readiness\s*$' -Label 'skill name frontmatter'
    Assert-Contains -Text $skill -Pattern '(?m)^description:\s*\S' -Label 'description frontmatter'
    Assert-Contains -Text $skill -Pattern '不要用于' -Label 'explicit not-for boundary in description'

    # 核心安全约束：回滚未验证是硬阻塞，不得判定为可以发
    Assert-Contains -Text $skill -Pattern '回滚.*硬条件|硬条件.*回滚' -Label 'unverified rollback is a hard blocker'
    Assert-Contains -Text $skill -Pattern '不能发' -Label 'explicit block verdict'
    Assert-Contains -Text $skill -Pattern '不可回滚' -Label 'irreversible change handling'
    Assert-Contains -Text $skill -Pattern '冻结' -Label 'freeze handling'
    Assert-Contains -Text $skill -Pattern '幂等' -Label 'upgrade script idempotency'

    # 不得声称未运行的检查已通过
    Assert-Contains -Text $skill -Pattern '不要声称未运行的检查已通过' -Label 'no fabricated verification claim'

    # 边界与相邻技能分工
    Assert-Contains -Text $skill -Pattern 'push-remote' -Label 'boundary with push-remote'
    Assert-Contains -Text $skill -Pattern 'incident-response' -Label 'boundary with incident-response'
    Assert-Contains -Text $skill -Pattern 'database-migration' -Label 'boundary with database-migration'
    Assert-Contains -Text $skill -Pattern 'observability-setup' -Label 'boundary with observability-setup'
    Assert-Contains -Text $skill -Pattern 'systematic-debugging' -Label 'boundary with systematic-debugging'

    # 不执行部署或改生产
    Assert-Contains -Text $skill -Pattern '不直接执行部署|不动生产' -Label 'no direct production action'
}

# ---------------------------------------------------------------- references 契约

if (Test-Path -LiteralPath $checklistPath -PathType Leaf) {
    $checklist = Get-Content -LiteralPath $checklistPath -Raw -Encoding UTF8

    foreach ($topic in @('范围与基线', '质量与产物', '数据与兼容', '观测与放量', '回滚', '判定口径', '反模式')) {
        Assert-Contains -Text $checklist -Pattern ([regex]::Escape($topic)) -Label "checklist topic $topic"
    }
    Assert-Contains -Text $checklist -Pattern '可以发.*不能发|不能发' -Label 'explicit verdict criteria'
}

if (Test-Path -LiteralPath $rollbackPath -PathType Leaf) {
    $rollback = Get-Content -LiteralPath $rollbackPath -Raw -Encoding UTF8

    foreach ($topic in @('触发条件', '决策时限', '不可回滚项', '幂等', '中断续跑', '灰度', '观测窗口')) {
        Assert-Contains -Text $rollback -Pattern ([regex]::Escape($topic)) -Label "rollback topic $topic"
    }
    Assert-Contains -Text $rollback -Pattern '兼容性变更' -Label 'compatible-first change ordering'
    Assert-Contains -Text $rollback -Pattern '正式副本属于代码仓库|正式脚本副本' -Label 'script single-copy rule'
}

if (Test-Path -LiteralPath $reportTemplatePath -PathType Leaf) {
    $template = Get-Content -LiteralPath $reportTemplatePath -Raw -Encoding UTF8

    foreach ($section in @('准出结论', '阻塞项', '发布范围', '准出检查单', '发布顺序', '回滚预案', '灰度与生产验证计划', '未验证项与需授权事项')) {
        Assert-Contains -Text $template -Pattern ([regex]::Escape($section)) -Label "report section $section"
    }
    Assert-Contains -Text $template -Pattern '可以发 / 不能发' -Label 'explicit verdict field'
}

# ---------------------------------------------------------------- evals 契约

if (Test-Path -LiteralPath $evalsPath -PathType Leaf) {
    $evals = Get-Content -LiteralPath $evalsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($evals.skill_name -ne 'release-readiness') {
        $failures.Add("evals.json skill_name mismatch: $($evals.skill_name)")
    }
    if (@($evals.evals).Count -lt 3) {
        $failures.Add('evals.json needs at least 3 cases')
    }
}

if (Test-Path -LiteralPath $triggerEvalPath -PathType Leaf) {
    $trigger = Get-Content -LiteralPath $triggerEvalPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($trigger.should_trigger).Count -lt 5) {
        $failures.Add('trigger-eval.json needs at least 5 should_trigger cases')
    }
    if (@($trigger.should_not_trigger).Count -lt 5) {
        $failures.Add('trigger-eval.json needs at least 5 should_not_trigger cases')
    }
}

# ---------------------------------------------------------------- 登记一致性

if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
    $registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json

    $entry = $registry.skills | Where-Object { $_.name -eq 'release-readiness' }
    if (-not $entry) {
        $failures.Add('release-readiness is not registered in skills/registry/skills.json')
    }
    else {
        if ($entry.maturity -ne 'stable') {
            $failures.Add("release-readiness maturity should be stable, got $($entry.maturity)")
        }
        if ($entry.evals -notmatch 'trigger-eval') {
            $failures.Add('release-readiness registry entry must reference trigger evals')
        }
    }

    $planned = $registry.planned | Where-Object { $_.name -eq 'release-readiness' }
    if ($planned) {
        $failures.Add('release-readiness is still listed under planned; move it into skills')
    }
}
else {
    $failures.Add('Missing skills/registry/skills.json')
}

if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
    Assert-Contains -Text $readme -Pattern 'release-readiness' -Label 'README skill registration'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'release-readiness skill checks passed'
