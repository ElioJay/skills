# This test verifies the project-level skill contract without scanning real secrets.
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$skillRoot = Join-Path $repoRoot ".claude\skills\audit-remote-secret-leaks"
$skillPath = Join-Path $skillRoot "SKILL.md"
$patternsPath = Join-Path $skillRoot "references\sensitive-patterns.md"
$templatePath = Join-Path $skillRoot "references\report-template.md"
$readmePath = Join-Path $repoRoot "README.md"

$failures = New-Object System.Collections.Generic.List[string]

function Assert-FileExists {
    param(
        [string] $Path,
        [string] $Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $failures.Add("Missing $Label at $Path")
    }
}

function Assert-Contains {
    param(
        [string] $Text,
        [string] $Pattern,
        [string] $Label
    )

    if ($Text -notmatch $Pattern) {
        $failures.Add("Missing content: $Label")
    }
}

Assert-FileExists -Path $skillPath -Label "SKILL.md"
Assert-FileExists -Path $patternsPath -Label "sensitive pattern reference"
Assert-FileExists -Path $templatePath -Label "report template reference"

if (Test-Path -LiteralPath $skillPath -PathType Leaf) {
    $skill = Get-Content -LiteralPath $skillPath -Raw -Encoding UTF8
    Assert-Contains -Text $skill -Pattern "(?m)^name:\s*audit-remote-secret-leaks\s*$" -Label "skill name frontmatter"
    Assert-Contains -Text $skill -Pattern "(?m)^description:\s*" -Label "description frontmatter"
    Assert-Contains -Text $skill -Pattern "Remote history audit" -Label "remote git history audit section"
    Assert-Contains -Text $skill -Pattern "Unpushed content statistics" -Label "unpushed content statistics section"
    Assert-Contains -Text $skill -Pattern "General remediation" -Label "general remediation section"
    Assert-Contains -Text $skill -Pattern "git fetch" -Label "remote refresh command guidance"
    Assert-Contains -Text $skill -Pattern "--force-with-lease" -Label "safe force push guidance"
    Assert-Contains -Text $skill -Pattern "references/sensitive-patterns.md" -Label "sensitive patterns reference link"
    Assert-Contains -Text $skill -Pattern "references/report-template.md" -Label "report template reference link"
    Assert-Contains -Text $skill -Pattern "refs/tags" -Label "remote tag coverage"
    Assert-Contains -Text $skill -Pattern "git stash list" -Label "stash coverage"
    Assert-Contains -Text $skill -Pattern "git ls-files --others --ignored --exclude-standard" -Label "ignored local file coverage"
    Assert-Contains -Text $skill -Pattern "Git LFS" -Label "Git LFS coverage"
    Assert-Contains -Text $skill -Pattern "git submodule" -Label "submodule coverage"
    Assert-Contains -Text $skill -Pattern "Do not validate live secrets" -Label "live secret validation boundary"
    Assert-Contains -Text $skill -Pattern "sanitized scanner output" -Label "scanner output sanitization"
}

if (Test-Path -LiteralPath $patternsPath -PathType Leaf) {
    $patterns = Get-Content -LiteralPath $patternsPath -Raw -Encoding UTF8
    foreach ($keyword in @("API Key", "Private key", "Token", "Password", "PII", "Internal address", "OpenAI", "Slack", "DingTalk", "Feishu")) {
        Assert-Contains -Text $patterns -Pattern $keyword -Label "pattern keyword $keyword"
    }
}

if (Test-Path -LiteralPath $templatePath -PathType Leaf) {
    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    foreach ($section in @("Audit summary", "Remote history findings", "Unpushed content statistics", "General remediation", "Sanitized evidence policy", "Remote tag scope", "Local stash and ignored files")) {
        Assert-Contains -Text $template -Pattern $section -Label "template section $section"
    }
}

if (Test-Path -LiteralPath $readmePath -PathType Leaf) {
    $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
    Assert-Contains -Text $readme -Pattern "audit-remote-secret-leaks" -Label "README skill registration"
    Assert-Contains -Text $readme -Pattern "### security" -Label "README security category"
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}

Write-Output "audit-remote-secret-leaks skill checks passed"
