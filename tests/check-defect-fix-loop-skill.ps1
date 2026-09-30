# check-defect-fix-loop-skill.ps1
# 用途：校验 defect-fix-loop 技能的契约——frontmatter、支撑文件、关键闭环约束是否齐全。
# 输入：无。以脚本所在目录的上一级为仓库根。
# 输出：逐条断言结果；全部通过时输出通过信息并以 0 退出，否则列出失败项并以 1 退出。
# 退出码：0 = 通过；1 = 存在失败项。

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
# 路径用正斜杠：PowerShell 在 Windows 与 Linux 上都接受，CI 在 ubuntu 上运行。
$skillRoot = Join-Path $repoRoot 'skills/skills/defect-fix-loop'
$skillPath = Join-Path $skillRoot 'SKILL.md'
$triagePath = Join-Path $skillRoot 'references/defect-triage.md'
$fixPath = Join-Path $skillRoot 'references/fix-and-regression.md'
$recordTemplatePath = Join-Path $skillRoot 'assets/defect-fix-record-template.md'
$evalsPath = Join-Path $skillRoot 'evals/evals.json'
$triggerEvalPath = Join-Path $skillRoot 'evals/trigger-eval.json'

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
Assert-FileExists -Path $triagePath -Label 'defect triage reference'
Assert-FileExists -Path $fixPath -Label 'fix and regression reference'
Assert-FileExists -Path $recordTemplatePath -Label 'defect fix record template'
Assert-FileExists -Path $evalsPath -Label 'quality evals'
Assert-FileExists -Path $triggerEvalPath -Label 'trigger evals'

# ---------------------------------------------------------------- SKILL.md 契约

if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
    $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8

    Assert-Contains -Text $skill -Pattern '(?m)^name:\s*defect-fix-loop\s*$' -Label 'skill name frontmatter'
    Assert-Contains -Text $skill -Pattern '(?m)^description:\s*\S' -Label 'description frontmatter'
    Assert-Contains -Text $skill -Pattern '不要用于' -Label 'explicit not-for boundary in description'

    # 硬约束 1：先有失败测试（或等价最小复现证据）再改代码
    Assert-Contains -Text $skill -Pattern '先有失败测试' -Label 'failing test first'
    Assert-Contains -Text $skill -Pattern '最小复现' -Label 'minimal reproduction evidence'
    Assert-Contains -Text $skill -Pattern '再改代码|先复现再修复|先复现' -Label 'reproduce before fixing'

    # 硬约束 2：最小改动，不做顺手的重构/格式化/依赖升级，扩大范围先确认
    Assert-Contains -Text $skill -Pattern '最小改动' -Label 'minimal change'
    Assert-Contains -Text $skill -Pattern '不做.{0,20}重构|不顺带重构|不做顺手的重构' -Label 'no opportunistic refactor'
    Assert-Contains -Text $skill -Pattern '格式化' -Label 'no opportunistic reformatting'
    Assert-Contains -Text $skill -Pattern '依赖升级|升级依赖' -Label 'no opportunistic dependency upgrade'
    Assert-Contains -Text $skill -Pattern '先.{0,6}确认|先向用户确认|先确认' -Label 'confirm before widening scope'

    # 硬约束 3：禁止弱化测试
    Assert-Contains -Text $skill -Pattern '禁止' -Label 'explicit prohibitions'
    foreach ($weakener in @('删除测试', '删', '跳过', '弱化')) {
        Assert-Contains -Text $skill -Pattern ([regex]::Escape($weakener)) -Label "test weakening prohibition $weakener"
    }
    Assert-Contains -Text $skill -Pattern '改宽|放宽断言|把断言改宽' -Label 'no widening assertions'
    Assert-Contains -Text $skill -Pattern '掩盖缺陷' -Label 'never mask the defect'

    # 硬约束 4：回归范围由影响面推导
    Assert-Contains -Text $skill -Pattern '回归范围' -Label 'regression scope'
    Assert-Contains -Text $skill -Pattern '影响面' -Label 'blast radius derived regression'
    Assert-Contains -Text $skill -Pattern '调用方' -Label 'affected callers'
    Assert-Contains -Text $skill -Pattern '共享工具' -Label 'shared utilities'
    Assert-Contains -Text $skill -Pattern '边界条件' -Label 'boundary conditions'
    Assert-Contains -Text $skill -Pattern '全量测试' -Label 'regression is not just running everything'

    # 硬约束 5：验证证据
    Assert-Contains -Text $skill -Pattern '验证证据' -Label 'verification evidence'
    Assert-Contains -Text $skill -Pattern '前后对照|修复前.{0,10}修复后|复现步骤' -Label 'before / after evidence'
    Assert-Contains -Text $skill -Pattern '无法验证' -Label 'state what cannot be verified'

    # 硬约束 6：区分已修复与未复现
    Assert-Contains -Text $skill -Pattern '未复现' -Label 'not-reproduced state'
    Assert-Contains -Text $skill -Pattern '未复现不等于已修复' -Label 'not reproduced is not fixed'
    Assert-Contains -Text $skill -Pattern '如实标注|如实' -Label 'honest labelling'

    # 硬约束 7：不夸大
    Assert-Contains -Text $skill -Pattern '不夸大' -Label 'no overclaiming'
    Assert-Contains -Text $skill -Pattern '不得声称|不要声称' -Label 'must not claim tests passed without running them'
    Assert-Contains -Text $skill -Pattern '未运行' -Label 'unrun tests must be disclosed'

    # 硬约束 8：关闭条件
    Assert-Contains -Text $skill -Pattern '关闭条件' -Label 'defect closure criteria'
    Assert-Contains -Text $skill -Pattern '关闭' -Label 'can this defect be closed'
    foreach ($closer in @('验证通过', '回归通过', '新增失败', '修复记录')) {
        Assert-Contains -Text $skill -Pattern ([regex]::Escape($closer)) -Label "closure criterion $closer"
    }

    # 硬约束 9：相邻技能边界，含与 systematic-debugging 的分工
    foreach ($neighbor in @('systematic-debugging', 'incident-response', 'code-testing', 'code-review-deep-zh', 'behavior-preserving-refactor', 'release-readiness')) {
        Assert-Contains -Text $skill -Pattern ([regex]::Escape($neighbor)) -Label "adjacent skill boundary $neighbor"
    }
    Assert-Contains -Text $skill -Pattern '原因未知' -Label 'unknown cause routes to systematic-debugging'
    Assert-Contains -Text $skill -Pattern '原因明确|原因已经明确|根因已经明确' -Label 'this skill handles known causes'
}

