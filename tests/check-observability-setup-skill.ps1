# check-observability-setup-skill.ps1
# 用途：校验 observability-setup 技能的契约——frontmatter、支撑文件、关键设计约束是否齐全。
# 输入：无。以脚本所在目录的上一级为仓库根。
# 输出：逐条断言结果；全部通过时输出通过信息并以 0 退出，否则列出失败项并以 1 退出。
# 退出码：0 = 通过；1 = 存在失败项。

$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
# 路径用正斜杠：PowerShell 在 Windows 与 Linux 上都接受，CI 在 ubuntu 上运行。
$skillRoot = Join-Path $repoRoot 'skills/skills/observability-setup'
$skillPath = Join-Path $skillRoot 'SKILL.md'
$metricsLogsPath = Join-Path $skillRoot 'references/metrics-and-logs.md'
$alertingPath = Join-Path $skillRoot 'references/alerting-and-runbook.md'
$planTemplatePath = Join-Path $skillRoot 'assets/observability-plan-template.md'
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
Assert-FileExists -Path $metricsLogsPath -Label 'metrics and logs reference'
Assert-FileExists -Path $alertingPath -Label 'alerting and runbook reference'
Assert-FileExists -Path $planTemplatePath -Label 'observability plan template'
Assert-FileExists -Path $evalsPath -Label 'quality evals'
Assert-FileExists -Path $triggerEvalPath -Label 'trigger evals'

# ---------------------------------------------------------------- SKILL.md 契约

if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
    $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8

    Assert-Contains -Text $skill -Pattern '(?m)^name:\s*observability-setup\s*$' -Label 'skill name frontmatter'
    Assert-Contains -Text $skill -Pattern '(?m)^description:\s*\S' -Label 'description frontmatter'
    Assert-Contains -Text $skill -Pattern '不要用于' -Label 'explicit not-for boundary in description'

    # 硬约束 1：从关键用户路径与故障模式出发，不先选工具
    Assert-Contains -Text $skill -Pattern '关键用户路径' -Label 'start from critical user paths'
    Assert-Contains -Text $skill -Pattern '故障模式' -Label 'start from failure modes'
    Assert-Contains -Text $skill -Pattern '不先选工具|不是先选工具|不从工具出发|而不是从某个监控工具出发' -Label 'tool-agnostic stance'

    # 硬约束 2：四类信号、指标类型、禁止平均值掩盖尾延迟
    Assert-Contains -Text $skill -Pattern 'golden signals|四类信号|四大信号' -Label 'four golden signals'
    Assert-Contains -Text $skill -Pattern '延迟' -Label 'latency signal'
    Assert-Contains -Text $skill -Pattern '流量' -Label 'traffic signal'
    Assert-Contains -Text $skill -Pattern '错误' -Label 'errors signal'
    Assert-Contains -Text $skill -Pattern '饱和度' -Label 'saturation signal'
    Assert-Contains -Text $skill -Pattern 'counter' -Label 'counter metric type'
    Assert-Contains -Text $skill -Pattern 'gauge' -Label 'gauge metric type'
    Assert-Contains -Text $skill -Pattern 'histogram|summary' -Label 'histogram or summary metric type'
    Assert-Contains -Text $skill -Pattern '禁止.{0,12}平均值|平均值.{0,20}(掩盖|掩盖尾)|不要用平均值' -Label 'no averages masking tail latency'
    Assert-Contains -Text $skill -Pattern '分位' -Label 'percentile requirement'

    # 硬约束 3：标签基数
    Assert-Contains -Text $skill -Pattern '基数' -Label 'label cardinality'
    foreach ($highCardinality in @('user_id', '订单号', 'traceId', '完整 URL')) {
        Assert-Contains -Text $skill -Pattern ([regex]::Escape($highCardinality)) -Label "high cardinality dimension $highCardinality"
    }
    Assert-Contains -Text $skill -Pattern '成本|查询退化|查询变慢' -Label 'cardinality cost and query degradation'

    # 硬约束 4：日志字段、结构化、异常堆栈、禁止敏感信息
    foreach ($requiredField in @('时间戳', '级别', 'traceId', 'requestId', '实例')) {
        Assert-Contains -Text $skill -Pattern ([regex]::Escape($requiredField)) -Label "required log field $requiredField"
    }
    Assert-Contains -Text $skill -Pattern '结构化' -Label 'structured logging'
    Assert-Contains -Text $skill -Pattern '堆栈' -Label 'exception stack trace'
    Assert-Contains -Text $skill -Pattern '不得记录密钥|不记录密钥|禁止记录密钥|不得记录.{0,20}密钥' -Label 'no secrets in logs'
    Assert-Contains -Text $skill -Pattern '敏感' -Label 'no sensitive personal data in logs'

    # 硬约束 5：trace 上下文透传
    Assert-Contains -Text $skill -Pattern '线程池' -Label 'trace context across thread pools'
    Assert-Contains -Text $skill -Pattern '异步' -Label 'trace context across async tasks'
    Assert-Contains -Text $skill -Pattern '消息队列|MQ' -Label 'trace context across message queues'
    Assert-Contains -Text $skill -Pattern '跨服务' -Label 'trace context across service boundaries'
    Assert-Contains -Text $skill -Pattern '断链' -Label 'common trace break points'

    # 硬约束 6：SLO 与错误预算
    Assert-Contains -Text $skill -Pattern 'SLO' -Label 'SLO definition'
    Assert-Contains -Text $skill -Pattern '用户可感知' -Label 'SLO from user-perceivable signals'
    Assert-Contains -Text $skill -Pattern '错误预算' -Label 'error budget'
    Assert-Contains -Text $skill -Pattern '预算.{0,10}烧完|烧完' -Label 'what to do when budget is burned'

    # 硬约束 7：告警必须可行动、分级、路由、宁少而准
    Assert-Contains -Text $skill -Pattern '可行动' -Label 'alerts must be actionable'
    Assert-Contains -Text $skill -Pattern '看到后.{0,10}做什么|该做什么|做什么' -Label 'each alert states the action'
    Assert-Contains -Text $skill -Pattern '不要.{0,10}每个异常.{0,10}告警|禁止把每个异常都设告警|不要把每个异常' -Label 'no alert per exception'
    Assert-Contains -Text $skill -Pattern '分级' -Label 'alert severity levels'
    Assert-Contains -Text $skill -Pattern '持续时间' -Label 'alert duration / for clause'
    Assert-Contains -Text $skill -Pattern '升级' -Label 'escalation path'
    Assert-Contains -Text $skill -Pattern '宁可少而准' -Label 'prefer few but accurate alerts'

    # 硬约束 8：值班手册
    Assert-Contains -Text $skill -Pattern '值班' -Label 'on-call runbook'
    Assert-Contains -Text $skill -Pattern '第一处置步骤' -Label 'first response step per alert'
    Assert-Contains -Text $skill -Pattern '看板' -Label 'dashboards referenced by the runbook'

    # 硬约束 9：不夸大
    Assert-Contains -Text $skill -Pattern '不夸大' -Label 'no overclaiming'
    Assert-Contains -Text $skill -Pattern '未验证' -Label 'mark unverified items'
    Assert-Contains -Text $skill -Pattern '不得声称|不要声称' -Label 'must not claim unverified monitoring is live'

    # 硬约束 10：相邻技能边界，含与 code-logging 的分工
    foreach ($neighbor in @('code-logging', 'release-readiness', 'incident-response', 'systematic-debugging', 'performance-investigation')) {
        Assert-Contains -Text $skill -Pattern ([regex]::Escape($neighbor)) -Label "adjacent skill boundary $neighbor"
    }
    Assert-Contains -Text $skill -Pattern 'log 语句|日志语句' -Label 'division of labor with code-logging'
    Assert-Contains -Text $skill -Pattern '字段' -Label 'this skill owns field design'
}

