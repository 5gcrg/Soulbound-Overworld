# OD-013 Performance Evidence Report - Soulbound

**Decision:** OD-013 - Platform and Performance Evidence, owner-ratified in
[`report/od013-ratification.md`](od013-ratification.md) (10 November 2026).
**Generated (UTC):** 2026-11-10T13:45:15.3001430Z
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
| Target 60 FPS with documented 30 FPS fallback | Section 5 gate semantics; evidence `target_fps=60`, `fallback_fps=30` |
| Measured scenes: title, overworld, combat, dungeon, learning journal | Section 4 (all five scenes captured per mode) |
| Automated capture **plus** manual profiling evidence | Sections 3-4 automated Godot-native capture; Section 6 manual profiling pending human execution |
| No maximum build-size budget | Section 5 - `build_size_budget = null`; pre-existing plausibility bounds in `validate_release.ps1` are unchanged and are not an OD-013 budget |
| Below-target -> warn and record, never auto-fail release | Section 5 - every below-target row is `WARN` and the script exits `0` |
| Godot 4.7.2 Compatibility, single-threaded Web retained | Section 3 - asserted in preflight; a violation fails the run |
| Performance evidence included in the canonical release gate with warning semantics | Section 7 |

## 2. Reference machine (captured 2026-11-10T13:44:47.8436738Z)

| Field | Value |
|---|---|
| Hostname | ALCOHOL |
| Operating system | Microsoft Windows 11 Pro |
| OS version / build | 10.0.26300 / 26300 |
| OS architecture | 64-bit |
| Memory | 23.9 GB |
| CPU | AMD Ryzen 7 5700X 8-Core Processor (1 package(s), 8 cores / 16 logical) |
| GPU adapter(s) | AMD Radeon RX590 GME |
| PowerShell / CLR | 5.1.26100.9711 / 4.0.30319.42000 |
| Time zone | Singapore Standard Time |

## 3. Engine and configuration (preflight-verified)

| Field | Value |
|---|---|
| Godot executable | `C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe` |
| Godot version | **4.7.2.stable.official.ed1daf0bf** (required prefix `4.7.2.stable`; mismatch fails preflight) |
| Executable SHA-256 | `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643` |
| Project renderer | `gl_compatibility` (must be `gl_compatibility`) |
| Web renderer override | `gl_compatibility` (must be `gl_compatibility`) |
| Web export thread support | `false` (single-threaded Web invariant, GDD-107) |
| Main scene | `res://scenes/main/game_root.tscn` |
| Viewport | 960x540 |

Preflight **fails the run with a non-zero exit** when: the engine path is missing or
not a Godot executable, the reported version is not `4.7.2.stable`, either
renderer setting is not `gl_compatibility`, or the Web preset is not single-threaded.
Preflight never silently skips.

## 4. Automated Godot-native capture

**Method.** A Godot `SceneTree` harness is generated into the system temporary
directory (never into the repository) and run with the project's own Godot binary
under proven disposable user-data isolation. Per scene the harness builds a real
fixture (title screen with a disposable `ProfileStore`; `GameRoot` overworld with a
disposable profile root; `BattleFixture`; `DungeonExpedition` started with seed
1337/6 rooms; `LearningJournal` configured with an `AssessmentController`), lets it
settle for 60 warm-up frames, then records 300 frame
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

### 4.1 Headless native capture (no renderer)

Environment: display server `headless`, renderer `n/a (headless has no adapter)`,
refresh rate `-1.0` Hz, engine-reported FPS `130.0`,
engine errors `0` / warnings `5`.

| Scene | Scene path | Avg FPS | Min FPS | Avg frame (ms) | Min frame (ms) | Max frame (ms) | Frames | Status | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Title screen | `res://scenes/ui/title_screen.tscn` | 144.9 | 138 | 6.9 | 6.589 | 7.248 | 300 | **PASS** | - |
| Overworld | `res://scenes/main/game_root.tscn` | 128 | 60.1 | 7.813 | 0.029 | 16.645 | 300 | **PASS** | - |
| Combat | `res://scenes/combat/battle_fixture.tscn` | 128.4 | 60.1 | 7.789 | 0.033 | 16.627 | 300 | **PASS** | - |
| Dungeon | `res://scenes/dungeon/dungeon_expedition.tscn` | 128 | 58.9 | 7.81 | 0.033 | 16.983 | 300 | **PASS** | - |
| Learning journal | `res://scenes/ui/learning_journal.tscn` | 128.3 | 57.8 | 7.793 | 0.03 | 17.304 | 300 | **PASS** | - |

### 4.2 Windowed native rendered capture

Environment: display server `Windows`, renderer `AMD Radeon RX590 GME`, refresh rate `240.0` Hz,
engine-reported FPS `240.0`, engine errors `0` / warnings `5`.

| Scene | Scene path | Avg FPS | Min FPS | Avg frame (ms) | Min frame (ms) | Max frame (ms) | Frames | Status | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Title screen | `res://scenes/ui/title_screen.tscn` | 239.9 | 185.7 | 4.168 | 2.927 | 5.386 | 300 | **PASS** | - |
| Overworld | `res://scenes/main/game_root.tscn` | 240.1 | 185.4 | 4.166 | 2.913 | 5.394 | 300 | **PASS** | - |
| Combat | `res://scenes/combat/battle_fixture.tscn` | 240 | 187 | 4.168 | 3.281 | 5.348 | 300 | **PASS** | - |
| Dungeon | `res://scenes/dungeon/dungeon_expedition.tscn` | 240 | 200.9 | 4.167 | 3.297 | 4.977 | 300 | **PASS** | - |
| Learning journal | `res://scenes/ui/learning_journal.tscn` | 240 | 192.9 | 4.167 | 3.198 | 5.184 | 300 | **PASS** | - |

## 5. Gate semantics

| Rule | Behavior |
|---|---|
| Target | 60 FPS (`avg_fps >= target` -> `PASS`) |
| Documented fallback | 30 FPS (a `min_fps` below it -> `WARN`) |
| Below-target result | Recorded as `WARN` in the evidence JSON and this report; **exit code stays 0** - release is never auto-failed |
| Preflight / capture failure | Missing or invalid engine, wrong Godot version, incompatible renderer or thread configuration, or an incomplete capture -> **non-zero exit** |
| Maximum build-size budget | **None.** `build_size_budget = null`; no size limit was introduced by OD-013 |
| Existing gates | Export, archive/PCK, manifest, save, and restoration gates are unchanged |

Summary for this run: 10 scene row(s) evaluated -
**10 PASS**, **0 WARN**, **0 FAIL** (FAIL count is structurally 0: below-target never fails).

_No warnings: every measured scene met the 60 FPS target and the 30 FPS fallback._

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
| Machine-readable evidence (this run) | `C:\Users\ALCOHOL\.codex\worktrees\soulbound-overworld\SoulBound\report\od013_performance_evidence.json` |
| This report | `C:\Users\ALCOHOL\.codex\worktrees\soulbound-overworld\SoulBound\report\od013_performance_report.md` |
| Raw execution log (transient) | `C:\Users\ALCOHOL\.codex\worktrees\soulbound-overworld\SoulBound\report\od013_performance_evidence.log` |
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