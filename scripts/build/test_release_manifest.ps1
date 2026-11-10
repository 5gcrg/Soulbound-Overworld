# Soulbound Release Manifest Test Suite (PowerShell)
# SBL-BLD-005: disposable positive and negative controls for the archive-contained
# JSON provenance manifest pipeline. Uses the SAME verifier functions as production
# validation (release_manifest.ps1): Test-SblReleaseArchive, the strict JSON parser,
# provenance capture and the archive-contained PCK gate. All tampered archives are
# disposable copies under a fresh temporary root; nothing under the repository is
# modified except gitignored build/report artifacts.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_release_manifest.ps1
# Exits 0 only when every control behaves as specified by the approved plan.

param (
    [string]$GodotPath = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [switch]$SkipAutoExport = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

. (Join-Path $PSScriptRoot "release_manifest.ps1")

$DistDir = Join-Path $ProjectRoot "dist"
$ReportDir = Join-Path $ProjectRoot "report"
$BuildsRoot = Join-Path $ProjectRoot "builds"
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sbl_bld_005_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

$TestLogPath = Join-Path $ReportDir "release_manifest_test.log"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$script:ControlRows = New-Object System.Collections.ArrayList
$script:ControlFailCount = 0

function Write-TestLog {
    param([string]$Message)
    Add-Content -LiteralPath $TestLogPath -Value $Message
}

function Add-ControlResult {
    param(
        [string]$Category,
        [string]$Control,
        [string]$Expected,
        [string]$Observed,
        [bool]$Passed
    )
    if (-not $Passed) { $script:ControlFailCount++ }
    [void]$script:ControlRows.Add([pscustomobject]@{
            Category = $Category
            Control  = $Control
            Expected = $Expected
            Observed = $Observed
            Status   = if ($Passed) { "PASS" } else { "FAIL" }
        })
    $color = if ($Passed) { "Green" } else { "Red" }
    Write-Host "  [$(if ($Passed) { 'PASS' } else { 'FAIL' })] $Category :: $Control" -ForegroundColor $color
    if (-not $Passed) {
        Write-Host "      expected: $Expected" -ForegroundColor $color
        Write-Host "      observed: $Observed" -ForegroundColor $color
    }
    Write-TestLog "[$(if ($Passed) { 'PASS' } else { 'FAIL' })] $Category :: $Control"
    Write-TestLog "    expected: $Expected"
    Write-TestLog "    observed: $Observed"
}

function Get-DistPackageState {
    $state = @{}
    if (-not (Test-Path -LiteralPath $DistDir)) { return $state }
    foreach ($file in @(Get-ChildItem -LiteralPath $DistDir -File -Force | Where-Object { $_.Name -like "*.zip" -or $_.Name -like "*.manifest.sha256" })) {
        $state[$file.Name] = "$($file.Length):$((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash)"
    }
    return $state
}

function Test-DistPackageStateEqual {
    param($Before, $After)
    if ($Before.Count -ne $After.Count) { return $false }
    foreach ($key in $Before.Keys) {
        if (-not $After.ContainsKey($key)) { return $false }
        if ($After[$key] -cne $Before[$key]) { return $false }
    }
    return $true
}

function Copy-StagingTree {
    param([string]$Source, [string]$Destination)
    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Recurse -Force }
    Copy-Item -LiteralPath $Source -Destination $Destination -Recurse
    return (Resolve-Path -LiteralPath $Destination).Path
}

function New-ControlArchive {
    param(
        [string]$StagingDir,
        [string]$ZipPath,
        [object[]]$ExtraEntries = @()
    )
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    New-SblArchiveFromDirectory -SourceDir $StagingDir -ArchivePath $ZipPath -ExtraEntries $ExtraEntries
    return $ZipPath
}

function Use-OriginalReceipt {
    param([string]$ZipPath, [string]$OriginalReceiptPath)
    Copy-Item -LiteralPath $OriginalReceiptPath -Destination ($ZipPath + ".manifest.sha256") -Force
}

function Write-RecomputedReceipt {
    param([string]$ZipPath)
    return (Write-SblManifestReceipt -ArchivePath $ZipPath)
}

function Get-StagedManifestText {
    param([string]$StagingDir)
    return [System.IO.File]::ReadAllText((Join-Path $StagingDir "release-manifest.json"))
}

function Set-StagedManifestText {
    param([string]$StagingDir, [string]$Text)
    [System.IO.File]::WriteAllText((Join-Path $StagingDir "release-manifest.json"), $Text, $Utf8NoBom)
}

function Update-StagedManifestObject {
    # Parse the staged manifest with the strict parser, apply a mutation
    # scriptblock, and re-serialize (used for semantic tamper controls where
    # the receipt is regenerated so only the intended check can fail).
    param([string]$StagingDir, [scriptblock]$Mutation)
    $text = Get-StagedManifestText -StagingDir $StagingDir
    $manifest = ConvertFrom-SblStrictJson -Text $text -Source "staged manifest"
    & $Mutation $manifest
    $newText = ConvertTo-Json -InputObject $manifest -Depth 8
    Set-StagedManifestText -StagingDir $StagingDir -Text $newText
    return $newText
}