# ---------------------------------------------------------------- references 契约

if (Test-Path -LiteralPath $metricsLogsPath -PathType Leaf) {
    $metricsLogs = Get-Content -LiteralPath $metricsLogsPath -Raw -Encoding UTF8

    foreach ($pattern in @('关键路径', 'golden signals|四类信号', '分位', '采样', '标签基数', '脱敏', '线程池', '异步', '消息队列|MQ', '跨服务', '批处理', '反模式')) {
        Assert-Contains -Text $metricsLogs -Pattern $pattern -Label "metrics/logs reference section $pattern"
    }
    foreach ($antiPattern in @('只测 CPU', '只告警不行动', '日志无关联 ID')) {
        Assert-Contains -Text $metricsLogs -Pattern ([regex]::Escape($antiPattern)) -Label "anti-pattern $antiPattern"
    }
}

if (Test-Path -LiteralPath $alertingPath -PathType Leaf) {
    $alerting = Get-Content -LiteralPath $alertingPath -Raw -Encoding UTF8

    foreach ($pattern in @('SLO', '错误预算', '阈值', '持续时间', '抖动', '分级', '路由', '升级', '静默', '抑制', '降噪', '值班手册', 'review|复盘')) {
        Assert-Contains -Text $alerting -Pattern $pattern -Label "alerting/runbook section $pattern"
    }
    Assert-Contains -Text $alerting -Pattern '从不被行动|从未被行动|从不被处置|没人行动' -Label 'periodic review of never-actioned alerts'
}

if (Test-Path -LiteralPath $planTemplatePath -PathType Leaf) {
    $template = Get-Content -LiteralPath $planTemplatePath -Raw -Encoding UTF8

    foreach ($section in @('关键用户路径', '故障模式', '指标清单', '日志字段', '脱敏', '追踪透传', 'SLO', '错误预算', '告警规则', '第一处置步骤', '看板', '未覆盖风险', '未验证')) {
        Assert-Contains -Text $template -Pattern $section -Label "plan template section $section"
    }
}

# ---------------------------------------------------------------- evals 契约

if (Test-Path -LiteralPath $evalsPath -PathType Leaf) {
    $evals = Get-Content -LiteralPath $evalsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($evals.skill_name -ne 'observability-setup') {
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
    Assert-Contains -Text $evalText -Pattern '告警' -Label 'eval coverage for alerting noise'
    Assert-Contains -Text $evalText -Pattern 'user_id|订单号' -Label 'eval coverage for high cardinality labels'
    Assert-Contains -Text $evalText -Pattern '关键用户路径|业务路径' -Label 'eval coverage for missing user paths'
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

Write-Output 'observability-setup skill checks passed'
