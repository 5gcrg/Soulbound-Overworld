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

At current development baseline (SBL-EDU-005 learning journal & reporting engine, hardened by SBL-EDU-005-FIX), there are **32 headless test suites**:

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
| `kurei_combat_test.gd` | In-battle Kurei spell menu, SP pip consumption, cooldown tracking, SBL-REV-005 Phase Mastery 4 SP capacity, SBL-REV-006 dynamic 6-slot menu generation, rejection of unequipped skills, casting of equipped skills, cancel and Escape dismissal, SBL-REV-008 empty loadout starter normalization regression test |
| `dungeon_scene_test.gd` | Procedural room layout, at-risk satchel, commit-first suspend/resume, session callback guarding, exact-once extraction, and OD-009 MVP save boundary (mid-battle/partial-turn/pending-encounter/boss/expedition save requests rejected before any profile mutation with byte-identical profile evidence, room/exploration boundary save round-trip, suspend ≠ extraction) |
| `overworld_gateway_test.gd` | Overworld dungeon shrine entrance, town bank transfers, defeat wipes |
| `education_report_test.gd` | Question bank, immutable first-attempt tracking, RFC-4180 CSV export |
| `ui_sheets_test.gd` | Character sheet, inventory sheet, hotkey toggles (`C` / `I`), gear equip |
| `chapter_progression_test.gd` | 3-chapter lifecycle, completion gating, bramble dissolve, academic portal |
| `settings_accessibility_test.gd` | Audio sliders, text scale (0.8–1.5x), high contrast overrides, keyboard navigation, SBL-REV-002 title settings overlay Escape & focus restoration, SBL-REV-004 SFX bus routing, mute flags, SBL-UX-001 Escape capture cancellation vs modal dismiss |
| `input_rebinding_test.gd` | SBL-UX-001 Persistent keyboard/mouse rebinding, authored snapshot, apply/reset idempotence, physical key release & replaced key disabling, mouse menu binding outside capture, transactional save/reload across profile switches, atomic validation & disk byte preservation on failure, legacy and future schema version safety, rebind capture event consumption & zero state leakage, atomic conflicting reset rejection & state preservation (Fix 1), malformed entry type validation without script error (Fix 2), real user settings file isolation & byte identity guarantee (Fix 3) |
| `e2e_academic_playthrough_test.gd` | Complete student journey: Ch I -> Ch II -> Ch III -> Academic Modal -> CSV |
| `educator_analytics_test.gd` | 12-student cohort batch simulation across archetypes, CSV generation |
| `web_backup_test.gd` | Web profile JSON backup export/import, invalid JSON rejection, clipboard bridge, suspended run roundtrip, SBL-REV-002 title-selected slot context isolation |
| `status_engine_test.gd` | DoT/HoT status ticks, shield absorption, stun/silence action blocking, serialization |
| `evaluator_debug_bar_test.gd` | F1 debug tools, warps, instant cheats, terminal modal input exclusivity |
| `title_screen_audio_test.gd` | Procedural AudioStreamWAV synthesis, 9 sound cues, title screen slot selection, SBL-REV-002 Title Settings and Backup layer 9 overlay, SBL-REV-004 idempotent bus creation, routing to Master, player SFX assignment |
| `ending_chapter5_test.gd` | Chapter V Void Citadel warp, dual-ending altars (A & B), capstone question |
| `boss_combat_test.gd` | Void Sovereign multi-phase combat, Astral Shield, Cataclysm 2-turn telegraph, SBL-REV-005 Phase Mastery 4 SP capacity, SBL-REV-006 dynamic spell menu, starter functionality, OD-003/004 advanced skill disabled state with notice, and zero mutation on unsupported skills, SBL-REV-007 4-column GridContainer viewport safety, starter/Cancel keyboard reachability, and SBL-REV-008 empty loadout starter normalization regression test |
| `kurei_tree_test.gd` | 4-branch 2-tier skill tree, talent points, tier prerequisites, respec refund, SBL-REV-005 Phase Mastery unlock, SBL-REV-006 6-slot equip lifecycle, minimum 1 skill invariant, auto-equip to 6, 7th unequipped, SBL-REV-008 atomic deserialize failure preservation, explicit empty loadout rejection, legacy starter defaulting, and starter normalization |
| `learning_journal_test.gd` | SBL-EDU-005 Learning journal & educational reporting engine (SBL-EDU-005-FIX hardened): immutable first-attempt correctness across wrong-first/correct-retry cycles, legacy records lacking first_response displaying 'Not recorded' without data inference, transient rows sorted by question ID, RFC-4180 CSV export with transport formula neutralization (=, +, -, @, \t, \r), standalone UTF-8 printable HTML report with print CSS, zero scripts, zero external resources, zero remote requests, zero inline handlers, zero auto-print, entity-escaped dynamic values, mandatory OD-012 notice, 'Last recorded activity' timestamp labeling, Exploration HUD button-only opening on SheetLayer (zero keyboard action), player movement freeze & restore, menu hotkeys & Escape consumption, modal exclusivity & stacking prevention, cross-profile isolation (Profile A -> B -> A), successful backup import refresh & failed import old-record preservation, desktop allowlisted exports redirected to the disposable `_test_root`, injectable web download buffer preparation with exact UTF-8 bytes and MIME without claiming browser execution, 4 disposable negative controls (mutating first-attempt data, omitting HTML escaping, stale controller after profile switch, claiming browser delivery), disposable `ProfileStore` root injected into the GameRoot fixture so no fixture answer reaches the real `user://profiles`, a recursive pre/post byte-identity invariant proving the real `user://profiles` and `user://reports` are untouched by the suite, and Part 9 regression coverage asserting the Academic Completion Modal attributes desktop and Web HTML reports to the active `profile_02` (no `profile_01` fallback) with GameRoot passing its active slot through `configure()` |
| `layout_audit_test.gd` | SBL-FIX-011 / SBL-REV-007 / SBL-REV-009 / SBL-EDU-005 960x540 viewport boundary & overflow audit across SettingsSheet, InventorySheet, CharacterSheet, ChapterActivityDialog, AcademicCompletionModal, EndingModal, BossEncounter, and LearningJournal at 1.0x and 1.5x accessibility text scale (SBL-REV-009 SceneTree attachment lifecycle order fix) |
| `build_tier_test.gd` | SBL-FIX-010 project.godot build tier configuration and scene exclusion validation |
| `release_tier_test.gd` | SBL-FIX-010 3-chapter academic MVP vs. full release tier separation |
| `save_compatibility_recovery_test.gd` | SBL-FIX-012/SBL-REV-001 Legacy profile compatibility, revision recovery, snapshot non-clamping validation |
| `profile_activation_test.gd` | SBL-REV-003 / SBL-REV-003-FIX Empty-slot new journey picker, non-launching profile selection, safe profile activation, defense demo title-selected activation & failure safety, world/dimension reset |
| `verify_exported_tier.gd` | Automated PCK content and entry point verification across release packages |

