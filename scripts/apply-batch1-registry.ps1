# apply-batch1-registry.ps1
# 用途：把第 1 批 P0 新技能从 skills.json 的 planned 区块移入 skills 区块，并补齐登记字段。
#       这是一次性收口脚本，执行后即可删除；保留是为了记录登记字段的取值口径。
# 输入：无。以脚本所在目录的上一级为仓库根。
# 输出：每个技能的处理结果。
# 退出码：0 = 全部处理完成；1 = 有技能不满足前置条件。

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$registryPath = Join-Path $repoRoot 'skills/registry/skills.json'
$sourceOfTruth = Join-Path $repoRoot 'skills/skills'

$json = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$existing = @($json.skills | Select-Object -ExpandProperty name)

$batch = @(
    @{
        name      = 'incident-response'
        summary   = '线上问题现场处置：先止血后定位，按严重度分级响应，记录时间线与影响面，破坏性操作与数据修复逐项授权，产出复盘与防复发项。'
        lifecycle = @('72')
        tests     = 'tests/check-incident-response-skill.ps1'
        notes     = '硬约束：止血优先于根因定位；破坏性操作（清数据、重启、回滚版本、封禁）需逐项授权；根因定位交给 systematic-debugging；复盘对事不对人。'
    },
    @{
        name      = 'observability-setup'
        summary   = '为关键路径设计可观测性：从用户路径与故障模式推导指标、日志字段与追踪透传，定义 SLO 与错误预算，设计可行动的告警与值班手册。'
        lifecycle = @('71')
        tests     = 'tests/check-observability-setup-skill.ps1'
        notes     = '硬约束：高基数维度不得作为指标标签；告警必须可行动；不得记录密钥与个人敏感信息；改代码里的 log 语句交给 code-logging。'
    },
    @{
        name      = 'defect-fix-loop'
        summary   = '缺陷修复闭环：分级与范围锁定、先有失败测试或等价复现证据再改代码、最小改动、由影响面推导回归范围、给出验证证据与关闭条件。'
        lifecycle = @('73', '55')
        tests     = 'tests/check-defect-fix-loop-skill.ps1'
        notes     = '硬约束：不得为让测试通过而删除或弱化测试；未复现不等于已修复；原因未知的排查交给 systematic-debugging。'
    }
)

$problems = New-Object System.Collections.Generic.List[string]

foreach ($item in $batch) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceOfTruth $item.name) -PathType Container)) {
        $problems.Add("真源目录不存在：$($item.name)")
    }
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $item.tests) -PathType Leaf)) {
        $problems.Add("契约测试不存在：$($item.tests)")
    }
    if ($item.name -in $existing) {
        $problems.Add("已存在于 skills 区块：$($item.name)")
    }
}

if ($problems.Count -gt 0) {
    $problems | ForEach-Object { Write-Error $_ }
    exit 1
}

foreach ($item in $batch) {
    $entry = [ordered]@{
        name      = $item.name
        summary   = $item.summary
        lifecycle = $item.lifecycle
        maturity  = 'stable'
        evals     = 'evals/evals.json + evals/trigger-eval.json'
        tests     = $item.tests
        notes     = $item.notes
    }
    $json.skills += [pscustomobject]$entry
    $json.planned = @($json.planned | Where-Object { $_.name -ne $item.name })
    Write-Output "moved: $($item.name)"
}

$json.updatedAt = (Get-Date -Format 'yyyy-MM-dd')
$json | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $registryPath -Encoding UTF8

Write-Output ''
Write-Output "skills: $(@($json.skills).Count)  planned: $(@($json.planned).Count)"
