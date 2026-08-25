# check-ps1.ps1
# 用途：PostToolUse(Write|Edit) 钩子 —— 对刚写入/编辑的 .ps1 文件做语法检查（不执行脚本）。
# 输入：stdin 收到 Claude Code 传入的 JSON，含 .tool_input.file_path。
# 退出码约定：0 = 通过或非 .ps1（跳过）；2 = 语法错误（stderr 回传给 Claude）。

$ErrorActionPreference = 'Stop'

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }

try {
    $payload = $raw | ConvertFrom-Json
} catch {
    exit 0
}

$path = $payload.tool_input.file_path
if ([string]::IsNullOrWhiteSpace($path)) { exit 0 }
if ($path -notlike '*.ps1') { exit 0 }                 # 非 PowerShell 脚本，跳过
if (-not (Test-Path -LiteralPath $path)) { exit 0 }    # 文件不存在（如被删除），跳过

# 用 PowerShell 语言解析器做语法检查（仅解析 AST，不运行任何代码）
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null

if ($errors -and $errors.Count -gt 0) {
    [Console]::Error.WriteLine("[check-ps1] PowerShell 语法错误（$path）：")
    foreach ($e in $errors) {
        [Console]::Error.WriteLine("  第 $($e.Extent.StartLineNumber) 行：$($e.Message)")
    }
    exit 2
}

exit 0
