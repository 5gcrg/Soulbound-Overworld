# Soulbound Canonical Headless Test Runner (PowerShell)
# SBL-BLD-001 — Canonical headless test execution across all test suites
# SBL-BLD-005 — Strict engine resolution (no silent fallback), proven disposable
#                user data for every Godot test/import run, and mandatory chaining
#                of test_release_manifest.ps1 into the canonical -Export path.
# OD-013 — the canonical -Export path additionally chains performance_evidence.ps1
#          with warning semantics (below-target records a warning, never a failure).
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 [-Suite <name>] [-Export] [-Tier <t>]

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

. (Join-Path $PSScriptRoot "release_manifest.ps1")

# Strict engine resolution: the canonical runner REQUIRES Godot. A missing
# default path fails instead of silently falling back to a GUI binary or a
# PATH candidate (SBL-BLD-005).
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found at '$GodotPath'; no fallback is attempted. Pass a valid -GodotPath."
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

# Disposable user-data isolation: redirect APPDATA/LOCALAPPDATA for every
# Godot child process and PROVE the redirection with a headless probe BEFORE
# any import or test suite executes. Real user data is snapshotted for
# byte-identity comparison at exit. The disposable root is seeded from a
# copy-on-enter snapshot of the real Godot data directory so suites keep the
# historical baseline state they depend on (e.g. pre-existing profile_01) and
# chained exporters can resolve export templates; every write still lands in
# the disposable copy and the real directory must stay byte-identical.
$realGodotData = Join-Path $env:APPDATA "Godot"
$seedArguments = @{}
if (Test-Path -LiteralPath $realGodotData) {
    $seedArguments = @{ SeedFrom = $realGodotData }
    Write-Host "Disposable user-data will be seeded from: $realGodotData" -ForegroundColor Gray
}
$isolation = Enter-SblGodotUserDataIsolation -GodotPath $GodotPath -ProjectRoot $ProjectRoot.Path -Label "headless_tests" @seedArguments
Write-Host "Disposable user data proved before test execution: $($isolation.ProbeUserDir)" -ForegroundColor Gray
$isolationResult = $null

try {
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

    # 4. Optional Release Export Chaining (+ mandatory manifest test chaining)
    if ($Export) {
        Write-Host "`n[3/3] Chaining automated release export (-Export)..." -ForegroundColor Cyan
        $exportScript = Join-Path $PSScriptRoot "export_release.ps1"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $exportScript -Tier $Tier -GodotPath $GodotPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Release export failed with exit code $LASTEXITCODE!" -ForegroundColor Red
            exit $LASTEXITCODE
        }

        # SBL-BLD-005: chain the release manifest test suite into the
        # canonical -Export path after successful export/validation and
        # propagate any failure as a non-zero exit.
        $manifestTestScript = Join-Path $PSScriptRoot "test_release_manifest.ps1"
        Write-Host "`nChaining release manifest tests (test_release_manifest.ps1)..." -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File $manifestTestScript -GodotPath $GodotPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Release manifest tests failed with exit code $LASTEXITCODE!" -ForegroundColor Red
            exit $LASTEXITCODE
        }

        # OD-013: performance evidence is part of the canonical release gate with
        # WARNING semantics - below-target results are recorded in
        # report/od013_performance_evidence.json and report/od013_performance_report.md
        # and printed as warnings, but they never fail the run (exit 0). Only a
        # preflight or capture failure (missing/invalid engine, wrong Godot
        # version, incompatible renderer or single-thread Web configuration, or an
        # incomplete capture) exits non-zero and fails this chain.
        $performanceScript = Join-Path $PSScriptRoot "performance_evidence.ps1"
        Write-Host "`nChaining performance evidence (performance_evidence.ps1, warning semantics)..." -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File $performanceScript -GodotPath $GodotPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Performance evidence preflight/capture failed with exit code $LASTEXITCODE!" -ForegroundColor Red
            exit $LASTEXITCODE
        }
    }
} finally {
    $isolationResult = Exit-SblGodotUserDataIsolation -State $isolation
    $isolationLog = Join-Path $ReportDir "godot_user_data_isolation.log"
    Add-Content -Path $isolationLog -Value "[$(Get-Date -Format o)] run_headless_tests: probe=$($isolationResult.ProbeUserDir); realUserDataUnchanged=$($isolationResult.RealDataUnchanged); disposableFiles=$($isolationResult.DisposableFileCount); rootRemoved=$($isolationResult.RootRemoved)"
    Write-Host "`nDisposable user-data isolation: realUserDataUnchanged=$($isolationResult.RealDataUnchanged), disposableFiles=$($isolationResult.DisposableFileCount), rootRemoved=$($isolationResult.RootRemoved)" -ForegroundColor $(if ($isolationResult.RealDataUnchanged) { "Green" } else { "Red" })
}

if (-not $isolationResult.RealDataUnchanged) {
    Write-Host "FAIL: real Godot user data changed despite disposable user-data isolation!" -ForegroundColor Red
    exit 1
}

Write-Host "`nAll operations completed successfully." -ForegroundColor Green
exit 0
