# check-incident-response-skill.ps1
# 用途：校验 incident-response 技能的契约——frontmatter、支撑文件、现场处置的关键纪律是否齐全。
# 输入：无。以脚本所在目录的上一级为仓库根。
# 输出：逐条断言结果；全部通过时输出通过信息并以 0 退出，否则列出失败项并以 1 退出。
# 退出码：0 = 通过；1 = 存在失败项。
# 说明：本脚本不断言 README 与 skills/registry/skills.json 的登记，登记由技能作者统一更新后另行校验。

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
# 路径用正斜杠：PowerShell 在 Windows 与 Linux 上都接受，CI 在 ubuntu 上运行。
$skillRoot = Join-Path $repoRoot 'skills/skills/incident-response'
$skillPath = Join-Path $skillRoot 'SKILL.md'
$severityPath = Join-Path $skillRoot 'references/severity-and-triage.md'
$safetyPath = Join-Path $skillRoot 'references/production-safety.md'
$timelinePath = Join-Path $skillRoot 'references/incident-timeline-template.md'
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
Assert-FileExists -Path $severityPath -Label 'severity and triage reference'
Assert-FileExists -Path $safetyPath -Label 'production safety reference'
Assert-FileExists -Path $timelinePath -Label 'incident timeline template'
Assert-FileExists -Path $evalsPath -Label 'quality evals'
Assert-FileExists -Path $triggerEvalPath -Label 'trigger evals'

# ---------------------------------------------------------------- SKILL.md 契约

if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
    $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8

    Assert-Contains -Text $skill -Pattern '(?m)^name:\s*incident-response\s*$' -Label 'skill name frontmatter'
    Assert-Contains -Text $skill -Pattern '(?m)^description:\s*\S' -Label 'description frontmatter'
    Assert-Contains -Text $skill -Pattern '不要用于' -Label 'explicit not-for boundary in description'

    # description 长度区间与 description 必须点名的触发场景
    $descMatch = [regex]::Match($skill, '(?m)^description:\s*(.+?)\s*$')
    if ($descMatch.Success) {
        $description = $descMatch.Groups[1].Value
        if ($description.Length -lt 40 -or $description.Length -gt 1200) {
            $failures.Add("description length out of range (40-1200): $($description.Length)")
        }
        foreach ($trigger in @('线上', '故障', '复盘', '严重度', 'on-call', 'postmortem', 'sev level', 'outage')) {
            Assert-Contains -Text $description -Pattern ([regex]::Escape($trigger)) -Label "description trigger wording $trigger"
        }
        foreach ($boundary in @('systematic-debugging', 'release-readiness', 'observability-setup', 'defect-fix-loop', 'code-review-deep-zh')) {
            Assert-Contains -Text $description -Pattern ([regex]::Escape($boundary)) -Label "description boundary skill $boundary"
        }
    }
    else {
        $failures.Add('description frontmatter is not a single line')
    }

    # 约束 1：先止血后定位
    Assert-Contains -Text $skill -Pattern '止血优先' -Label 'stop the bleeding takes priority principle'

    # 约束 2：可回滚或可解释 + 破坏性操作须逐项授权
    Assert-Contains -Text $skill -Pattern '可回滚或可解释' -Label 'bleeding-stop actions must be reversible or explainable'
    Assert-Contains -Text $skill -Pattern '预期效果' -Label 'expected effect must be stated before acting'
    Assert-Contains -Text $skill -Pattern '副作用' -Label 'side effects must be stated before acting'
    Assert-Contains -Text $skill -Pattern '执行后立即验证' -Label 'immediate verification after acting'
    Assert-Contains -Text $skill -Pattern '破坏性' -Label 'destructive operation discipline'
    Assert-Contains -Text $skill -Pattern '未经明确授权' -Label 'no destructive action without explicit authorization'
    Assert-Contains -Text $skill -Pattern '授权' -Label 'authorization requirement'
    Assert-Contains -Text $skill -Pattern '删数据' -Label 'deleting data listed as requiring authorization'
    Assert-Contains -Text $skill -Pattern '清缓存' -Label 'clearing cache listed as requiring authorization'
    Assert-Contains -Text $skill -Pattern '重启数据库' -Label 'restarting database listed as requiring authorization'
    Assert-Contains -Text $skill -Pattern '扩缩容' -Label 'scaling listed as requiring authorization'
    Assert-Contains -Text $skill -Pattern '回滚版本' -Label 'rolling back release listed as requiring authorization'
    Assert-Contains -Text $skill -Pattern '封禁用户' -Label 'banning users listed as requiring authorization'

    # 约束 3：严重度分级决定响应强度与分级依据
    Assert-Contains -Text $skill -Pattern '严重度' -Label 'severity classification'
    Assert-Contains -Text $skill -Pattern '分级决定响应强度|决定响应强度' -Label 'severity drives response intensity'
    foreach ($basis in @('影响面', '核心链路', '数据错误', '可绕过')) {
        Assert-Contains -Text $skill -Pattern $basis -Label "severity basis $basis"
    }
    Assert-Contains -Text $skill -Pattern '通知范围' -Label 'notification scope'

    # 约束 4：时间线记录与三类表述
    Assert-Contains -Text $skill -Pattern '时间线' -Label 'incident timeline'
    Assert-Contains -Text $skill -Pattern '时间戳' -Label 'timestamps on every action and observation'
    Assert-Contains -Text $skill -Pattern '证据来源' -Label 'evidence source recording'
    Assert-Contains -Text $skill -Pattern 'traceId' -Label 'traceId as evidence source'
    Assert-Contains -Text $skill -Pattern '已观察到' -Label 'observed vs inferred vs unverified marking'
    Assert-Contains -Text $skill -Pattern '由证据推断' -Label 'inferred-from-evidence marking'
    Assert-Contains -Text $skill -Pattern '尚未验证' -Label 'not-yet-verified marking'

    # 约束 5：影响面 + 数据修复单独授权
    Assert-Contains -Text $skill -Pattern '影响面' -Label 'blast radius section'
    Assert-Contains -Text $skill -Pattern '开始时间' -Label 'incident start time'
    Assert-Contains -Text $skill -Pattern '是否仍在扩大|仍在扩大' -Label 'still expanding check'
    Assert-Contains -Text $skill -Pattern '数据修复[\s\S]{0,80}单独' -Label 'data repair must be listed and authorized separately'

    # 约束 6：止血与根因的分工
    Assert-Contains -Text $skill -Pattern '根因定位交给 `systematic-debugging`' -Label 'hand off root cause to systematic-debugging'
    Assert-Contains -Text $skill -Pattern '现场处置不等于根因已找到' -Label 'on-scene handling is not root cause found'

    # 约束 7：复盘要点与对事不对人
    Assert-Contains -Text $skill -Pattern '直接原因' -Label 'retrospective direct cause'
    Assert-Contains -Text $skill -Pattern '促成条件' -Label 'retrospective contributing conditions'
    Assert-Contains -Text $skill -Pattern '为何未被更早发现' -Label 'retrospective why not detected earlier'
    Assert-Contains -Text $skill -Pattern '防复发项' -Label 'retrospective prevention items'
    Assert-Contains -Text $skill -Pattern '责任人' -Label 'retrospective owner'
    Assert-Contains -Text $skill -Pattern '期限' -Label 'retrospective deadline'
    Assert-Contains -Text $skill -Pattern '对事不对人' -Label 'blameless retrospective'
    Assert-Contains -Text $skill -Pattern '不用于追责' -Label 'retrospective is not for blame'

    # 约束 8：不夸大
    Assert-Contains -Text $skill -Pattern '不得声称未验证的恢复已生效' -Label 'no unverified recovery claims'
    Assert-Contains -Text $skill -Pattern '可观测依据|观测证据' -Label 'recovery verdict needs observable evidence'

    # 约束 9：边界段覆盖相邻技能
    Assert-Contains -Text $skill -Pattern '本 skill 管现场与止血，它管根因定位' -Label 'explicit split of labor with systematic-debugging'
    foreach ($neighbour in @('systematic-debugging', 'release-readiness', 'observability-setup', 'defect-fix-loop', 'code-review-deep-zh')) {
        Assert-Contains -Text $skill -Pattern ([regex]::Escape($neighbour)) -Label "boundary section mentions $neighbour"
    }

    # 现场不等于做根因结论：禁止把止血动作当根因
    Assert-NotContains -Text $skill -Pattern '本 skill 负责根因定位' -Label 'must not claim root cause ownership'
}

