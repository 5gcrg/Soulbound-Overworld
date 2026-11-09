# Soulbound Canonical Headless Test Runner (PowerShell)
# SBL-BLD-001 — Canonical headless test execution across all test suites
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 [-Suite <name>] [-Export]

param (
    [string]$GodotPath = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [string]$Suite = "",
    [string]$Tier = "both",
    [switch]$Export = $false,
    [switch]$SkipImport = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

# Locate Godot
if (-not (Test-Path $GodotPath)) {
    $fallbackGui = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\godot.exe"
    if (Test-Path $fallbackGui) {
        $GodotPath = $fallbackGui
    } else {
        $GodotCommand = Get-Command "godot" -ErrorAction SilentlyContinue
        if ($GodotCommand) {
            $GodotPath = $GodotCommand.Source
        } else {
            throw "Godot executable not found at '$GodotPath' and not in system PATH."
        }
    }
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "    Soulbound Headless Test Runner       " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Using Godot binary: $GodotPath" -ForegroundColor Gray

# Ensure report directory exists
$ReportDir = Join-Path $ProjectRoot "report"
if (-not (Test-Path $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

# 1. Project Import Scan
if (-not $SkipImport) {
    Write-Host "`n[1/3] Running Godot --import project scan..." -ForegroundColor Yellow
    $importLog = Join-Path $ReportDir "import.log"
    $importErr = Join-Path $ReportDir "import.err"

    $importProc = Start-Process -FilePath $GodotPath `
        -ArgumentList @("--headless", "--path", $ProjectRoot.Path, "--import") `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $importLog -RedirectStandardError $importErr

    if ($importProc.ExitCode -ne 0) {
        Write-Host "Godot --import failed with exit code $($importProc.ExitCode)!" -ForegroundColor Red
        Get-Content $importErr -Tail 20 -ErrorAction SilentlyContinue
        exit $importProc.ExitCode
    }
    Write-Host "Project import clean (exit code 0)." -ForegroundColor Green
}

# 2. Enumerate Test Suites
$TestsDir = Join-Path $ProjectRoot "tests\headless"
$AllSuites = Get-ChildItem -Path $TestsDir -Filter "*.gd" | Sort-Object Name

if (-not [string]::IsNullOrWhiteSpace($Suite)) {
    $cleanFilter = $Suite.Trim()
    if (-not $cleanFilter.EndsWith(".gd")) { $cleanFilter += ".gd" }
    $SuitesToRun = $AllSuites | Where-Object { $_.Name -like "*$cleanFilter*" }
    if ($SuitesToRun.Count -eq 0) {
        throw "No test suite found matching pattern: '$Suite'"
    }
} else {
    $SuitesToRun = $AllSuites
}

Write-Host "`n[2/3] Running $($SuitesToRun.Count) test suite(s)..." -ForegroundColor Yellow

$results = @()
$anyFailed = $false

foreach ($file in $SuitesToRun) {
    $suiteName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $logPath = Join-Path $ReportDir "$suiteName.log"
    $errPath = Join-Path $ReportDir "$suiteName.err"

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $testProc = Start-Process -FilePath $GodotPath `
        -ArgumentList @(
            "--headless",
            "--path", $ProjectRoot.Path,
            "--fixed-fps", "60",
            "--script", "res://tests/headless/$($file.Name)",
            "--quit-after", "600"
        ) `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $logPath -RedirectStandardError $errPath
    $sw.Stop()

    $durationSec = [math]::Round($sw.Elapsed.TotalSeconds, 2)
    $passed = ($testProc.ExitCode -eq 0)

    if (-not $passed) {
        $anyFailed = $true
        Write-Host "  FAIL: $($file.Name) (Exit $($testProc.ExitCode), ${durationSec}s)" -ForegroundColor Red
    } else {
        Write-Host "  PASS: $($file.Name) (${durationSec}s)" -ForegroundColor Green
    }

    $results += [PSCustomObject]@{
        Suite    = $file.Name
        Status   = if ($passed) { "PASS" } else { "FAIL" }
        ExitCode = $testProc.ExitCode
        Duration = "${durationSec}s"
    }
}

# 3. Print Results Summary Table
Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "          Test Results Summary           " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$results | Format-Table -Property Suite, Status, ExitCode, Duration -AutoSize

$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Host "Total: $($results.Count) | Passed: $passCount | Failed: $failCount" -ForegroundColor $(if ($anyFailed) { "Red" } else { "Green" })

if ($anyFailed) {
    Write-Host "`nOne or more test suites failed! Review logs under report/ for details." -ForegroundColor Red
    exit 1
}

# 4. Optional Release Export Chaining
if ($Export) {
    Write-Host "`n[3/3] Chaining automated release export (-Export)..." -ForegroundColor Cyan
    $exportScript = Join-Path $PSScriptRoot "export_release.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $exportScript -Tier $Tier -GodotPath $GodotPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Release export failed with exit code $LASTEXITCODE!" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "`nAll operations completed successfully." -ForegroundColor Green
exit 0
