# guard-bash.ps1
# 用途：PreToolUse(Bash) 钩子 —— 拦截危险 shell 命令。
# 输入：stdin 收到 Claude Code 传入的 JSON，含 .tool_input.command。
# 退出码约定：0 = 放行；2 = 拦截（stderr 内容会回传给 Claude 说明原因）。

$ErrorActionPreference = 'Stop'

# 读取 stdin 全部内容
$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

# 解析 JSON；解析失败时不阻断正常流程
try {
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0
}

$command = $payload.tool_input.command
if ([string]::IsNullOrWhiteSpace($command)) { exit 0 }

# 判断是否为 "递归 + 强制" 的 rm（仅这种组合才视为危险）
function Test-DangerousRm([string]$cmd) {
    if ($cmd -inotmatch '\brm\b') { return $false }
    # 收集 rm 命令里所有短选项（-rf / -r / -f 等）的字母
    $flags = ''
    foreach ($m in [regex]::Matches($cmd, '\s-([a-zA-Z]+)')) { $flags += $m.Groups[1].Value }
    # r/f 区分大小写：递归是小写 r，强制是小写 f
    $recursive = ($flags -cmatch 'r') -or ($cmd -imatch '--recursive')
    $force     = ($flags -cmatch 'f') -or ($cmd -imatch '--force')
    return $recursive -and $force
}

# 危险命令规则：正则匹配则拦截
$rules = @(
    @{ Test = { param($c) Test-DangerousRm $c };            Reason = 'rm 递归强制删除' },
    @{ Test = { param($c) $c -imatch 'git\s+push\s+.*--force' }; Reason = 'git push --force' },
    @{ Test = { param($c) $c -imatch 'git\s+reset\s+--hard' };   Reason = 'git reset --hard' },
    @{ Test = { param($c) $c -imatch 'git\s+clean\s+-[a-zA-Z]*f' }; Reason = 'git clean -f' }
)

foreach ($r in $rules) {
    if (& $r.Test $command) {
        # 退出码 2：拦截并把原因回传给 Claude
        [Console]::Error.WriteLine("[guard-bash] 已拦截危险命令（$($r.Reason)）：$command")
        [Console]::Error.WriteLine("如确需执行，请由人工手动运行。")
        exit 2
    }
}

exit 0
