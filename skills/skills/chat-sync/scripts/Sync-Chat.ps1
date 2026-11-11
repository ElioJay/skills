<#
.SYNOPSIS
    chat-sync：把当前会话增量同步到 Markdown 文件的指定章节。Claude Code 与 Codex 共用。

.DESCRIPTION
    分两步运行，中间由模型把 AI 回复压缩成要点：
      Export  读取当前会话记录，从目标章节里本会话的增量标记之后取出新轮次，
              写出临时 JSON：原话、AI 回复正文（都已打码）和改动的文件。
                Claude Code：~/.claude/projects/*/<会话ID>.jsonl
                Codex：$CODEX_HOME/sessions/**/rollout-*-<线程ID>*.jsonl（只支持 paginated 格式，读不了 .jsonl.zst）
      Write   读取 Export 的 JSON 和模型写的要点 JSON，定位或逐级新建标题，追加到章节末尾，更新标记。
    原话逐字写进代码块，只把疑似密钥、令牌、口令替换成 ***REDACTED***。
    执行 /chat-sync 或 $chat-sync 的那一轮整轮跳过。

.PARAMETER Mode
    Export 或 Write。
.PARAMETER File
    Export：目标 Markdown 文件（.md）；不存在时由 Write 新建（含上级目录）。
.PARAMETER Heading
    Export：标题路径，用 / 分隔层级，如 "项目A/讨论记录"；只写最后一级也行，但必须唯一。
.PARAMETER SyncHost
    claude、codex 或 auto（缺省）。auto 时按环境变量判断：只有 CLAUDE_CODE_SESSION_ID 是 claude，
    只有 CODEX_THREAD_ID 是 codex，两个都有或都没有就报错，要求显式指定。
    Write 时取导出文件里记录的宿主；显式指定了却与导出文件不符则报错。
.PARAMETER SessionId
    Export：当前会话 ID（Codex 是线程 ID，也可写 -ThreadId）。
    缺省时 claude 取 CLAUDE_CODE_SESSION_ID，codex 取 CODEX_THREAD_ID；
    codex 两者都没有时，按「同一工作目录、最新、主线程、最后一条用户消息调用了 $chat-sync」兜底查找。
.PARAMETER Transcript
    Export：直接指定会话记录 JSONL，跳过查找（测试用）。
.PARAMETER OutFile
    Export：导出 JSON 的路径，缺省为 <系统临时目录>/chat-sync/<宿主>-<会话ID>.json。
.PARAMETER ExportFile
    Write：Export 写出的 JSON。
.PARAMETER SummaryFile
    Write：要点 JSON，形如 {"1": ["要点", ...]}，键是轮次 id；缺省用导出 JSON 里记录的路径。

.NOTES
    需要 PowerShell 7+。
    退出码：0 成功（包括没有新内容）；1 参数、文件或要点有误；2 找不到或无法解析会话记录；
            3 标题路径匹配到多个标题（stderr 列出候选）；4 目标章节在导出后已被另一次同步更新。
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Export', 'Write')]
    [string] $Mode,
    [string] $File,
    [string] $Heading,
    [ValidateSet('auto', 'claude', 'codex')]
    [string] $SyncHost = 'auto',
    [Alias('ThreadId')]
    [string] $SessionId,
    [string] $Transcript,
    [string] $OutFile,
    [string] $ExportFile,
    [string] $SummaryFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)

$SkillName = 'chat-sync'
$Utf8NoBom = [Text.UTF8Encoding]::new($false)

# 整段字符串恰好是 ISO 时间时，ConvertFrom-Json 默认会把它转成 DateTime，原话就不再逐字
$JsonArgs = @{ AsHashtable = $true }
if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $JsonArgs.DateKind = 'String' }

function Stop-Sync {
    param([int] $Code, [string] $Message)
    [Console]::Error.WriteLine("chat-sync: $Message")
    exit $Code
}

# ---------------------------------------------------------------- 打码

$Redacted = '***REDACTED***'
$RedactionRules = @(
    @{ Pattern = '-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----'; Replacement = $Redacted }
    @{ Pattern = '\bsk-[A-Za-z0-9_\-]{20,}'; Replacement = $Redacted }
    @{ Pattern = '\bgithub_pat_[A-Za-z0-9_]{22,}'; Replacement = $Redacted }
    @{ Pattern = '\bgh[pousr]_[A-Za-z0-9]{30,}'; Replacement = $Redacted }
    @{ Pattern = '\bAKIA[0-9A-Z]{16}\b'; Replacement = $Redacted }
    @{ Pattern = '\bAIza[0-9A-Za-z_\-]{35}'; Replacement = $Redacted }
    @{ Pattern = '\bxox[abprs]-[A-Za-z0-9\-]{10,}'; Replacement = $Redacted }
    @{ Pattern = '\beyJ[A-Za-z0-9_\-]{8,}\.eyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}'; Replacement = $Redacted }
    @{ Pattern = '(?i)(\bBearer\s+)(?!\*\*\*REDACTED)[A-Za-z0-9._~+/=\-]{16,}'; Replacement = '${1}' + $Redacted }
    @{ Pattern = '(?i)(\b(?:[a-z0-9]+[_-])*(?:password|passwd|pwd|secret|token|api[_-]?key|access[_-]?key)\b["'']?\s*[:=：]\s*["'']?)(?!\*\*\*REDACTED)[^\s"''`,;]{6,}'; Replacement = '${1}' + $Redacted }
)

function Protect-Secret {
    param([AllowEmptyString()][string] $Text)
    $count = 0
    foreach ($rule in $RedactionRules) {
        $regex = [regex]::new($rule.Pattern)
        $hits = $regex.Matches($Text).Count
        if ($hits -gt 0) {
            $count += $hits
            $Text = $regex.Replace($Text, $rule.Replacement)
        }
    }
    [pscustomobject]@{ Text = $Text; Count = $count }
}

# ---------------------------------------------------------------- 读会话记录

