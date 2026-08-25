<#
.SYNOPSIS
    Mermaid 图集结构校验（零依赖）。

.DESCRIPTION
    用途：递归扫描目录（或单个 .md 文件）里的 ```mermaid 代码块，做结构校验。
          不做完整语法解析（那需要渲染引擎），但能抓住约 90% 的实际错误。

    检查项：
      fence   代码栏未闭合
      header  首行不是可识别的 Mermaid 图种声明
      block   subgraph / alt / opt / loop / par / critical / rect / box / note 与 end 未配对
      brace   classDiagram / stateDiagram 的花括号未配平
      pipe    flowchart 边标签竖线数为奇数（漏写一侧竖线）
      label   flowchart 节点标签内有未加引号的括号 / 花括号
      nodeid  flowchart 节点 id 含中文或全角字符
      endkw   flowchart 里把小写 end 当节点用（必然渲染失败）

    输入：
      -Path    必填。目录或单个 .md 文件。
      -Strict  可选。把 WARNING 也计入失败。
      -Quiet   可选。只输出汇总行，不逐条列出。

    退出码：
      0  无 ERROR（-Strict 时还需无 WARNING）
      1  发现 ERROR（或 -Strict 下发现 WARNING）
      2  参数或路径错误

.EXAMPLE
    pwsh -NoProfile -File Check-Mermaid.ps1 -Path ./docs/diagrams

.EXAMPLE
    pwsh -NoProfile -File Check-Mermaid.ps1 -Path ./docs/diagrams/project/01-架构与结构.md -Strict
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Path,

    [switch]$Strict,

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- 结果收集

$script:Findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param(
        [string]$File,
        [int]$Line,
        [ValidateSet('ERROR', 'WARN')][string]$Level,
        [string]$Rule,
        [string]$Message
    )
    $script:Findings.Add([pscustomobject]@{
            File    = $File
            Line    = $Line
            Level   = $Level
            Rule    = $Rule
            Message = $Message
        })
}

# ---------------------------------------------------------------- 代码栏提取

# 按 CommonMark 围栏规则提取 mermaid 块：N 个反引号开栏，需 >=N 个同字符收栏。
# 这样 ````markdown 里嵌套的 ```mermaid 会被正确当作外层围栏的内容跳过。
function Get-MermaidBlock {
    param([string[]]$Lines, [string]$File)

    $blocks = [System.Collections.Generic.List[object]]::new()
    $fenceChar = $null
    $fenceLen = 0
    $isMermaid = $false
    $startLine = 0
    $buf = $null

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]

        if ($null -eq $fenceChar) {
            if ($line -match '^\s*(`{3,}|~{3,})\s*([A-Za-z0-9_+.-]*)\s*$') {
                $fenceChar = $Matches[1][0]
                $fenceLen = $Matches[1].Length
                $isMermaid = ($Matches[2].ToLowerInvariant() -eq 'mermaid')
                $startLine = $i + 2      # 块体第一行的 1-based 行号
                $buf = [System.Collections.Generic.List[string]]::new()
            }
            continue
        }

        # 收栏：同字符且长度不短于开栏
        $closePattern = '^\s*' + [regex]::Escape([string]$fenceChar) + "{$fenceLen,}\s*`$"
        if ($line -match $closePattern) {
            if ($isMermaid) {
                $blocks.Add([pscustomobject]@{ StartLine = $startLine; Body = $buf.ToArray() })
            }
            $fenceChar = $null; $fenceLen = 0; $isMermaid = $false; $buf = $null
            continue
        }

        if ($isMermaid) { $buf.Add($line) }
    }

    if ($null -ne $fenceChar) {
        $lvl = if ($isMermaid) { 'ERROR' } else { 'WARN' }
        $what = if ($isMermaid) { '```mermaid' } else { '代码栏' }
        Add-Finding -File $File -Line $startLine -Level $lvl -Rule 'fence' `
            -Message "$what 未闭合（文件结束前没有收尾的围栏）"
    }

    return $blocks
}

# ---------------------------------------------------------------- 辅助

# 去掉 %% 注释与双引号包裹的内容，避免注释/标签里的字符干扰结构判断
function Get-CleanLine {
    param([string]$Raw)
    $t = $Raw -replace '%%.*$', ''
    return $t.Trim()
}

function Remove-QuotedText {
    param([string]$Text)
    return ([regex]::Replace($Text, '"[^"]*"', '""'))
}

function Get-DiagramType {
    param([string[]]$Body)

    $skippingFrontMatter = $false
    foreach ($raw in $Body) {
        $t = Get-CleanLine $raw
        if (-not $t) { continue }

        # mermaid 块内可带 --- YAML --- 配置头，跳过
        if ($t -eq '---') { $skippingFrontMatter = -not $skippingFrontMatter; continue }
        if ($skippingFrontMatter) { continue }

        switch -Regex ($t) {
            '^(flowchart|graph)\b' { return 'flowchart' }
            '^sequenceDiagram\b' { return 'sequence' }
            '^stateDiagram(-v2)?\b' { return 'state' }
            '^classDiagram(-v2)?\b' { return 'class' }
            '^erDiagram\b' { return 'er' }
            '^(mindmap|timeline|gitGraph|gantt|pie|journey|quadrantChart|requirementDiagram|C4Context|C4Container|C4Component|C4Deployment|C4Dynamic|sankey-beta|xychart-beta|block-beta|architecture-beta|packet-beta|kanban|radar|treemap|zenuml)\b' { return 'other' }
            default { return 'unknown' }
        }
    }
    return 'empty'
}

# ---------------------------------------------------------------- 单块校验

$script:ArrowPattern = '(-{2,}>|={2,}>|-\.{1,}->|-{2,}x|-{2,}o|-{3,}|={3,}|<-{2,}>)'

function Test-MermaidBlock {
    param([string]$File, [int]$StartLine, [string[]]$Body)

    $type = Get-DiagramType -Body $Body

    if ($type -eq 'empty') {
        Add-Finding -File $File -Line $StartLine -Level 'WARN' -Rule 'header' -Message '空的 mermaid 代码块'
        return
    }
    if ($type -eq 'unknown') {
        Add-Finding -File $File -Line $StartLine -Level 'ERROR' -Rule 'header' `
            -Message '首行不是可识别的 Mermaid 图种声明（flowchart / sequenceDiagram / stateDiagram-v2 / classDiagram / erDiagram …）'
        return
    }

    $stack = [System.Collections.Generic.List[object]]::new()
    $braceDepth = 0
    $inFrontMatter = $false

    for ($i = 0; $i -lt $Body.Count; $i++) {
        $ln = $StartLine + $i
        $t = Get-CleanLine $Body[$i]
        if (-not $t) { continue }

        if ($t -eq '---') { $inFrontMatter = -not $inFrontMatter; continue }
        if ($inFrontMatter) { continue }

        $noQuote = Remove-QuotedText $t

        # --- 块配对 -------------------------------------------------
        switch ($type) {
            'flowchart' {
                # 关键字一律区分大小写：mermaid 的 end/subgraph 是小写关键字，
                # 大写的 END 是合法节点 id，不能被当成块结束符。
                if ($noQuote -cmatch '^subgraph\b') {
                    $stack.Add([pscustomobject]@{ Kind = 'subgraph'; Line = $ln })
                }
                elseif ($noQuote -ceq 'end') {
                    if ($stack.Count -eq 0) {
                        Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'block' -Message '多余的 end（没有对应的 subgraph）'
                    }
                    else { $stack.RemoveAt($stack.Count - 1) }
                }
            }
            'sequence' {
                if ($noQuote -cmatch '^(alt|opt|loop|par|critical|rect|box)\b') {
                    $stack.Add([pscustomobject]@{ Kind = $Matches[1]; Line = $ln })
                }
                elseif ($noQuote -cmatch '^(else|and|option)\b') {
                    if ($stack.Count -eq 0) {
                        Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'block' `
                            -Message "$($Matches[1]) 没有对应的 alt / par / critical 块"
                    }
                }
                elseif ($noQuote -ceq 'end') {
                    if ($stack.Count -eq 0) {
                        Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'block' -Message '多余的 end（没有对应的 alt / opt / loop / par / critical / rect / box）'
                    }
                    else { $stack.RemoveAt($stack.Count - 1) }
                }
            }
            'state' {
                # note 块：带冒号是单行，不带冒号需 end note 收尾
                if ($noQuote -cmatch '^note\b' -and $noQuote -notmatch ':') {
                    $stack.Add([pscustomobject]@{ Kind = 'note'; Line = $ln })
                }
                elseif ($noQuote -cmatch '^end\s+note\b') {
                    if ($stack.Count -eq 0) {
                        Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'block' -Message '多余的 end note'
                    }
                    else { $stack.RemoveAt($stack.Count - 1) }
                }
                else {
                    $braceDepth += ([regex]::Matches($noQuote, '\{')).Count
                    $braceDepth -= ([regex]::Matches($noQuote, '\}')).Count
                }
            }
            'class' {
                $braceDepth += ([regex]::Matches($noQuote, '\{')).Count
                $braceDepth -= ([regex]::Matches($noQuote, '\}')).Count
            }
        }

        if ($braceDepth -lt 0) {
            Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'brace' -Message '花括号多出一个 }（未配平）'
            $braceDepth = 0
        }

        # --- flowchart 专项 ------------------------------------------
        if ($type -ne 'flowchart') { continue }

        # 竖线成对：边标签写成 A -->|标签| B，漏一侧就是奇数
        $pipeCount = ([regex]::Matches($t, '\|')).Count
        if ($pipeCount % 2 -ne 0) {
            Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'pipe' `
                -Message "边标签竖线数为奇数（$pipeCount 个），多半漏写了一侧的 |"
        }

        # 小写 end 当节点用：flowchart 里 end 是块结束符，必然渲染失败
        if ($t -match $script:ArrowPattern -and $t -cmatch '(^|\s)end(\s|$)') {
            Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'endkw' `
                -Message '把小写 end 当节点用了；flowchart 里 end 是块结束符，改成 END 或其他 id'
        }

        # 节点标签内未加引号的括号 / 花括号
        foreach ($m in [regex]::Matches($t, '\[([^\[\]"]*)\]')) {
            $inner = $m.Groups[1].Value
            $inner = $inner -replace '^\((.*)\)$', '$1'          # [( )] 圆柱
            $inner = $inner -replace '^[/\\](.*)[/\\]$', '$1'    # [/ /] 平行四边形 / 梯形
            if ($inner -match '[\(\)\{\}]') {
                Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'label' `
                    -Message "节点标签里有未加引号的括号：[$($m.Groups[1].Value)]；整体加双引号即可"
            }
        }

        # 节点 id 含中文 / 全角字符（id 必须是 ASCII，中文放标签里）
        foreach ($m in [regex]::Matches($noQuote, '([^\s\[\]\(\)\{\}<>|"=:;,.\-]+)\s*[\[\(\{]')) {
            $id = $m.Groups[1].Value
            if ($id -match '[　-〿一-鿿＀-￯]') {
                Add-Finding -File $File -Line $ln -Level 'ERROR' -Rule 'nodeid' `
                    -Message "节点 id 含中文或全角字符：`"$id`"；id 用 ASCII，中文写进标签"
            }
        }
    }

    # --- 收尾：未闭合的块 --------------------------------------------
    foreach ($open in $stack) {
        Add-Finding -File $File -Line $open.Line -Level 'ERROR' -Rule 'block' `
            -Message "$($open.Kind) 没有对应的 end"
    }
    if ($braceDepth -gt 0) {
        Add-Finding -File $File -Line $StartLine -Level 'ERROR' -Rule 'brace' `
            -Message "花括号少了 $braceDepth 个 }（未配平）"
    }
}

# ---------------------------------------------------------------- 主流程

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "路径不存在：$Path" -ForegroundColor Red
    exit 2
}

