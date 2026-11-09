# Automated Headless Testing Guide — Soulbound

## Overview

Soulbound uses Godot 4.7.2 Stable headless CLI execution to run automated GDScript test suites without opening an engine GUI window. All automated tests are housed in `tests/headless/` as standalone `SceneTree` scripts.

## Canonical Test Runner

The project provides an automated, canonical test runner:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1
```

### Options

1. **Run a single test suite**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite release_tier_test
   ```
2. **Run tests and chain release export**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Export
   ```
3. **Skip engine import scan**:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -SkipImport
   ```

## Why the Console Executable is Required

On Windows, the default Godot executable (`godot.exe`) is compiled targeting the Windows GUI subsystem (`/SUBSYSTEM:WINDOWS`). When launched from PowerShell or Command Prompt:
1. Windows detaches the console immediately unless redirected.
2. Direct pipe redirection (`| Out-Null` or standard piping) frequently results in truncated log streams or a blank exit code (`$LASTEXITCODE = $null` or `0`).
3. To eliminate the blank-exit-code trap, `run_headless_tests.ps1` standardizes on:
   - The official console binary: `Godot_v4.7.2-stable_win64_console.exe`
   - Explicit process management via `Start-Process -NoNewWindow -Wait -PassThru -RedirectStandardOutput <log> -RedirectStandardError <err>`
   - Full stdout and stderr capture into `report/<suite_name>.log` and `report/<suite_name>.err`.

## Suite Count and Inventory

At current development baseline (Batch 2), there are **25 headless test suites**:

| Suite Name | Scope & Verification Invariants |
|---|---|
| `smoke_test.gd` | M1 engine bootstrap, version check, 960x540 viewport, GL Compatibility renderer |
| `transition_test.gd` | W2 overworld displacement, physics frames, atomic portal signals, spawn rollbacks |
| `combat_test.gd` | W3 simple combat, intent cycle, guarded pips, victory/loss, portal racing |
| `save_model_test.gd` | W3 ProfileStore, 3 slots, atomic saves, corrupt fallback, strict JSON schema 1.0 |
| `vertical_slice_test.gd` | M2 quest progression, assessment completion gating, save round-trips |
| `vertical_slice_loop_test.gd` | Full vertical slice loop: NPC -> practice -> combat -> turn-in -> ProfileStore |
| `m3_systems_test.gd` | Character leveling, inventory defeat wipe vs. bank preservation, Kurei 6-spell pips, BFS dungeon reachability |
| `dimension_test.gd` | Physical/spirit plane shifting, player collision mask sync, zero-embed safety |
| `kurei_combat_test.gd` | In-battle Kurei spell menu, SP pip consumption, cooldown tracking |
| `dungeon_scene_test.gd` | Procedural room layout, at-risk satchel, commit-first suspend/resume, session callback guarding, exact-once extraction |
| `overworld_gateway_test.gd` | Overworld dungeon shrine entrance, town bank transfers, defeat wipes |
| `education_report_test.gd` | Question bank, immutable first-attempt tracking, RFC-4180 CSV export |
| `ui_sheets_test.gd` | Character sheet, inventory sheet, hotkey toggles (`C` / `I`), gear equip |
| `chapter_progression_test.gd` | 3-chapter lifecycle, completion gating, bramble dissolve, academic portal |
| `settings_accessibility_test.gd` | Audio sliders, text scale (0.8–1.5x), high contrast overrides, keyboard navigation, SBL-REV-002 title settings overlay Escape & focus restoration |
| `e2e_academic_playthrough_test.gd` | Complete student journey: Ch I -> Ch II -> Ch III -> Academic Modal -> CSV |
| `educator_analytics_test.gd` | 12-student cohort batch simulation across archetypes, CSV generation |
| `web_backup_test.gd` | Web profile JSON backup export/import, invalid JSON rejection, clipboard bridge, suspended run roundtrip, SBL-REV-002 title-selected slot context isolation |
| `status_engine_test.gd` | DoT/HoT status ticks, shield absorption, stun/silence action blocking, serialization |
| `evaluator_debug_bar_test.gd` | F1 debug tools, warps, instant cheats, terminal modal input exclusivity |
| `title_screen_audio_test.gd` | Procedural AudioStreamWAV synthesis, 9 sound cues, title screen slot selection, SBL-REV-002 Title Settings and Backup layer 9 overlay |
| `ending_chapter5_test.gd` | Chapter V Void Citadel warp, dual-ending altars (A & B), capstone question |
| `boss_combat_test.gd` | Void Sovereign multi-phase combat, Astral Shield, Cataclysm 2-turn telegraph |
| `kurei_tree_test.gd` | 4-branch 2-tier skill tree, talent points, tier prerequisites, respec refund |
| `release_tier_test.gd` | SBL-FIX-010 3-chapter academic MVP vs. full release tier separation |
| `save_compatibility_recovery_test.gd` | SBL-FIX-012/SBL-REV-001 Legacy profile compatibility, revision recovery, snapshot non-clamping validation |
| `profile_activation_test.gd` | SBL-REV-003 Empty-slot new journey picker, non-launching profile selection, safe profile activation and world/dimension reset |

## Verification & Exit Codes

- The script exits `0` if and only if Godot `--import` succeeds and every enumerated suite passes.
- If any suite exits non-zero, the runner prints a failure summary and terminates with exit code `1`.