function Read-JsonLines {
    param([string] $Path)
    # 宿主正在追加这个文件，必须以共享读写方式打开
    $stream = [IO.FileStream]::new($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
    try {
        $reader = [IO.StreamReader]::new($stream, $Utf8NoBom)
        $content = $reader.ReadToEnd()
    }
    finally {
        $stream.Dispose()
    }
    $lines = $content -split '\r?\n'
    $records = [Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if (-not $lines[$i].Trim()) { continue }
        try {
            $records.Add(($lines[$i] | ConvertFrom-Json @JsonArgs))
        }
        catch {
            # 最后一行可能还没写完整
            $isTail = $i -eq $lines.Count - 1 -or ($i -eq $lines.Count - 2 -and -not $lines[-1].Trim())
            if ($isTail) { continue }
            Stop-Sync 2 "会话记录第 $($i + 1) 行不是合法 JSON：$Path"
        }
    }
    , $records
}

# ---------------------------------------------------------------- Claude Code 会话记录

function Find-ClaudeTranscript {
    if ($Transcript) {
        if (-not (Test-Path -LiteralPath $Transcript -PathType Leaf)) { Stop-Sync 2 "会话记录不存在：$Transcript" }
        return (Resolve-Path -LiteralPath $Transcript).Path
    }
    if (-not $SessionId) { Stop-Sync 2 '拿不到当前会话 ID：请传 -SessionId，或在 Claude Code 里运行（环境变量 CLAUDE_CODE_SESSION_ID）' }
    $configDir = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
    $projects = Join-Path $configDir 'projects'
    # 项目目录名由工作目录换算而来，盘符大小写不固定，所以逐个目录找，不自己拼
    $found = @(Get-ChildItem -LiteralPath $projects -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Get-Item -LiteralPath (Join-Path $_.FullName "$SessionId.jsonl") -ErrorAction SilentlyContinue } |
            Where-Object { $_ })
    if ($found.Count -eq 0) { Stop-Sync 2 "在 $projects 下找不到会话记录 $SessionId.jsonl" }
    ($found | Sort-Object LastWriteTimeUtc -Descending)[0].FullName
}

function Get-Text {
    # 消息内容可能是字符串，也可能是块列表；只取文字块
    param($Content)
    if ($null -eq $Content) { return '' }
    if ($Content -is [string]) { return $Content }
    $parts = foreach ($block in $Content) {
        if ($block -is [Collections.IDictionary] -and $block['type'] -eq 'text') { [string]$block['text'] }
    }
    @($parts) -join "`n"
}

function Get-ImageCount {
    param($Content)
    if ($null -eq $Content -or $Content -is [string]) { return 0 }
    @($Content | Where-Object { $_ -is [Collections.IDictionary] -and $_['type'] -in 'image', 'document' }).Count
}

$ExcludedPrefixes = @(
    '<bash-stdout>', '<bash-stderr>', '<local-command-stdout>', '<local-command-stderr>', '<local-command-caveat>',
    '<task-notification>', '<system-reminder>', '<teammate-message', '<agent-message', 'Another Claude session'
)

function ConvertTo-HumanEvent {
    # 把一条用户侧输入转成事件；不是用户亲手输入的内容返回 $null
    param([string] $Text, [int] $Images, [string] $Kind)
    $trimmed = $Text.TrimStart()
    foreach ($prefix in $ExcludedPrefixes) {
        if ($trimmed.StartsWith($prefix)) { return $null }
    }
    if ($trimmed.StartsWith('[Request interrupted by user')) { return @{ Kind = 'interrupt'; Text = '' } }
    if ($trimmed.StartsWith('<bash-input>')) {
        $command = [regex]::Match($Text, '(?s)<bash-input>(.*?)</bash-input>').Groups[1].Value
        return @{ Kind = 'command'; Text = "! $command" }
    }
    if ($Text -match '<command-name>') {
        $name = [regex]::Match($Text, '(?s)<command-name>(.*?)</command-name>').Groups[1].Value.Trim()
        $argText = [regex]::Match($Text, '(?s)<command-args>(.*?)</command-args>').Groups[1].Value
        if (-not $name.StartsWith('/')) { $name = "/$name" }
        $line = if ($argText) { "$name $argText" } else { $name }
        $kindOut = if ($name -eq "/$SkillName") { 'sync' } else { $Kind }
        return @{ Kind = $kindOut; Text = $line }
    }
    if ($Images -gt 0 -and $Text -notmatch '\[Image #') {
        $placeholder = (@('[图片]') * $Images) -join ' '
        $Text = if ($Text) { "$placeholder`n$Text" } else { $placeholder }
    }
    if (-not $Text.Trim()) { return $null }
    @{ Kind = $Kind; Text = $Text }
}

function Format-ClaudeChoice {
    # AskUserQuestion 的回答：每个问题一行「问题 → 选择」，备注逐字附在下一行
    param($Result)
    $notes = $Result['annotations']
    $lines = foreach ($q in @($Result['questions'])) {
        $question = [string]$q['question']
        $answer = $Result['answers'][$question]
        if ($null -eq $answer) { continue }
        "$question → $answer"
        if ($notes -is [Collections.IDictionary] -and $notes[$question] -is [Collections.IDictionary] -and $notes[$question]['notes']) {
            "  备注：$($notes[$question]['notes'])"
        }
    }
    @($lines) -join "`n"
}

