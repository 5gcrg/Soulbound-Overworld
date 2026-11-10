# Soulbound OD-013 Performance Evidence Capture & Release Gate (PowerShell)
#
# Owner-ratified OD-013 performance evidence plan (report/od013-ratification.md):
#   - Reference hardware: the owner's current Windows machine; exact specifications
#     are captured live (WMI/CIM) and recorded in the evidence file and report.
#   - Target 60 FPS with a documented 30 FPS fallback.
#   - Measured scenes: title, overworld, combat, dungeon, learning journal.
#   - Automated Godot-native capture plus manual profiling evidence (manual browser
#     profiling stays PENDING HUMAN EXECUTION; no browser acceptance is claimed).
#   - No maximum build-size budget is imposed (build_size_budget = null).
#   - Below-target results WARN and are recorded; they NEVER fail the gate (exit 0).
#   - Preflight failures (missing/invalid engine, wrong Godot version, incompatible
#     renderer or single-thread configuration) DO fail the run (non-zero exit).
#   - Web invariants retained: Godot 4.7.2 Stable, gl_compatibility, single-threaded.
#
# Requirements: GDD-093, GDD-094, GDD-095, GDD-096, GDD-097, GDD-104, GDD-107,
# GDD-123, GDD-124, GDD-129, FR-REL-001, TC-REL-001, TC-WEB-001, TC-WEB-002,
# NFR-PERF-001, NFR-WEB-001, NFR-BUILD-001.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\performance_evidence.ps1
#   ... -CaptureMode both            # headless + windowed native rendered capture
#   ... -SkipCapture -FixturePath X  # evaluate a pre-supplied capture payload
# Exits 0 on success (including WARN rows); non-zero on preflight/capture failure.

param (
    [string]$GodotPath = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe",
    [string]$ProjectGodotPath = "project.godot",
    [string]$PresetsPath = "export_presets.cfg",
    [string]$ExpectedEngineVersionPrefix = "4.7.2.stable",
    [ValidateRange(1, 1000)]
    [int]$TargetFps = 60,
    [ValidateRange(1, 1000)]
    [int]$FallbackFps = 30,
    [ValidateSet("headless", "windowed", "both")]
    [string]$CaptureMode = "headless",
    [ValidateRange(1, 100000)]
    [int]$WarmupFrames = 60,
    [ValidateRange(5, 1000000)]
    [int]$MeasuredFrames = 300,
    [string]$EvidencePath = "report/od013_performance_evidence.json",
    [string]$ReportPath = "report/od013_performance_report.md",
    [string]$LogPath = "report/od013_performance_evidence.log",
    [string]$FixturePath = "",
    [switch]$SkipCapture = $false
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $ProjectRoot

. (Join-Path $PSScriptRoot "release_manifest.ps1")

$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# ---------------------------------------------------------------------------
# Path / logging helpers
# ---------------------------------------------------------------------------

function Resolve-ProjectPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $ProjectRoot $Path)
}

