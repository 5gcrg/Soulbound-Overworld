# Soulbound Release Artifact Validator (PowerShell)
# SBL-VER-003 / SBL-BLD-002: Asserts entry points, single-threaded web configuration, compatibility renderer,
# clean non-debug artifact contents, plausible binary/pck sizes, release tier marker verification,
# and end-to-end headless gate assertion.
# SBL-BLD-005: strictly verifies archive-contained release-manifest.json + external receipt, payload
# raw-byte sizes/SHA-256, duplicate/case-colliding/unsafe paths, unsupported entry types, package
# identity (archive/platform/tier/preset) and archived configuration semantics using archive bytes
# only - never local builds/ payloads or local configuration as archive evidence. The live PCK gate
# requires Godot and runs under proven disposable user data; a missing engine fails instead of skipping.

param (
    [string]$DistDir = "dist",
    [string]$PresetsPath = "export_presets.cfg",
    [string]$ProjectGodotPath = "project.godot",
    [string]$Tier = "auto",
    [string]$GodotPath = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [long]$MinPckSizeBytes = 300000,    # ~300 KB lower bound
    [long]$MaxPckSizeBytes = 50000000,  # ~50 MB upper bound
    [long]$MinWasmSizeBytes = 10000000, # ~10 MB lower bound
    [long]$MinExeSizeBytes = 50000000   # ~50 MB lower bound
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ResolvedDist = if ([System.IO.Path]::IsPathRooted($DistDir)) { $DistDir } else { Join-Path $ProjectRoot $DistDir }
$ResolvedPresets = if ([System.IO.Path]::IsPathRooted($PresetsPath)) { $PresetsPath } else { Join-Path $ProjectRoot $PresetsPath }
$ResolvedGodotConfig = if ([System.IO.Path]::IsPathRooted($ProjectGodotPath)) { $ProjectGodotPath } else { Join-Path $ProjectRoot $ProjectGodotPath }

. (Join-Path $PSScriptRoot "release_manifest.ps1")

# The live archive-contained PCK gate is REQUIRED. A missing engine (default
# or explicit) fails immediately: no silent fallback to a GUI/PATH binary and
# no successful skip of the gate (SBL-BLD-005).
if (-not (Test-Path -LiteralPath $GodotPath)) {
    throw "Godot executable not found at '$GodotPath'; the required archive-contained PCK gate cannot run. No fallback or skip is attempted."
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Soulbound Release Artifact Validator   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Target Tier: $Tier" -ForegroundColor Gray

$Failures = @()

# 1. Preset & Configuration Validation (local repository configuration only;
#    archive evidence is verified separately from archive bytes below).
Write-Host "`n[1/5] Validating Export Presets & Renderer Settings..." -ForegroundColor Yellow

if (-not (Test-Path $ResolvedPresets)) {
    $Failures += "Missing export presets file at: $ResolvedPresets"
} else {
    $presetContent = Get-Content $ResolvedPresets -Raw
    if ($presetContent -notmatch 'variant/thread_support=false') {
        $Failures += "Web export preset must have 'variant/thread_support=false' (single-threaded Web invariant)."
    } else {
        Write-Host "  PASS: Web preset thread_support is false (single-threaded)." -ForegroundColor Green
    }
}

if (-not (Test-Path $ResolvedGodotConfig)) {
    $Failures += "Missing project.godot at: $ResolvedGodotConfig"
} else {
    $godotContent = Get-Content $ResolvedGodotConfig -Raw
    if ($godotContent -notmatch 'rendering_method="gl_compatibility"') {
        $Failures += "project.godot must specify rendering_method='gl_compatibility'."
    } else {
        Write-Host "  PASS: Default rendering method is gl_compatibility." -ForegroundColor Green
    }
    if ($godotContent -notmatch 'rendering_method\.web="gl_compatibility"') {
        $Failures += "project.godot must specify rendering_method.web='gl_compatibility'."
    } else {
        Write-Host "  PASS: Web rendering method override is gl_compatibility." -ForegroundColor Green
    }
}

# Helper: verify one selected archive with the shared verifier (archive bytes
# and external receipt only) and return its diagnostics.
function Test-SelectedArchive {
    param (
        [string]$ZipPath,
        [string]$PlatformName,
        [string]$ExpectedTier,
        [string]$ExpectedPlatform,
        [string]$ExpectedPreset,
        [hashtable]$SizeConstraints
    )
    $verifyErrors = Test-SblReleaseArchive `
        -ArchivePath $ZipPath `
        -ExpectedTier $ExpectedTier `
        -ExpectedPlatform $ExpectedPlatform `
        -ExpectedPreset $ExpectedPreset `
        -SizeConstraints $SizeConstraints
    if ($verifyErrors.Count -eq 0) {
        Write-Host "  PASS: [$PlatformName] release-manifest.json, external receipt, payload sizes/SHA-256, entry paths, and package identity verified from archive bytes." -ForegroundColor Green
        return ,([string[]]@())
    }
    foreach ($verifyError in $verifyErrors) {
        Write-Host "  FAIL: [$PlatformName] $verifyError" -ForegroundColor Red
    }
    return ,([string[]]$verifyErrors)
}

# Determine which packages to validate
$checkAcademicMvp = ($Tier -in @("academic_mvp", "both", "all"))
$checkFullRelease = ($Tier -in @("full_release", "both", "all"))

if ($Tier -eq "auto") {
    $checkAcademicMvp = Test-Path (Join-Path $ResolvedDist "Soulbound-AcademicMVP-Web.zip")
    $checkFullRelease = (Test-Path (Join-Path $ResolvedDist "Soulbound-Web.zip")) -or (Test-Path (Join-Path $ResolvedDist "Soulbound-Windows-Portable.zip"))
    if (-not $checkAcademicMvp -and -not $checkFullRelease) {
        $Failures += "No release archives found in $ResolvedDist to validate in auto mode."
    }
}

# 2. Validate Academic MVP Package (if applicable)
Write-Host "`n[2/5] Validating Academic MVP distribution package (manifest + payload)..." -ForegroundColor Yellow
$gateTargets = @()
if ($checkAcademicMvp) {
    $MvpWebZipPath = Join-Path $ResolvedDist "Soulbound-AcademicMVP-Web.zip"
    $MvpWebConstraints = @{
        "index.pck"  = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
        "index.wasm" = @{ Min = $MinWasmSizeBytes; Max = $null }
    }
    $mvpErrors = Test-SelectedArchive -ZipPath $MvpWebZipPath -PlatformName "AcademicMVP-Web" -ExpectedTier "academic_mvp" -ExpectedPlatform "web" -ExpectedPreset "Web" -SizeConstraints $MvpWebConstraints
    $Failures += $mvpErrors
    if ($mvpErrors.Count -eq 0) {
        $gateTargets += @{ ZipPath = $MvpWebZipPath; Spec = Get-SblPackageSpec -ArchiveName "Soulbound-AcademicMVP-Web.zip" }
    }
} else {
    Write-Host "  Skipped (not requested for tier '$Tier')." -ForegroundColor Gray
}

# 3. Validate Full Release Packages (if applicable)
Write-Host "`n[3/5] Validating Full Release distribution packages (manifest + payload)..." -ForegroundColor Yellow
if ($checkFullRelease) {
    # Full Web
    $WebZipPath = Join-Path $ResolvedDist "Soulbound-Web.zip"
    $WebConstraints = @{
        "index.pck"  = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
        "index.wasm" = @{ Min = $MinWasmSizeBytes; Max = $null }
    }
    $webErrors = Test-SelectedArchive -ZipPath $WebZipPath -PlatformName "FullRelease-Web" -ExpectedTier "full_release" -ExpectedPlatform "web" -ExpectedPreset "Web" -SizeConstraints $WebConstraints
    $Failures += $webErrors
    if ($webErrors.Count -eq 0) {
        $gateTargets += @{ ZipPath = $WebZipPath; Spec = Get-SblPackageSpec -ArchiveName "Soulbound-Web.zip" }
    }

    # Full Windows
    $WinZipPath = Join-Path $ResolvedDist "Soulbound-Windows-Portable.zip"
    $WinConstraints = @{
        "Soulbound.pck" = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
        "Soulbound.exe" = @{ Min = $MinExeSizeBytes; Max = $null }
    }
    $winErrors = Test-SelectedArchive -ZipPath $WinZipPath -PlatformName "FullRelease-Windows" -ExpectedTier "full_release" -ExpectedPlatform "windows" -ExpectedPreset "Windows Desktop" -SizeConstraints $WinConstraints
    $Failures += $winErrors
    if ($winErrors.Count -eq 0) {
        $gateTargets += @{ ZipPath = $WinZipPath; Spec = Get-SblPackageSpec -ArchiveName "Soulbound-Windows-Portable.zip" }
    }
} else {
    Write-Host "  Skipped (not requested for tier '$Tier')." -ForegroundColor Gray
}

# 4. End-to-End Headless Gate Verification via each archive's OWN mounted PCK.
#    Runs only for archives that passed manifest verification, under proven
#    disposable user data (probe first, byte-identity assertion after).
Write-Host "`n[4/5] Running End-to-End Headless Gate Verification on Artifact PCKs..." -ForegroundColor Yellow

if ($gateTargets.Count -eq 0) {
    Write-Host "  No archive passed manifest verification; PCK gates not executed (validation is already failing)." -ForegroundColor Yellow
} else {
    $isolation = Enter-SblGodotUserDataIsolation -GodotPath $GodotPath -ProjectRoot $ProjectRoot.Path -Label "validate_release"
    Write-Host "  Disposable user data proved before gates: $($isolation.ProbeUserDir)" -ForegroundColor Gray
    $isolationResult = $null
    try {
        foreach ($target in $gateTargets) {
            $gateError = Invoke-SblArchivePckGate `
                -ArchivePath $target.ZipPath `
                -GodotPath $GodotPath `
                -Spec $target.Spec `
                -ReportDir (Join-Path $ProjectRoot "report")
            if ($gateError) {
                $Failures += $gateError
            } else {
                Write-Host "  PASS: [$($target.Spec.Label)] Headless gate verification succeeded on the archive's own extracted PCK (tier '$($target.Spec.Tier)')." -ForegroundColor Green
            }
        }
    } finally {
        $isolationResult = Exit-SblGodotUserDataIsolation -State $isolation
    }

    $isolationLog = Join-Path $ProjectRoot "report\godot_user_data_isolation.log"
    Add-Content -Path $isolationLog -Value "[$(Get-Date -Format o)] validate_release: probe=$($isolationResult.ProbeUserDir); realUserDataUnchanged=$($isolationResult.RealDataUnchanged); disposableFiles=$($isolationResult.DisposableFileCount); rootRemoved=$($isolationResult.RootRemoved)"
    if (-not $isolationResult.RealDataUnchanged) {
        $Failures += "Disposable user-data isolation proof failed: real Godot user data changed during validation."
    } else {
        Write-Host "  PASS: real Godot user data byte-identical before/after (disposable root used, $($isolationResult.DisposableFileCount) file(s) written there)." -ForegroundColor Green
    }
}

# 5. Summary and Result
Write-Host "`n[5/5] Release Validation Summary..." -ForegroundColor Yellow
if ($Failures.Count -gt 0) {
    Write-Host "`nVALIDATION FAILED with $($Failures.Count) error(s):" -ForegroundColor Red
    foreach ($err in $Failures) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    exit 1
}

Write-Host "ALL RELEASE ARTIFACTS AND PRESETS VALIDATED SUCCESSFULLY." -ForegroundColor Green
exit 0
