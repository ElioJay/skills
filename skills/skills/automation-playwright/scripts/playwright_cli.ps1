[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArguments
)

$ErrorActionPreference = 'Stop'

$npxCommand = Get-Command npx.cmd -ErrorAction SilentlyContinue
if (-not $npxCommand) {
    $npxCommand = Get-Command npx -ErrorAction SilentlyContinue
}
if (-not $npxCommand) {
    Write-Error 'npx is required but was not found on PATH.'
    exit 1
}

$playwrightArguments = @('--yes', '--package', '@playwright/cli', 'playwright-cli')
$hasSessionFlag = $false
foreach ($argument in $CliArguments) {
    if ($argument -eq '--session' -or $argument -like '--session=*') {
        $hasSessionFlag = $true
        break
    }
}

if (-not $hasSessionFlag -and $env:PLAYWRIGHT_CLI_SESSION) {
    $playwrightArguments += @('--session', $env:PLAYWRIGHT_CLI_SESSION)
}
$playwrightArguments += $CliArguments

& $npxCommand.Source @playwrightArguments
exit $LASTEXITCODE