$item = Get-Item -LiteralPath $Path
if ($item.PSIsContainer) {
    $files = Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.md'
}
elseif ($item.Extension -eq '.md') {
    $files = @($item)
}
else {
    Write-Host "只支持目录或 .md 文件，收到：$Path" -ForegroundColor Red
    exit 2
}

if ($files.Count -eq 0) {
    Write-Host "未找到任何 .md 文件：$Path" -ForegroundColor Yellow
    exit 0
}

$blockCount = 0
foreach ($f in $files) {
    $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
    if ($null -eq $lines) { continue }
    if ($lines -isnot [array]) { $lines = @($lines) }

    $rel = try { Resolve-Path -LiteralPath $f.FullName -Relative } catch { $f.FullName }

    foreach ($block in (Get-MermaidBlock -Lines $lines -File $rel)) {
        $blockCount++
        Test-MermaidBlock -File $rel -StartLine $block.StartLine -Body $block.Body
    }
}

$errors = @($script:Findings | Where-Object { $_.Level -eq 'ERROR' })
$warns = @($script:Findings | Where-Object { $_.Level -eq 'WARN' })

if (-not $Quiet -and $script:Findings.Count -gt 0) {
    foreach ($fd in ($script:Findings | Sort-Object File, Line)) {
        $color = if ($fd.Level -eq 'ERROR') { 'Red' } else { 'Yellow' }
        Write-Host ("{0}:{1}  [{2}] {3}  {4}" -f $fd.File, $fd.Line, $fd.Level, $fd.Rule, $fd.Message) -ForegroundColor $color
    }
    Write-Host ''
}

$summary = "扫描 $($files.Count) 个文件，$blockCount 个 mermaid 块：$($errors.Count) 个 ERROR，$($warns.Count) 个 WARN"

if ($errors.Count -gt 0) {
    Write-Host $summary -ForegroundColor Red
    exit 1
}
if ($Strict -and $warns.Count -gt 0) {
    Write-Host "$summary（-Strict：WARNING 计入失败）" -ForegroundColor Yellow
    exit 1
}

Write-Host $summary -ForegroundColor Green
exit 0