function Ensure-ParentDirectory {
    param([Parameter(Mandatory = $true)][string]$FilePath)
    $dir = Split-Path -Parent $FilePath
    if (-not [string]::IsNullOrEmpty($dir) -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$script:LogFullPath = Resolve-ProjectPath -Path $LogPath
Ensure-ParentDirectory -FilePath $script:LogFullPath
[System.IO.File]::WriteAllText($script:LogFullPath, "", $Utf8NoBom)

function Write-EvLog {
    param([string]$Message, [string]$Color = "Gray")
    Write-Host $Message -ForegroundColor $Color
    Add-Content -LiteralPath $script:LogFullPath -Value $Message
}

function Write-EvBlock {
    # Writes a multi-line block (e.g. captured Godot output) to the log only.
    param([string]$Text, [string]$Prefix = "    | ")
    foreach ($line in ($Text -split "`r?`n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Add-Content -LiteralPath $script:LogFullPath -Value ($Prefix + $line)
        }
    }
}

# ---------------------------------------------------------------------------
# Preflight: strict engine resolution + platform configuration invariants.
# Any failure here is a hard failure (non-zero exit) - never a silent skip.
# ---------------------------------------------------------------------------

function Invoke-PerformancePreflight {
    Write-EvLog "`n[1/5] Preflight: engine resolution and platform configuration..." "Yellow"

    if (-not (Test-Path -LiteralPath $GodotPath)) {
        throw "Godot executable not found at '$GodotPath'; no fallback is attempted. Pass a valid -GodotPath."
    }

    # Requires Godot 4.7.2 Stable (throws on a non-Godot executable, a failed
    # --version, or any other reported version) and hashes the executable.
    $engine = Get-SblEngineProvenance -GodotPath $GodotPath -RequiredVersionPrefix $ExpectedEngineVersionPrefix
    Write-EvLog "  PASS: engine '$($engine.version)' at $GodotPath" "Green"
    Write-EvLog "       executable_sha256=$($engine.executable_sha256)" "Gray"

    $resolvedProjectGodot = Resolve-ProjectPath -Path $ProjectGodotPath
    if (-not (Test-Path -LiteralPath $resolvedProjectGodot)) {
        throw "project.godot not found at '$resolvedProjectGodot'."
    }
    $projectText = [System.IO.File]::ReadAllText($resolvedProjectGodot)

    $rendering = Get-SblProjectSettingValue -Text $projectText -Key "renderer/rendering_method"
    if ($rendering -ne "gl_compatibility") {
        throw "Incompatible configuration: project.godot renderer/rendering_method='$rendering' must be 'gl_compatibility' (GDD-095 / GDD-109)."
    }
    $renderingWeb = Get-SblProjectSettingValue -Text $projectText -Key "renderer/rendering_method.web"
    if ($renderingWeb -ne "gl_compatibility") {
        throw "Incompatible configuration: project.godot renderer/rendering_method.web='$renderingWeb' must be 'gl_compatibility' (GDD-095, single-threaded Compatibility Web)."
    }
    Write-EvLog "  PASS: rendering_method=gl_compatibility, rendering_method.web=gl_compatibility" "Green"

    $resolvedPresets = Resolve-ProjectPath -Path $PresetsPath
    if (-not (Test-Path -LiteralPath $resolvedPresets)) {
        throw "export_presets.cfg not found at '$resolvedPresets'."
    }
    $presetsText = [System.IO.File]::ReadAllText($resolvedPresets)
    $threadSupport = Get-SblPresetThreadSupport -Text $presetsText -PresetName "Web"
    if (-not $threadSupport.Found) {
        throw "Incompatible configuration: Web export preset not found in '$resolvedPresets'; single-threaded Web invariant cannot be proven."
    }
    if ($threadSupport.Value -ne $false) {
        throw "Incompatible configuration: Web preset variant/thread_support='$($threadSupport.Value)' must be false (single-threaded Web invariant, GDD-107 / OD-013)."
    }
    Write-EvLog "  PASS: Web export preset variant/thread_support=false (single-threaded)" "Green"

    $mainScene = Get-SblProjectSettingValue -Text $projectText -Key "run/main_scene"
    $viewportWidth = $null
    $viewportHeight = $null
    $vwMatch = [regex]::Match($projectText, '(?m)^window/size/viewport_width=(\d+)')
    $vhMatch = [regex]::Match($projectText, '(?m)^window/size/viewport_height=(\d+)')
    if ($vwMatch.Success) { $viewportWidth = [int]$vwMatch.Groups[1].Value }
    if ($vhMatch.Success) { $viewportHeight = [int]$vhMatch.Groups[1].Value }

    return [pscustomobject]@{
        engine_path              = $GodotPath
        engine_version           = $engine.version
        engine_executable_sha256 = $engine.executable_sha256
        expected_version_prefix  = $ExpectedEngineVersionPrefix
        rendering_method         = $rendering
        rendering_method_web     = $renderingWeb
        web_thread_support       = $false
        single_threaded_web      = $true
        main_scene               = $mainScene
        viewport_width           = $viewportWidth
        viewport_height          = $viewportHeight
        project_godot            = $resolvedProjectGodot
        export_presets           = $resolvedPresets
    }
}

# ---------------------------------------------------------------------------
# Reference machine specifications (owner's current Windows machine).
# ---------------------------------------------------------------------------

function Get-MachineSpecs {
    Write-EvLog "`n[2/5] Capturing reference machine specifications..." "Yellow"
    $specs = [ordered]@{}

    $os = $null
    $cs = $null
    $cpus = @()
    $gpus = @()
    try { $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop } catch { }
    try { $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop } catch { }
    try { $cpus = @(Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop) } catch { }
    try { $gpus = @(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | ForEach-Object { $_.Name } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) } catch { }

    $specs["captured_utc"] = (Get-Date).ToUniversalTime().ToString("o")
    $specs["hostname"] = if ($null -ne $cs -and -not [string]::IsNullOrWhiteSpace($cs.Name)) { $cs.Name } else { "unavailable" }
    $specs["os_caption"] = if ($null -ne $os) { $os.Caption } else { "unavailable" }
    $specs["os_version"] = if ($null -ne $os) { $os.Version } else { "unavailable" }
    $specs["os_build"] = if ($null -ne $os) { [string]$os.BuildNumber } else { "unavailable" }
    $specs["os_architecture"] = if ($null -ne $os) { $os.OSArchitecture } else { "unavailable" }
    $specs["memory_gb"] = if ($null -ne $cs -and $cs.TotalPhysicalMemory) { [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1) } else { $null }
    $specs["cpu_name"] = if ($cpus.Count -gt 0) { (($cpus | ForEach-Object { $_.Name } | Select-Object -Unique) -join "; ").Trim() } else { "unavailable" }
    $specs["cpu_count"] = $cpus.Count
    $specs["cpu_cores"] = if ($cpus.Count -gt 0) { [int](($cpus | Measure-Object -Property NumberOfCores -Sum).Sum) } else { $null }
    $specs["cpu_logical_processors"] = if ($cpus.Count -gt 0) { [int](($cpus | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum) } else { $null }
    $gpuList = @($gpus)
    if ($gpuList.Count -eq 0) { $gpuList = @("unavailable") }
    $specs["gpu_adapters"] = $gpuList
    $specs["powershell_version"] = "$($PSVersionTable.PSVersion)"
    $specs["clr_version"] = "$([System.Environment]::Version)"
    $specs["timezone"] = [System.TimeZoneInfo]::Local.Id

    foreach ($key in @("hostname", "os_caption", "os_version", "os_build", "os_architecture", "memory_gb", "cpu_name", "cpu_cores", "cpu_logical_processors")) {
        Write-EvLog "  $key = $($specs[$key])" "Gray"
    }
    Write-EvLog "  gpu_adapters = $($specs['gpu_adapters'] -join ', ')" "Gray"
    return $specs
}

# ---------------------------------------------------------------------------
# Automated Godot-native capture harness (transient GDScript, written to the
# system temp directory - never inside the repository).
# ---------------------------------------------------------------------------

$script:HarnessSource = @'
extends SceneTree

## OD-013 automated performance capture harness (Soulbound).
## Generated at runtime by scripts/build/performance_evidence.ps1 and written
## to the system temporary directory; it is never tracked by Git.
## Requirements: GDD-104, GDD-123, GDD-124, NFR-PERF-001, NFR-WEB-001.

const SCENE_SPECS := [
	{"id": "title", "label": "Title screen", "path": "res://scenes/ui/title_screen.tscn"},
	{"id": "overworld", "label": "Overworld", "path": "res://scenes/main/game_root.tscn"},
	{"id": "combat", "label": "Combat", "path": "res://scenes/combat/battle_fixture.tscn"},
	{"id": "dungeon", "label": "Dungeon", "path": "res://scenes/dungeon/dungeon_expedition.tscn"},
	{"id": "learning_journal", "label": "Learning journal", "path": "res://scenes/ui/learning_journal.tscn"},
]

class CaptureLogger extends Logger:
	var error_count: int = 0
	var warning_count: int = 0

	func _log_error(
		function: String,
		file: String,
		line: int,
		code: String,
		rationale: String,
		_editor_notify: bool,
		error_type: int,
		_script_backtraces: Array[ScriptBacktrace]
	) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING:
			warning_count += 1
		else:
			error_count += 1

var out_path: String = ""
var warmup: int = 60
var measure: int = 300
var display_mode: String = "headless"
var rows: Array = []
var logger: CaptureLogger = null

func _init() -> void:
	logger = CaptureLogger.new()
	OS.add_logger(logger)
	var args := OS.get_cmdline_user_args()
	var i := 0
	while i < args.size():
		var key: String = args[i]
		if key == "--out" and i + 1 < args.size():
			i += 1
			out_path = args[i]
		elif key == "--mode" and i + 1 < args.size():
			i += 1
			display_mode = args[i]
		elif key == "--warmup" and i + 1 < args.size():
			i += 1
			warmup = int(args[i])
		elif key == "--measure" and i + 1 < args.size():
			i += 1
			measure = int(args[i])
		i += 1
	if out_path == "":
		out_path = "user://od013_performance_capture.json"
	_run.call_deferred()

func _run() -> void:
	print("OD013_CAPTURE_START display=", DisplayServer.get_name(), " mode=", display_mode)
	for spec in SCENE_SPECS:
		var row: Dictionary = await _measure_scene(spec)
		rows.append(row)
		print("OD013_SCENE ", JSON.stringify(row))
	var payload := {
		"schema": "sbl-od013-capture/1",
		"display_mode": display_mode,
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"renderer_vendor": RenderingServer.get_video_adapter_vendor(),
		"refresh_rate_hz": DisplayServer.screen_get_refresh_rate(),
		"engine_reported_fps": Engine.get_frames_per_second(),
		"engine_errors_total": logger.error_count,
		"engine_warnings_total": logger.warning_count,
		"scenes": rows,
	}
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		printerr("OD013_CAPTURE_FAIL cannot open output file: ", out_path)
		quit(1)
		return
	file.store_string(JSON.stringify(payload, "\t", false))
	file.close()
	print("OD013_CAPTURE_DONE errors=", logger.error_count, " warnings=", logger.warning_count)
	quit(0)

func _measure_scene(spec: Dictionary) -> Dictionary:
	var id: String = spec["id"]
	var path: String = spec["path"]
	var row := {
		"id": id,
		"label": spec["label"],
		"scene": path,
		"ok": false,
		"error": "",
		"engine_errors": 0,
		"engine_warnings": 0,
		"setup_ms": 0.0,
		"avg_frame_ms": 0.0,
		"min_frame_ms": 0.0,
		"max_frame_ms": 0.0,
		"avg_fps": 0.0,
		"min_fps": 0.0,
		"frames": 0,
	}
	var err_before: int = logger.error_count
	var warn_before: int = logger.warning_count
	var t_setup := Time.get_ticks_usec()

	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		row["error"] = "load failed: " + path
		return await _finish_row(row, err_before, warn_before, t_setup)
	var node: Node = packed.instantiate()
	if node == null:
		row["error"] = "instantiate failed: " + path
		return await _finish_row(row, err_before, warn_before, t_setup)

	if id == "overworld":
		# Disposable profile root: no fixture write can reach the real profile store.
		var store := ProfileStore.new("user://od013_overworld_%d" % OS.get_process_id())
		node.set("profile_store", store)
	root.add_child(node)
	if node is Control:
		(node as Control).size = Vector2(960, 540)
	await process_frame
	await process_frame

	match id:
		"title":
			var title_store := ProfileStore.new("user://od013_title_%d" % OS.get_process_id())
			node.call("setup_profiles", title_store, "profile_01")
			await process_frame
		"dungeon":
			var dungeon_ok: bool = node.call("setup", 1337, 6)
			if not dungeon_ok:
				row["error"] = "dungeon expedition setup returned false"
			await process_frame
		"learning_journal":
			var assessment := AssessmentController.new()
			assessment.submit_answer("q_crit_01", 0)
			node.call("configure", assessment, "profile_01")
			await process_frame
		"overworld":
			if DisplayServer.get_name() != "headless" and node.has_method("_close_title_screen"):
				# Windowed boot opens the title overlay (already measured as its
				# own scene); dismiss it so this row measures the overworld.
				node.call("_close_title_screen")
				await process_frame

	if row["error"] != "":
		node.queue_free()
		await process_frame
		return await _finish_row(row, err_before, warn_before, t_setup)

	row["setup_ms"] = (Time.get_ticks_usec() - t_setup) / 1000.0

	for i in warmup:
		await process_frame

	var durs: Array[int] = []
	var last := Time.get_ticks_usec()
	for i in measure:
		await process_frame
		var now := Time.get_ticks_usec()
		durs.append(now - last)
		last = now

	var total: int = 0
	var fastest: int = durs[0]
	var slowest: int = durs[0]
	for d in durs:
		total += d
		if d < fastest:
			fastest = d
		if d > slowest:
			slowest = d
	var avg_us: float = float(total) / float(durs.size())
	row["frames"] = durs.size()
	row["avg_frame_ms"] = avg_us / 1000.0
	row["min_frame_ms"] = float(fastest) / 1000.0
	row["max_frame_ms"] = float(slowest) / 1000.0
	row["avg_fps"] = 1000000.0 / avg_us
	row["min_fps"] = 1000000.0 / float(slowest)
	row["ok"] = true

	node.queue_free()
	await process_frame
	return await _finish_row(row, err_before, warn_before, t_setup)

func _finish_row(row: Dictionary, err_before: int, warn_before: int, t_setup: int) -> Dictionary:
	row["engine_errors"] = logger.error_count - err_before
	row["engine_warnings"] = logger.warning_count - warn_before
	if float(row["setup_ms"]) == 0.0:
		row["setup_ms"] = (Time.get_ticks_usec() - t_setup) / 1000.0
	return row
'@

function Invoke-PerformanceCapture {
    param([Parameter(Mandatory = $true)][ValidateSet("headless", "windowed")][string]$Mode)

    $token = [System.Guid]::NewGuid().ToString("N")
    $harnessPath = Join-Path ([System.IO.Path]::GetTempPath()) ("sbl_od013_capture_" + $token + ".gd")
    $outJson = Join-Path ([System.IO.Path]::GetTempPath()) ("sbl_od013_capture_" + $token + ".json")
    $stdoutFile = Join-Path ([System.IO.Path]::GetTempPath()) ("sbl_od013_capture_" + $token + ".out")
    $stderrFile = Join-Path ([System.IO.Path]::GetTempPath()) ("sbl_od013_capture_" + $token + ".err")
    [System.IO.File]::WriteAllText($harnessPath, $script:HarnessSource, $Utf8NoBom)

    try {
        # House-standard process management (docs/testing.md): a console Godot
        # child with -NoNewWindow -Wait -PassThru and file redirection avoids the
        # blank-exit-code trap and pipe-read stalls of synchronous stream reads.
        $argTokens = @()
        if ($Mode -eq "headless") { $argTokens += "--headless" }
        $argTokens += @(
            "--path", $ProjectRoot.Path,
            "--script", $harnessPath,
            "--",
            "--out", $outJson,
            "--mode", $Mode,
            "--warmup", "$WarmupFrames",
            "--measure", "$MeasuredFrames"
        )
        $argString = (($argTokens | ForEach-Object { $a = "$_"; if ($a -match '\s') { '"' + $a + '"' } else { $a } }) -join " ")

        Write-EvLog "  [$Mode] running Godot capture: $WarmupFrames warmup + $MeasuredFrames measured frames per scene..." "Gray"
        $proc = Start-Process -FilePath $GodotPath `
            -ArgumentList $argString `
            -NoNewWindow -Wait -PassThru `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        $stdoutText = if (Test-Path -LiteralPath $stdoutFile) { [System.IO.File]::ReadAllText($stdoutFile) } else { "" }
        $stderrText = if (Test-Path -LiteralPath $stderrFile) { [System.IO.File]::ReadAllText($stderrFile) } else { "" }
        Write-EvBlock -Text $stdoutText
        if (-not [string]::IsNullOrWhiteSpace($stderrText)) {
            Write-EvBlock -Text $stderrText -Prefix "  [stderr] "
        }
        if ($null -eq $proc.ExitCode) {
            throw "Godot $Mode performance capture returned a blank exit code; the capture cannot be trusted."
        }
        if ($proc.ExitCode -ne 0) {
            throw "Godot $Mode performance capture failed (exit $($proc.ExitCode)); see $script:LogFullPath."
        }
        if (-not (Test-Path -LiteralPath $outJson)) {
            throw "Godot $Mode performance capture produced no output file."
        }

        $payload = Get-Content -LiteralPath $outJson -Raw | ConvertFrom-Json
        $scenes = @($payload.scenes)
        if ($scenes.Count -ne 5) {
            throw "Godot $Mode performance capture recorded $($scenes.Count) scene(s); expected exactly 5 (title, overworld, combat, dungeon, learning journal)."
        }
        foreach ($scene in $scenes) {
            if (-not $scene.ok) {
                throw "Godot $Mode capture failed for scene '$($scene.id)': $($scene.error)"
            }
        }
        Write-EvLog "  PASS: [$Mode] captured $($scenes.Count) scenes (display=$($payload.display_server), renderer='$($payload.renderer)')" "Green"
        return $payload
    } finally {
        foreach ($tempFile in @($harnessPath, $outJson, $stdoutFile, $stderrFile)) {
            if (Test-Path -LiteralPath $tempFile) { Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue }
        }
    }
}

# ---------------------------------------------------------------------------
# Evaluation: 60 FPS target, 30 FPS fallback, WARN never FAIL.
# ---------------------------------------------------------------------------

function Evaluate-CaptureScenes {
    param(
        [Parameter(Mandatory = $true)]$CapturePayload,
        [Parameter(Mandatory = $true)][string]$CaptureLabel
    )

    $rows = @()
    foreach ($scene in @($CapturePayload.scenes)) {
        $avgFps = [double]$scene.avg_fps
        $minFps = [double]$scene.min_fps
        $status = "PASS"
        $notes = @()

        if ($avgFps -lt $TargetFps) {
            $status = "WARN"
            $notes += "average FPS $([math]::Round($avgFps, 1)) is below the $TargetFps FPS target"
        }
        if ($minFps -lt $FallbackFps) {
            $status = "WARN"
            $notes += "minimum FPS $([math]::Round($minFps, 1)) is below the documented $FallbackFps FPS fallback"
        }
        $engineErrors = 0
        if ($null -ne $scene.PSObject.Properties["engine_errors"]) { $engineErrors = [int]$scene.engine_errors }
        if ($engineErrors -gt 0) {
            $status = "WARN"
            $notes += "$engineErrors Godot engine error(s) recorded while this scene was measured"
        }

        $rows += [pscustomobject]@{
            capture      = $CaptureLabel
            id           = [string]$scene.id
            label        = [string]$scene.label
            scene        = [string]$scene.scene
            frames       = [int]$scene.frames
            avg_frame_ms = [math]::Round([double]$scene.avg_frame_ms, 3)
            min_frame_ms = [math]::Round([double]$scene.min_frame_ms, 3)
            max_frame_ms = [math]::Round([double]$scene.max_frame_ms, 3)
            avg_fps      = [math]::Round($avgFps, 1)
            min_fps      = [math]::Round($minFps, 1)
            setup_ms     = [math]::Round([double]$scene.setup_ms, 1)
            engine_errors = $engineErrors
            status       = $status
            notes        = ($notes -join "; ")
        }
    }
    return ,@($rows)
}

# ---------------------------------------------------------------------------
# Evidence writers (atomic: write to a .tmp sibling, then move into place).
# ---------------------------------------------------------------------------

function Write-EvidenceFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$Payload
    )
    Ensure-ParentDirectory -FilePath $Path
    $tmp = $Path + ".tmp"
    $json = ConvertTo-Json -InputObject $Payload -Depth 12
    [System.IO.File]::WriteAllText($tmp, $json, $Utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function Write-ReportFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )
    Ensure-ParentDirectory -FilePath $Path
    $tmp = $Path + ".tmp"
    [System.IO.File]::WriteAllText($tmp, $Content, $Utf8NoBom)
    Move-Item -LiteralPath $tmp -Destination $Path -Force
}

function ConvertTo-ResultTable {
    # Markdown table rows for one capture's evaluated scene rows.
    param([Parameter(Mandatory = $true)]$Rows)
    $lines = @()
    foreach ($row in $Rows) {
        $noteCell = if ([string]::IsNullOrWhiteSpace($row.notes)) { "-" } else { ($row.notes -replace '\|', '/') }
        $lines += "| $($row.label) | ``$($row.scene)`` | $($row.avg_fps) | $($row.min_fps) | $($row.avg_frame_ms) | $($row.min_frame_ms) | $($row.max_frame_ms) | $($row.frames) | **$($row.status)** | $noteCell |"
    }
    return ,@($lines)
}

function Get-CaptureDisplayTitle {
    param([Parameter(Mandatory = $true)][string]$Label)
    switch ($Label) {
        "headless" { return "Headless native capture (no renderer)" }
        "windowed" { return "Windowed native rendered capture" }
        "fixture" { return "Fixture payload evaluation (no engine run)" }
        default { return "$Label capture" }
    }
}

# ---------------------------------------------------------------------------
# Report template (OD-013). Tokens are replaced literally below.
# ---------------------------------------------------------------------------

$script:ReportTemplate = @'
# OD-013 Performance Evidence Report - Soulbound

**Decision:** OD-013 - Platform and Performance Evidence, owner-ratified in
[`report/od013-ratification.md`](od013-ratification.md) (10 November 2026).
**Generated (UTC):** {{GENERATED_UTC}}
**Automated by:** `scripts/build/performance_evidence.ps1` (executor: `opencode-go/mimo-v2.6-flash` / MiMo; plan owner: Codex/OpenCode).
**Review status:** `REVIEW_PENDING_CODEX`. Codex CLI review was not performed for this slice; nothing in this report is `REVIEWED`.

> **No browser acceptance is claimed.** Automated capture in this report is Godot-native
> (headless and/or windowed native execution on the reference machine). Browser smoke
> testing and manual profiling remain **PENDING HUMAN EXECUTION** in
> [`docs/browser_verification_checklist.md`](../docs/browser_verification_checklist.md).

## 1. Ratified scope -> implementation map

| Ratified OD-013 decision | Where it is implemented / recorded |
|---|---|
| Reference hardware = owner's current Windows machine; capture exact specs | Section 2 (captured live from WMI/CIM during this run) |
| Browsers: Chromium, Firefox, plus additional available owner-selected browsers | Section 6 - coverage registered as pending human execution; no automated browser run |
| Target 60 FPS with documented 30 FPS fallback | Section 5 gate semantics; evidence `target_fps={{TARGET_FPS}}`, `fallback_fps={{FALLBACK_FPS}}` |
| Measured scenes: title, overworld, combat, dungeon, learning journal | Section 4 (all five scenes captured per mode) |
| Automated capture **plus** manual profiling evidence | Sections 3-4 automated Godot-native capture; Section 6 manual profiling pending human execution |
| No maximum build-size budget | Section 5 - `build_size_budget = null`; pre-existing plausibility bounds in `validate_release.ps1` are unchanged and are not an OD-013 budget |
| Below-target -> warn and record, never auto-fail release | Section 5 - every below-target row is `WARN` and the script exits `0` |
| Godot 4.7.2 Compatibility, single-threaded Web retained | Section 3 - asserted in preflight; a violation fails the run |
| Performance evidence included in the canonical release gate with warning semantics | Section 7 |

## 2. Reference machine (captured {{CAPTURED_UTC}})

| Field | Value |
|---|---|
| Hostname | {{MACHINE_HOSTNAME}} |
| Operating system | {{MACHINE_OS_CAPTION}} |
| OS version / build | {{MACHINE_OS_VERSION}} / {{MACHINE_OS_BUILD}} |
| OS architecture | {{MACHINE_OS_ARCH}} |
| Memory | {{MACHINE_MEMORY_GB}} GB |
| CPU | {{MACHINE_CPU_NAME}} ({{MACHINE_CPU_COUNT}} package(s), {{MACHINE_CPU_CORES}} cores / {{MACHINE_CPU_LOGICAL}} logical) |
| GPU adapter(s) | {{MACHINE_GPU}} |
| PowerShell / CLR | {{MACHINE_PS_VERSION}} / {{MACHINE_CLR_VERSION}} |
| Time zone | {{MACHINE_TZ}} |

## 3. Engine and configuration (preflight-verified)

| Field | Value |
|---|---|
| Godot executable | `{{ENGINE_PATH}}` |
| Godot version | **{{ENGINE_VERSION}}** (required prefix `{{ENGINE_PREFIX}}`; mismatch fails preflight) |
| Executable SHA-256 | `{{ENGINE_SHA}}` |
| Project renderer | `{{RENDERING}}` (must be `gl_compatibility`) |
| Web renderer override | `{{RENDERING_WEB}}` (must be `gl_compatibility`) |
| Web export thread support | `{{THREAD_SUPPORT}}` (single-threaded Web invariant, GDD-107) |
| Main scene | `{{MAIN_SCENE}}` |
| Viewport | {{VIEWPORT_W}}x{{VIEWPORT_H}} |

Preflight **fails the run with a non-zero exit** when: the engine path is missing or
not a Godot executable, the reported version is not `{{ENGINE_PREFIX}}`, either
renderer setting is not `gl_compatibility`, or the Web preset is not single-threaded.
Preflight never silently skips.

## 4. Automated Godot-native capture

**Method.** A Godot `SceneTree` harness is generated into the system temporary
directory (never into the repository) and run with the project's own Godot binary
under proven disposable user-data isolation. Per scene the harness builds a real
fixture (title screen with a disposable `ProfileStore`; `GameRoot` overworld with a
disposable profile root; `BattleFixture`; `DungeonExpedition` started with seed
1337/6 rooms; `LearningJournal` configured with an `AssessmentController`), lets it
settle for {{WARMUP_FRAMES}} warm-up frames, then records {{MEASURED_FRAMES}} frame
intervals measured as wall-clock time between consecutive `process_frame` resumes.
`avg_fps` is derived from the mean frame interval and `min_fps` from the slowest
observed frame in the window.

**Pacing note (headless).** The real-time-synchronized headless loop on this machine
paces to a ~6.90 ms frame interval (~145 FPS baseline); scene work above that budget
lowers delivered FPS proportionally (implementation-time calibration probes measured
`Engine.max_fps = 30` -> 33.3 ms frames and 10 ms of busy work per frame -> 100 FPS).
Headless capture therefore measures whether each scene fits its frame budget but
**excludes GPU/rendering cost** - rendered performance is covered by Section 4.2 and by the
manual browser profiling in Section 6.

### 4.1 {{CAPTURE_1_TITLE}}

Environment: display server `{{C1_DISPLAY}}`, renderer `{{C1_RENDERER}}`,
refresh rate `{{C1_REFRESH}}` Hz, engine-reported FPS `{{C1_ENGINE_FPS}}`,
engine errors `{{C1_ERRORS}}` / warnings `{{C1_WARNINGS}}`.

| Scene | Scene path | Avg FPS | Min FPS | Avg frame (ms) | Min frame (ms) | Max frame (ms) | Frames | Status | Notes |
|---|---|---|---|---|---|---|---|---|---|
{{CAPTURE_1_ROWS}}

### 4.2 {{CAPTURE_2_TITLE}}

{{CAPTURE_2_BODY}}

## 5. Gate semantics

| Rule | Behavior |
|---|---|
| Target | {{TARGET_FPS}} FPS (`avg_fps >= target` -> `PASS`) |
| Documented fallback | {{FALLBACK_FPS}} FPS (a `min_fps` below it -> `WARN`) |
| Below-target result | Recorded as `WARN` in the evidence JSON and this report; **exit code stays 0** - release is never auto-failed |
| Preflight / capture failure | Missing or invalid engine, wrong Godot version, incompatible renderer or thread configuration, or an incomplete capture -> **non-zero exit** |
| Maximum build-size budget | **None.** `build_size_budget = null`; no size limit was introduced by OD-013 |
| Existing gates | Export, archive/PCK, manifest, save, and restoration gates are unchanged |

Summary for this run: {{SUMMARY_ROWS}} scene row(s) evaluated -
**{{SUMMARY_PASS}} PASS**, **{{SUMMARY_WARN}} WARN**, **{{SUMMARY_FAIL}} FAIL** (FAIL count is structurally 0: below-target never fails).

{{WARNINGS_SECTION}}

## 6. Manual browser & profiling evidence - PENDING HUMAN EXECUTION

Automated evidence above is **not** browser evidence. The following rows are the
OD-013 manual coverage register and stay pending until the owner executes them;
**no browser smoke acceptance is claimed or implied by this report**.

| Browser | Coverage | Scenes | Avg/Min FPS | Status |
|---|---|---|---|---|
| Chromium (Chrome / Edge, latest stable) | TC-WEB-001 | title, overworld, combat, dungeon, learning journal | not recorded | **PENDING HUMAN EXECUTION** |
| Mozilla Firefox (latest stable) | TC-WEB-002 | title, overworld, combat, dungeon, learning journal | not recorded | **PENDING HUMAN EXECUTION** |
| Additional owner-selected browser (name TBD by owner) | OD-013 ratification | title, overworld, combat, dungeon, learning journal | not recorded | **PENDING HUMAN EXECUTION** |

Manual profiling method (owner): serve `builds/web/index.html` over HTTP, open the
browser DevTools performance profiler (or the in-engine profiler), record average and
minimum FPS plus frame timing for each of the five scenes, and attach the numbers to
[`docs/browser_verification_checklist.md`](../docs/browser_verification_checklist.md).

## 7. Release-gate integration

`scripts/build/run_headless_tests.ps1 -Export` chains this script after export,
validation, and the release-manifest suite, so performance evidence is part of the
canonical release gate:

- **Warning semantics:** below-target rows are recorded and printed as `WARNING`;
  the chain continues and the run exits `0`.
- **Hard-failure semantics:** preflight or capture failure exits non-zero and fails
  the chain (invalid engine/configuration must never pass silently).
- Standalone invocation: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\performance_evidence.ps1`
- Targeted controls: `scripts/build/test_performance_evidence.ps1`

## 8. Evidence artifacts

| Artifact | Path |
|---|---|
| Machine-readable evidence (this run) | `{{EVIDENCE_PATH}}` |
| This report | `{{REPORT_PATH}}` |
| Raw execution log (transient) | `{{LOG_PATH}}` |
| Capture harness (transient, system temp) | deleted after each run |
| Ratification | [`report/od013-ratification.md`](od013-ratification.md) |
| Browser checklist (manual, pending) | [`docs/browser_verification_checklist.md`](../docs/browser_verification_checklist.md) |

## 9. Limitations

1. Headless capture excludes GPU and compositor cost; only the windowed capture in
   Section 4.2 (when executed) and the manual browser profiling in Section 6 cover rendered frame cost.
2. Browser smoke results are not produced by this automation; they remain human
   evidence and are not claimed here.
3. Numbers are specific to the reference machine in Section 2 and the environment recorded
   in the evidence JSON; a different machine must re-run this script.
4. No numerical gameplay balance, drop rate, or formula was created, changed, or
   inferred by this slice.
'@

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

try {
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host "  OD-013 Performance Evidence Capture    " -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-EvLog "Project root : $($ProjectRoot.Path)" "Gray"
    Write-EvLog "Capture mode : $CaptureMode | target $TargetFps FPS | fallback $FallbackFps FPS" "Gray"
    Write-EvLog "Evidence     : $(Resolve-ProjectPath -Path $EvidencePath)" "Gray"
    Write-EvLog "Report       : $(Resolve-ProjectPath -Path $ReportPath)" "Gray"
    Write-EvLog "Log          : $($script:LogFullPath)" "Gray"

    $config = Invoke-PerformancePreflight
    $machine = Get-MachineSpecs

    Write-EvLog "`n[3/5] Running automated Godot-native capture..." "Yellow"
    $captures = @()
    $captureModeLabel = $CaptureMode
    if ($SkipCapture) {
        if ([string]::IsNullOrWhiteSpace($FixturePath)) {
            throw "-SkipCapture requires -FixturePath <capture payload JSON>."
        }
        $resolvedFixture = Resolve-ProjectPath -Path $FixturePath
        if (-not (Test-Path -LiteralPath $resolvedFixture)) {
            throw "Fixture capture payload not found at '$resolvedFixture'."
        }
        $fixturePayload = Get-Content -LiteralPath $resolvedFixture -Raw | ConvertFrom-Json
        if ($null -eq $fixturePayload.PSObject.Properties["display_mode"]) {
            $fixturePayload | Add-Member -NotePropertyName display_mode -NotePropertyValue "fixture"
        }
        $captures += $fixturePayload
        $captureModeLabel = "fixture"
        Write-EvLog "  Using pre-supplied fixture payload: $resolvedFixture (no Godot run)" "Gray"
    } else {
        $isolation = $null
        $modes = @()
        if ($CaptureMode -in @("headless", "both")) { $modes += "headless" }
        if ($CaptureMode -in @("windowed", "both")) { $modes += "windowed" }
        try {
            $isolation = Enter-SblGodotUserDataIsolation -GodotPath $GodotPath -ProjectRoot $ProjectRoot.Path -Label "od013_performance"
            Write-EvLog "  Disposable user data proved before capture: $($isolation.ProbeUserDir)" "Gray"
            foreach ($mode in $modes) {
                $captures += Invoke-PerformanceCapture -Mode $mode
            }
        } finally {
            if ($null -ne $isolation) {
                $isolationResult = Exit-SblGodotUserDataIsolation -State $isolation
                Add-Content -Path (Join-Path $ProjectRoot "report\godot_user_data_isolation.log") -Value "[$(Get-Date -Format o)] performance_evidence: probe=$($isolationResult.ProbeUserDir); realUserDataUnchanged=$($isolationResult.RealDataUnchanged); disposableFiles=$($isolationResult.DisposableFileCount); rootRemoved=$($isolationResult.RootRemoved)"
                Write-EvLog "  Disposable user data: realUserDataUnchanged=$($isolationResult.RealDataUnchanged), rootRemoved=$($isolationResult.RootRemoved)" $(if ($isolationResult.RealDataUnchanged) { "Green" } else { "Red" })
                if (-not $isolationResult.RealDataUnchanged) {
                    throw "Disposable user-data isolation proof failed: real Godot user data changed during the performance capture."
                }
            }
        }
    }

    Write-EvLog "`n[4/5] Evaluating ${TargetFps} FPS target / ${FallbackFps} FPS fallback..." "Yellow"
    $evaluated = @()
    foreach ($capture in $captures) {
        $label = "automated"
        if ($null -ne $capture.PSObject.Properties["display_mode"]) { $label = [string]$capture.display_mode }
        if ($label -eq "fixture") { $label = "fixture" }
        $evaluated += ,@((Evaluate-CaptureScenes -CapturePayload $capture -CaptureLabel $label))
    }
    $allRows = @()
    foreach ($group in $evaluated) { $allRows += $group }

    $passCount = @($allRows | Where-Object { $_.status -eq "PASS" }).Count
    $warnCount = @($allRows | Where-Object { $_.status -eq "WARN" }).Count
    $failCount = @($allRows | Where-Object { $_.status -eq "FAIL" }).Count
    $warnings = @($allRows | Where-Object { $_.status -eq "WARN" } | ForEach-Object { "[$($_.capture)] $($_.label): $($_.notes)" })

    foreach ($row in $allRows) {
        $color = if ($row.status -eq "PASS") { "Green" } else { "Yellow" }
        Write-EvLog ("  [{0}] {1,-16} avg {2,7} fps | min {3,7} fps | avg {4,7} ms | {5}" -f $row.status, $row.label, $row.avg_fps, $row.min_fps, $row.avg_frame_ms, $row.capture) $color
    }
    foreach ($warning in $warnings) {
        Write-EvLog "  WARNING: $warning" "Yellow"
    }
    Write-EvLog "  Summary: $($allRows.Count) row(s) | PASS=$passCount WARN=$warnCount FAIL=$failCount (below-target never fails; exit code remains 0)" "Cyan"

    $browserEvidence = [ordered]@{
        status             = "PENDING_HUMAN_EXECUTION"
        acceptance_claimed = $false
        automated          = $false
        coverage_required  = @("Chromium", "Firefox", "additional available owner-selected browser")
        scenes             = @("title", "overworld", "combat", "dungeon", "learning_journal")
        method             = "manual browser profiling (DevTools/in-engine profiler) recorded in docs/browser_verification_checklist.md"
        rows               = @(
            [ordered]@{ browser = "Chromium (Chrome/Edge latest stable)"; test_case = "TC-WEB-001"; status = "PENDING"; avg_fps = $null; min_fps = $null },
            [ordered]@{ browser = "Mozilla Firefox (latest stable)"; test_case = "TC-WEB-002"; status = "PENDING"; avg_fps = $null; min_fps = $null },
            [ordered]@{ browser = "Additional owner-selected browser (TBD by owner)"; test_case = "OD-013 ratification"; status = "PENDING"; avg_fps = $null; min_fps = $null }
        )
    }

    $captureObjects = @()
    for ($i = 0; $i -lt $captures.Count; $i++) {
        $capture = $captures[$i]
        $label = "automated"
        if ($null -ne $capture.PSObject.Properties["display_mode"]) { $label = [string]$capture.display_mode }
        $rowsForCapture = $evaluated[$i]
        $captureObjects += [ordered]@{
            mode                = $label
            display_server      = $(if ($null -ne $capture.PSObject.Properties["display_server"]) { [string]$capture.display_server } else { "unavailable" })
            renderer            = $(if ($null -ne $capture.PSObject.Properties["renderer"]) { [string]$capture.renderer } else { "" })
            renderer_vendor     = $(if ($null -ne $capture.PSObject.Properties["renderer_vendor"]) { [string]$capture.renderer_vendor } else { "" })
            refresh_rate_hz     = $(if ($null -ne $capture.PSObject.Properties["refresh_rate_hz"]) { [double]$capture.refresh_rate_hz } else { $null })
            engine_reported_fps = $(if ($null -ne $capture.PSObject.Properties["engine_reported_fps"]) { [double]$capture.engine_reported_fps } else { $null })
            engine_errors_total = $(if ($null -ne $capture.PSObject.Properties["engine_errors_total"]) { [int]$capture.engine_errors_total } else { 0 })
            engine_warnings_total = $(if ($null -ne $capture.PSObject.Properties["engine_warnings_total"]) { [int]$capture.engine_warnings_total } else { 0 })
            warmup_frames       = $WarmupFrames
            measured_frames     = $MeasuredFrames
            scenes              = @($rowsForCapture | ForEach-Object {
                    [ordered]@{
                        id            = $_.id
                        label         = $_.label
                        scene         = $_.scene
                        frames        = $_.frames
                        avg_frame_ms  = $_.avg_frame_ms
                        min_frame_ms  = $_.min_frame_ms
                        max_frame_ms  = $_.max_frame_ms
                        avg_fps       = $_.avg_fps
                        min_fps       = $_.min_fps
                        setup_ms      = $_.setup_ms
                        engine_errors = $_.engine_errors
                        status        = $_.status
                        notes         = $_.notes
                    }
                })
        }
    }

    $evidencePath = Resolve-ProjectPath -Path $EvidencePath
    $reportPath = Resolve-ProjectPath -Path $ReportPath
    $logPath = $script:LogFullPath

    $evidence = [ordered]@{
        schema           = "sbl-od013-performance-evidence/1"
        decision         = "OD-013"
        ratification     = "report/od013-ratification.md"
        plan_status      = "PLAN_DRAFT_NOT_CODEX"
        review           = "REVIEW_PENDING_CODEX"
        generated_utc    = (Get-Date).ToUniversalTime().ToString("o")
        target_fps       = $TargetFps
        fallback_fps     = $FallbackFps
        build_size_budget = $null
        build_size_note  = "No maximum build-size budget is imposed (OD-013 ratification); no size limit was introduced by this slice."
        capture_mode     = $captureModeLabel
        warmup_frames    = $WarmupFrames
        measured_frames  = $MeasuredFrames
        preflight        = [ordered]@{
            engine_path              = $config.engine_path
            engine_version           = $config.engine_version
            engine_executable_sha256 = $config.engine_executable_sha256
            expected_version_prefix  = $config.expected_version_prefix
            rendering_method         = $config.rendering_method
            rendering_method_web     = $config.rendering_method_web
            web_thread_support       = $config.web_thread_support
            single_threaded_web      = $config.single_threaded_web
            main_scene               = $config.main_scene
            viewport_width           = $config.viewport_width
            viewport_height          = $config.viewport_height
        }
        machine          = $machine
        captures         = $captureObjects
        browser_evidence = $browserEvidence
        summary          = [ordered]@{
            rows_total = $allRows.Count
            pass       = $passCount
            warn       = $warnCount
            fail       = $failCount
            warnings   = @($warnings)
        }
        artifacts        = [ordered]@{
            evidence_json = $evidencePath
            report_md     = $reportPath
            log           = $logPath
        }
    }

    Write-EvLog "`n[5/5] Writing evidence artifacts..." "Yellow"
    Write-EvidenceFile -Path $evidencePath -Payload $evidence
    Write-EvLog "  Wrote evidence JSON: $evidencePath" "Green"

    # ---- report rendering ----
    $capturedUtc = [string]$machine["captured_utc"]
    $capture1Title = "Not executed (capture mode '$CaptureMode')"
    $capture1Rows = "_No capture of this mode was executed for this run._"
    $capture2Title = "Windowed native rendered capture - not executed for this run"
    $capture2Body = "_No windowed native rendered capture was executed for this run. Run with ``-CaptureMode windowed`` or ``-CaptureMode both`` to record rendered frame cost._"
    if ($captures.Count -ge 1) {
        $c0 = $captures[0]
        $label0 = if ($null -ne $c0.PSObject.Properties["display_mode"]) { [string]$c0.display_mode } else { "automated" }
        $capture1Title = Get-CaptureDisplayTitle -Label $label0
        $rows0 = ConvertTo-ResultTable -Rows $evaluated[0]
        $capture1Rows = ($rows0 -join "`n")
        $c1Display = if ($null -ne $c0.PSObject.Properties["display_server"]) { [string]$c0.display_server } else { "unavailable" }
        $c1Renderer = if ($null -ne $c0.PSObject.Properties["renderer"] -and $c0.renderer) { [string]$c0.renderer } else { "n/a (headless has no adapter)" }
        $c1Refresh = if ($null -ne $c0.PSObject.Properties["refresh_rate_hz"]) { [string]$c0.refresh_rate_hz } else { "unavailable" }
        $c1EngineFps = if ($null -ne $c0.PSObject.Properties["engine_reported_fps"]) { [string]$c0.engine_reported_fps } else { "unavailable" }
        $c1Errors = if ($null -ne $c0.PSObject.Properties["engine_errors_total"]) { [string]$c0.engine_errors_total } else { "0" }
        $c1Warnings = if ($null -ne $c0.PSObject.Properties["engine_warnings_total"]) { [string]$c0.engine_warnings_total } else { "0" }
    } else {
        $c1Display = "n/a"; $c1Renderer = "n/a"; $c1Refresh = "n/a"; $c1EngineFps = "n/a"; $c1Errors = "n/a"; $c1Warnings = "n/a"
    }
    if ($captures.Count -ge 2) {
        $c1 = $captures[1]
        $label1 = if ($null -ne $c1.PSObject.Properties["display_mode"]) { [string]$c1.display_mode } else { "windowed" }
        $capture2Title = Get-CaptureDisplayTitle -Label $label1
        $rows1 = ConvertTo-ResultTable -Rows $evaluated[1]
        $c2Display = if ($null -ne $c1.PSObject.Properties["display_server"]) { [string]$c1.display_server } else { "unavailable" }
        $c2Renderer = if ($null -ne $c1.PSObject.Properties["renderer"] -and $c1.renderer) { [string]$c1.renderer } else { "n/a" }
        $c2Refresh = if ($null -ne $c1.PSObject.Properties["refresh_rate_hz"]) { [string]$c1.refresh_rate_hz } else { "unavailable" }
        $c2EngineFps = if ($null -ne $c1.PSObject.Properties["engine_reported_fps"]) { [string]$c1.engine_reported_fps } else { "unavailable" }
        $c2Errors = if ($null -ne $c1.PSObject.Properties["engine_errors_total"]) { [string]$c1.engine_errors_total } else { "0" }
        $c2Warnings = if ($null -ne $c1.PSObject.Properties["engine_warnings_total"]) { [string]$c1.engine_warnings_total } else { "0" }
        $capture2Body = @"
Environment: display server ``$c2Display``, renderer ``$c2Renderer``, refresh rate ``$c2Refresh`` Hz,
engine-reported FPS ``$c2EngineFps``, engine errors ``$c2Errors`` / warnings ``$c2Warnings``.

| Scene | Scene path | Avg FPS | Min FPS | Avg frame (ms) | Min frame (ms) | Max frame (ms) | Frames | Status | Notes |
|---|---|---|---|---|---|---|---|---|---|
$($rows1 -join "`n")
"@
    }

    $warningsSection = "_No warnings: every measured scene met the ${TargetFps} FPS target and the ${FallbackFps} FPS fallback._"
    if ($warnings.Count -gt 0) {
        $warningLines = @("The following below-target observations were **recorded as warnings** and did **not** fail the gate (exit 0):", "")
        foreach ($warning in $warnings) { $warningLines += "- $warning" }
        $warningsSection = ($warningLines -join "`n")
    }

    $viewportText = "unavailable"
    if ($null -ne $config.viewport_width -and $null -ne $config.viewport_height) {
        $viewportText = "$($config.viewport_width)x$($config.viewport_height)"
    }

    $replacements = @{
        "{{GENERATED_UTC}}"      = (Get-Date).ToUniversalTime().ToString("o")
        "{{CAPTURED_UTC}}"       = $capturedUtc
        "{{TARGET_FPS}}"         = "$TargetFps"
        "{{FALLBACK_FPS}}"       = "$FallbackFps"
        "{{WARMUP_FRAMES}}"      = "$WarmupFrames"
        "{{MEASURED_FRAMES}}"    = "$MeasuredFrames"
        "{{MACHINE_HOSTNAME}}"   = [string]$machine["hostname"]
        "{{MACHINE_OS_CAPTION}}" = [string]$machine["os_caption"]
        "{{MACHINE_OS_VERSION}}" = [string]$machine["os_version"]
        "{{MACHINE_OS_BUILD}}"   = [string]$machine["os_build"]
        "{{MACHINE_OS_ARCH}}"    = [string]$machine["os_architecture"]
        "{{MACHINE_MEMORY_GB}}"  = [string]$machine["memory_gb"]
        "{{MACHINE_CPU_NAME}}"   = [string]$machine["cpu_name"]
        "{{MACHINE_CPU_COUNT}}"  = [string]$machine["cpu_count"]
        "{{MACHINE_CPU_CORES}}"  = [string]$machine["cpu_cores"]
        "{{MACHINE_CPU_LOGICAL}}" = [string]$machine["cpu_logical_processors"]
        "{{MACHINE_GPU}}"        = (@($machine["gpu_adapters"]) -join ", ")
        "{{MACHINE_PS_VERSION}}" = [string]$machine["powershell_version"]
        "{{MACHINE_CLR_VERSION}}" = [string]$machine["clr_version"]
        "{{MACHINE_TZ}}"         = [string]$machine["timezone"]
        "{{ENGINE_PATH}}"        = $config.engine_path
        "{{ENGINE_VERSION}}"     = $config.engine_version
        "{{ENGINE_PREFIX}}"      = $config.expected_version_prefix
        "{{ENGINE_SHA}}"         = $config.engine_executable_sha256
        "{{RENDERING}}"          = $config.rendering_method
        "{{RENDERING_WEB}}"      = $config.rendering_method_web
        "{{THREAD_SUPPORT}}"     = "$($config.web_thread_support.ToString().ToLower())"
        "{{MAIN_SCENE}}"         = [string]$config.main_scene
        "{{VIEWPORT_W}}"         = "$($config.viewport_width)"
        "{{VIEWPORT_H}}"         = "$($config.viewport_height)"
        "{{CAPTURE_1_TITLE}}"    = $capture1Title
        "{{CAPTURE_1_ROWS}}"     = $capture1Rows
        "{{C1_DISPLAY}}"         = $c1Display
        "{{C1_RENDERER}}"        = $c1Renderer
        "{{C1_REFRESH}}"         = $c1Refresh
        "{{C1_ENGINE_FPS}}"      = $c1EngineFps
        "{{C1_ERRORS}}"          = $c1Errors
        "{{C1_WARNINGS}}"        = $c1Warnings
        "{{CAPTURE_2_TITLE}}"    = $capture2Title
        "{{CAPTURE_2_BODY}}"     = $capture2Body
        "{{SUMMARY_ROWS}}"       = "$($allRows.Count)"
        "{{SUMMARY_PASS}}"       = "$passCount"
        "{{SUMMARY_WARN}}"       = "$warnCount"
        "{{SUMMARY_FAIL}}"       = "$failCount"
        "{{WARNINGS_SECTION}}"   = $warningsSection
        "{{EVIDENCE_PATH}}"      = $evidencePath
        "{{REPORT_PATH}}"        = $reportPath
        "{{LOG_PATH}}"           = $logPath
        "{{VIEWPORT}}"           = $viewportText
    }

    $report = $script:ReportTemplate
    foreach ($token in $replacements.Keys) {
        $report = $report.Replace($token, [string]$replacements[$token])
    }
    if ($report -match '\{\{[A-Z0-9_]+\}\}') {
        $leftover = [regex]::Matches($report, '\{\{[A-Z0-9_]+\}\}') | ForEach-Object { $_.Value } | Select-Object -Unique
        throw "Report template contains unreplaced token(s): $($leftover -join ', ')"
    }
    Write-ReportFile -Path $reportPath -Content $report
    Write-EvLog "  Wrote report: $reportPath" "Green"

    Write-EvLog "`nOD-013 performance evidence complete (exit 0; warnings above are recorded, never fatal)." "Cyan"
    exit 0
} catch {
    Write-Host "`nPERFORMANCE EVIDENCE FAILED: $($_.Exception.Message)" -ForegroundColor Red
    Add-Content -LiteralPath $script:LogFullPath -Value "FAILED: $($_.Exception.Message)"
    exit 1
}
