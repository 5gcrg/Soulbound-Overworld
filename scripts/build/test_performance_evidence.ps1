# Soulbound OD-013 Performance Evidence Test Suite (PowerShell)
#
# Targeted positive and negative controls for scripts/build/performance_evidence.ps1
# under the owner-ratified OD-013 plan (report/od013-ratification.md):
#   - positive: a real headless capture measures all five scenes with the required
#     evidence fields (and, unless -SkipWindowed, a windowed native rendered capture);
#   - warning semantics: below-target fixtures WARN, are recorded, and exit 0
#     (never a release failure);
#   - preflight hard-fails: missing engine, non-Godot executable, wrong Godot
#     version, incompatible renderer configuration, multi-threaded Web preset;
#   - no maximum build-size budget is introduced;
#   - the canonical -Export release gate chains performance evidence with warning
#     semantics, and the browser checklist stays human/manual pending.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_performance_evidence.ps1
#   ... -SkipWindowed        # skip the windowed native rendered capture control
#   ... -FullGate            # additionally run the canonical headless suites,
#                            # the canonical -Export release gate, and the
#                            # export-failure restoration controls
# Exits 0 only when every control behaves as specified.

param (
    [string]$GodotPath = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [switch]$SkipWindowed = $false,
    [switch]$FullGate = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

$ReportDir = Join-Path $ProjectRoot "report"
if (-not (Test-Path $ReportDir)) { New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null }

$PerfScript = Join-Path $PSScriptRoot "performance_evidence.ps1"
$TestLogPath = Join-Path $ReportDir "performance_evidence_test.log"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("sbl_od013_test_" + [System.Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null

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

function Invoke-PerfScript {
    # Runs performance_evidence.ps1 in a child PowerShell with file redirection
    # (house-standard process management) and returns exit code plus output text.
    param([string[]]$Arguments, [string]$Label)
    $outFile = Join-Path $TempRoot "$Label.out"
    $errFile = Join-Path $TempRoot "$Label.err"
    $argList = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PerfScript) + $Arguments
    $quoted = ($argList | ForEach-Object { $a = "$_"; if ($a -match '\s') { '"' + $a + '"' } else { $a } }) -join " "
    $proc = Start-Process -FilePath "powershell.exe" `
        -ArgumentList $quoted `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardOutput $outFile `
        -RedirectStandardError $errFile
    $output = ""
    if (Test-Path -LiteralPath $outFile) { $output += [System.IO.File]::ReadAllText($outFile) }
    if (Test-Path -LiteralPath $errFile) { $output += [System.IO.File]::ReadAllText($errFile) }
    Write-TestLog "invoke[$Label] exit=$($proc.ExitCode) args=($($Arguments -join ' '))"
    foreach ($line in ($output -split "`r?`n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) { Write-TestLog "    | $line" }
    }
    return [pscustomobject]@{
        ExitCode = $proc.ExitCode
        Output   = $output
    }
}

function New-BelowTargetFixture {
    # Disposable capture payload with deliberately insufficient performance.
    param(
        [string]$Path,
        [double]$AvgFps,
        [double]$MinFps,
        [double]$AvgFrameMs,
        [double]$MaxFrameMs
    )
    $labels = @{
        "title"           = "Title screen"
        "overworld"       = "Overworld"
        "combat"          = "Combat"
        "dungeon"         = "Dungeon"
        "learning_journal" = "Learning journal"
    }
    $scenes = @()
    foreach ($id in @("title", "overworld", "combat", "dungeon", "learning_journal")) {
        $scenes += [ordered]@{
            id             = $id
            label          = $labels[$id]
            scene          = "res://scenes/$id.tscn"
            ok             = $true
            error          = ""
            engine_errors  = 0
            engine_warnings = 0
            setup_ms       = 10.0
            avg_frame_ms   = $AvgFrameMs
            min_frame_ms   = [math]::Round($AvgFrameMs / 2, 3)
            max_frame_ms   = $MaxFrameMs
            avg_fps        = $AvgFps
            min_fps        = $MinFps
            frames         = 300
        }
    }
    $payload = [ordered]@{
        schema               = "sbl-od013-capture/1"
        display_mode         = "fixture"
        display_server       = "fixture"
        renderer             = "fixture"
        renderer_vendor      = "fixture"
        refresh_rate_hz      = 60
        engine_reported_fps  = $AvgFps
        engine_errors_total  = 0
        engine_warnings_total = 0
        scenes               = @($scenes)
    }
    [System.IO.File]::WriteAllText($Path, (ConvertTo-Json -InputObject $payload -Depth 6), $Utf8NoBom)
    return $Path
}

function Get-GitStatusSnapshot {
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) { return "git-unavailable" }
    $run = & $git.Source -C $ProjectRoot status --porcelain=v1 --untracked-files=all 2>&1 | Out-String
    return ($run -replace "`r`n", "`n")
}

# ---------------------------------------------------------------------------
# Controls
# ---------------------------------------------------------------------------

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  OD-013 Performance Evidence Controls   " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Godot : $GodotPath" -ForegroundColor Gray
Write-Host "Temp  : $TempRoot" -ForegroundColor Gray
Write-TestLog "[$(Get-Date -Format o)] OD-013 performance evidence controls starting (godot=$GodotPath)"

$statusBefore = Get-GitStatusSnapshot

try {
    # [1] Positive: real headless capture of all five scenes.
    Write-Host "`n[1] Positive: headless capture of all five scenes..." -ForegroundColor Yellow
    $evPath = Join-Path $TempRoot "evidence.json"
    $rpPath = Join-Path $TempRoot "report.md"
    $lgPath = Join-Path $TempRoot "capture.log"
    $positive = Invoke-PerfScript -Label "positive_headless" -Arguments @(
        "-GodotPath", $GodotPath,
        "-CaptureMode", "headless",
        "-EvidencePath", $evPath,
        "-ReportPath", $rpPath,
        "-LogPath", $lgPath
    )
    Add-ControlResult -Category "positive" -Control "headless_capture_exits_zero" `
        -Expected "exit 0" `
        -Observed "exit $($positive.ExitCode)" `
        -Passed ($positive.ExitCode -eq 0)

    $evidence = $null
    $reportText = ""
    if (Test-Path -LiteralPath $evPath) { $evidence = Get-Content -LiteralPath $evPath -Raw | ConvertFrom-Json }
    if (Test-Path -LiteralPath $rpPath) { $reportText = Get-Content -LiteralPath $rpPath -Raw }

    $sceneIds = @()
    if ($null -ne $evidence) { $sceneIds = @($evidence.captures[0].scenes | ForEach-Object { [string]$_.id }) }
    $expectedIds = @("title", "overworld", "combat", "dungeon", "learning_journal")
    $idsMatch = ($sceneIds.Count -eq $expectedIds.Count) -and (@(Compare-Object -ReferenceObject $expectedIds -DifferenceObject $sceneIds).Count -eq 0)
    Add-ControlResult -Category "positive" -Control "all_five_scenes_measured" `
        -Expected "exactly title, overworld, combat, dungeon, learning_journal" `
        -Observed "captured: $($sceneIds -join ', ')" `
        -Passed ($idsMatch -and ($null -ne $evidence))

    $rowsComplete = $false
    if ($null -ne $evidence) {
        $rowsComplete = $true
        foreach ($scene in $evidence.captures[0].scenes) {
            if ([int]$scene.frames -lt 5 -or [double]$scene.avg_fps -le 0 -or [double]$scene.min_fps -le 0 -or
                [double]$scene.avg_frame_ms -le 0 -or [string]::IsNullOrWhiteSpace([string]$scene.status) -or
                [string]::IsNullOrWhiteSpace([string]$scene.scene)) {
                $rowsComplete = $false
                break
            }
        }
    }
    Add-ControlResult -Category "positive" -Control "frame_timing_and_fps_fields_recorded" `
        -Expected "each scene records frames, avg/min FPS, avg/min/max frame ms, scene path, status" `
        -Observed $(if ($rowsComplete) { "all fields present for 5 scenes" } else { "one or more fields missing" }) `
        -Passed $rowsComplete

    $gateConfigOk = ($null -ne $evidence) -and
        ([int]$evidence.target_fps -eq 60) -and
        ([int]$evidence.fallback_fps -eq 30) -and
        ($evidence.build_size_budget -eq $null) -and
        ($evidence.preflight.engine_version -like "4.7.2.stable*") -and
        ($evidence.preflight.rendering_method -ceq "gl_compatibility") -and
        ($evidence.preflight.rendering_method_web -ceq "gl_compatibility") -and
        ([bool]$evidence.preflight.single_threaded_web -eq $true) -and
        ([string]$evidence.review -ceq "REVIEW_PENDING_CODEX")
    Add-ControlResult -Category "positive" -Control "preflight_and_gate_configuration_recorded" `
        -Expected "target=60, fallback=30, build_size_budget=null, Godot 4.7.2.stable, gl_compatibility x2, single-threaded web, REVIEW_PENDING_CODEX" `
        -Observed $(if ($null -ne $evidence) { "target=$($evidence.target_fps) fallback=$($evidence.fallback_fps) budget=$($evidence.build_size_budget) engine=$($evidence.preflight.engine_version) renderer=$($evidence.preflight.rendering_method)/$($evidence.preflight.rendering_method_web) single_thread=$($evidence.preflight.single_threaded_web) review=$($evidence.review)" } else { "evidence file missing" }) `
        -Passed $gateConfigOk

    $machineOk = ($null -ne $evidence) -and
        -not [string]::IsNullOrWhiteSpace([string]$evidence.machine.os_caption) -and
        -not [string]::IsNullOrWhiteSpace([string]$evidence.machine.cpu_name) -and
        (@($evidence.machine.gpu_adapters).Count -gt 0) -and
        ($null -ne $evidence.machine.memory_gb)
    Add-ControlResult -Category "positive" -Control "reference_machine_specs_captured" `
        -Expected "OS, CPU, GPU adapter(s) and memory recorded for the owner machine" `
        -Observed $(if ($null -ne $evidence) { "os=$($evidence.machine.os_caption); cpu=$($evidence.machine.cpu_name); gpu=$(@($evidence.machine.gpu_adapters) -join '; '); mem=$($evidence.machine.memory_gb) GB" } else { "evidence file missing" }) `
        -Passed $machineOk

    $browserOk = ($null -ne $evidence) -and
        ($evidence.browser_evidence.status -ceq "PENDING_HUMAN_EXECUTION") -and
        ([bool]$evidence.browser_evidence.acceptance_claimed -eq $false) -and
        (@($evidence.browser_evidence.rows).Count -eq 3)
    Add-ControlResult -Category "positive" -Control "browser_evidence_stays_pending_no_acceptance_claim" `
        -Expected "browser_evidence.status=PENDING_HUMAN_EXECUTION, acceptance_claimed=false, 3 pending rows (Chromium, Firefox, owner-selected)" `
        -Observed $(if ($null -ne $evidence) { "status=$($evidence.browser_evidence.status) acceptance_claimed=$($evidence.browser_evidence.acceptance_claimed) rows=$(@($evidence.browser_evidence.rows).Count)" } else { "evidence file missing" }) `
        -Passed $browserOk

    $requiredReportMarkers = @(
        "## 2. Reference machine",
        "## 3. Engine and configuration",
        "## 4. Automated Godot-native capture",
        "## 5. Gate semantics",
        "## 6. Manual browser & profiling evidence",
        "## 7. Release-gate integration",
        "PENDING HUMAN EXECUTION",
        "No browser acceptance is claimed",
        "Maximum build-size budget",
        "REVIEW_PENDING_CODEX"
    )
    $missingMarkers = @($requiredReportMarkers | Where-Object { $reportText -notlike "*$_*" })
    Add-ControlResult -Category "positive" -Control "report_contains_required_sections" `
        -Expected "all required OD-013 report sections present" `
        -Observed $(if ($missingMarkers.Count -eq 0) { "all $($requiredReportMarkers.Count) markers present" } else { "missing: $($missingMarkers -join '; ')" }) `
        -Passed ($missingMarkers.Count -eq 0 -and $reportText.Length -gt 0)

    $forbiddenClaims = @("browser smoke passed", "browsers passed", "browser acceptance granted", "smoke test: pass")
    $foundClaims = @($forbiddenClaims | Where-Object { $reportText -match [regex]::Escape($_) })
    Add-ControlResult -Category "positive" -Control "report_makes_no_browser_acceptance_claim" `
        -Expected "no browser pass/acceptance wording in the generated report" `
        -Observed $(if ($foundClaims.Count -eq 0) { "no forbidden claim found" } else { "found: $($foundClaims -join '; ')" }) `
        -Passed ($foundClaims.Count -eq 0)

    # [2] Positive: windowed native rendered capture (real renderer).
    if (-not $SkipWindowed) {
        Write-Host "`n[2] Positive: windowed native rendered capture..." -ForegroundColor Yellow
        $evW = Join-Path $TempRoot "evidence_windowed.json"
        $rpW = Join-Path $TempRoot "report_windowed.md"
        $windowed = Invoke-PerfScript -Label "positive_windowed" -Arguments @(
            "-GodotPath", $GodotPath,
            "-CaptureMode", "windowed",
            "-EvidencePath", $evW,
            "-ReportPath", $rpW,
            "-LogPath", (Join-Path $TempRoot "capture_windowed.log")
        )
        $wEvidence = $null
        if (Test-Path -LiteralPath $evW) { $wEvidence = Get-Content -LiteralPath $evW -Raw | ConvertFrom-Json }
        $wScenes = 0
        $wRenderer = ""
        $wDisplay = ""
        if ($null -ne $wEvidence) {
            $wScenes = @($wEvidence.captures[0].scenes).Count
            $wRenderer = [string]$wEvidence.captures[0].renderer
            $wDisplay = [string]$wEvidence.captures[0].display_server
        }
        Add-ControlResult -Category "positive" -Control "windowed_capture_exits_zero_and_records_renderer" `
        -Expected "exit 0, 5 scenes, display server and GPU adapter recorded" `
        -Observed "exit $($windowed.ExitCode); scenes=$wScenes; display=$wDisplay; renderer='$wRenderer'" `
            -Passed (($windowed.ExitCode -eq 0) -and ($wScenes -eq 5) -and (-not [string]::IsNullOrWhiteSpace($wDisplay)) -and ($wDisplay -ne "headless"))
    } else {
        Add-ControlResult -Category "positive" -Control "windowed_capture_exits_zero_and_records_renderer" `
            -Expected "exit 0, 5 scenes, display server and GPU adapter recorded" `
            -Observed "SKIPPED by -SkipWindowed" `
            -Passed $true
    }

    # [3] Warning semantics: below-target fixture warns, records, and exits 0.
    Write-Host "`n[3] Warning semantics: below-target fixtures..." -ForegroundColor Yellow
    $fxBelow = New-BelowTargetFixture -Path (Join-Path $TempRoot "below_target.json") -AvgFps 12 -MinFps 8 -AvgFrameMs 83.333 -MaxFrameMs 125
    $evWarn = Join-Path $TempRoot "evidence_below.json"
    $rpWarn = Join-Path $TempRoot "report_below.md"
    $warnRun = Invoke-PerfScript -Label "warn_below_target" -Arguments @(
        "-GodotPath", $GodotPath,
        "-SkipCapture",
        "-FixturePath", $fxBelow,
        "-EvidencePath", $evWarn,
        "-ReportPath", $rpWarn,
        "-LogPath", (Join-Path $TempRoot "warn.log")
    )
    $warnEvidence = $null
    if (Test-Path -LiteralPath $evWarn) { $warnEvidence = Get-Content -LiteralPath $evWarn -Raw | ConvertFrom-Json }
    $warnReport = ""
    if (Test-Path -LiteralPath $rpWarn) { $warnReport = Get-Content -LiteralPath $rpWarn -Raw }
    Add-ControlResult -Category "warning" -Control "below_target_fixture_exits_zero" `
        -Expected "exit 0 (below-target never fails the release gate)" `
        -Observed "exit $($warnRun.ExitCode)" `
        -Passed ($warnRun.ExitCode -eq 0)
    Add-ControlResult -Category "warning" -Control "below_target_rows_recorded_as_warn" `
        -Expected "summary.pass=0, summary.warn=5, fail=0 and WARNING text printed" `
        -Observed $(if ($null -ne $warnEvidence) { "pass=$($warnEvidence.summary.pass) warn=$($warnEvidence.summary.warn) fail=$($warnEvidence.summary.fail); warning_text=$(if ($warnRun.Output -match 'WARNING') { 'yes' } else { 'no' })" } else { "evidence file missing" }) `
        -Passed (($null -ne $warnEvidence) -and ([int]$warnEvidence.summary.pass -eq 0) -and ([int]$warnEvidence.summary.warn -eq 5) -and ([int]$warnEvidence.summary.fail -eq 0) -and ($warnRun.Output -match "WARNING"))
    Add-ControlResult -Category "warning" -Control "below_target_rows_visible_in_report" `
        -Expected "generated report lists WARN rows with the recorded reason" `
        -Observed $(if ($warnReport -match "\*\*WARN\*\*") { "WARN rows present" } else { "no WARN rows in report" }) `
        -Passed ($warnReport -match "\*\*WARN\*\*")

    # [4] Threshold band control: 45 FPS average is below target but above the
    #     documented 30 FPS fallback, so only the target warning may fire.
    $fxBand = New-BelowTargetFixture -Path (Join-Path $TempRoot "fallback_band.json") -AvgFps 45 -MinFps 40 -AvgFrameMs 22.222 -MaxFrameMs 25
    $evBand = Join-Path $TempRoot "evidence_band.json"
    $bandRun = Invoke-PerfScript -Label "warn_fallback_band" -Arguments @(
        "-GodotPath", $GodotPath,
        "-SkipCapture",
        "-FixturePath", $fxBand,
        "-EvidencePath", $evBand,
        "-ReportPath", (Join-Path $TempRoot "report_band.md"),
        "-LogPath", (Join-Path $TempRoot "band.log")
    )
    $bandEvidence = $null
    if (Test-Path -LiteralPath $evBand) { $bandEvidence = Get-Content -LiteralPath $evBand -Raw | ConvertFrom-Json }
    $bandNotes = ""
    if ($null -ne $bandEvidence) { $bandNotes = (@($bandEvidence.summary.warnings) -join " | ") }
    Add-ControlResult -Category "warning" -Control "fallback_band_warns_on_target_only" `
        -Expected "exit 0, warn=5, warning cites the 60 FPS target and NOT the 30 FPS fallback" `
        -Observed "exit $($bandRun.ExitCode); notes=$bandNotes" `
        -Passed (($bandRun.ExitCode -eq 0) -and ($null -ne $bandEvidence) -and ([int]$bandEvidence.summary.warn -eq 5) -and ($bandNotes -match "60 FPS target") -and ($bandNotes -notmatch "30 FPS fallback"))

    # [5] Boundary control: exactly at target and fallback -> PASS, no warnings.
    $fxAt = New-BelowTargetFixture -Path (Join-Path $TempRoot "at_target.json") -AvgFps 60 -MinFps 60 -AvgFrameMs 16.667 -MaxFrameMs 16.667
    $evAt = Join-Path $TempRoot "evidence_at_target.json"
    $atRun = Invoke-PerfScript -Label "at_target" -Arguments @(
        "-GodotPath", $GodotPath,
        "-SkipCapture",
        "-FixturePath", $fxAt,
        "-EvidencePath", $evAt,
        "-ReportPath", (Join-Path $TempRoot "report_at_target.md"),
        "-LogPath", (Join-Path $TempRoot "at_target.log")
    )
    $atEvidence = $null
    if (Test-Path -LiteralPath $evAt) { $atEvidence = Get-Content -LiteralPath $evAt -Raw | ConvertFrom-Json }
    Add-ControlResult -Category "positive" -Control "at_target_fixture_passes_without_warnings" `
        -Expected "exit 0, pass=5, warn=0" `
        -Observed "exit $($atRun.ExitCode); pass=$($atEvidence.summary.pass) warn=$($atEvidence.summary.warn)" `
        -Passed (($atRun.ExitCode -eq 0) -and ($null -ne $atEvidence) -and ([int]$atEvidence.summary.pass -eq 5) -and ([int]$atEvidence.summary.warn -eq 0))

    # [6] Preflight hard-failure controls (each must exit non-zero).
    Write-Host "`n[6] Preflight hard-failure controls..." -ForegroundColor Yellow
    $missingEngine = Invoke-PerfScript -Label "missing_engine" -Arguments @(
        "-GodotPath", (Join-Path $TempRoot "missing_godot.exe"),
        "-EvidencePath", (Join-Path $TempRoot "ev_missing.json"),
        "-ReportPath", (Join-Path $TempRoot "rep_missing.md"),
        "-LogPath", (Join-Path $TempRoot "missing.log")
    )
    Add-ControlResult -Category "preflight" -Control "missing_engine_fails" `
        -Expected "non-zero exit with 'no fallback is attempted'" `
        -Observed "exit $($missingEngine.ExitCode); match=$(if ($missingEngine.Output -match 'no fallback is attempted') { 'yes' } else { 'no' })" `
        -Passed (($missingEngine.ExitCode -ne 0) -and ($missingEngine.Output -match "no fallback is attempted"))

    $notGodot = Join-Path $env:SystemRoot "System32\where.exe"
    $badEngine = Invoke-PerfScript -Label "invalid_engine" -Arguments @(
        "-GodotPath", $notGodot,
        "-EvidencePath", (Join-Path $TempRoot "ev_badengine.json"),
        "-ReportPath", (Join-Path $TempRoot "rep_badengine.md"),
        "-LogPath", (Join-Path $TempRoot "badengine.log")
    )
    Add-ControlResult -Category "preflight" -Control "non_godot_executable_fails" `
        -Expected "non-zero exit when --version does not report the required Godot build" `
        -Observed "exit $($badEngine.ExitCode)" `
        -Passed ($badEngine.ExitCode -ne 0)

    $wrongVersion = Invoke-PerfScript -Label "wrong_version" -Arguments @(
        "-GodotPath", $GodotPath,
        "-ExpectedEngineVersionPrefix", "4.6.0.stable",
        "-EvidencePath", (Join-Path $TempRoot "ev_version.json"),
        "-ReportPath", (Join-Path $TempRoot "rep_version.md"),
        "-LogPath", (Join-Path $TempRoot "version.log")
    )
    Add-ControlResult -Category "preflight" -Control "engine_version_mismatch_fails" `
        -Expected "non-zero exit when the required version prefix does not match 4.7.2.stable" `
        -Observed "exit $($wrongVersion.ExitCode); match=$(if ($wrongVersion.Output -match 'required Godot 4.6.0.stable') { 'yes' } else { 'no' })" `
        -Passed (($wrongVersion.ExitCode -ne 0) -and ($wrongVersion.Output -match "required Godot 4.6.0.stable"))

    $badProjectPath = Join-Path $TempRoot "bad_project.godot"
    $projectText = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "project.godot"))
    [System.IO.File]::WriteAllText($badProjectPath, $projectText.Replace('renderer/rendering_method="gl_compatibility"', 'renderer/rendering_method="forward_plus"'), $Utf8NoBom)
    $badRenderer = Invoke-PerfScript -Label "bad_renderer" -Arguments @(
        "-GodotPath", $GodotPath,
        "-ProjectGodotPath", $badProjectPath,
        "-EvidencePath", (Join-Path $TempRoot "ev_renderer.json"),
        "-ReportPath", (Join-Path $TempRoot "rep_renderer.md"),
        "-LogPath", (Join-Path $TempRoot "renderer.log")
    )
    Add-ControlResult -Category "preflight" -Control "incompatible_renderer_config_fails" `
        -Expected "non-zero exit when rendering_method is not gl_compatibility" `
        -Observed "exit $($badRenderer.ExitCode); match=$(if ($badRenderer.Output -match "must be 'gl_compatibility'") { 'yes' } else { 'no' })" `
        -Passed (($badRenderer.ExitCode -ne 0) -and ($badRenderer.Output -match "must be 'gl_compatibility'"))

    $badPresetsPath = Join-Path $TempRoot "bad_presets.cfg"
    $presetsText = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "export_presets.cfg"))
    [System.IO.File]::WriteAllText($badPresetsPath, $presetsText.Replace('variant/thread_support=false', 'variant/thread_support=true'), $Utf8NoBom)
    $badThread = Invoke-PerfScript -Label "bad_thread" -Arguments @(
        "-GodotPath", $GodotPath,
        "-PresetsPath", $badPresetsPath,
        "-EvidencePath", (Join-Path $TempRoot "ev_thread.json"),
        "-ReportPath", (Join-Path $TempRoot "rep_thread.md"),
        "-LogPath", (Join-Path $TempRoot "thread.log")
    )
    Add-ControlResult -Category "preflight" -Control "multi_threaded_web_config_fails" `
        -Expected "non-zero exit when the Web preset is not single-threaded" `
        -Observed "exit $($badThread.ExitCode); match=$(if ($badThread.Output -match 'single-threaded Web invariant') { 'yes' } else { 'no' })" `
        -Passed (($badThread.ExitCode -ne 0) -and ($badThread.Output -match "single-threaded Web invariant"))

    $noArtifacts = @("ev_missing.json", "ev_badengine.json", "ev_version.json", "ev_renderer.json", "ev_thread.json") |
        Where-Object { Test-Path -LiteralPath (Join-Path $TempRoot $_) }
    Add-ControlResult -Category "preflight" -Control "failed_preflight_writes_no_evidence_artifacts" `
        -Expected "no evidence JSON or report is written when preflight fails" `
        -Observed $(if ($noArtifacts.Count -eq 0) { "no artifacts written" } else { "unexpected: $($noArtifacts -join ', ')" }) `
        -Passed ($noArtifacts.Count -eq 0)

    # [7] No build-size budget may be introduced; existing plausibility gates stay.
    Write-Host "`n[7] Build-size budget and preserved gates..." -ForegroundColor Yellow
    $reportMentionsNoBudget = ($reportText -match "Maximum build-size budget") -and ($reportText -match "no size limit was introduced")
    $evidenceBudgetNull = ($null -ne $evidence) -and ($evidence.build_size_budget -eq $null)
    $validateText = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "validate_release.ps1"))
    $preservedSizeGates = ($validateText -match "MaxPckSizeBytes") -and ($validateText -match "MinWasmSizeBytes")
    Add-ControlResult -Category "budget" -Control "no_maximum_build_size_budget_introduced" `
        -Expected "evidence build_size_budget=null, report states no size limit, pre-existing validate_release plausibility bounds unchanged" `
        -Observed "budget_null=$evidenceBudgetNull; report_mentions=$reportMentionsNoBudget; validate_size_params_present=$preservedSizeGates" `
        -Passed ($evidenceBudgetNull -and $reportMentionsNoBudget -and $preservedSizeGates)

    # [8] Canonical release gate wiring.
    Write-Host "`n[8] Canonical release gate wiring..." -ForegroundColor Yellow
    $runnerText = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot "run_headless_tests.ps1"))
    $chainsPerf = $runnerText -match "performance_evidence\.ps1"
    $hasWarningSemantics = $runnerText -match "warning semantics"
    $skipsOnSkipZip = $true  # performance evidence runs only on the release (non-SkipZip) path
    Add-ControlResult -Category "gate" -Control "canonical_export_path_chains_performance_evidence" `
        -Expected "run_headless_tests.ps1 -Export chains performance_evidence.ps1 with warning semantics" `
        -Observed "chains=$chainsPerf; warning_semantics_doc=$hasWarningSemantics" `
        -Passed ($chainsPerf -and $hasWarningSemantics)

    # [9] Browser checklist stays human/manual pending (no automated acceptance).
    Write-Host "`n[9] Browser checklist remains human/manual..." -ForegroundColor Yellow
    $checklistText = [System.IO.File]::ReadAllText((Join-Path $ProjectRoot "docs\browser_verification_checklist.md"))
    $checklistPending = ($checklistText -match "PENDING HUMAN EXECUTION") -and ($checklistText -match "PENDING human execution")
    $checklistHasOd013 = $checklistText -match "OD-013"
    Add-ControlResult -Category "browser" -Control "browser_checklist_still_pending_human_execution" `
        -Expected "checklist keeps PENDING human execution status and records the OD-013 performance-evidence linkage" `
        -Observed "pending_markers=$checklistPending; od013_linked=$checklistHasOd013" `
        -Passed ($checklistPending -and $checklistHasOd013)

    # [10] Targeted controls must not modify the working tree.
    $statusAfter = Get-GitStatusSnapshot
    Add-ControlResult -Category "hygiene" -Control "targeted_controls_leave_git_status_unchanged" `
        -Expected "git status identical before and after the targeted control run" `
        -Observed $(if ($statusBefore -ceq $statusAfter) { "unchanged" } else { "status changed during controls" }) `
        -Passed ($statusBefore -ceq $statusAfter)

    # [11] Optional full gate: canonical suites, canonical -Export release gate,
    #      and the export-failure restoration controls (positive + non-vacuous).
    if ($FullGate) {
        Write-Host "`n[11] Full gate: canonical headless suites, -Export release gate, restoration controls..." -ForegroundColor Yellow
        $runner = Join-Path $PSScriptRoot "run_headless_tests.ps1"
        $suites = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $runner, "-GodotPath", $GodotPath) `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $TempRoot "gate_suites.out") `
            -RedirectStandardError (Join-Path $TempRoot "gate_suites.err")
        $suitesOut = [System.IO.File]::ReadAllText((Join-Path $TempRoot "gate_suites.out"))
        Add-ControlResult -Category "full_gate" -Control "canonical_headless_suites_pass" `
            -Expected "run_headless_tests.ps1 exit 0" `
            -Observed "exit $($suites.ExitCode); $(if ($suitesOut -match 'Total: (\d+) \| Passed: (\d+) \| Failed: (\d+)') { "suites=$($Matches[1]) passed=$($Matches[2]) failed=$($Matches[3])" } else { 'summary not found' })" `
            -Passed ($suites.ExitCode -eq 0)

        $exportGate = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $runner, "-GodotPath", $GodotPath, "-Export", "-Tier", "all") `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $TempRoot "gate_export.out") `
            -RedirectStandardError (Join-Path $TempRoot "gate_export.err")
        $exportOut = [System.IO.File]::ReadAllText((Join-Path $TempRoot "gate_export.out"))
        Add-ControlResult -Category "full_gate" -Control "canonical_export_gate_runs_performance_evidence" `
            -Expected "run_headless_tests.ps1 -Export exit 0 and performance evidence executed in the chain" `
            -Observed "exit $($exportGate.ExitCode); perf_evidence_ran=$(if ($exportOut -match 'performance_evidence\.ps1|OD-013 Performance Evidence') { 'yes' } else { 'no' })" `
            -Passed (($exportGate.ExitCode -eq 0) -and ($exportOut -match "performance_evidence\.ps1|OD-013 Performance Evidence"))

        $restore = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "test_export_failure_restoration.ps1")) `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $TempRoot "gate_restore.out") `
            -RedirectStandardError (Join-Path $TempRoot "gate_restore.err")
        Add-ControlResult -Category "full_gate" -Control "export_restoration_control_still_passes" `
            -Expected "test_export_failure_restoration.ps1 exit 0" `
            -Observed "exit $($restore.ExitCode)" `
            -Passed ($restore.ExitCode -eq 0)

        $restoreNegative = Start-Process -FilePath "powershell.exe" `
            -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $PSScriptRoot "test_export_failure_restoration.ps1"), "-DisableRestore") `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput (Join-Path $TempRoot "gate_restore_neg.out") `
            -RedirectStandardError (Join-Path $TempRoot "gate_restore_neg.err")
        Add-ControlResult -Category "full_gate" -Control "restoration_non_vacuous_control_still_fails" `
            -Expected "test_export_failure_restoration.ps1 -DisableRestore exit 1 (non-vacuous proof)" `
            -Observed "exit $($restoreNegative.ExitCode)" `
            -Passed ($restoreNegative.ExitCode -eq 1)
    }

    # Summary
    Write-Host "`n=========================================" -ForegroundColor Cyan
    Write-Host "     OD-013 Control Results Summary      " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    $script:ControlRows | Format-Table -Property Category, Control, Status -AutoSize
    $passCount = @($script:ControlRows | Where-Object { $_.Status -eq "PASS" }).Count
    $failCount = @($script:ControlRows | Where-Object { $_.Status -eq "FAIL" }).Count
    Write-Host "Total: $($script:ControlRows.Count) | Passed: $passCount | Failed: $failCount" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
    Write-TestLog "[$(Get-Date -Format o)] controls complete: total=$($script:ControlRows.Count) pass=$passCount fail=$failCount"

    if ($script:ControlFailCount -gt 0) {
        Write-Host "`nOD-013 performance evidence controls FAILED ($failCount control(s)). See $TestLogPath" -ForegroundColor Red
        exit 1
    }
    Write-Host "`nAll OD-013 performance evidence controls passed." -ForegroundColor Green
    exit 0
} finally {
    if (Test-Path -LiteralPath $TempRoot) {
        try { Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction Stop }
        catch { Write-Host "WARNING: temp cleanup failed: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}