# ---------------------------------------------------------------- references 契约

if (Test-Path -LiteralPath $severityPath -PathType Leaf) {
    $severity = Get-Content -LiteralPath $severityPath -Raw -Encoding UTF8

    foreach ($level in @('Sev1', 'Sev2', 'Sev3', 'Sev4')) {
        Assert-Contains -Text $severity -Pattern $level -Label "severity level $level"
    }
    foreach ($basis in @('判定依据', '响应时限', '通知范围', '有权决策')) {
        Assert-Contains -Text $severity -Pattern $basis -Label "severity column $basis"
    }
    foreach ($step in @('先判断是否需要立即止血', '再定影响面', '再定是否升级')) {
        Assert-Contains -Text $severity -Pattern $step -Label "triage step $step"
    }
    Assert-Contains -Text $severity -Pattern '常见误判' -Label 'misjudgement section'
    Assert-Contains -Text $severity -Pattern '把最后一条报错当根因' -Label 'misjudgement: last error is not the cause'
    Assert-Contains -Text $severity -Pattern '把表象当范围' -Label 'misjudgement: symptom mistaken for scope'
    Assert-Contains -Text $severity -Pattern '过早宣布恢复' -Label 'misjudgement: premature recovery claim'
}

if (Test-Path -LiteralPath $safetyPath -PathType Leaf) {
    $safety = Get-Content -LiteralPath $safetyPath -Raw -Encoding UTF8

    foreach ($measure in @('回滚版本', '切流量', '降级开关', '限流', '重启', '扩容', '封禁')) {
        Assert-Contains -Text $safety -Pattern $measure -Label "bleeding-stop measure $measure"
    }
    foreach ($column in @('代价', '可逆性', '授权要求', '执行前后必须记录')) {
        Assert-Contains -Text $safety -Pattern $column -Label "measure table column $column"
    }
    foreach ($prerequisite in @('备份', '影响行数预估', '可回滚方案', '双人确认')) {
        Assert-Contains -Text $safety -Pattern $prerequisite -Label "data repair prerequisite $prerequisite"
    }
    Assert-Contains -Text $safety -Pattern '风险最高' -Label 'data repair is the highest risk'
    Assert-Contains -Text $safety -Pattern '单独列出、单独申请授权' -Label 'data repair authorized separately'
    Assert-Contains -Text $safety -Pattern '绝不能作为止血手段' -Label 'forbidden bleeding-stop operations section'
    Assert-Contains -Text $safety -Pattern '清库' -Label 'must forbid wiping the database'
    Assert-Contains -Text $safety -Pattern '跳过备份' -Label 'must forbid skipping backups'
    Assert-Contains -Text $safety -Pattern '范围未确认时批量改数据' -Label 'must forbid bulk data edits without a confirmed scope'
    Assert-NotContains -Text $safety -Pattern '可以直接清缓存作为标准止血' -Label 'clearing cache must not be presented as a standard fix'
}

