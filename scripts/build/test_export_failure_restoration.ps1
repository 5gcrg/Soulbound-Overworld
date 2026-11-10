# Soulbound Export Failure Restoration Verification
# SBL-BLD-004: Proves deterministic export-failure injection and byte-identical tree restoration.
# Proves that the failure is injected AFTER release_tier and build_tier.txt mutations occur,
# that the exporter's finally block restores project.godot byte-identically and removes build_tier.txt,
# and proves the test is non-vacuous by verifying that running with restore disabled fails (exits 1).
# SBL-BLD-005: additionally covers the new temporary export state - the fresh staging root must be
# removed and dist/ archives plus receipts must remain byte-identical on the failed run (both modes;
# a violation exits 2 so it cannot hide behind the expected exit 1 of the disabled control).
#
# Usage:
#   Normal test (exits 0 on success):
#     powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_export_failure_restoration.ps1
#   Non-vacuous proof (exits 1 with restore disabled):
#     powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_export_failure_restoration.ps1 -DisableRestore

param (
    [string]$ExportScript = (Join-Path $PSScriptRoot "export_release.ps1"),
    [switch]$DisableRestore = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

$godotConfig = Join-Path $ProjectRoot "project.godot"
$markerPath = Join-Path $ProjectRoot "build_tier.txt"
$buildsRoot = Join-Path $ProjectRoot "builds"
$distRoot = Join-Path $ProjectRoot "dist"

if (-not (Test-Path $godotConfig)) {
    throw "project.godot not found at: $godotConfig"
}

function Get-DistPackageState {
    # name -> "length:sha256" for every dist archive and manifest receipt.
    $state = @{}
    if (-not (Test-Path -LiteralPath $distRoot)) { return $state }
    foreach ($file in @(Get-ChildItem -LiteralPath $distRoot -File -Force | Where-Object { $_.Name -like "*.zip" -or $_.Name -like "*.manifest.sha256" })) {
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

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  SBL-BLD-004 Export Failure Test        " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Mode: $(if ($DisableRestore) { 'Non-vacuous proof (Restore DISABLED)' } else { 'Standard verification (Restore ENABLED)' })" -ForegroundColor Gray

# 1. Capture Pre-Test State
$preBytes = [System.IO.File]::ReadAllBytes($godotConfig)
$preSha = (Get-FileHash -Path $godotConfig -Algorithm SHA256).Hash
$markerPreExisted = Test-Path $markerPath

Write-Host "Pre-test project.godot SHA256: $preSha" -ForegroundColor Gray
Write-Host "Pre-test build_tier.txt exists: $markerPreExisted" -ForegroundColor Gray
$preDist = Get-DistPackageState
Write-Host "Pre-test dist archives/receipts: $($preDist.Count) artifact(s) snapshotted." -ForegroundColor Gray

$tempScriptPath = $null
$stdoutFile = [System.IO.Path]::GetTempFileName()
$stderrFile = [System.IO.Path]::GetTempFileName()

try {
    $targetScript = $ExportScript

    # 2. If -DisableRestore is requested, create an isolated exporter copy with the finally restore omitted
    if ($DisableRestore) {
        $tempScriptPath = Join-Path $PSScriptRoot ("export_release_norestore_" + [System.Guid]::NewGuid().ToString("N") + ".ps1")
        $origScriptContent = [System.IO.File]::ReadAllText($ExportScript)

        # Disable the restoration logic inside finally to prove non-vacuity
        $disabledContent = $origScriptContent.Replace(
            '[System.IO.File]::WriteAllBytes($ProjectGodotPath, $origProjectGodotBytes)',
            'Write-Host "  [TEST NEGATIVE CONTROL] project.godot restore disabled." -ForegroundColor Red'
        ).Replace(
            'Remove-Item $origMarkerPath -Force',
            'Write-Host "  [TEST NEGATIVE CONTROL] build_tier.txt removal disabled." -ForegroundColor Red'
        ).Replace(
            'Write-Error "CRITICAL: project.godot was not restored to exact byte-identical state!"',
            'Write-Host "  [TEST NEGATIVE CONTROL] exporter internal restore check skipped." -ForegroundColor Red'
        )
        [System.IO.File]::WriteAllText($tempScriptPath, $disabledContent, [System.Text.Encoding]::UTF8)
        $targetScript = $tempScriptPath
        Write-Host "Prepared exporter copy with restore disabled at: $tempScriptPath" -ForegroundColor Yellow
    }

    # 3. Trigger Forced Failure during export_release.ps1 after tier mutation
    Write-Host "`nExecuting exporter with post-mutation failure injection (-Tier academic_mvp -FailAfterMutation)..." -ForegroundColor Yellow

    $proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $targetScript, "-Tier", "academic_mvp", "-FailAfterMutation") `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $stdoutFile `
        -RedirectStandardError $stderrFile

    $output = ""
    if (Test-Path $stdoutFile) { $output += [System.IO.File]::ReadAllText($stdoutFile) }
    if (Test-Path $stderrFile) { $output += [System.IO.File]::ReadAllText($stderrFile) }

    Write-Host "`n--- Captured Exporter Output ---" -ForegroundColor DarkGray
    Write-Host $output -ForegroundColor DarkGray
    Write-Host "--- End Captured Exporter Output ---`n" -ForegroundColor DarkGray

    Write-Host "Exporter process exited with code $($proc.ExitCode)." -ForegroundColor Yellow

    # 4. Inspect Output for Mutation Observation & Injected Failure
    $mutationObserved = ($output -match '\[MUTATION_APPLIED\] Tier ''academic_mvp'' applied to project\.godot and build_tier\.txt written')
    $failureInjected = ($output -match 'SIMULATED_EXPORT_FAILURE')

    # 5. Inspect Post-Failure Working Tree State
    $postBytes = [System.IO.File]::ReadAllBytes($godotConfig)
    $postSha = (Get-FileHash -Path $godotConfig -Algorithm SHA256).Hash
    $markerPostExisted = Test-Path $markerPath
    $bytesIdentical = [System.Linq.Enumerable]::SequenceEqual($preBytes, $postBytes)

    Write-Host "`n=== Verification Assertions ===" -ForegroundColor Cyan
    Write-Host "  Non-zero exit captured:         $($proc.ExitCode -ne 0) (ExitCode=$($proc.ExitCode))"
    Write-Host "  Mutation observed before fail:  $mutationObserved"
    Write-Host "  Injected failure triggered:     $failureInjected"
    Write-Host "  project.godot byte-identical:   $bytesIdentical"
    Write-Host "  project.godot SHA256 matched:   $($preSha -eq $postSha) ($postSha)"
    Write-Host "  build_tier.txt absent from root: $(-not $markerPostExisted)"

    if ($proc.ExitCode -eq 0) {
        Write-Error "FAIL: Expected exporter to fail, but it exited 0!"
        exit 1
    }

    if (-not $mutationObserved) {
        Write-Error "FAIL: Configuration mutation was NOT observed before failure!"
        exit 1
    }

    if (-not $failureInjected) {
        Write-Error "FAIL: SIMULATED_EXPORT_FAILURE was NOT observed in output!"
        exit 1
    }

    # 5b. Temporary export state (SBL-BLD-005): the fresh staging root must be
    #     removed and dist/ archives + receipts must remain byte-identical,
    #     because the injected failure occurs before packaging. Checked in both
    #     modes; a violation exits 2 so it cannot hide behind the disabled
    #     control's expected exit 1.
    $stagingLeftovers = @(Get-ChildItem -LiteralPath $buildsRoot -Directory -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -like ".staging_*" })
    $stagingClean = ($stagingLeftovers.Count -eq 0)
    $postDist = Get-DistPackageState
    $distUnchanged = Test-DistPackageStateEqual -Before $preDist -After $postDist
    Write-Host "  Staging root removed after failure: $stagingClean"
    Write-Host "  dist archives/receipts unchanged:   $distUnchanged ($($postDist.Count) artifact(s) snapshotted)"
    if (-not $stagingClean) {
        Write-Error "FAIL: staging leftovers after failed export: $($stagingLeftovers.Name -join ', ')"
        exit 2
    }
    if (-not $distUnchanged) {
        Write-Error "FAIL: dist archives/receipts changed during the failed export run!"
        exit 2
    }

    # 6. Branch on Restore Mode
    if ($DisableRestore) {
        # Proving the test is non-vacuous: with restore disabled, tree MUST be left dirty
        if ($bytesIdentical -and (-not $markerPostExisted)) {
            Write-Error "FAIL: Even with restore disabled, the working tree was unchanged! Test is vacuous."
            exit 2
        }

        Write-Host "`n[NON-VACUOUS PROOF CONFIRMED]" -ForegroundColor Green
        Write-Host "  When exporter restore is disabled, failure leaves tree dirty:" -ForegroundColor Green
        Write-Host "    - project.godot bytes differ: $(-not $bytesIdentical)" -ForegroundColor Green
        Write-Host "    - build_tier.txt remained:   $markerPostExisted" -ForegroundColor Green
        Write-Host "  Exiting 1 as expected for disabled-restore negative control." -ForegroundColor Yellow
        exit 1
    }

    # Standard run: tree MUST be 100% restored
    if (-not $bytesIdentical) {
        Write-Error "CRITICAL: project.godot bytes differ after failed export run!"
        exit 1
    }

    if ($markerPostExisted) {
        Write-Error "CRITICAL: build_tier.txt was left behind in project root after failed export run!"
        exit 1
    }

    Write-Host "`nPASS: SBL-BLD-004 Deterministic export failure path verified and restored tree byte-identically." -ForegroundColor Green
    exit 0

} finally {
    # Working tree safety invariant: NEVER leave the repository dirty after test runs
    if (Test-Path $godotConfig) {
        $currentBytes = [System.IO.File]::ReadAllBytes($godotConfig)
        if (-not [System.Linq.Enumerable]::SequenceEqual($preBytes, $currentBytes)) {
            [System.IO.File]::WriteAllBytes($godotConfig, $preBytes)
            Write-Host "Safety cleanup: restored project.godot to pre-test bytes." -ForegroundColor DarkYellow
        }
    }

    if ((Test-Path $markerPath) -and (-not $markerPreExisted)) {
        Remove-Item $markerPath -Force
        Write-Host "Safety cleanup: removed temporary build_tier.txt." -ForegroundColor DarkYellow
    }

    if ($null -ne $tempScriptPath -and (Test-Path $tempScriptPath)) {
        Remove-Item $tempScriptPath -Force
    }

    if (Test-Path $stdoutFile) { Remove-Item $stdoutFile -Force }
    if (Test-Path $stderrFile) { Remove-Item $stderrFile -Force }
}
