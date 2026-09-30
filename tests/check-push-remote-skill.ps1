# check-push-remote-skill.ps1
# 用途：校验 push-remote 技能的契约——frontmatter、支撑文件、关键安全约束是否齐全。
# 输入：无。以脚本所在目录的上一级为仓库根。
# 输出：逐条断言结果；全部通过时输出通过信息并以 0 退出，否则列出失败项并以 1 退出。
# 退出码：0 = 通过；1 = 存在失败项。

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$skillRoot = Join-Path $repoRoot 'skills\skills\push-remote'
$skillPath = Join-Path $skillRoot 'SKILL.md'
$strategiesPath = Join-Path $skillRoot 'references\push-strategies.md'
$failureModesPath = Join-Path $skillRoot 'references\failure-modes.md'
$reportTemplatePath = Join-Path $skillRoot 'assets\push-report-template.md'
$evalsPath = Join-Path $skillRoot 'evals\evals.json'
$triggerEvalPath = Join-Path $skillRoot 'evals\trigger-eval.json'
$registryPath = Join-Path $repoRoot 'skills\registry\skills.json'
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

function Assert-NotContains {
    param([string] $Text, [string] $Pattern, [string] $Label)

    if ($Text -match $Pattern) {
        $script:failures.Add("Forbidden content: $Label")
    }
}

# ---------------------------------------------------------------- 文件齐备

Assert-FileExists -Path $skillPath -Label 'SKILL.md'
Assert-FileExists -Path $strategiesPath -Label 'push strategies reference'
Assert-FileExists -Path $failureModesPath -Label 'failure modes reference'
Assert-FileExists -Path $reportTemplatePath -Label 'push report template'
Assert-FileExists -Path $evalsPath -Label 'quality evals'
Assert-FileExists -Path $triggerEvalPath -Label 'trigger evals'

# ---------------------------------------------------------------- SKILL.md 契约

if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
    $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8

    Assert-Contains -Text $skill -Pattern '(?m)^name:\s*push-remote\s*$' -Label 'skill name frontmatter'
    Assert-Contains -Text $skill -Pattern '(?m)^description:\s*\S' -Label 'description frontmatter'
    Assert-Contains -Text $skill -Pattern '不要用于' -Label 'explicit not-for boundary in description'

    # 安全约束：必须写明授权边界与安全强推替代
    Assert-Contains -Text $skill -Pattern 'force-with-lease' -Label 'safe force push alternative'
    Assert-Contains -Text $skill -Pattern '不新建分支' -Label 'no new branch boundary'
    Assert-Contains -Text $skill -Pattern 'git status -sb' -Label 'branch and upstream inspection'
    Assert-Contains -Text $skill -Pattern 'git remote -v' -Label 'remote inspection'
    Assert-Contains -Text $skill -Pattern 'audit-remote-secret-leaks' -Label 'delegation to leak audit skill'
    Assert-Contains -Text $skill -Pattern 'release-readiness' -Label 'delegation to release readiness skill'
    Assert-Contains -Text $skill -Pattern '/commit' -Label 'boundary with commit command'

    # 必须强调推送后验证，而不是只看退出码
    Assert-Contains -Text $skill -Pattern '推送后' -Label 'post-push verification requirement'
}

# ---------------------------------------------------------------- references 契约

if (Test-Path -LiteralPath $strategiesPath -PathType Leaf) {
    $strategies = Get-Content -LiteralPath $strategiesPath -Raw -Encoding UTF8

    Assert-Contains -Text $strategies -Pattern 'non-fast-forward' -Label 'non-fast-forward coverage'
    Assert-Contains -Text $strategies -Pattern 'force-with-lease' -Label 'safe force push guidance'
    Assert-Contains -Text $strategies -Pattern 'protected branch|分支保护|protected' -Label 'protected branch caution'
    Assert-NotContains -Text $strategies -Pattern 'git push\s+--force\s*$' -Label 'bare --force must not be recommended'
}

if (Test-Path -LiteralPath $failureModesPath -PathType Leaf) {
    $failureModes = Get-Content -LiteralPath $failureModesPath -Raw -Encoding UTF8

    foreach ($pattern in @('non-fast-forward', 'stale info', 'Authentication failed', 'protected branch', 'ls-remote', 'RPC failed')) {
        Assert-Contains -Text $failureModes -Pattern ([regex]::Escape($pattern)) -Label "failure mode $pattern"
    }
    Assert-Contains -Text $failureModes -Pattern '不要用 `--force` 绕过|不要用 --force 绕过|绝不要改用 `--force`' -Label 'must forbid force as a shortcut'
}

if (Test-Path -LiteralPath $reportTemplatePath -PathType Leaf) {
    $template = Get-Content -LiteralPath $reportTemplatePath -Raw -Encoding UTF8

    foreach ($section in @('推送目标', '本次上传的提交', '执行的命令', '推送后验证', '结果状态')) {
        Assert-Contains -Text $template -Pattern $section -Label "report section $section"
    }
}

# ---------------------------------------------------------------- evals 契约

if (Test-Path -LiteralPath $evalsPath -PathType Leaf) {
    $evals = Get-Content -LiteralPath $evalsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($evals.skill_name -ne 'push-remote') {
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
    $entry = $registry.skills | Where-Object { $_.name -eq 'push-remote' }
    if (-not $entry) {
        $failures.Add('push-remote is not registered in skills/registry/skills.json')
    }
    elseif ($entry.maturity -ne 'stable') {
        $failures.Add("push-remote maturity should be stable, got $($entry.maturity)")
    }
}
else {
    $failures.Add('Missing skills/registry/skills.json')
}

if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
    Assert-Contains -Text $readme -Pattern 'push-remote' -Label 'README skill registration'
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'push-remote skill checks passed'
