# Soulbound Release Artifact Validator (PowerShell)
# SBL-VER-003: Asserts entry points, single-threaded web configuration, compatibility renderer,
# clean non-debug artifact contents, and plausible binary/pck sizes.

param (
    [string]$DistDir = "dist",
    [string]$PresetsPath = "export_presets.cfg",
    [string]$ProjectGodotPath = "project.godot",
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

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Soulbound Release Artifact Validator   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$Failures = @()

# 1. Preset & Configuration Validation
Write-Host "`n[1/4] Validating Export Presets & Renderer Settings..." -ForegroundColor Yellow

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

# Helper to inspect zip
function Validate-ZipArchive {
    param (
        [string]$ZipPath,
        [string]$PlatformName,
        [string[]]$RequiredEntries,
        [hashtable]$SizeConstraints
    )

    if (-not (Test-Path $ZipPath)) {
        return @("Missing distribution package for ${PlatformName}: $ZipPath")
    }

    $errors = @()
    $zip = $null
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        $entryNames = @($zip.Entries | ForEach-Object { $_.FullName })
        $entryMap = @{}
        foreach ($e in $zip.Entries) {
            $entryMap[$e.FullName] = $e.Length
        }

        # Check required entry points
        foreach ($req in $RequiredEntries) {
            if ($entryNames -notcontains $req) {
                $errors += "[$PlatformName] Missing required entry point: '$req'"
            } else {
                Write-Host "  PASS: [$PlatformName] Contains required entry point '$req' ($($entryMap[$req]) bytes)." -ForegroundColor Green
            }
        }

        # Check for forbidden leftovers (debug, editor, temp, import metadata)
        $forbiddenExtensions = @(".uid", ".import", ".tmp", ".bak", ".swp", ".log", ".err")
        $forbiddenPrefixes = @(".godot/", ".git/", "tests/", "report/")

        foreach ($entry in $entryNames) {
            foreach ($ext in $forbiddenExtensions) {
                if ($entry.EndsWith($ext, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $errors += "[$PlatformName] Contains forbidden editor/build artifact: '$entry'"
                }
            }
            foreach ($pfx in $forbiddenPrefixes) {
                if ($entry.StartsWith($pfx, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $errors += "[$PlatformName] Contains forbidden debug/test path: '$entry'"
                }
            }
        }

        # Check size constraints
        foreach ($entryName in $SizeConstraints.Keys) {
            if ($entryMap.ContainsKey($entryName)) {
                $len = $entryMap[$entryName]
                $min = $SizeConstraints[$entryName].Min
                $max = $SizeConstraints[$entryName].Max
                if ($null -ne $min -and $len -lt $min) {
                    $errors += "[$PlatformName] '$entryName' size $len bytes is below minimum threshold of $min bytes."
                }
                if ($null -ne $max -and $len -gt $max) {
                    $errors += "[$PlatformName] '$entryName' size $len bytes exceeds maximum threshold of $max bytes."
                }
            }
        }
    } catch {
        $errors += "[$PlatformName] Failed reading zip archive: $_"
    } finally {
        if ($null -ne $zip) {
            $zip.Dispose()
        }
    }

    return $errors
}

# 2. Validate Web Package
Write-Host "`n[2/4] Validating Web distribution package..." -ForegroundColor Yellow
$WebZipPath = Join-Path $ResolvedDist "Soulbound-Web.zip"
$WebRequired = @("index.html", "index.wasm", "index.pck")
$WebConstraints = @{
    "index.pck"  = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
    "index.wasm" = @{ Min = $MinWasmSizeBytes; Max = $null }
}
$webErrors = Validate-ZipArchive -ZipPath $WebZipPath -PlatformName "Web" -RequiredEntries $WebRequired -SizeConstraints $WebConstraints
$Failures += $webErrors

# 3. Validate Windows Package
Write-Host "`n[3/4] Validating Windows distribution package..." -ForegroundColor Yellow
$WinZipPath = Join-Path $ResolvedDist "Soulbound-Windows-Portable.zip"
$WinRequired = @("Soulbound.exe", "Soulbound.pck")
$WinConstraints = @{
    "Soulbound.pck" = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
    "Soulbound.exe" = @{ Min = $MinExeSizeBytes; Max = $null }
}
$winErrors = Validate-ZipArchive -ZipPath $WinZipPath -PlatformName "Windows" -RequiredEntries $WinRequired -SizeConstraints $WinConstraints
$Failures += $winErrors

# 4. Summary and Result
Write-Host "`n[4/4] Release Validation Summary..." -ForegroundColor Yellow
if ($Failures.Count -gt 0) {
    Write-Host "`nVALIDATION FAILED with $($Failures.Count) error(s):" -ForegroundColor Red
    foreach ($err in $Failures) {
        Write-Host "  - $err" -ForegroundColor Red
    }
    exit 1
}

Write-Host "ALL RELEASE ARTIFACTS AND PRESETS VALIDATED SUCCESSFULLY." -ForegroundColor Green
exit 0