function Assert-VerificationFailure {
    param(
        [string]$Category,
        [string]$Name,
        [string]$ZipPath,
        [string[]]$ExpectPatterns,
        [string]$ReceiptPath = "",
        [string]$ExpectedTier = "full_release",
        [string]$ExpectedPlatform = "web",
        [string]$ExpectedPreset = "Web"
    )
    $errors = @()
    try {
        $errors = Test-SblReleaseArchive -ArchivePath $ZipPath -ReceiptPath $ReceiptPath -ExpectedTier $ExpectedTier -ExpectedPlatform $ExpectedPlatform -ExpectedPreset $ExpectedPreset
    } catch {
        Write-TestLog "--- $Name THREW: $($_.Exception.Message) ---"
        Add-ControlResult -Category $Category -Control $Name -Expected ("verification fails matching: " + ($ExpectPatterns -join " AND ")) -Observed "THREW: $($_.Exception.Message)" -Passed $false
        return
    }
    $joined = ($errors -join " || ")
    $unmatched = @($ExpectPatterns | Where-Object { $joined -notmatch $_ })
    $passed = (($errors.Count -gt 0) -and ($unmatched.Count -eq 0))
    Write-TestLog "--- $Name ($ZipPath) : $($errors.Count) diagnostic(s) ---"
    Write-TestLog $joined
    Add-ControlResult -Category $Category -Control $Name `
        -Expected ("nonzero verification failure; diagnostics match: " + ($ExpectPatterns -join " AND ")) `
        -Observed ("$($errors.Count) error(s): " + $joined) `
        -Passed $passed
}

function Assert-VerificationSuccess {
    param(
        [string]$Category,
        [string]$Name,
        [string]$ZipPath,
        [string]$ReceiptPath = "",
        [string]$ExpectedTier = "",
        [string]$ExpectedPlatform = "",
        [string]$ExpectedPreset = ""
    )
    $errors = @()
    try {
        $errors = Test-SblReleaseArchive -ArchivePath $ZipPath -ReceiptPath $ReceiptPath -ExpectedTier $ExpectedTier -ExpectedPlatform $ExpectedPlatform -ExpectedPreset $ExpectedPreset
    } catch {
        Add-ControlResult -Category $Category -Control $Name -Expected "0 diagnostics" -Observed "THREW: $($_.Exception.Message)" -Passed $false
        return $false
    }
    $joined = ($errors -join " || ")
    $passed = ($errors.Count -eq 0)
    Write-TestLog "--- $Name ($ZipPath) : $($errors.Count) diagnostic(s) ---"
    if (-not $passed) { Write-TestLog $joined }
    Add-ControlResult -Category $Category -Control $Name -Expected "0 diagnostics (valid package)" -Observed ("$($errors.Count) error(s): " + $joined) -Passed $passed
    return $passed
}

function Invoke-ControlProcess {
    param(
        [string]$Category,
        [string]$Name,
        [string]$FilePath,
        [string[]]$Arguments,
        [int[]]$ExpectedExitCodes,
        [string[]]$ExpectPatterns = @(),
        [string[]]$ForbidPatterns = @(),
        [switch]$RealUserData = $false
    )
    $stdoutFile = Join-Path $TempRoot ("stdout_" + [System.Guid]::NewGuid().ToString("N") + ".txt")
    $stderrFile = Join-Path $TempRoot ("stderr_" + [System.Guid]::NewGuid().ToString("N") + ".txt")
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $FilePath) + $Arguments

    # Exporter subprocesses require the REAL user-data directories because
    # Godot resolves export templates from %APPDATA%\Godot\export_templates;
    # a disposable redirection makes --export-release fail with
    # "No export template found". The suite's own Godot tests and PCK gates
    # stay under disposable isolation, nested validate_release re-enters its
    # own disposable isolation before its gates, and an export run leaves the
    # real %APPDATA%\Godot digest unchanged (verified), so restoring the
    # pre-isolation environment only for the export child is safe.
    $savedAppData = $env:APPDATA
    $savedLocalAppData = $env:LOCALAPPDATA
    if ($RealUserData -and $null -ne $script:Isolation) {
        $env:APPDATA = $script:Isolation.OldAppData
        $env:LOCALAPPDATA = $script:Isolation.OldLocalAppData
    }
    try {
        $proc = Start-Process -FilePath "powershell.exe" -ArgumentList $argList `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutFile -RedirectStandardError $stderrFile
        $output = ""
        if (Test-Path $stdoutFile) { $output += [System.IO.File]::ReadAllText($stdoutFile) }
        if (Test-Path $stderrFile) { $output += [System.IO.File]::ReadAllText($stderrFile) }

        $exitOk = ($ExpectedExitCodes -contains $proc.ExitCode)
        $missing = @($ExpectPatterns | Where-Object { $output -notmatch $_ })
        $forbidden = @($ForbidPatterns | Where-Object { $output -match $_ })
        $passed = $exitOk -and ($missing.Count -eq 0) -and ($forbidden.Count -eq 0)

        Write-TestLog "--- $Name : exit=$($proc.ExitCode) (expected $($ExpectedExitCodes -join '|')) ---"
        Write-TestLog ($output -replace "(?m)^.{2000,}$", "<TRUNCATED-LINE>")

        $observed = "exit=$($proc.ExitCode)"
        if ($missing.Count -gt 0) { $observed += "; missing output patterns: $($missing -join ', ')" }
        if ($forbidden.Count -gt 0) { $observed += "; forbidden output present: $($forbidden -join ', ')" }
        if (-not $exitOk) {
            $tail = (($output -split "`r?`n" | Where-Object { $_ -match '\S' } | Select-Object -Last 5) -join " | ")
            $observed += "; output tail: $tail"
        }
        Add-ControlResult -Category $Category -Control $Name `
            -Expected ("exit in (" + ($ExpectedExitCodes -join ",") + ")" + $(if ($ExpectPatterns.Count -gt 0) { "; output matches: " + ($ExpectPatterns -join " AND ") } else { "" }) + $(if ($ForbidPatterns.Count -gt 0) { "; output avoids: " + ($ForbidPatterns -join " AND ") } else { "" })) `
            -Observed $observed `
            -Passed $passed
        return [pscustomobject]@{ ExitCode = $proc.ExitCode; Output = $output; Passed = $passed }
    } finally {
        if ($RealUserData) {
            $env:APPDATA = $savedAppData
            $env:LOCALAPPDATA = $savedLocalAppData
        }
    }
}

# ---------------------------------------------------------------------------
# Control fixtures
# ---------------------------------------------------------------------------

function New-SyntheticProjectGodot {
    param([string]$Tier)
    return @"
config_version=5

[application]

config/name="Soulbound"

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
renderer/rendering_method.web="gl_compatibility"

[soulbound]

release_tier="$Tier"
"@
}

function New-SyntheticPresets {
    return @"
[preset.0]

name="Windows Desktop"
platform="Windows Desktop"
export_filter="all_resources"

[preset.0.options]

custom_template/release=""

[preset.1]

name="Web"
platform="Web"
export_filter="all_resources"

[preset.1.options]

variant/thread_support=false
"@
}

function New-SyntheticFixture {
    # Builds a minimal but fully valid package (payload + snapshots + manifest
    # + receipt) for a named release archive and returns its zip path.
    param(
        [Parameter(Mandatory = $true)][string]$ArchiveName,
        [Parameter(Mandatory = $true)][string]$Platform,
        [Parameter(Mandatory = $true)][string]$Tier,
        [Parameter(Mandatory = $true)][string]$PresetName,
        [string]$Label
    )
    $fixtureDir = Join-Path $TempRoot ("synthetic_" + $(if ($Label) { $Label } else { [System.IO.Path]::GetFileNameWithoutExtension($ArchiveName) }))
    if (Test-Path -LiteralPath $fixtureDir) { Remove-Item -LiteralPath $fixtureDir -Recurse -Force }
    New-Item -ItemType Directory -Path $fixtureDir -Force | Out-Null

    if ($Platform -eq "web") {
        [System.IO.File]::WriteAllText((Join-Path $fixtureDir "index.html"), "<!doctype html><html><body>soulbound synthetic fixture</body></html>", $Utf8NoBom)
        [System.IO.File]::WriteAllBytes((Join-Path $fixtureDir "index.wasm"), [byte[]](0..63))
        [System.IO.File]::WriteAllBytes((Join-Path $fixtureDir "index.pck"), [byte[]](128..191))
    } else {
        [System.IO.File]::WriteAllBytes((Join-Path $fixtureDir "Soulbound.exe"), [byte[]](0..255))
        [System.IO.File]::WriteAllBytes((Join-Path $fixtureDir "Soulbound.pck"), [byte[]](128..191))
    }
    [System.IO.File]::WriteAllText((Join-Path $fixtureDir "build_tier.txt"), "$Tier`n", $Utf8NoBom)

    $source = Get-SblSourceProvenance -RepoRoot $ProjectRoot.Path
    $engine = Get-SblEngineProvenance -GodotPath $GodotPath
    $projectBytes = [System.Text.Encoding]::UTF8.GetBytes((New-SyntheticProjectGodot -Tier $Tier))
    $presetsBytes = [System.Text.Encoding]::UTF8.GetBytes((New-SyntheticPresets))
    [void](New-SblReleaseManifest -StagingDir $fixtureDir -ArchiveName $ArchiveName -Platform $Platform -Tier $Tier -PresetName $PresetName -SourceProvenance $source -EngineProvenance $engine -ProjectGodotBytes $projectBytes -PresetsBytes $presetsBytes)

    $zipPath = Join-Path $fixtureDir $ArchiveName
    New-SblArchiveFromDirectory -SourceDir $fixtureDir -ArchivePath $zipPath
    [void](Write-SblManifestReceipt -ArchivePath $zipPath)
    return $zipPath
}

