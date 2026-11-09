# Soulbound Release Export Script (PowerShell)
# SBL-BLD-002: Builds Windows Desktop and Web distributions using Godot 4.7.2 Stable headless CLI,
# supporting release tier injection (academic_mvp / full_release) while preserving working tree byte-identity.

param (
    [string]$GodotPath = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [ValidateSet("academic_mvp", "full_release", "both", "all")]
    [string]$Tier = "full_release",
    [switch]$SkipZip = $false,
    [switch]$FailAfterMutation = $false,
    [switch]$SimulateFailureAfterMutation = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   Soulbound Automated Release Exporter   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Target Release Tier: $Tier" -ForegroundColor Gray

# Locate Godot
if ($PSBoundParameters.ContainsKey('GodotPath')) {
    if (-not (Test-Path $GodotPath)) {
        throw "Specified Godot executable not found at '$GodotPath'."
    }
} else {
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
}

Write-Host "Using Godot executable: $GodotPath" -ForegroundColor Green

# Prepare directories
$WebFullDir = Join-Path $ProjectRoot "builds\web"
$WebMvpDir = Join-Path $ProjectRoot "builds\web-academic_mvp"
$WindowsDir = Join-Path $ProjectRoot "builds\windows"
$DistDir = Join-Path $ProjectRoot "dist"

foreach ($dir in @($WebFullDir, $WebMvpDir, $WindowsDir, $DistDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $gdignore = Join-Path $dir ".gdignore"
    if (-not (Test-Path $gdignore)) {
        New-Item -ItemType File -Path $gdignore -Force | Out-Null
    }
}

$ProjectGodotPath = Join-Path $ProjectRoot "project.godot"
if (-not (Test-Path $ProjectGodotPath)) {
    throw "project.godot not found at: $ProjectGodotPath"
}

# Snapshot original bytes for guaranteed byte-identical restoration
$origProjectGodotBytes = [System.IO.File]::ReadAllBytes($ProjectGodotPath)
$origMarkerPath = Join-Path $ProjectRoot "build_tier.txt"
$origMarkerExisted = Test-Path $origMarkerPath
$origMarkerBytes = if ($origMarkerExisted) { [System.IO.File]::ReadAllBytes($origMarkerPath) } else { $null }

function Export-TierPackage {
    param (
        [string]$TargetTier,
        [switch]$ExportWeb,
        [switch]$ExportWindows,
        [string]$TargetWebDir,
        [string]$TargetWebZipName,
        [string]$TargetWinDir = "",
        [string]$TargetWinZipName = ""
    )

    Write-Host "`n>>> [Export Pipeline] Processing Tier: '$TargetTier' <<<" -ForegroundColor Magenta

    # 1. Temporarily configure project.godot with requested release_tier
    $godotText = [System.IO.File]::ReadAllText($ProjectGodotPath)
    if ($godotText -match 'release_tier="[^"]*"') {
        $updatedText = $godotText -replace 'release_tier="[^"]*"', "release_tier=`"$TargetTier`""
    } else {
        $updatedText = $godotText + "`n[soulbound]`n`nrelease_tier=`"$TargetTier`"`n"
    }
    [System.IO.File]::WriteAllText($ProjectGodotPath, $updatedText, [System.Text.Encoding]::UTF8)

    # 2. Write root marker res://build_tier.txt so it gets packed into .pck via include_filter
    [System.IO.File]::WriteAllText($origMarkerPath, "$TargetTier`n", [System.Text.Encoding]::UTF8)

    Write-Host "  [MUTATION_APPLIED] Tier '$TargetTier' applied to project.godot and build_tier.txt written." -ForegroundColor Magenta

    if ($FailAfterMutation -or $SimulateFailureAfterMutation) {
        throw "SIMULATED_EXPORT_FAILURE: Injected failure immediately after tree mutation for tier '$TargetTier'."
    }

    # 3. Export Web Build
    if ($ExportWeb) {
        Write-Host "  Exporting Web Release ($TargetTier)..." -ForegroundColor Yellow
        $webOutput = Join-Path $TargetWebDir "index.html"
        $relWebPath = $webOutput.Substring($ProjectRoot.Path.Length).TrimStart('\', '/').Replace('\', '/')
        $webArgs = @(
            "--headless",
            "--path", $ProjectRoot.Path,
            "--export-release", "Web",
            $relWebPath
        )
        & $GodotPath @webArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Web export failed for tier '$TargetTier' with exit code $LASTEXITCODE"
        }
        Write-Host "  Web export successful ($relWebPath)." -ForegroundColor Green

        # Write build_tier.txt into the target web build folder
        $webMarker = Join-Path $TargetWebDir "build_tier.txt"
        [System.IO.File]::WriteAllText($webMarker, "$TargetTier`n", [System.Text.Encoding]::UTF8)

        # Package Web Zip
        if (-not $SkipZip) {
            $webZip = Join-Path $DistDir $TargetWebZipName
            if (Test-Path $webZip) { Remove-Item $webZip -Force }
            Get-ChildItem -Path $TargetWebDir -Filter "*.import" -File -Recurse | Remove-Item -Force
            $webFiles = Get-ChildItem -Path $TargetWebDir -File | Where-Object { $_.Name -ne ".gdignore" } | Select-Object -ExpandProperty FullName
            Compress-Archive -Path $webFiles -DestinationPath $webZip -CompressionLevel Optimal
            Write-Host "  Created Web package: $webZip" -ForegroundColor Green
        }
    }

    # 4. Export Windows Desktop Build
    if ($ExportWindows) {
        Write-Host "  Exporting Windows Desktop Release ($TargetTier)..." -ForegroundColor Yellow
        $winOutput = Join-Path $TargetWinDir "Soulbound.exe"
        $relWinPath = $winOutput.Substring($ProjectRoot.Path.Length).TrimStart('\', '/').Replace('\', '/')
        $winArgs = @(
            "--headless",
            "--path", $ProjectRoot.Path,
            "--export-release", "Windows Desktop",
            $relWinPath
        )
        & $GodotPath @winArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Windows Desktop export failed for tier '$TargetTier' with exit code $LASTEXITCODE"
        }
        Write-Host "  Windows Desktop export successful ($relWinPath)." -ForegroundColor Green

        # Write build_tier.txt into the target windows build folder
        $winMarker = Join-Path $TargetWinDir "build_tier.txt"
        [System.IO.File]::WriteAllText($winMarker, "$TargetTier`n", [System.Text.Encoding]::UTF8)

        # Package Windows Zip
        if (-not $SkipZip) {
            $winZip = Join-Path $DistDir $TargetWinZipName
            if (Test-Path $winZip) { Remove-Item $winZip -Force }
            Get-ChildItem -Path $TargetWinDir -Filter "*.import" -File -Recurse | Remove-Item -Force
            $winFiles = Get-ChildItem -Path $TargetWinDir -File | Where-Object { $_.Name -ne ".gdignore" } | Select-Object -ExpandProperty FullName
            Compress-Archive -Path $winFiles -DestinationPath $winZip -CompressionLevel Optimal
            Write-Host "  Created Windows package: $winZip" -ForegroundColor Green
        }
    }
}

try {
    # Execute exports per tier request
    if ($Tier -in @("academic_mvp", "both", "all")) {
        Export-TierPackage `
            -TargetTier "academic_mvp" `
            -ExportWeb `
            -TargetWebDir $WebMvpDir `
            -TargetWebZipName "Soulbound-AcademicMVP-Web.zip"
    }

    if ($Tier -in @("full_release", "both", "all")) {
        Export-TierPackage `
            -TargetTier "full_release" `
            -ExportWeb `
            -ExportWindows `
            -TargetWebDir $WebFullDir `
            -TargetWebZipName "Soulbound-Web.zip" `
            -TargetWinDir $WindowsDir `
            -TargetWinZipName "Soulbound-Windows-Portable.zip"
    }

    # Validate release artifacts
    if (-not $SkipZip) {
        Write-Host "`n>>> Validating Release Artifacts via validate_release.ps1 <<<" -ForegroundColor Yellow
        $ValidateScript = Join-Path $PSScriptRoot "validate_release.ps1"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ValidateScript -DistDir $DistDir -Tier $Tier -GodotPath $GodotPath
        if ($LASTEXITCODE -ne 0) {
            throw "Release validation failed with exit code $LASTEXITCODE"
        }
    }
} finally {
    Write-Host "`n>>> Restoring Working Tree Invariants <<<" -ForegroundColor Yellow

    # 1. Clean up temporary root marker
    if (Test-Path $origMarkerPath) {
        if ($origMarkerExisted -and $null -ne $origMarkerBytes) {
            [System.IO.File]::WriteAllBytes($origMarkerPath, $origMarkerBytes)
        } else {
            Remove-Item $origMarkerPath -Force
        }
    }

    # 2. Restore project.godot to exact original bytes
    if ($null -ne $origProjectGodotBytes) {
        [System.IO.File]::WriteAllBytes($ProjectGodotPath, $origProjectGodotBytes)
        $restoredBytes = [System.IO.File]::ReadAllBytes($ProjectGodotPath)
        if (-not [System.Linq.Enumerable]::SequenceEqual($origProjectGodotBytes, $restoredBytes)) {
            Write-Error "CRITICAL: project.godot was not restored to exact byte-identical state!"
        } else {
            Write-Host "  PASS: Working tree project.godot verified byte-identical to pre-export state." -ForegroundColor Green
        }
    }
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "            Artifact Summary            " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Get-ChildItem -Path $DistDir, $WebFullDir, $WebMvpDir, $WindowsDir -File | Format-Table -Property Name, Length, LastWriteTime

Write-Host "`nExport build process completed successfully." -ForegroundColor Green