## Verification & Exit Codes

- The script exits `0` if and only if Godot `--import` succeeds and every enumerated suite passes.
- If any suite exits non-zero, the runner prints a failure summary and terminates with exit code `1`.

## Release Manifest Tests (SBL-BLD-005)

The canonical runner chains the release-manifest suite after a successful `-Export`, and it can
be run standalone:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_release_manifest.ps1
```

- The suite exits `0` only when **all 62 controls** behave as specified; any unexpected result
  exits `1`. Controls cover valid synthetic fixtures, the three real packages plus their
  archive-contained PCK gates, missing/malformed/future manifests and receipts, metadata/payload
  tampering, duplicate/case-colliding/traversal/unsupported entry paths and types, swapped
  manifests, configuration tampering, clean/dirty/pre-mutation Git capture, stale output,
  `-SkipZip`, engine failures (explicit-invalid and missing-default, with no silent fallback),
  the existing restoration controls, and real-user-data byte identity.
- It uses the **same verifier functions** as production validation
  (`scripts/build/release_manifest.ps1`), and every tampered archive is a disposable copy under a
  fresh temporary directory that is removed on exit.
- Full control list, artifact hashes/sizes, and command/exit evidence:
  [`report/sbl_bld_005_release_manifest_report.md`](../report/sbl_bld_005_release_manifest_report.md).
  Raw log: `report/release_manifest_test.log`.

## Disposable User-Data Isolation for Godot Runs

Every Godot test and PCK gate runs with `APPDATA`/`LOCALAPPDATA` redirected to a fresh temporary
root, and the redirection is **proved before execution** by a headless probe that prints
`OS.get_user_data_dir()` under that root:

- `run_headless_tests.ps1` (import + all suites), `validate_release.ps1` (PCK gates), and
  `test_release_manifest.ps1` (its gates) each enter isolation, then compare SHA-256 digests of
  the real roaming/local Godot directories before and after the run; a change fails the run.
- The runner additionally **seeds** its disposable from a copy-on-enter snapshot of the real
  `%APPDATA%\Godot` (robocopy, verified by file count) so suites keep the historical baseline
  state they depend on (e.g. pre-existing `profile_01`) and chained exporters can resolve
  `%APPDATA%\Godot\export_templates`; every write still lands in the disposable copy, which is
  removed at exit through a containment-checked, long-path-safe cleanup.
- Exporter subprocesses spawned by the manifest suite are restored to the pre-isolation
  environment solely because Godot resolves export templates from `%APPDATA%\Godot`; an
  empirical before/after digest proves an export leaves the real directory byte-identical.
- Evidence is appended to `report/godot_user_data_isolation.log` (probe path,
  `realUserDataUnchanged`, disposable file count, root removal).
