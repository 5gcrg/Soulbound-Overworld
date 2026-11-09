# Runs agy non-interactively against docs/agy-dispatch-prompt.md and logs the session.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\agy\run_next_queue.ps1

param (
    [string]$AgyPath = "C:\Users\ALCOHOL\AppData\Local\agy\bin\agy.exe",
    # Gemini 4 Argon is quota-blocked (429) while Gemini 3.8 Flash still has quota.
    [string]$Model = "gemini-3.8-flash-high",
    [string]$Effort = "high",
    [switch]$ContinueLast
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

if (-not (Test-Path $AgyPath)) {
    $cmd = Get-Command "agy" -ErrorAction SilentlyContinue
    if ($cmd) { $AgyPath = $cmd.Source } else { throw "agy not found at '$AgyPath' and not on PATH." }
}

$promptFile = Join-Path $ProjectRoot "docs\agy-dispatch-prompt.md"
if (-not (Test-Path $promptFile)) { throw "Dispatch prompt missing: $promptFile" }

# Extract the fenced prompt block so the markdown wrapper is never sent to agy.
$raw = Get-Content $promptFile -Raw
$match = [regex]::Match($raw, '(?s)```text\r?\n(.*?)```')
if (-not $match.Success) { throw "No ```text prompt block found in $promptFile" }
$prompt = $match.Groups[1].Value.Trim()

$reportDir = Join-Path $ProjectRoot "report"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$log = Join-Path $reportDir ("agy-next-queue-" + $stamp + ".log")
$err = $log + ".err"

# Windows PowerShell 5.1 has no ProcessStartInfo.ArgumentList, so build the command line
# explicitly. The prompt is wrapped in quotes and inner quotes/backslashes are escaped, which
# keeps a multi-line prompt as ONE argv element (Start-Process re-splits it and corrupts it).
function ConvertTo-CommandLineArg([string]$value) {
    $escaped = $value -replace '(\\*)"', '$1$1\"'
    $escaped = $escaped -replace '(\\+)$', '$1$1'
    return '"' + $escaped + '"'
}

$argLine = "-p " + (ConvertTo-CommandLineArg $prompt) + " --dangerously-skip-permissions"
$argLine += " --model " + (ConvertTo-CommandLineArg $Model)
$argLine += " --effort " + (ConvertTo-CommandLineArg $Effort)
if ($ContinueLast) { $argLine += " -c" }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $AgyPath
$psi.WorkingDirectory = $ProjectRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.Arguments = $argLine

Write-Host "agy: $AgyPath" -ForegroundColor Cyan
Write-Host "model: $Model (effort $Effort)" -ForegroundColor Cyan
Write-Host "log: $log" -ForegroundColor Cyan

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$null = $proc.Start()
$stdout = $proc.StandardOutput.ReadToEnd()
$stderr = $proc.StandardError.ReadToEnd()
$proc.WaitForExit()
Set-Content -Path $log -Value $stdout -Encoding UTF8
Set-Content -Path $err -Value $stderr -Encoding UTF8

Write-Host ("agy exit=" + $proc.ExitCode) -ForegroundColor Yellow
Get-Content $log -Tail 40 -ErrorAction SilentlyContinue
Get-Content $err -Tail 20 -ErrorAction SilentlyContinue

if ($proc.ExitCode -ne 0) {
    Write-Host "agy did not complete. Queue stays REVIEW_PENDING_CODEX; do not represent this as reviewed." -ForegroundColor Red
}
exit $proc.ExitCode
