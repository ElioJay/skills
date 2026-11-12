---
name: chat-sync
description: 把当前会话的对话增量同步到用户指定 Markdown 文件里的指定标题（章节）下，写成编号问答：「问」是用户发的话，逐字写入（只把疑似密钥、令牌、口令打码），「答」是压缩成一段话的 AI 回复。用户输入 /chat-sync <文件> <标题路径>（Claude Code、DeepSeek Harness）、$chat-sync <文件> <标题路径>（Codex）或 /skill:chat-sync <文件> <标题路径>（pi）时使用，仅手动调用。不要用于：① 只想让 AI 总结或回顾刚才聊了什么、不写文件（直接回答）；② 把对话导出成 Word 或 PDF（用 docx / pdf）；③ 把讨论结论整理成正式的调研或设计文档（用 research）；④ 多步骤任务的计划与进度跟踪（用 planning-with-files-zh）。
argument-hint: <文件路径> <标题路径，如 项目A/讨论记录>
disable-model-invocation: true
---

# 同步对话到 Markdown

用户的输入：用户在 `/chat-sync`（Claude Code、DeepSeek Harness）、`$chat-sync`（Codex）或 `/skill:chat-sync`（pi）后面写的内容。Claude Code 会把这段内容附在本文末尾的 `ARGUMENTS:` 之后；其他宿主里，它就在用户那条消息里。

把当前会话里还没同步过的对话，以编号问答的形式追加到目标文件指定章节的末尾：问是用户的原话，逐字写入；答是压缩成一段话的 AI 回复。读记录、定位章节、打码、写入都由 `scripts/Sync-Chat.ps1` 完成。你只负责拆参数、压缩 AI 回复和转述结果，不要自己动手编辑目标文件。

下文的「提问工具」指宿主的交互式提问工具：Claude Code 用 AskUserQuestion，Codex 用 request_user_input，DeepSeek Harness 用 ask_user_question。pi 没有提问工具，就在回复里列出选项直接问用户，等用户回答后再继续。命令里的 `<skill-dir>` 是本 SKILL.md 所在的目录（Claude Code 里是 `${CLAUDE_SKILL_DIR}`，其他宿主载入本技能时会给出它的位置）。

## 第一步：拆参数

- 从用户的输入里拆出两个参数：目标文件路径，以及标题路径。标题路径用 `/` 分隔层级，比如 `项目A/讨论记录`；只写最后一级也行。路径里有空格时，用户会加引号。
- 缺任何一个参数，或者文件不是 `.md`，就用提问工具问用户，不要猜。

## 第二步：导出新内容

在 shell 里运行与当前宿主对应的那条命令。参数用单引号包住，参数里本身的单引号写成两个单引号：

```powershell
# Claude Code
pwsh -NoProfile -File '<skill-dir>/scripts/Sync-Chat.ps1' -Mode Export -SyncHost claude -File '<文件>' -Heading '<标题路径>' -SessionId '${CLAUDE_SESSION_ID}'

# Codex：脚本通过 Codex 注入的环境变量 CODEX_THREAD_ID 找到当前会话，不需要另外传会话 ID
pwsh -NoProfile -File '<skill-dir>/scripts/Sync-Chat.ps1' -Mode Export -SyncHost codex -File '<文件>' -Heading '<标题路径>'

# pi：脚本通过 pi 注入的环境变量 PI_SESSION_ID、PI_SESSION_FILE 找到当前会话
pwsh -NoProfile -File '<skill-dir>/scripts/Sync-Chat.ps1' -Mode Export -SyncHost pi -File '<文件>' -Heading '<标题路径>'

# DeepSeek Harness：脚本通过环境变量 DSH_SESSION_ID 找到当前会话；压缩的记录由 scripts/read-dsh-session.mjs 用 Node.js 解压
pwsh -NoProfile -File '<skill-dir>/scripts/Sync-Chat.ps1' -Mode Export -SyncHost dsh -File '<文件>' -Heading '<标题路径>'
```

按退出码处理：

- **0**：输出里有导出文件、要点文件的路径，以及哪些轮次需要压缩。
- **3**：标题路径匹配到了多个标题，stderr 里列出了各个候选的完整路径。用提问工具让用户选一个，再用选中的完整路径重新导出。
- **1 或 2**：把错误原样告诉用户，然后停止。

## 第三步：压缩 AI 回复

读导出文件。`units` 里的每一轮都有这些字段：`user`（原话）、`ai`（AI 回复正文）、`choices`（提问工具里的回答，脚本已排好格式）、`interrupted`（是否被中断）、`files`（改动的文件）。`user`、`ai`、`choices` 都已经打过码。

对 `ai` 不为空的每一轮写一段「答」：

