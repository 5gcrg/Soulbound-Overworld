# Soulbound Release Export Script (PowerShell)
# SBL-BLD-002: Builds Windows Desktop and Web distributions using Godot 4.7.2 Stable headless CLI,
# supporting release tier injection (academic_mvp / full_release) while preserving working tree byte-identity.
# SBL-BLD-005: captures source/engine provenance before any mutation, exports each package from a fresh
# isolated staging directory, embeds a schema-version-1 release-manifest.json plus provenance/ configuration
# snapshots in every ZIP, writes the external <archive>.manifest.sha256 receipt, and re-verifies the created
# archive against its receipt before packaging is considered successful.

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

. (Join-Path $PSScriptRoot "release_manifest.ps1")

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   Soulbound Automated Release Exporter   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Target Release Tier: $Tier" -ForegroundColor Gray

# Locate Godot — strict. A required engine that is missing, or an explicitly
# supplied invalid path, fails immediately; there is no silent fallback to a
# GUI binary or a PATH candidate (SBL-BLD-005).
if ($PSBoundParameters.ContainsKey('GodotPath')) {
    if (-not (Test-Path -LiteralPath $GodotPath)) {
        throw "Specified Godot executable not found at '$GodotPath'."
    }
} else {
    if (-not (Test-Path -LiteralPath $GodotPath)) {
        throw "Godot executable not found at '$GodotPath' and no fallback is attempted; pass a valid -GodotPath."
    }
}

Write-Host "Using Godot executable: $GodotPath" -ForegroundColor Green

# Prepare directories
$WebFullDir = Join-Path $ProjectRoot "builds\web"
$WebMvpDir = Join-Path $ProjectRoot "builds\web-academic_mvp"
$WindowsDir = Join-Path $ProjectRoot "builds\windows"
$DistDir = Join-Path $ProjectRoot "dist"
$BuildsRoot = Join-Path $ProjectRoot "builds"

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

$PresetsPath = Join-Path $ProjectRoot "export_presets.cfg"
if (-not (Test-Path -LiteralPath $PresetsPath)) {
    throw "export_presets.cfg not found at: $PresetsPath"
}
$PresetsBytes = [System.IO.File]::ReadAllBytes($PresetsPath)

# Capture source provenance BEFORE creating staging files or mutating source
# configuration, so the exporter's own temporary mutation can never flip a
# clean capture. Fails hard if Git or `godot --version` fail (never "unknown").
Write-Host "`n>>> Capturing source and engine provenance (before mutation) <<<" -ForegroundColor Yellow
$SourceProvenance = Get-SblSourceProvenance -RepoRoot $ProjectRoot.Path
$EngineProvenance = Get-SblEngineProvenance -GodotPath $GodotPath
Write-Host "  Source commit: $($SourceProvenance.commit)  dirty=$($SourceProvenance.dirty)  status_porcelain_sha256=$($SourceProvenance.status_porcelain_sha256)" -ForegroundColor Gray
Write-Host "  Godot version: $($EngineProvenance.version)  executable_sha256=$($EngineProvenance.executable_sha256)" -ForegroundColor Gray

# Snapshot original bytes for guaranteed byte-identical restoration
$origProjectGodotBytes = [System.IO.File]::ReadAllBytes($ProjectGodotPath)
$origMarkerPath = Join-Path $ProjectRoot "build_tier.txt"
$origMarkerExisted = Test-Path $origMarkerPath
$origMarkerBytes = if ($origMarkerExisted) { [System.IO.File]::ReadAllBytes($origMarkerPath) } else { $null }