function Get-ClaudeEvents {
    # 按记录顺序产出事件：用户侧（prompt/queued/choice/command/interrupt/sync）、ai 文本、改动文件
    param($Records, [string] $CursorFrom)
    $startIndex = 0
    if ($CursorFrom -and $CursorFrom -ne 'start') {
        $startIndex = -1
        for ($i = 0; $i -lt $Records.Count; $i++) {
            if ($Records[$i]['uuid'] -eq $CursorFrom) { $startIndex = $i + 1; break }
        }
        if ($startIndex -lt 0) { Stop-Sync 1 "增量标记指向的位置 $CursorFrom 不在当前会话记录里" }
    }

    $events = [Collections.Generic.List[object]]::new()
    $add = {
        param([string] $Kind, [string] $Text)
        if ($emit) { $events.Add([pscustomobject]@{ Kind = $Kind; Text = $Text; Time = $time; Id = $id; PrevId = $prevId }) }
    }
    $prevId = $null
    $lastId = $null
    $cwd = $null
    for ($i = 0; $i -lt $Records.Count; $i++) {
        $r = $Records[$i]
        $id = $r['uuid']
        if (-not $id) { continue }
        $emit = $i -ge $startIndex
        $time = $r['timestamp']
        if ($r['cwd']) { $cwd = [string]$r['cwd'] }
        if (-not $r['isSidechain']) {
            switch ($r['type']) {
                'user' {
                    $message = $r['message']
                    if (-not $message -or $r['isMeta'] -or $r['isCompactSummary'] -or $r['isVisibleInTranscriptOnly']) { break }
                    if ($r.Contains('toolUseResult')) {
                        $result = $r['toolUseResult']
                        if ($result -is [Collections.IDictionary] -and $result['answers'] -is [Collections.IDictionary] -and $result['questions']) {
                            & $add 'choice' (Format-ClaudeChoice $result)
                        }
                        break
                    }
                    $origin = $r['origin']
                    if ($origin -is [Collections.IDictionary] -and $origin['kind'] -and $origin['kind'] -ne 'human') { break }
                    if ($r['promptSource'] -eq 'system') { break }
                    $content = $message['content']
                    if ($content -isnot [string] -and @($content | Where-Object { $_ -is [Collections.IDictionary] -and $_['type'] -eq 'tool_result' }).Count) { break }
                    $ev = ConvertTo-HumanEvent (Get-Text $content) (Get-ImageCount $content) 'prompt'
                    if ($ev) { & $add $ev.Kind $ev.Text }
                }
                'attachment' {
                    # Claude 工作时用户插进来的话只记在 queued_command 附件里
                    $a = $r['attachment']
                    if ($a -isnot [Collections.IDictionary] -or $a['type'] -ne 'queued_command' -or $a['commandMode'] -ne 'prompt') { break }
                    $origin = $a['origin']
                    $human = $a['humanTurn'] -or ($origin -is [Collections.IDictionary] -and $origin['kind'] -eq 'human')
                    if (-not $human) { break }
                    $ev = ConvertTo-HumanEvent (Get-Text $a['prompt']) (Get-ImageCount $a['prompt']) 'queued'
                    if ($ev) { & $add $ev.Kind $ev.Text }
                }
                'assistant' {
                    $message = $r['message']
                    if (-not $message -or $r['isApiErrorMessage']) { break }
                    foreach ($block in @($message['content'])) {
                        if ($block -isnot [Collections.IDictionary]) { continue }
                        if ($block['type'] -eq 'text' -and $block['text']) {
                            & $add 'ai' $block['text']
                        }
                        elseif ($block['type'] -eq 'tool_use' -and $block['name'] -in 'Edit', 'Write', 'MultiEdit', 'NotebookEdit') {
                            $toolInput = $block['input']
                            if ($toolInput -is [Collections.IDictionary]) {
                                $path = if ($toolInput['file_path']) { $toolInput['file_path'] } else { $toolInput['notebook_path'] }
                                if ($path) { & $add 'file' (Format-FilePath $path $cwd) }
                            }
                        }
                    }
                }
            }
        }
        if ($emit) { $lastId = $id }
        $prevId = $id
    }
    [pscustomobject]@{ Events = $events; LastId = $lastId }
}

function Get-ClaudeSessionKey {
    param([string] $TranscriptPath)
    $key = if ($SessionId) { $SessionId } else { [IO.Path]::GetFileNameWithoutExtension($TranscriptPath) }
    if ($key -notmatch '^[0-9A-Za-z-]{8,64}$') { Stop-Sync 1 "会话 ID 格式不对：$key" }
    $key
}

# ---------------------------------------------------------------- Codex 会话记录

function Test-SyncInvocation {
    param([string] $Text)
    $Text -match '(?:^|\s)\$chat-sync(?![\w-])' -or $Text -match '\[\$chat-sync\]\('
}

function Get-PartText {
    # 消息内容是块列表；只取带 text 的块
    param($Parts)
    $texts = foreach ($part in @($Parts)) {
        if ($part -is [Collections.IDictionary] -and $part['text']) { [string]$part['text'] }
    }
    @($texts) -join "`n"
}

function Test-ThreadInvokedSync {
    # 兜底查找用：最后一条用户消息是否调用了 $chat-sync
    param($Records)
    for ($i = $Records.Count - 1; $i -ge 0; $i--) {
        $p = $Records[$i]['payload']
        if ($Records[$i]['type'] -ne 'event_msg' -or $p -isnot [Collections.IDictionary] -or $p['type'] -ne 'item_completed') { continue }
        $item = $p['item']
        if ($item -isnot [Collections.IDictionary] -or $item['type'] -ne 'UserMessage') { continue }
        $skills = @(@($item['content']) | Where-Object { $_ -is [Collections.IDictionary] -and $_['type'] -eq 'skill' } | ForEach-Object { $_['name'] })
        return ($skills -contains $SkillName) -or (Test-SyncInvocation (Get-PartText $item['content']))
    }
    $false
}