if (Test-Path -LiteralPath $timelinePath -PathType Leaf) {
    $timeline = Get-Content -LiteralPath $timelinePath -Raw -Encoding UTF8

    foreach ($section in @('故障摘要', '严重度', '影响面与时间窗', '时间线', '止血过程', '根因结论', '防复发项', '遗留未验证项')) {
        Assert-Contains -Text $timeline -Pattern $section -Label "timeline template section $section"
    }
    foreach ($column in @('证据来源', '执行人', '验证方式')) {
        Assert-Contains -Text $timeline -Pattern $column -Label "timeline template column $column"
    }
    Assert-Contains -Text $timeline -Pattern '置信度' -Label 'root cause confidence level'
    Assert-Contains -Text $timeline -Pattern '未定位' -Label 'root cause may be unresolved'
    Assert-Contains -Text $timeline -Pattern '对事不对人' -Label 'blameless retrospective reminder'
    Assert-Contains -Text $timeline -Pattern 'systematic-debugging' -Label 'hand-off to systematic-debugging in template'
}

# ---------------------------------------------------------------- evals 契约

if (Test-Path -LiteralPath $evalsPath -PathType Leaf) {
    $evals = Get-Content -LiteralPath $evalsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($evals.skill_name -ne 'incident-response') {
        $failures.Add("evals.json skill_name mismatch: $($evals.skill_name)")
    }
    if (@($evals.evals).Count -lt 3) {
        $failures.Add('evals.json needs at least 3 cases')
    }
    foreach ($case in @($evals.evals)) {
        # id 允许为 0，因此按"缺字段或空字符串"判断，而不是按真假值判断。
        foreach ($field in @('id', 'name', 'prompt', 'expected_output')) {
            if (-not $case.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string] $case.$field)) {
                $failures.Add("evals.json case '$($case.name)' is missing field $field")
            }
        }
    }

    $evalText = ($evals.evals | ForEach-Object { "$($_.prompt) $($_.expected_output)" }) -join "`n"
    Assert-Contains -Text $evalText -Pattern '授权' -Label 'eval coverage: authorization before destructive action'
    Assert-Contains -Text $evalText -Pattern '影响行数|影响面' -Label 'eval coverage: blast radius before data repair'
    Assert-Contains -Text $evalText -Pattern 'systematic-debugging' -Label 'eval coverage: root cause hand-off'
    Assert-Contains -Text $evalText -Pattern '不等于根因已找到' -Label 'eval coverage: on-scene is not root cause found'
    Assert-Contains -Text $evalText -Pattern '待确认|编造' -Label 'eval coverage: sparse information must not be invented'
}

if (Test-Path -LiteralPath $triggerEvalPath -PathType Leaf) {
    $trigger = Get-Content -LiteralPath $triggerEvalPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($trigger.skill_name -ne 'incident-response') {
        $failures.Add("trigger-eval.json skill_name mismatch: $($trigger.skill_name)")
    }
    if (@($trigger.should_trigger).Count -lt 10) {
        $failures.Add('trigger-eval.json needs at least 10 should_trigger cases')
    }
    if (@($trigger.should_not_trigger).Count -lt 10) {
        $failures.Add('trigger-eval.json needs at least 10 should_not_trigger cases')
    }

    $negativeText = @($trigger.should_not_trigger) -join "`n"
    foreach ($neighbour in @('systematic-debugging', 'release-readiness', 'observability-setup', 'defect-fix-loop', 'code-review-deep-zh')) {
        Assert-Contains -Text $negativeText -Pattern ([regex]::Escape($neighbour)) -Label "trigger-eval routes away to $neighbour"
    }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output 'incident-response skill checks passed'
