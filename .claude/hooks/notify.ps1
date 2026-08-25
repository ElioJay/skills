# notify.ps1
# 用途：Stop 钩子 —— Claude 完成一轮回复时发出系统提示音。
# 输入：stdin 收到 Claude Code 传入的 JSON（本脚本不需要解析其内容）。
# 退出码约定：恒为 0（提示音失败也不应阻断流程）。

try {
    [Console]::In.ReadToEnd() | Out-Null   # 读空 stdin，避免管道阻塞
    [System.Console]::Beep(880, 200)        # 880Hz、200ms 的提示音
} catch {
    # 无声卡 / 非交互环境下静默忽略
}

exit 0
