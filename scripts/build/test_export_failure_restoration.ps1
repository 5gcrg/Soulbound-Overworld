# Soulbound Export Failure Restoration Verification
# SBL-BLD-003: Proves that the export failure path restores project.godot byte-identically
# and removes any temporary build_tier.txt from the repository root.
# Usage: powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_export_failure_restoration.ps1

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

$godotConfig = Join-Path $ProjectRoot "project.godot"
$markerPath = Join-Path $ProjectRoot "build_tier.txt"

if (-not (Test-Path $godotConfig)) {
    throw "project.godot not found at: $godotConfig"
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  SBL-BLD-003 Export Failure Tree Test   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Capture Pre-Test State
$preBytes = [System.IO.File]::ReadAllBytes($godotConfig)
$preSha = (Get-FileHash -Path $godotConfig -Algorithm SHA256).Hash
$markerPreExisted = Test-Path $markerPath

Write-Host "Pre-test project.godot SHA256: $preSha" -ForegroundColor Gray
Write-Host "Pre-test build_tier.txt exists: $markerPreExisted" -ForegroundColor Gray

# 2. Trigger Forced Failure during export_release.ps1
Write-Host "`nExecuting export_release.ps1 with forced failure path..." -ForegroundColor Yellow
$exportScript = Join-Path $PSScriptRoot "export_release.ps1"

# Force export failure by providing a nonexistent Godot binary path
$proc = Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $exportScript, "-GodotPath", "C:\nonexistent\godot.exe") `
    -NoNewWindow -Wait -PassThru

Write-Host "Export process exited with code $($proc.ExitCode) (expected non-zero failure)." -ForegroundColor Yellow
if ($proc.ExitCode -eq 0) {
    Write-Error "FAIL: Expected export_release.ps1 to fail, but it exited 0!"
    exit 1
}

# 3. Assert Post-Failure Working Tree Invariants
$postBytes = [System.IO.File]::ReadAllBytes($godotConfig)
$postSha = (Get-FileHash -Path $godotConfig -Algorithm SHA256).Hash
$markerPostExisted = Test-Path $markerPath
$bytesIdentical = [System.Linq.Enumerable]::SequenceEqual($preBytes, $postBytes)

Write-Host "`n=== Verification Assertions ===" -ForegroundColor Cyan
Write-Host "  Failure captured:               $($proc.ExitCode -ne 0) (ExitCode=$($proc.ExitCode))"
Write-Host "  project.godot byte-identical:   $bytesIdentical"
Write-Host "  project.godot SHA256 matched:   $($preSha -eq $postSha) ($postSha)"
Write-Host "  build_tier.txt absent from root: $(-not $markerPostExisted)"

if (-not $bytesIdentical) {
    Write-Error "CRITICAL: project.godot bytes differ after failed export run!"
    exit 1
}

if ($markerPostExisted) {
    Write-Error "CRITICAL: build_tier.txt was left behind in project root after failed export run!"
    exit 1
}

Write-Host "`nPASS: SBL-BLD-003 Export failure path restored tree byte-identically." -ForegroundColor Green
exit 0