function Find-CodexTranscript {
    if ($Transcript) {
        if (-not (Test-Path -LiteralPath $Transcript -PathType Leaf)) { Stop-Sync 2 "会话记录不存在：$Transcript" }
        return (Resolve-Path -LiteralPath $Transcript).Path
    }
    $codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME '.codex' }
    $sessions = Join-Path $codexHome 'sessions'
    $all = @(Get-ChildItem -LiteralPath $sessions -Recurse -File -Filter 'rollout-*' -ErrorAction SilentlyContinue)
    $plain = @($all | Where-Object { $_.Name -like '*.jsonl' })

    if ($SessionId) {
        if ($SessionId -notmatch '^[0-9A-Za-z-]{8,64}$') { Stop-Sync 1 "线程 ID 格式不对：$SessionId" }
        # 回退过的线程会多出 rollout-<时间>-<ID>_<rolloutID>.jsonl，取最近写入的那份
        $mine = @($plain | Where-Object { $_.Name -like "*-$SessionId.jsonl" -or $_.Name -like "*-${SessionId}_*.jsonl" })
        if ($mine.Count) { return ($mine | Sort-Object LastWriteTimeUtc -Descending)[0].FullName }
        if (@($all | Where-Object { $_.Name -like "*$SessionId*.jsonl.zst" }).Count) {
            Stop-Sync 2 "线程 $SessionId 的记录已被压缩成 .jsonl.zst，PowerShell 读不了"
        }
        Stop-Sync 2 "在 $sessions 下找不到线程 $SessionId 的记录"
    }

    # 兜底：同一工作目录、最新、主线程、最后一条用户消息调用了 $chat-sync
    $cwd = (Get-Location).Path.TrimEnd('\', '/')
    foreach ($candidate in @($plain | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 20)) {
        $records = Read-JsonLines $candidate.FullName
        if (-not $records.Count -or $records[0]['type'] -ne 'session_meta') { continue }
        $meta = $records[0]['payload']
        if ($meta -isnot [Collections.IDictionary] -or $meta['parent_thread_id'] -or $meta['source'] -isnot [string]) { continue }
        if ($meta['thread_source'] -and $meta['thread_source'] -ne 'user') { continue }
        if (([string]$meta['cwd']).TrimEnd('\', '/') -ne $cwd) { continue }
        if (Test-ThreadInvokedSync $records) { return $candidate.FullName }
    }
    Stop-Sync 2 '拿不到 CODEX_THREAD_ID，也没能按「同一工作目录、最新、主线程、最后一条消息调用了 $chat-sync」找到当前会话'
}

function Remove-CodexWrapper {
    # Desktop 会把提到的文件包成「# Files mentioned by the user: … ## My request:」，只留原话和附件占位
    param([string] $Text)
    if ($Text -match '(?s)^\s*# Files (?:mentioned|pasted) by the user:[ \t]*\r?\n(.*?)\r?\n## My request:[ \t]*\r?\n?(.*)$') {
        $header = $Matches[1]
        $request = $Matches[2]
        $attachments = foreach ($m in [regex]::Matches($header, '(?m)^## .*?: (.+?)\s*$')) { "[附件: $($m.Groups[1].Value)]" }
        $Text = (@($attachments) + $request) -join "`n"
    }
    # Desktop 里提到 skill 写成 [$name](路径)，还原成用户打的 $name
    [regex]::Replace($Text, '\[\$([A-Za-z0-9_-]+)\]\([^)]*\)', '$$$1')
}

function Format-CodexChoice {
    # request_user_input 的回答：每个问题一行「问题 → 选择」
    param($Questions, $Answers)
    $lines = foreach ($q in @($Questions)) {
        if ($q -isnot [Collections.IDictionary]) { continue }
        $entry = $Answers[[string]$q['id']]
        if ($null -eq $entry) { continue }
        $values = if ($entry -is [Collections.IDictionary]) { @($entry['answers']) } else { @($entry) }
        "$($q['question']) → $(@($values) -join ', ')"
    }
    @($lines) -join "`n"
}

function Format-Reply {
    # 异步提问的回答以 <send_user_message_question_reply>[{question, answer}] 的形式回到用户消息里
    param($Replies)
    $lines = foreach ($reply in @($Replies)) {
        if ($reply -is [Collections.IDictionary]) { "$($reply['question']) → $(@($reply['answer']) -join ', ')" }
    }
    @($lines) -join "`n"
}

function Get-CodexEvents {
    # 按记录顺序产出事件：用户侧（prompt/queued/choice/command/interrupt/sync）、ai 文本、改动文件
    param($Records, [string] $CursorFrom)
    if (-not $Records.Count -or $Records[0]['type'] -ne 'session_meta') { Stop-Sync 2 '记录第一行不是 session_meta，不是 Codex rollout 文件' }
    $meta = $Records[0]['payload']
    if ($meta['history_mode'] -ne 'paginated') {
        Stop-Sync 2 "只支持 paginated 格式的 Codex 记录，当前是：$($meta['history_mode'])"
    }
    $start = -1L
    if ($CursorFrom -and $CursorFrom -ne 'start') {
        if ($CursorFrom -notmatch '^\d+$') { Stop-Sync 1 "增量标记的位置不是记录序号：$CursorFrom" }
        $start = [long]$CursorFrom
    }

    $events = [Collections.Generic.List[object]]::new()
    $add = {
        param([string] $Kind, [string] $Text)
        if ($emit) { $events.Add([pscustomobject]@{ Kind = $Kind; Text = $Text; Time = $time; Id = $id; PrevId = $prevId }) }
    }
    $calls = @{}
    $lastUserTurn = $null
    $prevId = $null
    $lastId = $null
    $maxOrdinal = -1L
    $cwd = [string]$meta['cwd']
    for ($i = 0; $i -lt $Records.Count; $i++) {
        $r = $Records[$i]
        $ordinal = if ($null -ne $r['ordinal']) { [long]$r['ordinal'] } else { [long]$i }
        $id = [string]$ordinal
        $emit = $ordinal -gt $start
        $time = $r['timestamp']
        $p = $r['payload']
        if ($p -is [Collections.IDictionary]) {
            switch ($r['type']) {
                'turn_context' {
                    if ($p['cwd']) { $cwd = [string]$p['cwd'] }
                }
                'event_msg' {
                    if ($p['type'] -eq 'turn_aborted') {
                        if ($p['reason'] -eq 'interrupted') { & $add 'interrupt' '' }
                        break
                    }
                    $item = $p['item']
                    if ($p['type'] -ne 'item_completed' -or $item -isnot [Collections.IDictionary]) { break }
                    if ($item['type'] -eq 'UserMessage') {
                        $parts = @($item['content'])
                        $text = Get-PartText ($parts | Where-Object { $_ -is [Collections.IDictionary] -and $_['type'] -eq 'text' })
                        $images = @($parts | Where-Object { $_ -is [Collections.IDictionary] -and $_['type'] -in 'local_image', 'image' }).Count
                        $skills = @($parts | Where-Object { $_ -is [Collections.IDictionary] -and $_['type'] -eq 'skill' } | ForEach-Object { $_['name'] })
                        # 同一 turn 里的第二条及以后的用户消息，是 Codex 工作时插进来的话
                        $turn = [string]$p['turn_id']
                        $newTurn = -not $turn -or $turn -ne $lastUserTurn
                        $lastUserTurn = $turn
                        if ($text -match '(?s)<send_user_message_question_reply>(.*?)</send_user_message_question_reply>') {
                            $replies = $null
                            try { $replies = $Matches[1] | ConvertFrom-Json @JsonArgs } catch { $replies = $null }
                            if ($replies) { & $add 'choice' (Format-Reply $replies) }
                            break
                        }
                        $isSync = ($skills -contains $SkillName) -or (Test-SyncInvocation $text)
                        $kind = if (-not $newTurn) { 'queued' } elseif ($isSync) { 'sync' } else { 'prompt' }
                        $clean = Remove-CodexWrapper $text
                        if ($images -gt 0) {
                            $placeholder = (@('[图片]') * $images) -join ' '
                            $clean = if ($clean) { "$placeholder`n$clean" } else { $placeholder }
                        }
                        if ($clean.Trim() -or $kind -eq 'sync') { & $add $kind $clean }
                    }
                    elseif ($item['type'] -eq 'AgentMessage') {
                        $text = Get-PartText $item['content']
                        if ($text.Trim()) { & $add 'ai' $text }
                    }
                    elseif ($item['type'] -eq 'FileChange' -and $item['changes'] -is [Collections.IDictionary]) {
                        foreach ($key in @($item['changes'].Keys)) {
                            & $add 'file' (Format-FilePath ([string]$key) $cwd)
                            $change = $item['changes'][$key]
                            if ($change -is [Collections.IDictionary] -and $change['move_path']) {
                                & $add 'file' (Format-FilePath ([string]$change['move_path']) $cwd)
                            }
                        }
                    }
                }
                'response_item' {
                    if ($p['type'] -eq 'function_call' -and $p['name'] -eq 'request_user_input') {
                        $callArgs = $null
                        try { $callArgs = [string]$p['arguments'] | ConvertFrom-Json @JsonArgs } catch { $callArgs = $null }
                        if ($callArgs -is [Collections.IDictionary]) { $calls[[string]$p['call_id']] = @($callArgs['questions']) }
                    }
                    elseif ($p['type'] -eq 'function_call_output' -and $calls.ContainsKey([string]$p['call_id'])) {
                        $output = $p['output']
                        if ($output -is [Collections.IDictionary]) { $output = $output['content'] }
                        $answer = $null
                        try { $answer = [string]$output | ConvertFrom-Json @JsonArgs } catch { $answer = $null }
                        if ($answer -is [Collections.IDictionary] -and $answer['answers'] -is [Collections.IDictionary]) {
                            & $add 'choice' (Format-CodexChoice $calls[[string]$p['call_id']] $answer['answers'])
                        }
                    }
                    elseif ($p['type'] -eq 'message' -and $p['role'] -eq 'user') {
                        # 用户用 ! 直接跑的命令，以 <user_shell_command> 片段记在用户角色消息里
                        $text = Get-PartText $p['content']
                        if ($text -match '(?s)<user_shell_command>.*?<command>(.*?)</command>') {
                            & $add 'command' ('! ' + $Matches[1].Trim())
                        }
                    }
                }
            }
        }
        if ($emit) { $lastId = $id }
        $prevId = $id
        if ($ordinal -gt $maxOrdinal) { $maxOrdinal = $ordinal }
    }
    if ($start -gt $maxOrdinal) { Stop-Sync 1 "增量标记指向的位置 $start 不在当前会话记录里" }
    [pscustomobject]@{ Events = $events; LastId = $lastId }
}

function Get-CodexSessionKey {
    param($Records)
    $key = [string]$Records[0]['payload']['id']
    if (-not $key) { $key = $SessionId }
    if ($key -notmatch '^[0-9A-Za-z-]{8,64}$') { Stop-Sync 1 "线程 ID 格式不对：$key" }
    $key
}

# ---------------------------------------------------------------- 组装轮次

$TopLevelKinds = 'prompt', 'command', 'sync'
$UnitKinds = 'prompt', 'queued', 'choice', 'command', 'interrupt'

function Format-Time {
    param($Value)
    if ($null -eq $Value -or '' -eq $Value) { return '' }
    if ($Value -is [datetime]) {
        $utc = if ($Value.Kind -eq [DateTimeKind]::Unspecified) { [datetime]::SpecifyKind($Value, [DateTimeKind]::Utc) } else { $Value }
        return $utc.ToLocalTime().ToString('yyyy-MM-dd HH:mm')
    }
    try {
        [DateTimeOffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture).ToLocalTime().ToString('yyyy-MM-dd HH:mm')
    }
    catch { '' }
}

function Format-FilePath {
    # 工作目录下的文件显示相对路径，其余保留原样
    param([string] $Path, [string] $Cwd)
    if ($Cwd) {
        $root = $Cwd.TrimEnd('\', '/')
        foreach ($sep in '\', '/') {
            if ($Path.StartsWith("$root$sep", [StringComparison]::OrdinalIgnoreCase)) { return $Path.Substring($root.Length + 1) }
        }
    }
    $Path
}

function Build-Units {
    param($Events, [string] $LastId, [string] $CursorFrom)
    $units = [Collections.Generic.List[object]]::new()
    $current = $null
    $skipping = $false
    $syncPrev = $null
    $orphans = 0
    foreach ($ev in $Events) {
        if ($ev.Kind -in $TopLevelKinds) {
            # 同步命令那一轮整轮跳过，直到下一条顶层输入
            $skipping = $ev.Kind -eq 'sync'
            if ($skipping) {
                $syncPrev = $ev.PrevId
                $current = $null
            }
        }
        if ($skipping) { continue }
        if ($ev.Kind -in $UnitKinds) {
            $current = [ordered]@{
                id       = $units.Count + 1
                kind     = $ev.Kind
                time     = Format-Time $ev.Time
                user     = $ev.Text
                ai       = ''
                files    = [Collections.Generic.List[string]]::new()
                redacted = 0
            }
            $units.Add($current)
        }
        elseif ($null -eq $current) {
            $orphans++
        }
        elseif ($ev.Kind -eq 'ai') {
            $current.ai = if ($current.ai) { $current.ai + "`n`n" + $ev.Text } else { $ev.Text }
        }
        elseif ($ev.Kind -eq 'file' -and -not $current.files.Contains($ev.Text)) {
            $current.files.Add($ev.Text)
        }
    }
    # 停在正在执行的同步命令之前：这一轮下次同步时仍会被识别并跳过
    $cursorTo = if ($skipping) { $syncPrev } elseif ($LastId) { $LastId } else { $CursorFrom }
    if (-not $cursorTo) { $cursorTo = 'start' }
    [pscustomobject]@{ Units = $units; CursorTo = $cursorTo; Orphans = $orphans }
}

# ---------------------------------------------------------------- Markdown 章节

function Get-FenceMask {
    # 标出代码块内的行：里面的 # 和标记都不算数
    param([Collections.Generic.List[string]] $Lines)
    $mask = [bool[]]::new($Lines.Count)
    $fence = $null
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($fence) {
            $mask[$i] = $true
            if ($line -match '^ {0,3}(`{3,}|~{3,})\s*$' -and $Matches[1][0] -eq $fence[0] -and $Matches[1].Length -ge $fence.Length) { $fence = $null }
        }
        elseif ($line -match '^ {0,3}(`{3,}|~{3,})') {
            $mask[$i] = $true
            $fence = $Matches[1]
        }
    }
    , $mask
}

function Get-Headings {
    param([Collections.Generic.List[string]] $Lines)
    $mask = Get-FenceMask $Lines
    $headings = [Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($mask[$i]) { continue }
        if ($Lines[$i] -match '^ {0,3}(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$') {
            $text = if ($null -ne $Matches[2]) { $Matches[2].Trim() } else { '' }
            $headings.Add([pscustomobject]@{ Pos = $headings.Count; Index = $i; Level = $Matches[1].Length; Text = $text })
        }
    }
    , $headings
}

function Get-HeadingChain {
    # 返回 [根 ... 自身] 的标题文本：逐级向上找最近的更高级标题
    param($Headings, $Target)
    $chain = [Collections.Generic.List[string]]::new()
    $chain.Add($Target.Text)
    $level = $Target.Level
    for ($k = $Target.Pos - 1; $k -ge 0; $k--) {
        if ($Headings[$k].Level -lt $level) {
            $chain.Insert(0, $Headings[$k].Text)
            $level = $Headings[$k].Level
        }
    }
    , $chain
}

function Find-Heading {
    # 标题路径须与某个标题的祖先链末尾逐级相同（区分大小写）
    param($Headings, [string[]] $Segments)
    $hits = [Collections.Generic.List[object]]::new()
    foreach ($h in $Headings) {
        if ($h.Text -cne $Segments[-1]) { continue }
        $chain = Get-HeadingChain $Headings $h
        if ($chain.Count -lt $Segments.Count) { continue }
        $offset = $chain.Count - $Segments.Count
        $same = $true
        for ($s = 0; $s -lt $Segments.Count; $s++) {
            if ($chain[$offset + $s] -cne $Segments[$s]) { $same = $false; break }
        }
        if ($same) { $hits.Add($h) }
    }
    , $hits
}

function Stop-Ambiguous {
    param($Headings, $Hits)
    $paths = foreach ($h in $Hits) { "第 $($h.Index + 1) 行：" + ((Get-HeadingChain $Headings $h) -join '/') }
    Stop-Sync 3 ("标题路径匹配到多个标题，请改用更完整的路径：`n" + (@($paths) -join "`n"))
}

function Get-SectionEnd {
    param($Headings, $Target, [int] $LineCount)
    for ($k = $Target.Pos + 1; $k -lt $Headings.Count; $k++) {
        if ($Headings[$k].Level -le $Target.Level) { return $Headings[$k].Index }
    }
    $LineCount
}

function Add-BlockAt {
    # 插在 [Floor, End) 里最后一个非空行之后，前后各留一个空行
    param([Collections.Generic.List[string]] $Lines, [int] $Floor, [int] $End, [string[]] $Block)
    $pos = $End
    while ($pos -gt $Floor -and -not $Lines[$pos - 1].Trim()) { $pos-- }
    $insert = [Collections.Generic.List[string]]::new()
    if ($pos -gt 0) { $insert.Add('') }
    $insert.AddRange($Block)
    if ($pos -lt $Lines.Count -and $Lines[$pos].Trim()) { $insert.Add('') }
    $Lines.InsertRange($pos, $insert)
}

function Resolve-Section {
    param([Collections.Generic.List[string]] $Lines, [string[]] $Segments, [switch] $Create)
    $headings = Get-Headings $Lines
    $hits = Find-Heading $headings $Segments
    if ($hits.Count -gt 1) { Stop-Ambiguous $headings $hits }
    if ($hits.Count -eq 1) { return [pscustomobject]@{ Heading = $hits[0]; Created = @() } }
    if (-not $Create) { return $null }

    # 找已存在的最长前缀作父标题，其余层级在父章节末尾逐级新建
    $parent = $null
    $start = 0
    for ($k = $Segments.Count - 1; $k -ge 1; $k--) {
        $prefixHits = Find-Heading $headings @($Segments[0..($k - 1)])
        if ($prefixHits.Count -gt 1) { Stop-Ambiguous $headings $prefixHits }
        if ($prefixHits.Count -eq 1) {
            $parent = $prefixHits[0]
            $start = $k
            break
        }
    }
    $level = if ($parent) { $parent.Level + 1 } else { 2 }
    $missing = @($Segments[$start..($Segments.Count - 1)])
    if ($level + $missing.Count - 1 -gt 6) { Stop-Sync 1 "Markdown 标题最多 6 级，无法新建：$($missing -join '/')" }
    $block = [Collections.Generic.List[string]]::new()
    for ($m = 0; $m -lt $missing.Count; $m++) {
        if ($m -gt 0) { $block.Add('') }
        $block.Add(('#' * ($level + $m)) + ' ' + $missing[$m])
    }
    if ($parent) {
        Add-BlockAt $Lines ($parent.Index + 1) (Get-SectionEnd $headings $parent $Lines.Count) $block
    }
    else {
        Add-BlockAt $Lines 0 $Lines.Count $block
    }
    $hits = Find-Heading (Get-Headings $Lines) $Segments
    [pscustomobject]@{ Heading = $hits[0]; Created = $missing }
}

function Find-Markers {
    param([Collections.Generic.List[string]] $Lines, [int] $From, [int] $To, [string] $Session)
    $mask = Get-FenceMask $Lines
    $pattern = '^<!-- chat-sync:' + $SyncHost + ':' + [regex]::Escape($Session) + ':(\S+) -->$'
    $found = [Collections.Generic.List[object]]::new()
    for ($i = $From; $i -lt $To; $i++) {
        if (-not $mask[$i] -and $Lines[$i] -match $pattern) { $found.Add([pscustomobject]@{ Index = $i; Cursor = $Matches[1] }) }
    }
    , $found
}

function Read-Markdown {
    param([string] $Path)
    $bytes = [IO.File]::ReadAllBytes($Path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $offset = if ($bom) { 3 } else { 0 }
    $text = $Utf8NoBom.GetString($bytes, $offset, $bytes.Length - $offset)
    $newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = [Collections.Generic.List[string]]::new()
    if ($text.Length) {
        $parts = $text -split '\r?\n'
        # 文件末尾的换行会多切出一个空串
        $count = if ($parts.Count -gt 1 -and $parts[-1] -eq '') { $parts.Count - 1 } else { $parts.Count }
        for ($i = 0; $i -lt $count; $i++) { $lines.Add($parts[$i]) }
    }
    [pscustomobject]@{ Lines = $lines; Bom = $bom; Newline = $newline }
}

function Save-Markdown {
    param([string] $Path, $Doc)
    $text = ($Doc.Lines -join $Doc.Newline) + $Doc.Newline
    [IO.File]::WriteAllText($Path, $text, [Text.UTF8Encoding]::new($Doc.Bom))
}

function Split-HeadingPath {
    param([string] $Value)
    @($Value -split '/' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# ---------------------------------------------------------------- 渲染

$Labels = @{ prompt = '**我**'; queued = '**我（插话）**'; choice = '**我（选择）**'; command = '**我（命令）**' }

function Format-Block {
    param($Units, $Summaries)
    $lines = [Collections.Generic.List[string]]::new()
    $redactions = [Collections.Generic.List[string]]::new()
    foreach ($unit in $Units) {
        $id = [string]$unit['id']
        $time = [string]$unit['time']
        $stamp = if ($time) { " · $time" } else { '' }
        if ($unit['kind'] -eq 'interrupt') {
            $lines.Add("*[已中断]*$stamp")
        }
        else {
            $lines.Add("$($Labels[[string]$unit['kind']])$stamp")
            $lines.Add('')
            $user = [string]$unit['user']
            # 围栏比原话里最长的反引号串再长一截，原话才能一字不改地放进去
            $longest = 0
            foreach ($run in [regex]::Matches($user, '`+')) { $longest = [Math]::Max($longest, $run.Length) }
            $fence = '`' * [Math]::Max(3, $longest + 1)
            $lines.Add("${fence}text")
            foreach ($userLine in ($user -split '\r?\n')) { $lines.Add($userLine) }
            $lines.Add($fence)
        }
        $bullets = [Collections.Generic.List[string]]::new()
        $summaryRedacted = 0
        foreach ($point in @($Summaries[$id])) {
            if (-not $point) { continue }
            $safe = Protect-Secret (([string]$point -replace '\s*\r?\n\s*', ' ').Trim())
            $summaryRedacted += $safe.Count
            $bullets.Add("- $($safe.Text)")
        }
        $files = @($unit['files'] | Where-Object { $_ })
        if ($files.Count) { $bullets.Add('- 改动文件：' + (($files | ForEach-Object { "``$_``" }) -join '、')) }
        if ($bullets.Count) {
            $lines.Add('')
            $lines.Add('**AI**')
            $lines.Add('')
            foreach ($bullet in $bullets) { $lines.Add($bullet) }
        }
        $lines.Add('')
        $lines.Add('---')
        $lines.Add('')
        $total = [int]$unit['redacted'] + $summaryRedacted
        if ($total) { $redactions.Add("第 $id 轮（$time）$total 处") }
    }
    [pscustomobject]@{ Lines = $lines; Redactions = $redactions }
}

# ---------------------------------------------------------------- Export

function Resolve-SyncHost {
    if ($SyncHost -ne 'auto') { return $SyncHost }
    $claude = [bool]$env:CLAUDE_CODE_SESSION_ID
    $codex = [bool]$env:CODEX_THREAD_ID
    if ($claude -and -not $codex) { return 'claude' }
    if ($codex -and -not $claude) { return 'codex' }
    # 一个宿主里启动了另一个宿主时，两个变量会同时继承下来，只能让调用方说清楚
    $why = if ($claude) { '同时检测到 CLAUDE_CODE_SESSION_ID 和 CODEX_THREAD_ID' } else { '没有检测到 CLAUDE_CODE_SESSION_ID 或 CODEX_THREAD_ID' }
    Stop-Sync 1 "判断不出当前宿主（$why），请用 -SyncHost claude 或 -SyncHost codex 指定"
}

function Invoke-Export {
    if (-not $File) { Stop-Sync 1 '缺少 -File（目标 Markdown 文件）' }
    if (-not $Heading) { Stop-Sync 1 '缺少 -Heading（标题路径）' }
    $target = [IO.Path]::GetFullPath($File, (Get-Location).Path)
    if ([IO.Path]::GetExtension($target) -ne '.md') { Stop-Sync 1 "只支持 .md 文件：$target" }
    if (Test-Path -LiteralPath $target -PathType Container) { Stop-Sync 1 "目标是目录，不是文件：$target" }
    $segments = @(Split-HeadingPath $Heading)
    if ($segments.Count -eq 0) { Stop-Sync 1 "标题路径为空：$Heading" }

    $script:SyncHost = Resolve-SyncHost
    if (-not $SessionId) {
        $script:SessionId = if ($SyncHost -eq 'claude') { $env:CLAUDE_CODE_SESSION_ID } else { $env:CODEX_THREAD_ID }
    }
    $isClaude = $SyncHost -eq 'claude'
    $transcriptPath = if ($isClaude) { Find-ClaudeTranscript } else { Find-CodexTranscript }
    $records = Read-JsonLines $transcriptPath
    if (-not $records.Count) { Stop-Sync 2 "会话记录是空的：$transcriptPath" }
    $session = if ($isClaude) { Get-ClaudeSessionKey $transcriptPath } else { Get-CodexSessionKey $records }

    $cursorFrom = $null
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $doc = Read-Markdown $target
        $section = Resolve-Section $doc.Lines $segments
        if ($section) {
            $h = $section.Heading
            $headings = Get-Headings $doc.Lines
            $markers = Find-Markers $doc.Lines ($h.Index + 1) (Get-SectionEnd $headings $h $doc.Lines.Count) $session
            if ($markers.Count) { $cursorFrom = $markers[-1].Cursor }
        }
    }

    $parsed = if ($isClaude) { Get-ClaudeEvents $records $cursorFrom } else { Get-CodexEvents $records $cursorFrom }
    $built = Build-Units $parsed.Events $parsed.LastId $cursorFrom
    foreach ($unit in $built.Units) {
        $user = Protect-Secret $unit.user
        $ai = Protect-Secret $unit.ai
        $unit.user = $user.Text
        $unit.ai = $ai.Text
        $unit.redacted = $user.Count + $ai.Count
    }

    if (-not $OutFile) {
        $OutFile = Join-Path (Join-Path ([IO.Path]::GetTempPath()) 'chat-sync') "$SyncHost-$session.json"
    }
    $OutFile = [IO.Path]::GetFullPath($OutFile, (Get-Location).Path)
    $summaryPath = [IO.Path]::ChangeExtension($OutFile, '.summaries.json')
    $outDir = Split-Path -Parent $OutFile
    if (-not (Test-Path -LiteralPath $outDir)) { $null = New-Item -ItemType Directory -Path $outDir -Force }
    # 上一次同步留下的要点文件不能被误用
    if (Test-Path -LiteralPath $summaryPath -PathType Leaf) { Remove-Item -LiteralPath $summaryPath -Force }

    $export = [ordered]@{
        version     = 1
        host        = $SyncHost
        sessionId   = $session
        transcript  = $transcriptPath
        file        = $target
        heading     = $segments -join '/'
        segments    = $segments
        cursorFrom  = $cursorFrom
        cursorTo    = $built.CursorTo
        summaryFile = $summaryPath
        units       = $built.Units
    }
    [IO.File]::WriteAllText($OutFile, ($export | ConvertTo-Json -Depth 10), $Utf8NoBom)

    $needs = @($built.Units | Where-Object { $_.ai.Trim() } | ForEach-Object { $_.id })
    Write-Output "导出文件：$OutFile"
    Write-Output "要点文件：$summaryPath"
    Write-Output "新轮次：$($built.Units.Count) 轮；需要压缩 AI 回复的轮次：$(if ($needs.Count) { $needs -join ', ' } else { '无' })"
    if ($built.Orphans) { Write-Output "提示：有 $($built.Orphans) 段 AI 回复前面没有用户输入，已忽略" }
}

# ---------------------------------------------------------------- Write

function Invoke-Write {
    if (-not $ExportFile -or -not (Test-Path -LiteralPath $ExportFile -PathType Leaf)) { Stop-Sync 1 "找不到导出文件：$ExportFile" }
    $export = Get-Content -LiteralPath $ExportFile -Raw -Encoding utf8 | ConvertFrom-Json @JsonArgs
    $exportHost = [string]$export['host']
    if ($exportHost -notin 'claude', 'codex') { Stop-Sync 1 "导出文件里的宿主无法识别：$exportHost" }
    if ($SyncHost -ne 'auto' -and $SyncHost -ne $exportHost) { Stop-Sync 1 "导出文件来自 $exportHost，不是 $SyncHost" }
    $script:SyncHost = $exportHost
    $session = [string]$export['sessionId']
    $units = @($export['units'])

    $summaryPath = if ($SummaryFile) { $SummaryFile } else { [string]$export['summaryFile'] }
    $summaries = @{}
    if ($summaryPath -and (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
        $raw = Get-Content -LiteralPath $summaryPath -Raw -Encoding utf8
        if ($raw -and $raw.Trim()) {
            try { $summaries = $raw | ConvertFrom-Json @JsonArgs }
            catch { Stop-Sync 1 "要点文件不是合法 JSON：$summaryPath" }
            if ($summaries -isnot [Collections.IDictionary]) { Stop-Sync 1 "要点文件应是 {""轮次id"": [""要点"", ...]} 形式：$summaryPath" }
        }
    }
    $missing = @($units | Where-Object {
            ([string]$_['ai']).Trim() -and -not @(@($summaries[[string]$_['id']]) | Where-Object { $_ }).Count
        } | ForEach-Object { $_['id'] })
    if ($missing.Count) { Stop-Sync 1 "这些轮次有 AI 回复但没有要点：$($missing -join ', ')（要点文件：$summaryPath）" }

    $target = [string]$export['file']
    $segments = @($export['segments'])
    $createdFile = -not (Test-Path -LiteralPath $target -PathType Leaf)
    if ($createdFile) {
        $doc = [pscustomobject]@{ Lines = [Collections.Generic.List[string]]::new(); Bom = $false; Newline = "`n" }
    }
    else {
        $doc = Read-Markdown $target
    }

    $section = Resolve-Section $doc.Lines $segments -Create
    $h = $section.Heading
    $markers = Find-Markers $doc.Lines ($h.Index + 1) (Get-SectionEnd (Get-Headings $doc.Lines) $h $doc.Lines.Count) $session
    $current = if ($markers.Count) { $markers[-1].Cursor } else { $null }
    if ([string]$current -ne [string]$export['cursorFrom']) {
        Stop-Sync 4 '目标章节在导出之后被另一次同步更新过，请重新导出'
    }
    $cursorTo = [string]$export['cursorTo']
    if (-not $units.Count -and $current -eq $cursorTo -and -not $createdFile -and -not $section.Created.Count) {
        Write-Output "没有新内容：$target（$($segments -join '/')）"
        return
    }

    # 旧标记从后往前删，删后若留下连续空行收掉一个
    for ($m = $markers.Count - 1; $m -ge 0; $m--) {
        $index = $markers[$m].Index
        $doc.Lines.RemoveAt($index)
        if ($index -gt 0 -and $index -lt $doc.Lines.Count -and -not $doc.Lines[$index - 1].Trim() -and -not $doc.Lines[$index].Trim()) {
            $doc.Lines.RemoveAt($index)
        }
    }
    $h = (Resolve-Section $doc.Lines $segments).Heading
    $end = Get-SectionEnd (Get-Headings $doc.Lines) $h $doc.Lines.Count

    $rendered = Format-Block $units $summaries
    $block = [Collections.Generic.List[string]]::new()
    foreach ($line in $rendered.Lines) { $block.Add($line) }
    $block.Add("<!-- chat-sync:${SyncHost}:${session}:$cursorTo -->")
    Add-BlockAt $doc.Lines ($h.Index + 1) $end $block

    if ($createdFile) {
        $dir = Split-Path -Parent $target
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
    }
    Save-Markdown $target $doc

    $kinds = [ordered]@{ prompt = '原话'; queued = '插话'; choice = '选择'; command = '命令'; interrupt = '中断' }
    $counts = foreach ($k in $kinds.Keys) {
        $n = @($units | Where-Object { $_['kind'] -eq $k }).Count
        if ($n) { "$($kinds[$k]) $n" }
    }
    Write-Output ("已写入：$target" + $(if ($createdFile) { '（新建文件）' } else { '' }))
    Write-Output ("章节：$($segments -join '/')" + $(if ($section.Created.Count) { "（新建标题：$($section.Created -join '/')）" } else { '' }))
    Write-Output ("新增：$($units.Count) 轮" + $(if ($counts) { "（$(@($counts) -join '、')）" } else { '' }))
    Write-Output ("打码：" + $(if ($rendered.Redactions.Count) { $rendered.Redactions -join '；' } else { '无' }))
}

if ($Mode -eq 'Export') { Invoke-Export } else { Invoke-Write }
exit 0
