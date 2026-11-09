# Soulbound Release Artifact Validator (PowerShell)
# SBL-VER-003 / SBL-BLD-002: Asserts entry points, single-threaded web configuration, compatibility renderer,
# clean non-debug artifact contents, plausible binary/pck sizes, release tier marker verification,
# and end-to-end headless gate assertion.

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

if (-not (Test-Path $GodotPath)) {
    $fallbackGui = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\godot.exe"
    if (Test-Path $fallbackGui) {
        $GodotPath = $fallbackGui
    } else {
        $cmd = Get-Command "godot" -ErrorAction SilentlyContinue
        if ($cmd) { $GodotPath = $cmd.Source }
    }
}

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  Soulbound Release Artifact Validator   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Target Tier: $Tier" -ForegroundColor Gray

$Failures = @()

# 1. Preset & Configuration Validation
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

# Helper to inspect zip
function Validate-ZipArchive {
    param (
        [string]$ZipPath,
        [string]$PlatformName,
        [string]$ExpectedTier,
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

        # Check build_tier.txt marker
        $tierEntry = $zip.GetEntry("build_tier.txt")
        if ($null -eq $tierEntry) {
            $errors += "[$PlatformName] Missing 'build_tier.txt' marker inside $ZipPath"
        } else {
            $stream = $tierEntry.Open()
            $reader = New-Object System.IO.StreamReader($stream)
            $actualMarker = $reader.ReadToEnd().Trim()
            $reader.Dispose()
            $stream.Dispose()

            if (-not [string]::IsNullOrWhiteSpace($ExpectedTier)) {
                if ($actualMarker -ne $ExpectedTier) {
                    $errors += "[$PlatformName] build_tier.txt marker '$actualMarker' does not match expected tier '$ExpectedTier'."
                } else {
                    Write-Host "  PASS: [$PlatformName] build_tier.txt marker matches expected tier '$ExpectedTier'." -ForegroundColor Green
                }
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
Write-Host "`n[2/5] Validating Academic MVP distribution package..." -ForegroundColor Yellow
if ($checkAcademicMvp) {
    $MvpWebZipPath = Join-Path $ResolvedDist "Soulbound-AcademicMVP-Web.zip"
    $MvpWebRequired = @("index.html", "index.wasm", "index.pck", "build_tier.txt")
    $MvpWebConstraints = @{
        "index.pck"  = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
        "index.wasm" = @{ Min = $MinWasmSizeBytes; Max = $null }
    }
    $mvpErrors = Validate-ZipArchive -ZipPath $MvpWebZipPath -PlatformName "AcademicMVP-Web" -ExpectedTier "academic_mvp" -RequiredEntries $MvpWebRequired -SizeConstraints $MvpWebConstraints
    $Failures += $mvpErrors
} else {
    Write-Host "  Skipped (not requested for tier '$Tier')." -ForegroundColor Gray
}

# 3. Validate Full Release Packages (if applicable)
Write-Host "`n[3/5] Validating Full Release distribution packages..." -ForegroundColor Yellow
if ($checkFullRelease) {
    # Full Web
    $WebZipPath = Join-Path $ResolvedDist "Soulbound-Web.zip"
    $WebRequired = @("index.html", "index.wasm", "index.pck", "build_tier.txt")
    $WebConstraints = @{
        "index.pck"  = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
        "index.wasm" = @{ Min = $MinWasmSizeBytes; Max = $null }
    }
    $webErrors = Validate-ZipArchive -ZipPath $WebZipPath -PlatformName "FullRelease-Web" -ExpectedTier "full_release" -RequiredEntries $WebRequired -SizeConstraints $WebConstraints
    $Failures += $webErrors

    # Full Windows
    $WinZipPath = Join-Path $ResolvedDist "Soulbound-Windows-Portable.zip"
    $WinRequired = @("Soulbound.exe", "Soulbound.pck", "build_tier.txt")
    $WinConstraints = @{
        "Soulbound.pck" = @{ Min = $MinPckSizeBytes; Max = $MaxPckSizeBytes }
        "Soulbound.exe" = @{ Min = $MinExeSizeBytes; Max = $null }
    }
    $winErrors = Validate-ZipArchive -ZipPath $WinZipPath -PlatformName "FullRelease-Windows" -ExpectedTier "full_release" -RequiredEntries $WinRequired -SizeConstraints $WinConstraints
    $Failures += $winErrors
} else {
    Write-Host "  Skipped (not requested for tier '$Tier')." -ForegroundColor Gray
}

# 4. End-to-End Headless Gate Verification via Mounted PCK
Write-Host "`n[4/5] Running End-to-End Headless Gate Verification on Artifact PCKs..." -ForegroundColor Yellow
$verifyScript = "res://tests/headless/verify_exported_tier.gd"

if (Test-Path $GodotPath) {
    # Helper to test pck extracted from archive
    function Test-PckGate {
        param (
            [string]$PckPath,
            [string]$TierName,
            [string]$PlatformName
        )
        if (-not (Test-Path $PckPath)) {
            return "[$PlatformName] PCK file not found for verification: $PckPath"
        }
        $logPath = Join-Path $ProjectRoot "report\verify_pck_${PlatformName}.log"
        $errPath = Join-Path $ProjectRoot "report\verify_pck_${PlatformName}.err"
        
        $proc = Start-Process -FilePath $GodotPath `
            -ArgumentList @(
                "--headless",
                "--main-pack", $PckPath,
                "--script", $verifyScript,
                "--quit-after", "600",
                "--", $TierName
            ) `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $logPath -RedirectStandardError $errPath

        if ($proc.ExitCode -ne 0) {
            $errText = Get-Content $errPath -Raw -ErrorAction SilentlyContinue
            return "Headless gate verification failed for '$TierName' on $PlatformName ($PckPath) (Exit $($proc.ExitCode)): $errText"
        }
        Write-Host "  PASS: [$PlatformName] Headless gate verification succeeded on extracted $PckPath (tier '$TierName')." -ForegroundColor Green
        return $null
    }

    $targetsToVerify = @()
    if ($checkAcademicMvp) {
        $targetsToVerify += @{
            ZipName = "Soulbound-AcademicMVP-Web.zip"
            PckEntry = "index.pck"
            PlatformName = "AcademicMVP-Web"
            ExpectedMarker = "academic_mvp"
        }
    }
    if ($checkFullRelease) {
        $targetsToVerify += @{
            ZipName = "Soulbound-Web.zip"
            PckEntry = "index.pck"
            PlatformName = "FullRelease-Web"
            ExpectedMarker = "full_release"
        }
        $targetsToVerify += @{
            ZipName = "Soulbound-Windows-Portable.zip"
            PckEntry = "Soulbound.pck"
            PlatformName = "FullRelease-Windows"
            ExpectedMarker = "full_release"
        }
    }

    $tempExtractDir = Join-Path ([System.IO.Path]::GetTempPath()) ("sb_validate_pck_" + [System.Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Path $tempExtractDir -Force | Out-Null

    try {
        foreach ($target in $targetsToVerify) {
            $zipPath = Join-Path $ResolvedDist $target.ZipName
            if (-not (Test-Path $zipPath)) {
                $Failures += "[$($target.PlatformName)] Archive not found: $zipPath"
                continue
            }

            $zip = $null
            $markerTier = ""
            $extractedPckPath = Join-Path $tempExtractDir "$($target.PlatformName)_$($target.PckEntry)"
            try {
                $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
                $tierEntry = $zip.GetEntry("build_tier.txt")
                if ($null -eq $tierEntry) {
                    $Failures += "[$($target.PlatformName)] Missing 'build_tier.txt' in $zipPath"
                    continue
                }
                $stream = $tierEntry.Open()
                $reader = New-Object System.IO.StreamReader($stream)
                $markerTier = $reader.ReadToEnd().Trim()
                $reader.Dispose()
                $stream.Dispose()

                if (-not [string]::IsNullOrWhiteSpace($target.ExpectedMarker) -and $markerTier -ne $target.ExpectedMarker) {
                    $Failures += "[$($target.PlatformName)] build_tier.txt marker '$markerTier' does not match expected tier '$($target.ExpectedMarker)'."
                }

                $pckEntry = $zip.GetEntry($target.PckEntry)
                if ($null -eq $pckEntry) {
                    $Failures += "[$($target.PlatformName)] Missing '$($target.PckEntry)' in $zipPath"
                    continue
                }

                [System.IO.Compression.ZipFileExtensions]::ExtractToFile($pckEntry, $extractedPckPath, $true)
            } catch {
                $Failures += "[$($target.PlatformName)] Failed extracting from zip: $_"
                continue
            } finally {
                if ($null -ne $zip) { $zip.Dispose() }
            }

            $gateErr = Test-PckGate -PckPath $extractedPckPath -TierName $markerTier -PlatformName $target.PlatformName
            if ($gateErr) {
                $Failures += $gateErr
            }
        }
    } finally {
        if (Test-Path $tempExtractDir) {
            Remove-Item -Path $tempExtractDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
} else {
    Write-Host "  Godot binary not found at '$GodotPath'; skipping live headless PCK gate execution." -ForegroundColor Yellow
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