function Get-ArchiveManifestObject {
    param([string]$ZipPath)
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    try {
        $entry = $zip.GetEntry("release-manifest.json")
        if ($null -eq $entry) { return $null }
        $bytes = Get-SblEntryBytes -Entry $entry
    } finally {
        $zip.Dispose()
    }
    return (ConvertFrom-SblStrictJson -Text ([System.Text.Encoding]::UTF8.GetString($bytes)) -Source $ZipPath)
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

$script:Isolation = $null
$script:IsolationResult = $null
$exitCode = 1

try {
    Write-Host "===============================================" -ForegroundColor Cyan
    Write-Host "  SBL-BLD-005 Release Manifest Test Suite      " -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    [System.IO.File]::WriteAllText($TestLogPath, "[$(Get-Date -Format o)] SBL-BLD-005 test_release_manifest.ps1`n", $Utf8NoBom)

    if (-not (Test-Path -LiteralPath $GodotPath)) {
        throw "Godot executable not found at '$GodotPath'; no fallback is attempted."
    }

    # [0] Prove disposable user data BEFORE any Godot test or PCK gate runs.
    Write-Host "`n[0] Disposable user-data isolation proof (before any Godot test/gate)..." -ForegroundColor Yellow
    $script:Isolation = Enter-SblGodotUserDataIsolation -GodotPath $GodotPath -ProjectRoot $ProjectRoot.Path -Label "manifest_tests"
    Write-Host "  PROVED: OS.get_user_data_dir() -> $($script:Isolation.ProbeUserDir)" -ForegroundColor Green
    Write-TestLog "isolation probe: $($script:Isolation.ProbeUserDir)"

    # [1] Preflight: the three real packages must exist (auto-export if not).
    Write-Host "`n[1] Preflight real package availability..." -ForegroundColor Yellow
    $requiredArtifacts = @(
        "Soulbound-AcademicMVP-Web.zip", "Soulbound-AcademicMVP-Web.zip.manifest.sha256",
        "Soulbound-Web.zip", "Soulbound-Web.zip.manifest.sha256",
        "Soulbound-Windows-Portable.zip", "Soulbound-Windows-Portable.zip.manifest.sha256"
    )
    $missingArtifacts = @($requiredArtifacts | Where-Object { -not (Test-Path -LiteralPath (Join-Path $DistDir $_)) })
    if ($missingArtifacts.Count -gt 0) {
        if ($SkipAutoExport) { throw "Missing dist artifacts and -SkipAutoExport set: $($missingArtifacts -join ', ')" }
        Write-Host "  Missing: $($missingArtifacts -join ', ') -> running export_release.ps1 -Tier all ..." -ForegroundColor Yellow
        $preflight = Invoke-ControlProcess -Category "preflight" -Name "auto_export_produces_packages" `
            -FilePath (Join-Path $PSScriptRoot "export_release.ps1") `
            -Arguments @("-Tier", "all", "-GodotPath", $GodotPath) `
            -ExpectedExitCodes @(0) `
            -RealUserData
        if (-not $preflight.Passed) { throw "Preflight export failed; cannot run manifest controls." }
    } else {
        Add-ControlResult -Category "preflight" -Control "real_packages_present" -Expected "all 6 dist artifacts present" -Observed "present" -Passed $true
    }

    # [2] Positive: valid synthetic fixtures.
    Write-Host "`n[2] Positive controls: valid synthetic fixtures..." -ForegroundColor Yellow
    $syntheticWeb = New-SyntheticFixture -ArchiveName "Soulbound-Web.zip" -Platform "web" -Tier "full_release" -PresetName "Web" -Label "web"
    [void](Assert-VerificationSuccess -Category "positive" -Name "valid_synthetic_web_fixture" -ZipPath $syntheticWeb)
    $syntheticWindows = New-SyntheticFixture -ArchiveName "Soulbound-Windows-Portable.zip" -Platform "windows" -Tier "full_release" -PresetName "Windows Desktop" -Label "windows"
    [void](Assert-VerificationSuccess -Category "positive" -Name "valid_synthetic_windows_fixture" -ZipPath $syntheticWindows -ExpectedTier "full_release" -ExpectedPlatform "windows" -ExpectedPreset "Windows Desktop")

    # [3] Positive: the three real exported packages + their own PCK gates.
    Write-Host "`n[3] Positive controls: real exported packages and archive-contained PCK gates..." -ForegroundColor Yellow
    $realSpecs = @(
        (Get-SblPackageSpec -ArchiveName "Soulbound-AcademicMVP-Web.zip"),
        (Get-SblPackageSpec -ArchiveName "Soulbound-Web.zip"),
        (Get-SblPackageSpec -ArchiveName "Soulbound-Windows-Portable.zip")
    )
    foreach ($spec in $realSpecs) {
        $zipPath = Join-Path $DistDir $spec.ArchiveName
        $packageOk = Assert-VerificationSuccess -Category "positive" -Name "real_package_$($spec.Label)" -ZipPath $zipPath
        if ($packageOk) {
            $gateError = Invoke-SblArchivePckGate -ArchivePath $zipPath -GodotPath $GodotPath -Spec $spec -ReportDir $ReportDir
            Add-ControlResult -Category "positive" -Control "pck_gate_$($spec.Label)" `
                -Expected "archive's own PCK passes verify_exported_tier gate" `
                -Observed $(if ($gateError) { $gateError } else { "pass (exit 0)" }) `
                -Passed ($null -eq $gateError)
        } else {
            Add-ControlResult -Category "positive" -Control "pck_gate_$($spec.Label)" `
                -Expected "archive's own PCK passes verify_exported_tier gate" `
                -Observed "skipped: package manifest verification failed" -Passed $false
        }
    }

    # [4] Negative controls on disposable archive copies (shared verifier).
    Write-Host "`n[4] Negative controls: disposable archive copies..." -ForegroundColor Yellow
    $SourceZip = Join-Path $DistDir "Soulbound-Web.zip"
    $SourceReceipt = Join-Path $DistDir "Soulbound-Web.zip.manifest.sha256"
    $pristineStaging = Join-Path $TempRoot "staging_pristine_web"
    Expand-SblArchiveToDirectory -ArchivePath $SourceZip -DestinationDir $pristineStaging

    function New-WebControlCopy {
        param([string]$Name)
        $dir = Join-Path $TempRoot "ctl_$Name"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $staging = Copy-StagingTree -Source $pristineStaging -Destination (Join-Path $dir "staging")
        return [pscustomobject]@{ Dir = $dir; Staging = $staging }
    }

    # 4.0 Sanity: a byte-faithful rebuild of the pristine staging passes.
    $rebuildStaging = Copy-StagingTree -Source $pristineStaging -Destination (Join-Path $TempRoot "ctl_rebuild_staging")
    $rebuildDirOut = Join-Path $TempRoot "ctl_rebuild_out"
    New-Item -ItemType Directory -Path $rebuildDirOut -Force | Out-Null
    $rebuildZipOut = New-ControlArchive -StagingDir $rebuildStaging -ZipPath (Join-Path $rebuildDirOut "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $rebuildZipOut -OriginalReceiptPath $SourceReceipt
    [void](Assert-VerificationSuccess -Category "sanity" -Name "byte_faithful_rebuild_still_valid" -ZipPath $rebuildZipOut)

    # 4.1 Missing manifest
    $ctl = New-WebControlCopy -Name "missing_manifest"
    Remove-Item -LiteralPath (Join-Path $ctl.Staging "release-manifest.json") -Force
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "missing_manifest" -ZipPath $zip -ExpectPatterns @("Missing required root 'release-manifest\.json'")

    # 4.2 Missing receipt (no fallback to self-declared metadata)
    $ctl = New-WebControlCopy -Name "missing_receipt"
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Assert-VerificationFailure -Category "negative" -Name "missing_receipt" -ZipPath $zip -ExpectPatterns @("Missing required manifest receipt")

    # 4.3 Malformed manifest (receipt regenerated so only parsing fails)
    $ctl = New-WebControlCopy -Name "malformed_manifest"
    Set-StagedManifestText -StagingDir $ctl.Staging -Text "{`"manifest_schema_version`": 1, `"package`": {"
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "malformed_manifest_json" -ZipPath $zip -ExpectPatterns @("Malformed release manifest")

    # 4.4 Future schema version
    $ctl = New-WebControlCopy -Name "future_schema"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation { param($m) $m["manifest_schema_version"] = [long]2 })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "future_schema_version_2" -ZipPath $zip -ExpectPatterns @("unsupported manifest schema version")

    # 4.5 Duplicate JSON object member name (receipt regenerated)
    $ctl = New-WebControlCopy -Name "duplicate_json_member"
    Set-StagedManifestText -StagingDir $ctl.Staging -Text "{`"manifest_schema_version`": 1, `"source`": {`"dirty`": false, `"dirty`": true}}"
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "duplicate_json_member_name" -ZipPath $zip -ExpectPatterns @("duplicate object member name")

    # 4.6 Change only source.commit -> receipt mismatch (payload untouched)
    $ctl = New-WebControlCopy -Name "source_commit_tamper"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation { param($m) $m["source"]["commit"] = "0123456789abcdef0123456789abcdef01234567" })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "source_commit_tamper_receipt_mismatch" -ZipPath $zip -ExpectPatterns @("Manifest receipt mismatch")

    # 4.7 Change only source.dirty -> receipt mismatch
    $ctl = New-WebControlCopy -Name "source_dirty_tamper"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $current = [bool]$m["source"]["dirty"]
            $m["source"]["dirty"] = (-not $current)
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "source_dirty_tamper_receipt_mismatch" -ZipPath $zip -ExpectPatterns @("Manifest receipt mismatch")

    # 4.8 Older same-tier manifest substitution (metadata-only change of a
    #     previous commit) -> the expected receipt detects it.
    $olderRun = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $ProjectRoot.Path, "rev-parse", "HEAD~1")
    $olderCommit = $olderRun.StdOut.Trim()
    if ($olderRun.ExitCode -ne 0 -or $olderCommit -notmatch '^[0-9a-f]{40}$') { $olderCommit = "0123456789abcdef0123456789abcdef01234567" }
    $ctl = New-WebControlCopy -Name "older_manifest_swap"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $m["source"]["commit"] = $olderCommit
            $m["source"]["status_porcelain_sha256"] = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "older_same_tier_manifest_swap" -ZipPath $zip -ExpectPatterns @("Manifest receipt mismatch")

    # 4.9 Payload byte change (same length) -> SHA mismatch only
    $ctl = New-WebControlCopy -Name "payload_byte_flip"
    $indexHtmlPath = Join-Path $ctl.Staging "index.html"
    $htmlBytes = [System.IO.File]::ReadAllBytes($indexHtmlPath)
    $mid = [int]($htmlBytes.Length / 2)
    $htmlBytes[$mid] = $htmlBytes[$mid] -bxor 0x01
    [System.IO.File]::WriteAllBytes($indexHtmlPath, $htmlBytes)
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "payload_byte_change_same_size" -ZipPath $zip -ExpectPatterns @("index\.html' SHA-256 mismatch")

    # 4.10 Payload length change -> size/length failure
    $ctl = New-WebControlCopy -Name "payload_length_change"
    [System.IO.File]::WriteAllText((Join-Path $ctl.Staging "index.html"), "<!doctype html><html><body>soulbound synthetic fixture with different length</body></html>", $Utf8NoBom)
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "payload_length_change" -ZipPath $zip -ExpectPatterns @("index\.html' size mismatch|index\.html' raw-byte length mismatch")

    # 4.11 Delete a listed file -> missing payload
    $ctl = New-WebControlCopy -Name "missing_listed_file"
    Remove-Item -LiteralPath (Join-Path $ctl.Staging "index.html") -Force
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "delete_listed_file" -ZipPath $zip -ExpectPatterns @("no matching ZIP entry \(missing file\)", "Missing required entry point: 'index\.html'")

    # 4.12 Add an unlisted file -> exact entry-set failure
    $ctl = New-WebControlCopy -Name "extra_unlisted_file"
    [System.IO.File]::WriteAllText((Join-Path $ctl.Staging "unlisted_extra.txt"), "not in manifest", $Utf8NoBom)
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "add_unlisted_file" -ZipPath $zip -ExpectPatterns @("not listed in the manifest payload")

    # 4.13 Duplicate ZIP entry path (before any hash lookup)
    $ctl = New-WebControlCopy -Name "duplicate_zip_entry"
    $dupBytes = [System.Text.Encoding]::UTF8.GetBytes("<!doctype html> duplicate entry")
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip") -ExtraEntries @(@{ Name = "index.html"; Bytes = $dupBytes })
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "duplicate_zip_entry_path" -ZipPath $zip -ExpectPatterns @("duplicate ZIP entry path")

    # 4.14 Case-colliding ZIP entry path
    $ctl = New-WebControlCopy -Name "case_collision"
    $caseBytes = [System.Text.Encoding]::UTF8.GetBytes("<!doctype html> case variant")
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip") -ExtraEntries @(@{ Name = "Index.html"; Bytes = $caseBytes })
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "case_colliding_zip_entry" -ZipPath $zip -ExpectPatterns @("case-colliding ZIP entry paths")

    # 4.15 Duplicate root manifest entry
    $ctl = New-WebControlCopy -Name "duplicate_manifest_entry"
    $manifestBytesForDup = [System.IO.File]::ReadAllBytes((Join-Path $ctl.Staging "release-manifest.json"))
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip") -ExtraEntries @(@{ Name = "release-manifest.json"; Bytes = $manifestBytesForDup })
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "duplicate_manifest_entry" -ZipPath $zip -ExpectPatterns @("duplicate ZIP entry path")

    # 4.16 Case-variant manifest file name
    $ctl = New-WebControlCopy -Name "case_variant_manifest"
    Move-Item -LiteralPath (Join-Path $ctl.Staging "release-manifest.json") -Destination (Join-Path $ctl.Staging "Release-Manifest.json") -Force
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "case_variant_manifest_name" -ZipPath $zip -ExpectPatterns @("case-variant manifest entry", "Missing required root")

    # 4.17 Traversal / absolute / backslash / drive paths + nothing written outside temp root
    $ctl = New-WebControlCopy -Name "unsafe_paths"
    $sentinelBytes = [System.Text.Encoding]::UTF8.GetBytes("sentinel")
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip") -ExtraEntries @(
        @{ Name = "../sbl_bld_005_evil_traversal.txt"; Bytes = $sentinelBytes },
        @{ Name = "/sbl_bld_005_evil_absolute.txt"; Bytes = $sentinelBytes },
        @{ Name = "sub\sbl_bld_005_evil_backslash.txt"; Bytes = $sentinelBytes },
        @{ Name = "C:/sbl_bld_005_evil_drive.txt"; Bytes = $sentinelBytes },
        @{ Name = "a//b.txt"; Bytes = $sentinelBytes }
    )
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "unsafe_traversal_absolute_paths" -ZipPath $zip -ExpectPatterns @("traversal component", "absolute", "backslash", "drive-qualified", "empty component")
    $evilHits = @()
    foreach ($probeRoot in @($ProjectRoot.Path, (Split-Path -Parent $ProjectRoot.Path))) {
        $evilHits += @(Get-ChildItem -LiteralPath $probeRoot -Filter "sbl_bld_005_evil*" -Force -File -ErrorAction SilentlyContinue)
    }
    $evilHits += @(Get-ChildItem -LiteralPath $TempRoot -Filter "sbl_bld_005_evil*" -Recurse -Force -File -ErrorAction SilentlyContinue)
    $evilHits += @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter "sbl_bld_005_evil*" -Force -File -ErrorAction SilentlyContinue)
    Add-ControlResult -Category "negative" -Control "unsafe_paths_write_nothing_outside_root" `
        -Expected "no sbl_bld_005_evil* file exists outside the disposable temp root" `
        -Observed ("evil artifacts found: $($evilHits.Count)") `
        -Passed ($evilHits.Count -eq 0)

    # 4.18 Unsupported entry types (symlink / reparse / directory)
    $ctl = New-WebControlCopy -Name "unsupported_types"
    $typeBytes = [System.Text.Encoding]::UTF8.GetBytes("type probe")
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip") -ExtraEntries @(
        @{ Name = "symlink_probe.txt"; Bytes = $typeBytes; ExternalAttributes = [int]0xA1FF0000 },
        @{ Name = "reparse_probe.txt"; Bytes = $typeBytes; ExternalAttributes = [int]0x400 },
        @{ Name = "dir_probe/"; Bytes = [byte[]]@() }
    )
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "unsupported_symlink_reparse_directory_types" -ZipPath $zip -ExpectPatterns @("unsupported symlink entry", "unsupported reparse-point entry", "unsupported directory entry")

    # 4.19 Duplicate payload path in the manifest (receipt regenerated)
    $ctl = New-WebControlCopy -Name "duplicate_payload_path"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $clone = $m["payload"][0]
            $m["payload"].Add($clone)
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "duplicate_manifest_payload_path" -ZipPath $zip -ExpectPatterns @("duplicate payload path")

    # 4.20 Case-colliding payload paths in the manifest (receipt regenerated)
    $ctl = New-WebControlCopy -Name "case_colliding_payload"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $first = $m["payload"][0]
            $clone = [ordered]@{ path = $first["path"].ToString().ToUpperInvariant(); size_bytes = $first["size_bytes"]; sha256 = $first["sha256"] }
            $m["payload"].Add($clone)
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "case_colliding_manifest_payload_path" -ZipPath $zip -ExpectPatterns @("case-colliding payload paths")

    # 4.21 Swapped manifests across tiers/platforms (manifests AND receipts
    #     swapped so the receipt itself passes; identity must catch it)
    $mvpZip = Join-Path $DistDir "Soulbound-AcademicMVP-Web.zip"
    $mvpReceipt = Join-Path $DistDir "Soulbound-AcademicMVP-Web.zip.manifest.sha256"
    $swapDir = Join-Path $TempRoot "ctl_swapped"
    New-Item -ItemType Directory -Path $swapDir -Force | Out-Null
    $swapWebStaging = Copy-StagingTree -Source $pristineStaging -Destination (Join-Path $swapDir "web")
    $mvpStaging = Join-Path $TempRoot "ctl_swapped_mvp"
    Expand-SblArchiveToDirectory -ArchivePath $mvpZip -DestinationDir $mvpStaging
    # swap manifest files
    $webManifestText = [System.IO.File]::ReadAllText((Join-Path $swapWebStaging "release-manifest.json"))
    $mvpManifestText = [System.IO.File]::ReadAllText((Join-Path $mvpStaging "release-manifest.json"))
    Set-StagedManifestText -StagingDir $swapWebStaging -Text $mvpManifestText
    Set-StagedManifestText -StagingDir $mvpStaging -Text $webManifestText
    $swappedWebZip = New-ControlArchive -StagingDir $swapWebStaging -ZipPath (Join-Path $swapDir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $swappedWebZip -OriginalReceiptPath $mvpReceipt
    Assert-VerificationFailure -Category "negative" -Name "swapped_manifest_across_tiers" -ZipPath $swappedWebZip -ExpectPatterns @("does not match archive file name")
    $swappedMvpZip = New-ControlArchive -StagingDir $mvpStaging -ZipPath (Join-Path $swapDir "Soulbound-AcademicMVP-Web.zip")
    Use-OriginalReceipt -ZipPath $swappedMvpZip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "swapped_manifest_across_tiers_mvp" -ZipPath $swappedMvpZip -ExpectedTier "academic_mvp" -ExpectPatterns @("does not match archive file name")

    # 4.22 Godot version metadata tamper (receipt regenerated -> schema catch)
    $ctl = New-WebControlCopy -Name "godot_version_tamper"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $m["godot"]["version"] = "4.6.0.stable.official.deadbeef"
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "godot_version_metadata_tamper" -ZipPath $zip -ExpectPatterns @("godot\.version' must record the actual Godot")

    # 4.23 Configuration: renderer field tamper (receipt regenerated)
    $ctl = New-WebControlCopy -Name "renderer_field_tamper"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $m["configuration"]["renderer"] = "forward_plus"
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "configuration_renderer_field_tamper" -ZipPath $zip -ExpectPatterns @("configuration\.renderer' must be 'gl_compatibility'")

    # 4.24 Configuration: web single-thread flag tamper (receipt regenerated)
    $ctl = New-WebControlCopy -Name "thread_flag_tamper"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $m["configuration"]["web_thread_support"] = $true
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "configuration_web_thread_flag_tamper" -ZipPath $zip -ExpectPatterns @("web_thread_support=false \(single-threaded web invariant\)")

    # 4.25 Configuration: effective tier tamper (receipt regenerated)
    $ctl = New-WebControlCopy -Name "tier_field_tamper"
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            $m["package"]["tier"] = "academic_mvp"
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "configuration_tier_tamper" -ZipPath $zip -ExpectPatterns @("package specification tier", "build_tier\.txt marker")

    # 4.26 Configuration snapshot bytes changed without manifest update -> payload hash mismatch
    $ctl = New-WebControlCopy -Name "snapshot_bytes_tamper"
    [System.IO.File]::WriteAllText((Join-Path $ctl.Staging "provenance\export_presets.cfg"), ((New-SyntheticPresets) + "`n# tampered snapshot`n"), $Utf8NoBom)
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    Assert-VerificationFailure -Category "negative" -Name "configuration_snapshot_bytes_tamper" -ZipPath $zip -ExpectPatterns @("provenance/export_presets\.cfg' SHA-256 mismatch")

    # 4.27 Configuration snapshot semantically inconsistent with manifest
    #     (payload hash + receipt regenerated; thread semantics must still fail)
    $ctl = New-WebControlCopy -Name "snapshot_semantic_tamper"
    $tamperedPresets = (New-SyntheticPresets) -replace "variant/thread_support=false", "variant/thread_support=true"
    [System.IO.File]::WriteAllText((Join-Path $ctl.Staging "provenance\export_presets.cfg"), $tamperedPresets, $Utf8NoBom)
    $newPresetsBytes = [System.IO.File]::ReadAllBytes((Join-Path $ctl.Staging "provenance\export_presets.cfg"))
    $newPresetsSha = Get-SblSha256LowerFromBytes -Bytes $newPresetsBytes
    [void](Update-StagedManifestObject -StagingDir $ctl.Staging -Mutation {
            param($m)
            foreach ($record in $m["payload"]) {
                if ($record["path"] -ceq "provenance/export_presets.cfg") {
                    $record["size_bytes"] = [long]$newPresetsBytes.Length
                    $record["sha256"] = $newPresetsSha
                }
            }
        })
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [void](Write-RecomputedReceipt -ZipPath $zip)
    Assert-VerificationFailure -Category "negative" -Name "configuration_snapshot_semantic_mismatch" -ZipPath $zip -ExpectPatterns @("disagrees with the archived export preset snapshot")

    # 4.28 Corrupt archive bytes (packaging verification failure)
    $ctl = New-WebControlCopy -Name "corrupt_archive"
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    Use-OriginalReceipt -ZipPath $zip -OriginalReceiptPath $SourceReceipt
    $zipBytes = [System.IO.File]::ReadAllBytes($zip)
    $truncated = New-Object byte[] ([int]($zipBytes.Length * 0.6))
    [System.Array]::Copy($zipBytes, $truncated, $truncated.Length)
    [System.IO.File]::WriteAllBytes($zip, $truncated)
    Assert-VerificationFailure -Category "negative" -Name "corrupt_archive_bytes" -ZipPath $zip -ExpectPatterns @("cannot be read as a ZIP package")

    # 4.29 Garbage receipt
    $ctl = New-WebControlCopy -Name "garbage_receipt"
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [System.IO.File]::WriteAllText(($zip + ".manifest.sha256"), "this-is-not-a-digest`n", $Utf8NoBom)
    Assert-VerificationFailure -Category "negative" -Name "garbage_receipt_content" -ZipPath $zip -ExpectPatterns @("does not contain a single lowercase SHA-256 digest")

    # 4.30 Receipt with wrong digest
    $ctl = New-WebControlCopy -Name "wrong_receipt_digest"
    $zip = New-ControlArchive -StagingDir $ctl.Staging -ZipPath (Join-Path $ctl.Dir "Soulbound-Web.zip")
    [System.IO.File]::WriteAllText(($zip + ".manifest.sha256"), ("0" * 64) + "`n", $Utf8NoBom)
    Assert-VerificationFailure -Category "negative" -Name "wrong_receipt_digest" -ZipPath $zip -ExpectPatterns @("Manifest receipt mismatch")

    # [5] Subprocess controls: literal non-zero exits through validate/export.
    Write-Host "`n[5] Subprocess controls: validate_release/export_release non-zero exits..." -ForegroundColor Yellow
    $ValidateScript = Join-Path $PSScriptRoot "validate_release.ps1"
    $ExportScript = Join-Path $PSScriptRoot "export_release.ps1"
    $badEnginePath = "C:\sbl_bld_005_missing_engine\Godot_v4.7.2-stable_win64_console.exe"

    # 5.1 validate_release: missing manifest -> exit 1 with diagnostic
    $subDir = Join-Path $TempRoot "sub_dist_missing_manifest"
    New-Item -ItemType Directory -Path $subDir -Force | Out-Null
    $mvpStagingSub = Join-Path $TempRoot "staging_sub_mvp"
    Expand-SblArchiveToDirectory -ArchivePath $mvpZip -DestinationDir $mvpStagingSub
    $mvpNoManifestStaging = Copy-StagingTree -Source $mvpStagingSub -Destination (Join-Path $TempRoot "staging_sub_mvp_nomanifest")
    Remove-Item -LiteralPath (Join-Path $mvpNoManifestStaging "release-manifest.json") -Force
    $subMvpZip = New-ControlArchive -StagingDir $mvpNoManifestStaging -ZipPath (Join-Path $subDir "Soulbound-AcademicMVP-Web.zip")
    Use-OriginalReceipt -ZipPath $subMvpZip -OriginalReceiptPath $mvpReceipt
    [void](Invoke-ControlProcess -Category "subprocess" -Name "validate_missing_manifest_exit_nonzero" `
            -FilePath $ValidateScript `
            -Arguments @("-DistDir", $subDir, "-Tier", "academic_mvp", "-GodotPath", $GodotPath) `
            -ExpectedExitCodes @(1) `
            -ExpectPatterns @("Missing required root 'release-manifest\.json'"))

    # 5.2 validate_release: missing receipt -> exit 1 with diagnostic
    $subDir2 = Join-Path $TempRoot "sub_dist_missing_receipt"
    New-Item -ItemType Directory -Path $subDir2 -Force | Out-Null
    $mvpReceiptlessStaging = Copy-StagingTree -Source $mvpStagingSub -Destination (Join-Path $TempRoot "staging_sub_mvp_noreceipt")
    $subMvpZip2 = New-ControlArchive -StagingDir $mvpReceiptlessStaging -ZipPath (Join-Path $subDir2 "Soulbound-AcademicMVP-Web.zip")
    [void](Invoke-ControlProcess -Category "subprocess" -Name "validate_missing_receipt_exit_nonzero" `
            -FilePath $ValidateScript `
            -Arguments @("-DistDir", $subDir2, "-Tier", "academic_mvp", "-GodotPath", $GodotPath) `
            -ExpectedExitCodes @(1) `
            -ExpectPatterns @("Missing required manifest receipt"))

    # 5.3 validate_release: payload tamper -> exit 1 with SHA diagnostic
    $subDir3 = Join-Path $TempRoot "sub_dist_payload_tamper"
    New-Item -ItemType Directory -Path $subDir3 -Force | Out-Null
    $mvpTamperStaging = Copy-StagingTree -Source $mvpStagingSub -Destination (Join-Path $TempRoot "staging_sub_mvp_tamper")
    $pckPath = Join-Path $mvpTamperStaging "index.pck"
    $pckBytes = [System.IO.File]::ReadAllBytes($pckPath)
    $pckBytes[0] = $pckBytes[0] -bxor 0x01
    [System.IO.File]::WriteAllBytes($pckPath, $pckBytes)
    $subMvpZip3 = New-ControlArchive -StagingDir $mvpTamperStaging -ZipPath (Join-Path $subDir3 "Soulbound-AcademicMVP-Web.zip")
    Use-OriginalReceipt -ZipPath $subMvpZip3 -OriginalReceiptPath $mvpReceipt
    [void](Invoke-ControlProcess -Category "subprocess" -Name "validate_payload_tamper_exit_nonzero" `
            -FilePath $ValidateScript `
            -Arguments @("-DistDir", $subDir3, "-Tier", "academic_mvp", "-GodotPath", $GodotPath) `
            -ExpectedExitCodes @(1) `
            -ExpectPatterns @("index\.pck' SHA-256 mismatch"))

    # 5.4 Explicit invalid engine path -> fail (export + validate)
    [void](Invoke-ControlProcess -Category "engine" -Name "export_explicit_invalid_engine_fails" `
            -FilePath $ExportScript `
            -Arguments @("-Tier", "academic_mvp", "-SkipZip", "-GodotPath", $badEnginePath) `
            -ExpectedExitCodes @(1) `
            -ExpectPatterns @("Specified Godot executable not found"))
    [void](Invoke-ControlProcess -Category "engine" -Name "validate_explicit_invalid_engine_fails" `
            -FilePath $ValidateScript `
            -Arguments @("-GodotPath", $badEnginePath) `
            -ExpectedExitCodes @(1) `
            -ExpectPatterns @("Godot executable not found"))

    # 5.5 Required (default) engine missing -> fail without silent fallback
    #     (patched copies of the scripts with a nonexistent default path; the
    #     old behavior would fall back and pass, so this is non-vacuous).
    $patchedValidate = Join-Path $PSScriptRoot ("validate_release_noengine_" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
    try {
        $validateText = [System.IO.File]::ReadAllText($ValidateScript)
        $defaultEngine = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
        [System.IO.File]::WriteAllText($patchedValidate, $validateText.Replace($defaultEngine, $badEnginePath), $Utf8NoBom)
        [void](Invoke-ControlProcess -Category "engine" -Name "validate_missing_engine_no_fallback_fails" `
                -FilePath $patchedValidate `
                -Arguments @("-Tier", "auto") `
                -ExpectedExitCodes @(1) `
                -ExpectPatterns @("Godot executable not found", "required archive-contained PCK gate cannot run") `
                -ForbidPatterns @("skipping live headless PCK gate"))
    } finally {
        if (Test-Path -LiteralPath $patchedValidate) { Remove-Item -LiteralPath $patchedValidate -Force }
    }

    $patchedExport = Join-Path $PSScriptRoot ("export_release_noengine_" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
    try {
        $exportText = [System.IO.File]::ReadAllText($ExportScript)
        $defaultEngine = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
        [System.IO.File]::WriteAllText($patchedExport, $exportText.Replace($defaultEngine, $badEnginePath), $Utf8NoBom)
        [void](Invoke-ControlProcess -Category "engine" -Name "export_missing_engine_no_fallback_fails" `
                -FilePath $patchedExport `
                -Arguments @("-Tier", "academic_mvp", "-SkipZip") `
                -ExpectedExitCodes @(1) `
                -ExpectPatterns @("Godot executable not found", "no fallback is attempted"))
    } finally {
        if (Test-Path -LiteralPath $patchedExport) { Remove-Item -LiteralPath $patchedExport -Force }
    }

    # [6] Git provenance capture controls (clean / dirty / failure / timing).
    Write-Host "`n[6] Git provenance capture controls..." -ForegroundColor Yellow
    $gitFixture = Join-Path $TempRoot "git_fixture"
    New-Item -ItemType Directory -Path $gitFixture -Force | Out-Null
    $null = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $gitFixture, "init")
    $null = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $gitFixture, "config", "user.email", "sbl-bld-005@example.invalid")
    $null = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $gitFixture, "config", "user.name", "SBL BLD 005 Fixture")
    [System.IO.File]::WriteAllText((Join-Path $gitFixture "tracked.txt"), "line one`n", $Utf8NoBom)
    $null = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $gitFixture, "add", "tracked.txt")
    $commitRun = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $gitFixture, "commit", "-m", "fixture commit")
    if ($commitRun.ExitCode -ne 0) { throw "git fixture commit failed: $($commitRun.StdErr)" }
    $fixtureCommitRun = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $gitFixture, "rev-parse", "HEAD")
    $fixtureCommit = $fixtureCommitRun.StdOut.Trim()

    $cleanCapture = Get-SblSourceProvenance -RepoRoot $gitFixture
    $emptySha = Get-SblSha256LowerFromBytes -Bytes ([byte[]]@())
    Add-ControlResult -Category "git" -Control "clean_fixture_capture" `
        -Expected "dirty=false, commit matches, status digest = SHA-256 of empty status" `
        -Observed "dirty=$($cleanCapture.dirty); commit=$($cleanCapture.commit); digest=$($cleanCapture.status_porcelain_sha256)" `
        -Passed ((-not $cleanCapture.dirty) -and ($cleanCapture.commit -ceq $fixtureCommit) -and ($cleanCapture.status_porcelain_sha256 -ceq $emptySha))

    # capture-before-mutation semantics: capturing BEFORE a mutation yields
    # clean; a capture AFTER the same mutation yields dirty.
    [System.IO.File]::WriteAllText((Join-Path $gitFixture "tracked.txt"), "line one`nline two (mutation)`n", $Utf8NoBom)
    [System.IO.File]::WriteAllText((Join-Path $gitFixture "untracked_new.txt"), "new`n", $Utf8NoBom)
    $afterMutationCapture = Get-SblSourceProvenance -RepoRoot $gitFixture
    $statusRun = Invoke-SblProcessCapture -FilePath "git" -ArgumentList @("-C", $gitFixture, "status", "--porcelain=v1", "--untracked-files=all")
    $gitOut = $statusRun.StdOut -replace "`r`n", "`n" -replace "`r", "`n"
    $expectedDirtySha = Get-SblSha256LowerFromBytes -Bytes ([System.Text.Encoding]::UTF8.GetBytes($gitOut))
    Add-ControlResult -Category "git" -Control "dirty_fixture_capture" `
        -Expected "dirty=true and status digest equals SHA-256 of LF-normalized porcelain output" `
        -Observed "dirty=$($afterMutationCapture.dirty); digest=$($afterMutationCapture.status_porcelain_sha256)" `
        -Passed (($afterMutationCapture.dirty) -and ($afterMutationCapture.status_porcelain_sha256 -ceq $expectedDirtySha) -and ($afterMutationCapture.status_porcelain_sha256 -cne $emptySha))
    Add-ControlResult -Category "git" -Control "capture_before_mutation_not_flipped" `
        -Expected "pre-mutation capture (clean) differs from post-mutation capture (dirty)" `
        -Observed "pre.dirty=$($cleanCapture.dirty); post.dirty=$($afterMutationCapture.dirty)" `
        -Passed ((-not $cleanCapture.dirty) -and ($afterMutationCapture.dirty))

    # git failure must throw (never substitute "unknown")
    $nonRepo = Join-Path $TempRoot "git_nonrepo"
    New-Item -ItemType Directory -Path $nonRepo -Force | Out-Null
    $threw = $false
    try { $null = Get-SblSourceProvenance -RepoRoot $nonRepo } catch { $threw = $true }
    Add-ControlResult -Category "git" -Control "git_failure_throws" `
        -Expected "capture throws outside a Git work tree" `
        -Observed $(if ($threw) { "threw as expected" } else { "returned a value (no failure)" }) `
        -Passed $threw

    # [7] Stale build output control: seed an unrelated file in an old output
    #     directory; the freshly packaged archive must not contain it.
    Write-Host "`n[7] Stale build output control (fresh staging excludes old output)..." -ForegroundColor Yellow
    $staleSeedName = "SBL_BLD_005_STALE_SEED.txt"
    $mvpOutputDir = Join-Path $BuildsRoot "web-academic_mvp"
    if (-not (Test-Path -LiteralPath $mvpOutputDir)) { New-Item -ItemType Directory -Path $mvpOutputDir -Force | Out-Null }
    [System.IO.File]::WriteAllText((Join-Path $mvpOutputDir $staleSeedName), "stale output sentinel from a previous build`n", $Utf8NoBom)
    $staleRun = Invoke-ControlProcess -Category "export" -Name "stale_output_excluded_from_new_package" `
        -FilePath $ExportScript `
        -Arguments @("-Tier", "academic_mvp", "-GodotPath", $GodotPath) `
        -ExpectedExitCodes @(0) `
        -RealUserData
    $mvpZipFresh = Join-Path $DistDir "Soulbound-AcademicMVP-Web.zip"
    $freshEntries = @()
    $zipRead = [System.IO.Compression.ZipFile]::OpenRead($mvpZipFresh)
    try { $freshEntries = @($zipRead.Entries | ForEach-Object { $_.FullName }) } finally { $zipRead.Dispose() }
    $seedInZip = ($freshEntries -contains $staleSeedName)
    $seedStillInBuilds = Test-Path -LiteralPath (Join-Path $mvpOutputDir $staleSeedName)
    Add-ControlResult -Category "export" -Control "stale_seed_absent_from_new_zip" `
        -Expected "freshly packaged archive does not contain the seeded stale file" `
        -Observed "seed present in zip: $seedInZip ($($freshEntries.Count) entries)" `
        -Passed ((-not $seedInZip) -and $staleRun.Passed)
    Add-ControlResult -Category "export" -Control "stale_seed_removed_from_output_dir" `
        -Expected "publish step replaces old output directory contents" `
        -Observed "seed still present in builds/web-academic_mvp: $seedStillInBuilds" `
        -Passed (-not $seedStillInBuilds)

    # [8] -SkipZip control: no new/changed archive or receipt and no
    #     validation of stale packages.
    Write-Host "`n[8] -SkipZip control..." -ForegroundColor Yellow
    $distBeforeSkip = Get-DistPackageState
    $skipRun = Invoke-ControlProcess -Category "export" -Name "skipzip_creates_nothing_and_validates_nothing" `
        -FilePath $ExportScript `
        -Arguments @("-Tier", "academic_mvp", "-SkipZip", "-GodotPath", $GodotPath) `
        -ExpectedExitCodes @(0) `
        -ExpectPatterns @("\[SkipZip\]") `
        -ForbidPatterns @("Validating Release Artifacts", "ALL RELEASE ARTIFACTS AND PRESETS VALIDATED") `
        -RealUserData
    $distAfterSkip = Get-DistPackageState
    $distUntouched = Test-DistPackageStateEqual -Before $distBeforeSkip -After $distAfterSkip
    Add-ControlResult -Category "export" -Control "skipzip_leaves_dist_byte_identical" `
        -Expected "no new or modified ZIP/receipt in dist after -SkipZip" `
        -Observed ("artifacts before=$($distBeforeSkip.Count) after=$($distAfterSkip.Count) identical=$distUntouched") `
        -Passed ($distUntouched -and $skipRun.Passed)

    # [9] Source capture timing: the freshly exported manifest must equal a
    #     live capture taken now (the exporter mutated and restored the tree
    #     in between, so a during-mutation capture would differ).
    Write-Host "`n[9] Manifest source capture vs live capture..." -ForegroundColor Yellow
    $liveSource = Get-SblSourceProvenance -RepoRoot $ProjectRoot.Path
    $mvpManifest = Get-ArchiveManifestObject -ZipPath $mvpZipFresh
    $sourceMatches = ($null -ne $mvpManifest) -and
    ($mvpManifest.source.commit -ceq $liveSource.commit) -and
    ([bool]$mvpManifest.source.dirty -eq [bool]$liveSource.dirty) -and
    ($mvpManifest.source.status_porcelain_sha256 -ceq $liveSource.status_porcelain_sha256)
    Add-ControlResult -Category "git" -Control "manifest_source_equals_live_capture" `
        -Expected "manifest source metadata equals a live pre-mutation capture (exporter mutation did not flip it)" `
        -Observed "manifest.dirty=$($mvpManifest.source.dirty) live.dirty=$($liveSource.dirty); commitMatch=$($mvpManifest.source.commit -ceq $liveSource.commit); digestMatch=$($mvpManifest.source.status_porcelain_sha256 -ceq $liveSource.status_porcelain_sha256)" `
        -Passed $sourceMatches

    # [10] Restoration controls (existing behavior preserved).
    Write-Host "`n[10] Export failure restoration controls..." -ForegroundColor Yellow
    [void](Invoke-ControlProcess -Category "restoration" -Name "existing_restoration_positive_control" `
            -FilePath (Join-Path $PSScriptRoot "test_export_failure_restoration.ps1") `
            -Arguments @() `
            -ExpectedExitCodes @(0) `
            -ExpectPatterns @("byte-identical"))
    [void](Invoke-ControlProcess -Category "restoration" -Name "restoration_disabled_negative_control" `
            -FilePath (Join-Path $PSScriptRoot "test_export_failure_restoration.ps1") `
            -Arguments @("-DisableRestore") `
            -ExpectedExitCodes @(1) `
            -ExpectPatterns @("NON-VACUOUS PROOF CONFIRMED"))

    # [11] Isolation bookkeeping control is recorded after the finally block.
}
finally {
    if ($null -ne $script:Isolation) {
        $script:IsolationResult = Exit-SblGodotUserDataIsolation -State $script:Isolation
        Add-Content -Path (Join-Path $ReportDir "godot_user_data_isolation.log") -Value "[$(Get-Date -Format o)] test_release_manifest: probe=$($script:IsolationResult.ProbeUserDir); realUserDataUnchanged=$($script:IsolationResult.RealDataUnchanged); disposableFiles=$($script:IsolationResult.DisposableFileCount); rootRemoved=$($script:IsolationResult.RootRemoved)"
    }
    if (Test-Path -LiteralPath $TempRoot) {
        try { Remove-SblDirectoryWithinRoot -Path $TempRoot -Root ([System.IO.Path]::GetTempPath()) } catch { Write-Host "WARNING: temp cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}

# Isolation proof control (recorded after exit so real-data comparison exists)
if ($null -ne $script:IsolationResult) {
    Add-ControlResult -Category "isolation" -Control "real_user_data_untouched" `
        -Expected "real roaming/local Godot user data byte-identical across the suite" `
        -Observed "realDataUnchanged=$($script:IsolationResult.RealDataUnchanged); disposableFiles=$($script:IsolationResult.DisposableFileCount); rootRemoved=$($script:IsolationResult.RootRemoved)" `
        -Passed ([bool]$script:IsolationResult.RealDataUnchanged)
}

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

Write-Host "`n===============================================" -ForegroundColor Cyan
Write-Host "  SBL-BLD-005 Control Results ($($script:ControlRows.Count) controls)   " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
$script:ControlRows | Format-Table -Property Category, Control, Status -AutoSize

$passCount = @($script:ControlRows | Where-Object { $_.Status -eq "PASS" }).Count
$failCount = @($script:ControlRows | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Host "Total controls: $($script:ControlRows.Count) | Passed: $passCount | Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
Write-TestLog "TOTAL=$($script:ControlRows.Count) PASS=$passCount FAIL=$failCount"

if ($failCount -gt 0) {
    Write-Host "`nSBL-BLD-005 release manifest tests FAILED ($failCount control(s))." -ForegroundColor Red
    exit 1
}

Write-Host "`nSBL-BLD-005 release manifest tests PASSED ($passCount control(s))." -ForegroundColor Green
exit 0