- 写成一段话，不分条。先说结论或做了什么，再补必要的细节，比如关键的文件、命令、数字、还没做的事。一般一两句，内容多的轮次可以多写几句，但不要写成清单。
- 只依据 `ai` 里写了的内容，不补充原文没有的事实，也不要凭你对这次对话的记忆补全。`files` 里的文件只在重要时点名。
- 语言跟 `ai` 原文保持一致。不写代码块，文件名、命令、标识符用行内代码。不把密钥或令牌写进答里。
- 不复述 `choices`，也不写“已中断”：这两样脚本会单独写。
- 不改 `user`，也不要把原话抄进答里。

把答写进导出输出给出的要点文件，格式是 `{"1": "一段话", "3": "一段话"}`，键是轮次的 `id`。没有需要压缩的轮次时，写 `{}`。轮次很多时，可以分批读导出文件，最后合并成一个要点文件。

## 第四步：写入

```powershell
pwsh -NoProfile -File '<skill-dir>/scripts/Sync-Chat.ps1' -Mode Write -ExportFile '<导出文件>'
```

宿主由导出文件决定，这一步各宿主命令相同。在 Codex 里，目标文件不在可写的工作区时沙箱会拦住写入，按 Codex 的审批流程申请提权后重跑这条命令。

- **0**：把脚本的报告转述给用户，包括写到了哪个文件和章节、新增了几条（第几条到第几条）、新建了哪些文件或标题、哪几条打了码。
- **4**：目标章节在这次导出之后又被同步过。回到第二步重新导出。
- **1**：把错误原样告诉用户。如果是缺要点，补齐要点文件后再写一次。

## 脚本保证的规则

下面这些规则由脚本执行，你不需要手工处理，回答用户的疑问时以此为准：

- **同步范围**：只同步当前会话，从目标章节里本会话的隐藏标记 `<!-- chat-sync:<宿主>:<会话ID>:<位置> -->` 之后开始（宿主是 `claude`、`codex`、`pi` 或 `dsh`）；章节里没有这个标记，就从会话开头写起。执行 /chat-sync、$chat-sync 或 /skill:chat-sync 的那一轮整轮跳过。
- **pi 的分支**：只同步当前分支。用 /tree 切换过分支、标记落在已离开的分支上时，从它与当前分支的分叉点之后续写，已经写进文件的旧分支内容保留不动，脚本会提示这一点。
- **输出格式**：每轮写成一条编号问答，不记时间。

  ```markdown
  **对话记录**（问为原文，答为压缩后的回复）

  1. **问**：用户的原话

     **答**：压缩后的一段话

     **选择**：短标题＝「选项」；短标题＝「选项」。
  ```

  - 编号接着章节里上一条问答往下加。章节里还没有问答时，先写上面那行标题。
  - 插话写成「**插话**」，`!` 命令写成「**命令**」，各占一条。被中断的轮次在答的末尾标「（已中断）」；记录里没有回复的轮次，答写「（记录里没有回复）」。
  - 选择用提问工具里每个问题的短标题（没有短标题时用问题原文），并入所在的那一条。
  - 旧版本写的「我 / AI」格式内容保持原样，新内容接在后面。
- **原话**：逐字写入。单行原话直接接在「问」后面；多行原话放进代码块，原话里有反引号时围栏会自动加长。只有疑似密钥、令牌、口令会被替换成 `***REDACTED***`。
- **收录哪些内容**：
  - 收录：直接输入的消息、AI 工作时的插话、提问工具里的回答、`!` 命令（只记命令行）、中断。
  - 不收录：宿主注入的内容（如 system-reminder、AGENTS.md、环境上下文）、工具结果、skill 正文、上下文压缩摘要。
  - Codex Desktop 里“提到的文件”会写成 `[附件: 路径]` 占位。
- **写入位置**：
  - 追加在章节末尾，也就是下一个同级或更高级标题之前，章节里已有的内容不动。
  - 标题不存在就在父章节末尾逐级新建；连父标题都没有时，建成 `##`。
  - 文件不存在就连同上级目录一起新建。
- **记录本身的局限**：
  - 会话记录写入有延迟，个别回复的正文可能没写进记录。这种轮次的答是「（记录里没有回复）」。
  - Codex 只支持当前版本的 paginated 记录格式。旧的 legacy 格式和 `.jsonl.zst` 压缩记录都会直接报错。
  - 导出里的 `files`：Codex 只统计 apply_patch 这类文件变更，通过 shell 命令改的文件不在里面；pi 和 DeepSeek Harness 只统计 edit、write 工具改的文件。
  - pi 只支持第 3 版会话记录，提示模板（`/模板名`）在记录里已经展开，写入的是展开后的文本。
  - DeepSeek Harness 只支持第 4 版会话记录。记录默认是 zstd 压缩的，解压要用 Node.js 22.15 或更新版本，找不到 node 时会直接报错。