# ---------------------------------------------------------------- references 契约

if (Test-Path -LiteralPath $triagePath -PathType Leaf) {
    $triage = Get-Content -LiteralPath $triagePath -Raw -Encoding UTF8

    foreach ($pattern in @('影响面', '严重度', '紧急度', '主流程', '数据错误', '优先级', '可复现', '需求变更', '误报', '范围锁定', '先问再扩|先确认再扩')) {
        Assert-Contains -Text $triage -Pattern $pattern -Label "triage reference section $pattern"
    }
}

if (Test-Path -LiteralPath $fixPath -PathType Leaf) {
    $fix = Get-Content -LiteralPath $fixPath -Raw -Encoding UTF8

    # 注意：这里刻意不用 '可改' 这个两字子串——本机 .NET 的子串匹配对它返回假阴性，
    # 会导致契约测试出现难以排查的偶发失败。改用不含该组合的同义字面。
    foreach ($pattern in @('失败测试', '最小改动', '可以改', '不可', '回归范围', '调用方', '共享工具', '边界', '空值', '并发', '时序', '权限', '数据迁移', '验证证据', '单元', '组件', '端到端', '无法验证')) {
        Assert-Contains -Text $fix -Pattern $pattern -Label "fix/regression reference section $pattern"
    }
}

if (Test-Path -LiteralPath $recordTemplatePath -PathType Leaf) {
    $template = Get-Content -LiteralPath $recordTemplatePath -Raw -Encoding UTF8

    foreach ($section in @('缺陷编号', '级别', '复现条件', '影响面', '根因结论', '置信度', '失败测试', '修改点', '最小改动', '刻意没做', '回归范围', '验证证据', '未验证', '关闭条件', '遗留风险', '后续项')) {
        Assert-Contains -Text $template -Pattern $section -Label "record template section $section"
    }
}

# ---------------------------------------------------------------- evals 契约

if (Test-Path -LiteralPath $evalsPath -PathType Leaf) {
    $evals = Get-Content -LiteralPath $evalsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($evals.skill_name -ne 'defect-fix-loop') {
        $failures.Add("evals.json skill_name mismatch: $($evals.skill_name)")
    }
    if (@($evals.evals).Count -lt 3) {
        $failures.Add('evals.json needs at least 3 cases')
    }
    foreach ($case in @($evals.evals)) {
        foreach ($field in @('id', 'name', 'prompt', 'expected_output')) {
            if ($null -eq $case.$field -or "$($case.$field)" -eq '') {
                $failures.Add("evals.json case $($case.id) is missing $field")
            }
        }
    }
    $evalText = $evals | ConvertTo-Json -Depth 6
    Assert-Contains -Text $evalText -Pattern '注释掉|跳过|弱化' -Label 'eval coverage for weakening tests'
    Assert-Contains -Text $evalText -Pattern '重构|升级依赖' -Label 'eval coverage for scope creep'
    Assert-Contains -Text $evalText -Pattern '未复现' -Label 'eval coverage for not reproduced'
}

if (Test-Path -LiteralPath $triggerEvalPath -PathType Leaf) {
    $trigger = Get-Content -LiteralPath $triggerEvalPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if (@($trigger.should_trigger).Count -lt 10) {
        $failures.Add('trigger-eval.json needs at least 10 should_trigger cases')
    }
    if (@($trigger.should_not_trigger).Count -lt 10) {
        $failures.Add('trigger-eval.json needs at least 10 should_not_trigger cases')
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'defect-fix-loop skill checks passed'