# Fresh isolated staging root for this export run. Every requested package
# gets its own new subdirectory, so no stale output from a prior export can
# enter a new package. Cleanup is containment-checked against $BuildsRoot.
$StagingRoot = Join-Path $BuildsRoot (".staging_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $StagingRoot -Force | Out-Null
Write-Host "Fresh staging root: $StagingRoot" -ForegroundColor Gray

function Publish-StagingDirectory {
    # Moves a package's current staging output into its builds/ target,
    # replacing prior contents (so stale local output cannot survive) while
    # excluding package-only manifest/provenance files.
    param (
        [string]$SourceDir,
        [string]$TargetDir
    )
    if (-not (Test-Path -LiteralPath $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    Get-ChildItem -LiteralPath $TargetDir -Force | Remove-Item -Recurse -Force

    $sourceRoot = (Resolve-Path -LiteralPath $SourceDir).Path
    foreach ($file in @(Get-ChildItem -LiteralPath $sourceRoot -Recurse -File -Force)) {
        $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart('\', '/').Replace('\', '/')
        if ($relative -ieq "release-manifest.json") { continue }
        if ($relative -like "provenance/*") { continue }
        $destination = Join-Path $TargetDir ($relative.Replace('/', [System.IO.Path]::DirectorySeparatorChar))
        $destinationDir = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $destinationDir)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }
        Move-Item -LiteralPath $file.FullName -Destination $destination -Force
    }

    $gdignore = Join-Path $TargetDir ".gdignore"
    if (-not (Test-Path $gdignore)) {
        New-Item -ItemType File -Path $gdignore -Force | Out-Null
    }
    Write-Host "  Published staging output to: $TargetDir" -ForegroundColor Green
}

function Package-ReleaseArchive {
    # Stages configuration snapshots, creates release-manifest.json from the
    # staged payload bytes, zips payload plus manifest, writes the external
    # receipt for the EXACT archived manifest bytes, then reopens the new ZIP
    # and verifies it against its receipt before packaging succeeds.
    param (
        [string]$StagingDir,
        [string]$ArchivePath,
        [string]$Platform,
        [string]$PresetName,
        [string]$TierValue
    )
    $archiveName = [System.IO.Path]::GetFileName($ArchivePath)
    Write-Host "  Creating provenance manifest for $archiveName ..." -ForegroundColor Yellow

    # Effective (tier-mutated) project.godot is the configuration actually
    # used by this export; export_presets.cfg is captured unmodified.
    $projectSnapshotBytes = [System.IO.File]::ReadAllBytes($ProjectGodotPath)
    $manifest = New-SblReleaseManifest `
        -StagingDir $StagingDir `
        -ArchiveName $archiveName `
        -Platform $Platform `
        -Tier $TierValue `
        -PresetName $PresetName `
        -SourceProvenance $SourceProvenance `
        -EngineProvenance $EngineProvenance `
        -ProjectGodotBytes $projectSnapshotBytes `
        -PresetsBytes $PresetsBytes

    if (Test-Path -LiteralPath $ArchivePath) {
        Remove-Item -LiteralPath $ArchivePath -Force
    }
    New-SblArchiveFromDirectory -SourceDir $StagingDir -ArchivePath $ArchivePath

    $receiptDigest = Write-SblManifestReceipt -ArchivePath $ArchivePath
    Write-Host "  Wrote receipt: $ArchivePath.manifest.sha256 ($receiptDigest)" -ForegroundColor Gray

    $verifyErrors = Test-SblReleaseArchive `
        -ArchivePath $ArchivePath `
        -ExpectedTier $TierValue `
        -ExpectedPlatform $Platform `
        -ExpectedPreset $PresetName
    if ($verifyErrors.Count -gt 0) {
        throw "Packaging verification failed for '$archiveName': " + ($verifyErrors -join ' | ')
    }
    Write-Host "  PASS: $archiveName reopened and verified against its receipt ($($manifest.payload.Count) payload entries)." -ForegroundColor Green
}

function Export-TierPackage {
    param (
        [string]$TargetTier,
        [switch]$ExportWeb,
        [switch]$ExportWindows,
        [string]$TargetWebDir,
        [string]$TargetWebZipName,
        [string]$TargetWinDir = "",
        [string]$TargetWinZipName = "",
        [string]$PackageKey = "package"
    )

    Write-Host "`n>>> [Export Pipeline] Processing Tier: '$TargetTier' <<<" -ForegroundColor Magenta

    # Fresh isolated staging directory for this package.
    $stagingDir = Join-Path $StagingRoot $PackageKey
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

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
        $webOutput = Join-Path $stagingDir "index.html"
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

        # Write build_tier.txt into the staging web build folder
        $webMarker = Join-Path $stagingDir "build_tier.txt"
        [System.IO.File]::WriteAllText($webMarker, "$TargetTier`n", [System.Text.Encoding]::UTF8)

        # Package Web Zip (manifest + receipt + self-verification)
        if (-not $SkipZip) {
            Package-ReleaseArchive `
                -StagingDir $stagingDir `
                -ArchivePath (Join-Path $DistDir $TargetWebZipName) `
                -Platform "web" `
                -PresetName "Web" `
                -TierValue $TargetTier
        }

        # Publish the current export output into builds/ (stale files removed).
        Publish-StagingDirectory -SourceDir $stagingDir -TargetDir $TargetWebDir
    }

    # 4. Export Windows Desktop Build
    if ($ExportWindows) {
        Write-Host "  Exporting Windows Desktop Release ($TargetTier)..." -ForegroundColor Yellow
        $winOutput = Join-Path $stagingDir "Soulbound.exe"
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

        # Write build_tier.txt into the staging windows build folder
        $winMarker = Join-Path $stagingDir "build_tier.txt"
        [System.IO.File]::WriteAllText($winMarker, "$TargetTier`n", [System.Text.Encoding]::UTF8)

        # Package Windows Zip (manifest + receipt + self-verification)
        if (-not $SkipZip) {
            Package-ReleaseArchive `
                -StagingDir $stagingDir `
                -ArchivePath (Join-Path $DistDir $TargetWinZipName) `
                -Platform "windows" `
                -PresetName "Windows Desktop" `
                -TierValue $TargetTier
        }

        # Publish the current export output into builds/ (stale files removed).
        Publish-StagingDirectory -SourceDir $stagingDir -TargetDir $TargetWinDir
    }
}

try {
    # Execute exports per tier request
    if ($Tier -in @("academic_mvp", "both", "all")) {
        Export-TierPackage `
            -TargetTier "academic_mvp" `
            -ExportWeb `
            -TargetWebDir $WebMvpDir `
            -TargetWebZipName "Soulbound-AcademicMVP-Web.zip" `
            -PackageKey "web_academic_mvp"
    }

    if ($Tier -in @("full_release", "both", "all")) {
        Export-TierPackage `
            -TargetTier "full_release" `
            -ExportWeb `
            -ExportWindows `
            -TargetWebDir $WebFullDir `
            -TargetWebZipName "Soulbound-Web.zip" `
            -TargetWinDir $WindowsDir `
            -TargetWinZipName "Soulbound-Windows-Portable.zip" `
            -PackageKey "full_release"
    }

    # Validate release artifacts (manifest, receipt, payload hashes, gates)
    if (-not $SkipZip) {
        Write-Host "`n>>> Validating Release Artifacts via validate_release.ps1 <<<" -ForegroundColor Yellow
        $ValidateScript = Join-Path $PSScriptRoot "validate_release.ps1"
        & powershell -NoProfile -ExecutionPolicy Bypass -File $ValidateScript -DistDir $DistDir -Tier $Tier -GodotPath $GodotPath
        if ($LASTEXITCODE -ne 0) {
            throw "Release validation failed with exit code $LASTEXITCODE"
        }
    } else {
        Write-Host "`n[SkipZip] No archive, receipt, or archive-manifest verification performed." -ForegroundColor Yellow
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

    # 3. Remove the fresh staging root; the helper refuses any path that does
    #    not resolve inside the expected builds/ root before recursive delete.
    if ($null -ne $StagingRoot -and (Test-Path -LiteralPath $StagingRoot)) {
        Remove-SblDirectoryWithinRoot -Path $StagingRoot -Root $BuildsRoot
        Write-Host "  PASS: staging root removed after export." -ForegroundColor Green
    }
}

Write-Host "`n=========================================" -ForegroundColor Cyan
Write-Host "            Artifact Summary            " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

Get-ChildItem -Path $DistDir, $WebFullDir, $WebMvpDir, $WindowsDir -File | Format-Table -Property Name, Length, LastWriteTime

Write-Host "`nExport build process completed successfully." -ForegroundColor Green
