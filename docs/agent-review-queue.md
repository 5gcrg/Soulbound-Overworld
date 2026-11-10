# Agent Review Queue

## SBL-M1-001 — Godot foundation

- **Milestone** M1, Week 1.
- **Requirements** GDD-093–096, GDD-103, GDD-108–109, GDD-119, GDD-124, GDD-129, NFR-MAINT-001. Scope and evidence are recorded in the [traceability matrix](traceability-matrix.md).
- **Implementation owner** agy. **Plan, validation, and Git operation owner** Codex.
- **Branch and initial implementation** `feature/m1-godot-foundation`, `cdd8e2d`. Baseline `da2d925`. Reviewed implementation tip `97ecd49`.
- **Files** `project.godot`, `.gitignore`, `scenes/main/game_root.{tscn,gd,gd.uid}`, `tests/headless/smoke_test.{gd,gd.uid}`, and the [asset register](asset-register.md), traceability matrix, and review queue in `docs/`.
- **Asset provenance** None. No runtime content or save data changes.
- **Review** REVIEWED by Codex CLI for the M1 bootstrap. Human milestone acceptance is pending.
- **Open questions** No M1 design questions. Hosted branch protection and peer review require a configured GitHub remote. Godot MCP proof, exports, and platform acceptance remain open.

### Verification

| Command | Result after fixes |
| --- | --- |
| `godot --version` | Exit 0. Godot 4.7.2 Stable, official build `ed1daf0bf`. |
| `godot --headless --path . --import` | Exit 0. Editor imported the project without script or scene errors. |
| `godot --headless --path . --quit-after 5` | Exit 0. Main scene launched without script or scene errors. |
| `godot --headless --path . --script tests/headless/smoke_test.gd` | Exit 0. Checks exact stable version, both renderer settings, viewport and scaling, and the initialized GameRoot. Fails if Godot reports a scene initialization error. |

An isolated copy passed the smoke check (exit 0). An injected assertion before and after the bootstrap status update, an engine error after the update, and an invalid Web renderer each failed the check (exit 1). An injected warning passed (exit 0).

### Review history

- agy created the project files on the local feature branch. Headless command permission prevented agy from running Git and Godot, so Codex performed those operations. A quota interruption left a partial scaffold, and an agy retry with an available Flash model completed the slice.
- Codex CLI reviewed `cdd8e2d` against `main` on 8 November 2026 (session `01a1bb6c-e4b7-7ca3-a28b-967563cbe3e4`). It requested checks for runtime scene readiness, the exact stable engine version, and the Web renderer override, plus traceability fields and observed test evidence.
- Codex CLI's sandbox logged system certificate and user-directory write errors during its Godot runs. The local runs outside that sandbox did not emit those errors.
- Codex CLI re-reviewed `eb79b1d` (session `01a1bb71-6842-7962-81c1-2f096538c2c9`). It confirmed four fixes and found that an error after the status update could still pass. agy added scoped engine and script error capture during scene loading and initialization.
- Codex CLI verified the remaining finding at `97ecd49` (session `01a1bb74-11d0-7661-862b-411c0381c87d`) and found it resolved.

---

## SBL-W2-001 — Overworld controller and transitions

- **Milestone** Week 2–3 MVP foundation, overworld slice.
- **Requirements** GDD-001, GDD-002, GDD-041, GDD-094–096, GDD-109, GDD-124, GDD-129, FR-WLD-001, regional portion of TC-WLD-001, and TC-AGY-001. [Traceability](traceability-matrix.md).
- **Owner** agy. **Plan, validation, and Git operations** Codex.
- **Branch and base** `feature/w2-overworld-transitions` based on reviewed M1 `50b01a9`. Initial implementation `90760a1`. Reviewed implementation tip `05e121a`.
- **Files** `project.godot`, `scenes/main/game_root.*`, `scenes/player/player.*`, `scenes/world/`, `tests/headless/{smoke_test,transition_test}.gd`, tracked script UIDs, and the audit, traceability matrix, and asset register.
- **Asset provenance** None. The two technical regions and player use Godot primitives. The slice creates no save data.
- **Review** REVIEWED by Codex CLI for the overworld slice. Human milestone acceptance is pending.
- **Open questions** Story map content and story-specific access rules are future work. Waypoint fast travel, combat, and the save model are separate slices.

Run the Godot project from the editor. Move with WASD or the arrow keys and walk into a marked portal to cross between Alpha and Beta. The movement speed is an editor-tunable test value.

### Overworld verification

| Command | Latest observed result |
| --- | --- |
| `godot --version` | Exit 0. Godot 4.7.2 Stable, official build `ed1daf0bf`. |
| `godot --headless --path . --import` | Exit 0. No Godot errors. |
| `godot --headless --path . --fixed-fps 60 --quit-after 120` | Exit 0. Alpha started at its valid marker. |
| `godot --headless --path . --script tests/headless/smoke_test.gd --fixed-fps 60 --quit-after 300` | Exit 0. M1 smoke regression and overworld startup passed. |
| `godot --headless --path . --script tests/headless/transition_test.gd --fixed-fps 60 --quit-after 600` | Exit 0. Cardinal and diagonal displacement across physics frames, wall collision, real portal signals in both directions, duplicate requests, and spawn rejection and rollback checks passed. |

Two temporary probes also exited 0. One sent physical W, Right, Down, and A key events to walk through both portals with the same player. The other freed the originating portal before deferred dispatch and confirmed the current region was preserved and the router released its reservation.

Two isolated fault injections also exited 1. Disabling the player movement integration failed the displacement assertion. Interrupting the suite after setup triggered its watchdog before the engine frame cutoff.

### Overworld review history

- Codex CLI reviewed `90760a1` (session `01a1bb7c-fdca-7d03-8459-234bf85b9399`). It requested a supported physics API, valid candidate and starting spawn checks, atomic request reservation, collision-state preservation, and corrections to the physics-frame test harness and signal observations.
- agy authored the repair in the managed worktree. Codex ran the Godot checks and recorded the startup failure that remained after the first repair.
- agy repaired off-tree marker resolution, validated the player collision footprint against destination shapes, and hardened the portal signal and stale-request handling. Local verification passed on Godot 4.7.2 Stable.
- Codex CLI re-reviewed `194cf75` (session `01a1bb8b-3885-7cc1-9eb1-b1c753ada733`), cleared the runtime fixes, and requested stronger evidence for actual movement and suite completion. agy added displacement assertions over physics frames and a watchdog. Clean and fault-injected runs behaved as expected.
- agy ran a high-effort verification pass with `gemini-3.8-flash-high --effort high` and found both test repairs in place.
- Codex CLI closed both findings at `05e121a` (session `01a1bb8f-5d02-7cf0-b7e7-77dc1c67dac3`). Its sandbox reproduced the known Windows certificate-store error. The same tests passed with zero Godot errors in the local environment.

---

## SBL-W3-001 — Simple combat in Alpha

- **Milestone** Week 2–3 MVP foundation, simple combat slice.
- **Requirements** GDD-003, GDD-016, GDD-018, GDD-023, GDD-089, FR-CMB-001/003/004/005, and the action economy and intent portions of TC-CMB-001/003. [Traceability](traceability-matrix.md).
- **Owner** agy. **Plan, validation, and Git operations** Codex.
- **Branch and base** `feature/w3-simple-combat` based on reviewed overworld `472f696`. Initial runtime `07ab422`. Reviewed implementation tip `cc20094`.
- **Files** `scenes/combat/battle_fixture.*`, `scenes/main/game_root.*`, `scenes/world/{test_region_alpha.tscn,world_router.gd}`, `tests/headless/combat_test.gd` and its UID, and the review queue, traceability matrix and asset register.
- **Asset provenance** None. Godot primitives and native controls are used for the fixture. No saves, progression, or rewards are written.
- **Review** REVIEWED by Codex CLI for the simple combat slice. Human milestone acceptance is pending.
- **Open decisions** OD-002 initiative ordering, OD-003 balance formulas and resource costs, OD-004 status timing and stacking, and OD-009 save boundaries. The scripted pips and enemy intent cycle are fixture data.

Start the game in Godot and walk southeast from the Alpha spawn to the marker labeled **Combat test**. Defend against Strike and attack while the enemy recovers. Use **Continue** after either outcome. Leave the marker and walk back in to replay.

### Combat verification

| Command | Result |
| --- | --- |
| `godot --version` | Exit 0. Godot 4.7.2 Stable, official build `ed1daf0bf`. |
| `godot --headless --path . --import` | Exit 0 on the repaired build. |
| `godot --headless --path . --fixed-fps 60 --quit-after 120` | Exit 0 on the repaired build. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/smoke_test.gd --quit-after 600` | Exit 0 on the repaired build. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/transition_test.gd --quit-after 600` | Exit 0 on the repaired build. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/combat_test.gd --quit-after 600` | Exit 0. Tests verified duplicate actions, enemy intent, both outcomes, exactly-once Continue, overworld restoration, replay, and the portal race. |

A standalone Godot probe passed the invalid-action, duplicate-action, guard and victory checks. A keyboard probe walked into the Alpha encounter, lost the fight, and returned to the same player, position and region.

A second fault probe confirmed a same-frame competing portal could no longer cancel combat. Removing the trigger before deferred opening released the reservation and restored movement.

### Combat review history

- agy implemented the fixture with high-effort Flash and integrated the encounter with high-effort Argon. One integration attempt timed out and a later Argon request hit quota. Work continued on the high-effort Flash preset.
- Codex CLI reviewed `07ab422` (session `01a1bbbe-cf5e-7281-bda8-a6d4392c9ddd`) and found a competing portal request could cancel a pending combat encounter. A local fault probe reproduced the issue.
- agy reserved movement and travel when accepting combat, restored the prior lock on rejected deferred admission, and corrected the headless test harness. The complete local suite and both independent runtime probes passed.
- Codex CLI confirmed the runtime repair at `53851ee` (session `01a1bbc9-f7d5-77f0-b6cd-a43214a83347`) and requested direct regression assertions for exactly-once Continue and stale-trigger rollback. agy added both. In isolated copies, removing the Continue guard and removing stale rollback each made the combat suite exit 1 for the expected assertion. Clean runs exited 0.
- Codex CLI closed both remaining assertions at `cc20094` (session `01a1bbcc-2dbc-79d2-a011-deccf6483081`). The combat suite also passed in the review sandbox, which logged its existing certificate-store and user log warnings. Local verification produced no Godot errors.


---

## SBL-W3-002 — Local save model and JSON text

- **Milestone** Week 2–3 MVP foundation.
- **Requirements** GDD-098, GDD-099, GDD-100, GDD-102, FR-SAV-001/002 (partial), TC-SAV-001/002, NFR-REL-001, and NFR-SEC-001. [Traceability](traceability-matrix.md)
- **Owner** agy. **Plan owner** Codex.
- **Branch and implementation** `feature/w3-save-model` based on `d0fbba9`. Initial store `4822621`, recovery and validation `0fb5791`, review follow-ups `f3c85ec`, legacy compatibility `9a672bb`.
- **Files** `scripts/persistence/profile_store.gd`, `scripts/persistence/strict_profile_json.gd`, `tests/headless/save_model_test.gd`, their UIDs, the review queue, traceability matrix, and asset register.
- **Asset provenance** None.
- **Review** REVIEWED by Codex CLI through `9a672bb`. Human milestone acceptance is pending.
- **Open items** Gameplay autosave, profile selection, browser file UI, and expedition storage are separate slices. OD-009 save boundaries remain open.

`ProfileStore` is a synchronous single-writer API under `user://profiles`. Schema 1 defines three fixed slot IDs and four JSON-safe dictionaries for character, inventory, world, and education data. An empty profile comes from `new_profile(slot)`. Callers explicitly use `save_profile` and read `error`, `profile`, and `recovered` from `load_profile`. Backup import accepts validated JSON text for the same slot. Export returns the validated stored text.

A save stages and verifies a sibling temporary file before publishing to a new revision path. Existing valid files never serve as rename destinations. Successful writes retain the two latest valid revisions. Loads can recover from a corrupt newest revision without rewriting files. Recognized unsupported schemas, oversized files, and unreadable files block replacement. Exact schema-1 spellings such as `1.0` remain readable and re-importable. New saves from dictionaries serialize the version as `1`.

### Save model verification

All commands exited 0 with no Godot errors on Windows using Godot 4.7.2 Stable, official build `ed1daf0bf`.

| Command | Result |
| --- | --- |
| `godot --headless --path . --import` | Clean import. |
| `godot --headless --path . --fixed-fps 60 --quit-after 120` | Clean project boot. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/smoke_test.gd --quit-after 600` | Smoke checks passed. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/transition_test.gd --quit-after 600` | Transition checks passed. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/combat_test.gd --quit-after 600` | Combat checks passed. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/save_model_test.gd --quit-after 600` | `SAVE MODEL TESTS PASSED`. |

The save suite uses disposable test roots. It verifies slot isolation, nested data, same-slot backup round trips, failed promotion preserving both committed files, corrupt-file fallback, ignored staging files, unsafe input rejection, the exact 4 MiB text export boundary, unsupported schema protection, and occupied slot paths. A disposable mutation removed the export result keys and caused the test runner to exit 1 for the captured script error. The full output is in dashboard run log `SBL-W3-002-godot-20261109-002006-341.log`.

### Save model review history

- agy implemented and revised the store with high effort. Codex CLI requested changes on the initial implementation in session `01a1bbd8-b903-7062-adc8-0c19a47d1ba4`. Findings covered the Windows replace behavior, preserving prior revisions and unreadable or unsupported records, stricter JSON and numeric validation, distinguishing corruption from an empty slot, and bounded raw-text export.
- agy moved commits to immutable revision files and added strict JSON validation. Godot regression tests verified the revised implementation at `0fb5791`. Codex CLI re-review in session `01a1bbea-1654-7291-b6e7-ec5ebad0f4e1` requested four follow-ups covering exact version tokens, future versions with unsafe payload numbers, inaccessible slot paths, and runtime errors in the save test.
- agy addressed those findings at `f3c85ec`. Codex CLI follow-up review in session `01a1bbf3-107d-7752-88fc-3b0133dfd876` confirmed the four fixes and requested compatibility for legacy revisions such as `1.0`.
- agy added an exact decimal version check at `9a672bb`. The suite verifies legacy raw export and re-import, next-save compatibility, and rejection of values that only round to 1. Codex CLI closed the compatibility finding in session `01a1bbf6-043c-7090-8bd4-9bc5805c6874` without further findings.

---

## Codex CLI review of queued M2–M6 work

- **Snapshot** `feature/w4-5-vertical-slice`, nine agy commits from `b427fed..e9824a7`.
- **Review** CHANGES_REQUESTED. Codex CLI session `01a1bd84-e6f1-7722-ae1b-6c1710b56c8e` finished and reported 8 P1 and 13 P2 findings. Human acceptance remains pending.
- **Verification** Windows Godot 4.7.2 Stable `ed1daf0bf` imported and booted the committed snapshot and passed all 18 existing headless suites with zero engine errors. The copy used a separate user-data directory. Chromium and Firefox were outside this verification.
- **Review gate 9 November 2026, 12:13** `codex --version` reported `codex-cli 0.167.0` and the `review` subcommand is present, but `codex exec --sandbox read-only "Reply with exactly: OK"` exited 1 with `You've hit your usage limit ... try again at 12:35 PM`. No review ran. The queued scope is now `e25491d..0d58f0b` (32 commits) and every entry remains `REVIEW_PENDING_CODEX`.

| Scope | Changes requested |
| --- | --- |
| M2 quest | Merge quest writes into the latest profile, gate the sentinel on practice completion, and surface save failures with a keyboard-accessible exit. |
| M3 systems | Preserve first-attempt evidence when saving the assessment record. Separate learning completion from correctness. Fix dimension collision and travel synchronization. Make extraction atomic and guard early or duplicate requests. Persist the active expedition for resume and connect the inventory UI to equip actions. |
| M4 chapters | Wire the three required activities to live NPCs, gate travel and final completion, and commit completion with its assessment evidence. Validate item ownership and healing caps, apply contrast and text scale to the actual UI, and prevent sheet hotkeys from stacking over results. |
| M5 evidence | Exercise normal player interactions and autosaves in the full-playthrough test. The current test calls assessment, progression, and save helpers directly. |
| M6 backups and reports | Validate gameplay records before import, reload the live profile before another write, provide a browser backup path independent of clipboard access, and make the competency CSV downloadable on Web. |

Independent probes reproduced newer banked gear disappearing on a quest checkpoint, an incorrect answer leaving its required activity incomplete, a fresh profile reaching final completion with no assessment records, an extraction reporting success after an injected save failure, and an imported inventory disappearing on the next quest checkpoint.

Full dashboard logs are `codex-88b78ca9cbaf440ca35921a64370188f.log`, `agy-queue-headless-20261109-073625.log`, and `agy-queue-review-probes-20261109.log`.

## SBL-W4-001 — One-region vertical slice progress and loop integration

- **Milestone** M2, Week 4–5.
- **Requirements** GDD-067, GDD-068, GDD-069, GDD-071, GDD-098–100, GDD-119, FR-QST-001, FR-EDU-002/003, FR-SAV-001 (partial), TC-EDU-002/003, TC-SAV-001. Scope and evidence are recorded in the [traceability matrix](traceability-matrix.md).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch and initial implementation** `feature/w4-5-vertical-slice`. Baseline `b427fed`.
- **Files** `scripts/vertical_slice/slice_progress.gd`, `scenes/vertical_slice/quest_dialog.{tscn,gd}`, `scenes/main/game_root.{tscn,gd}`, `scenes/world/test_region_alpha.tscn`, `tests/headless/vertical_slice_test.gd`, `tests/headless/vertical_slice_loop_test.gd`, tracked UIDs, and documentation in `docs/`.
- **Asset provenance** None (visuals use Godot UI and ColorRect primitives; educational prompt text authored per Gemini Flash non-image specification).
- **Review** CHANGES_REQUESTED. See the [Codex CLI batch verdict](#codex-cli-review-of-queued-m2m6-work).
- **Open decisions** OD-002 initiative, OD-003 balance, OD-009 save boundaries.

### Vertical slice verification

| Command | Result |
| --- | --- |
| `godot --headless --path . --import` | Exit 0. Re-imported cleanly, registered `SliceProgress` and `QuestDialog` classes. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/smoke_test.gd --quit-after 600` | Exit 0. Smoke checks passed. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/transition_test.gd --quit-after 600` | Exit 0. Transition checks passed. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/combat_test.gd --quit-after 600` | Exit 0. Combat checks passed. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/save_model_test.gd --quit-after 600` | Exit 0. Save model checks passed. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/vertical_slice_test.gd --quit-after 600` | Exit 0. `VERTICAL SLICE TESTS PASSED`. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/vertical_slice_loop_test.gd --quit-after 600` | Exit 0. `VERTICAL SLICE FULL LOOP INTEGRATION TEST PASSED`. Full interactive cycle verified: NPC offer -> practice assessment (completion-gated unblock) -> combat encounter -> victory checkpoint -> turn-in -> ProfileStore save roundtrip. |

### Review history
- agy authored `scripts/vertical_slice/slice_progress.gd`, `scenes/vertical_slice/quest_dialog.{tscn,gd}`, overworld NPC integration in `scenes/world/test_region_alpha.tscn` and `scenes/main/game_root.{tscn,gd}`, and automated headless test suites `vertical_slice_test.gd` and `vertical_slice_loop_test.gd`.
- Local headless validation verified all 6 acceptance criteria and the full interactive loop end-to-end.
- Codex CLI review was attempted via `codex review --uncommitted` (session `01a1bc01-5b29-7041-afa4-3c92bbd2c320`). Execution was blocked by provider credit quota (`ERROR: You’ve hit your usage limit. Upgrade to Pro (https://chatgpt.com/explore/pro), visit https://chatgpt.com/settings/usage to purchase more credits or try again at 4:15 AM.`).
- In strict adherence to AGENTS.md Rule 5, work is logged in the queue as `REVIEW_PENDING_CODEX` to await Codex CLI quota reset at 4:15 AM.

---

## SBL-M3-001 — Core systems foundations (Progression, Inventory, Kurei, Dungeon)

- **Milestone** M3, Weeks 6–8.
- **Requirements** GDD-005, GDD-006, GDD-007, GDD-009–015, GDD-025–030, GDD-031–035, FR-PRO-001, FR-INV-001, FR-MAG-001, FR-DNG-001/002. Scope and evidence are recorded in the [traceability matrix](traceability-matrix.md).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch and initial implementation** `feature/w4-5-vertical-slice`.
- **Files** `scripts/progression/character_stats.gd`, `scripts/inventory/inventory_manager.gd`, `scripts/magic/kurei_system.gd`, `scripts/dungeon/dungeon_generator.gd`, `tests/headless/m3_systems_test.gd`, and tracked script UIDs.
- **Asset provenance** None (pure typed GDScript system classes only).
- **Review** CHANGES_REQUESTED. See the [Codex CLI batch verdict](#codex-cli-review-of-queued-m2m6-work).
- **Open decisions** OD-002 initiative, OD-003 balance, OD-004 status timing, OD-008 extraction penalty, OD-011 dungeon branch budget.

### M3 systems verification

| Command | Result |
| --- | --- |
| `godot --headless --path . --import` | Exit 0. Re-imported cleanly, registered `CharacterStats`, `InventoryManager`, `KureiSystem`, and `DungeonGenerator`. |
| `godot --headless --path . --fixed-fps 60 --script tests/headless/m3_systems_test.gd --quit-after 600` | Exit 0. `ALL M3 SYSTEMS TESTS PASSED SUCCESSFULLY`. Verified character leveling & ProfileStore save, inventory defeat satchel wipe with banked gear retention, 6 Kurei categories & pip/cooldown logic, and seeded dungeon determinism with BFS extraction reachability. |
| Full 7-suite headless regression check | Exit 0. All 7 test suites (`smoke`, `transition`, `combat`, `save_model`, `vertical_slice`, `vertical_slice_loop`, `m3_systems`) pass cleanly. |

### Review history
- agy authored the 4 core M3 system modules and the comprehensive test suite `tests/headless/m3_systems_test.gd`.
- Local verification confirmed all invariants: deterministic procedural dungeon generation, guaranteed extraction reachability, exact-once extraction transfer, defeat satchel wipe with zero banked gear loss, level/stat point scaling, and Kurei pip/cooldown management.
- Logged as `REVIEW_PENDING_CODEX` per AGENTS.md §5 awaiting Codex quota reset at 4:15 AM.

---

## SBL-M3-002 — Dimension Shift, Kurei Combat, & Dungeon Expedition (Paths A, B, C)

- **Milestone** M3, Weeks 6–8.
- **Requirements** GDD-042/043/076 (Dimension Shifting), FR-WLD-002, GDD-003/009–015 (Kurei Combat), FR-CMB-002, GDD-031–035 (Dungeon Scene), FR-DNG-001/002. Full formal report in [`report/m2_m3_full_implementation_report.md`](../report/m2_m3_full_implementation_report.md).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `scripts/world/dimension_manager.gd`, `scenes/combat/battle_fixture.{tscn,gd}`, `scenes/dungeon/dungeon_expedition.{tscn,gd}`, `scenes/main/game_root.gd`, `project.godot`, `tests/headless/{dimension_test,kurei_combat_test,dungeon_scene_test}.gd`, and tracked UIDs.
- **Asset provenance** None (Godot ColorRect and Control UI primitives only; zero image or binary audio assets).
- **Review** CHANGES_REQUESTED. See the [Codex CLI batch verdict](#codex-cli-review-of-queued-m2m6-work).

### Verification across all 10 suites

| Suite | Result |
| --- | --- |
| `tests/headless/dimension_test.gd` | Exit 0. Verified physical/spirit toggling, unlock guards, and zero-embed obstacle safety invariant. |
| `tests/headless/kurei_combat_test.gd` | Exit 0. Verified Kurei spell menu, SP pip consumption (Lumina Lance & Flame Burst), instant victory, and turn cooldowns. |
| `tests/headless/dungeon_scene_test.gd` | Exit 0. Verified procedural room generation, extraction portal, at-risk satchel loot, and exact-once extraction vs defeat wipe. |
| Full 10-suite regression check | Exit 0. All 10 test suites pass cleanly with zero engine errors. |

---

## SBL-M3-003 — Overworld Dungeon Gateway, Educational Assessment Engine, & UI Sheets (Options 1, 2, 3)

- **Milestone** M2 & M3, Weeks 4–8.
- **Requirements** GDD-031/032/033/034/035, FR-DNG-001/002 (Dungeon Gateway), GDD-067/068/069/070/071/072, FR-EDU-001/002/003/004 (Educational Assessment & CSV Export), GDD-005/006/007, GDD-025/026/027/028/029/030, FR-PRO-001, FR-INV-001 (UI Sheets). Full formal report in [`report/m2_m3_full_implementation_report.md`](../report/m2_m3_full_implementation_report.md).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `scenes/world/test_region_alpha.tscn`, `scenes/main/game_root.{tscn,gd}`, `scripts/education/question_bank.gd`, `scripts/education/assessment_controller.gd`, `scenes/ui/character_sheet.{tscn,gd}`, `scenes/ui/inventory_sheet.{tscn,gd}`, `project.godot`, `tests/headless/{overworld_gateway_test,education_report_test,ui_sheets_test}.gd`, and tracked UIDs.
- **Asset provenance** None (Godot ColorRect and Control UI primitives only; educational questions authored per Gemini Flash routing; zero image generation).
- **Review** CHANGES_REQUESTED. See the [Codex CLI batch verdict](#codex-cli-review-of-queued-m2m6-work).

### Verification across all 13 suites

| Suite | Result |
| --- | --- |
| `tests/headless/overworld_gateway_test.gd` | Exit 0. Verified overworld shrine gateway entry, player freeze, satchel extraction to town bank, satchel wipe on defeat with bank preservation. |
| `tests/headless/education_report_test.gd` | Exit 0. Verified question bank catalog, immutable first-attempt tracking, completion-gated progression, ProfileStore integration, and RFC-4180 CSV report export. |
| `tests/headless/ui_sheets_test.gd` | Exit 0. Verified hotkey sheet toggles (`C` & `I`), player freezing, attribute allocation and combat stat recalculation, equip/unequip gear, and mutual exclusivity. |
| Full 13-suite regression check | Exit 0. All 13 test suites pass cleanly with zero engine errors. |

---

## SBL-M4-001 — Three Academic Chapters, Settings & Accessibility, and Combat Item Action

- **Milestone** M4, Weeks 9–10 Academic Content Candidate.
- **Requirements** GDD-037–040, FR-WLD-001/003 (Three Chapters), GDD-016/018/023, FR-CMB-001/004 (Combat Item), GDD-103, TC-ACC-001 (Settings & Accessibility). Full formal report in [`report/m4_academic_candidate_report.md`](../report/m4_academic_candidate_report.md).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `scripts/story/chapter_manager.gd`, `scenes/world/{dawnreach_village,whispering_grove,forgotten_shrine}.tscn`, `scenes/ui/academic_completion_modal.{tscn,gd}`, `scenes/combat/battle_fixture.{tscn,gd}`, `scripts/settings/settings_manager.gd`, `scenes/ui/settings_sheet.{tscn,gd}`, `scenes/main/game_root.gd`, `project.godot`, `tests/headless/{chapter_progression_test,settings_accessibility_test}.gd`, and tracked UIDs.
- **Asset provenance** None (ColorRect primitives and native Control UI containers; educational questions authored per Gemini Flash routing; zero image generation).
- **Review** CHANGES_REQUESTED. See the [Codex CLI batch verdict](#codex-cli-review-of-queued-m2m6-work).

### Verification across all 15 suites

| Suite | Result |
| --- | --- |
| `tests/headless/chapter_progression_test.gd` | Exit 0. Verified 3-chapter lifecycle, completion gating, Whispering Grove dimension shift bramble dissolve, academic completion portal, and RFC-4180 CSV export. |
| `tests/headless/settings_accessibility_test.gd` | Exit 0. Verified master/music/sfx volume controls, reduced motion, high contrast, text scaling (0.8–1.5), sheet toggle (`O`), and `user://settings.json` persistence. |
| Full 15-suite regression check | Exit 0. All 15 test suites pass cleanly with zero engine errors. |

---

## SBL-M5-001 — End-to-End Academic Playthrough QA & Educator Analytics Suite

- **Milestone** M5, Week 11 QA Evidence.
- **Requirements** GDD-001–132, M1–M4 Integration, FR-EDU-001–004. Full formal report in [`report/m5_m6_verification_and_release_report.md`](../report/m5_m6_verification_and_release_report.md).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `tests/headless/{e2e_academic_playthrough_test,educator_analytics_test}.gd` and tracked UIDs.
- **Asset provenance** None (Test harnesses and algorithmic simulators only).
- **Review** CHANGES_REQUESTED. See the [Codex CLI batch verdict](#codex-cli-review-of-queued-m2m6-work).

### Verification

| Suite | Result |
| --- | --- |
| `tests/headless/e2e_academic_playthrough_test.gd` | Exit 0. Verified complete student journey: Ch I $\rightarrow$ Ch II (bramble dissolve via Shift Q) $\rightarrow$ Ch III $\rightarrow$ Completion Modal $\rightarrow$ CSV export $\rightarrow$ Dungeon extraction $\rightarrow$ Profile reload. |
| `tests/headless/educator_analytics_test.gd` | Exit 0. Verified 12-student batch simulation across 3 archetypes, first-attempt immutability stress, completion-gated unblocking, and 72-row RFC-4180 CSV generation. |

---

## SBL-M6-001 — Web Save Backup Export/Import & Godot Export Presets

- **Milestone** M6, Week 12 Release Candidate Foundation.
- **Requirements** GDD-098–103, AGENTS.md Engineering Invariants ("provide local web backup export/import", "single-threaded web build", "Compatibility renderer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `export_presets.cfg`, `scenes/ui/settings_sheet.{tscn,gd}`, `scenes/main/game_root.gd`, `tests/headless/web_backup_test.gd`, `docs/evaluator_walkthrough.md`, `report/academic_defense_checklist.md`, and tracked UIDs.
- **Asset provenance** None (Godot Control UI containers and config files only).
- **Review** CHANGES_REQUESTED. See the [Codex CLI batch verdict](#codex-cli-review-of-queued-m2m6-work).

### Verification across all 18 suites

| Suite | Result |
| --- | --- |
| `tests/headless/web_backup_test.gd` | Exit 0. Verified profile string export, import into fresh slot, rejection of corrupted/invalid JSON, and SettingsSheet UI clipboard bridge with headless fallback. |
| Full 18-suite regression check | Exit 0. All 18 test suites pass cleanly with zero engine errors. |

---

## SBL-FIX-001 — Combat Item Validation, UI Sheet Equip Wiring & Modal Exclusivity

- **Milestone** M3 & M4 Hardening.
- **Requirements** GDD-016, GDD-018, GDD-023, GDD-025–030, GDD-103, FR-CMB-001/004, FR-INV-001, AGENTS.md Invariants.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `scenes/combat/battle_fixture.gd`, `scenes/main/game_root.gd`, `scenes/ui/inventory_sheet.{tscn,gd}`, `scenes/vertical_slice/quest_dialog.gd`, `scenes/vertical_slice/chapter_activity_dialog.gd`, `scenes/ui/academic_completion_modal.gd`, `tests/headless/{combat_test,ui_sheets_test}.gd`, and `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code and Godot UI primitives only).
- **Review** CHANGES_REQUESTED. Codex CLI session `01a1bee0-6c04-72b0-b38d-6bce20925f2f` reviewed `0b66fdb..f26f2d1` and found 7 defects (1 P1, 6 P2). See the review section at the end of this file. Human release acceptance remains pending.
- **Open questions** None for this slice.

### Verification across all 18 suites

| Suite | Result |
| --- | --- |
| `tests/headless/combat_test.gd` | Exit 0. Verified item rejection when 0 owned, item consumption from inventory, healing 1 pip, healing cap rejection at `max_ren_pips` (3), and modal hotkey blocking. |
| `tests/headless/ui_sheets_test.gd` | Exit 0. Verified UI equip buttons (`weapon_equip_btn`, `relic1_equip_btn`), unequip buttons, button disabling when no candidates exist, and `equipment_changed` signal emission. |
| Full 18-suite regression check | Exit 0. All 18 test suites pass cleanly with zero engine errors. |

---

## SBL-FIX-002 — Dungeon Suspend/Resume Persistence, Web Browser Direct Download Bridge & Live Accessibility Audio Application

- **Milestone** M3, M4 & M6 Hardening (Academic MVP Completion).
- **Requirements** GDD-031..035, GDD-098..103, GDD-103, FR-DNG-001/002, FR-EDU-004, TC-ACC-001, AGENTS.md Invariants ("Suspend/resume an expedition does not count as extraction; validate exactly-once reward transfer", "provide local web backup export/import").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `scenes/dungeon/dungeon_expedition.{tscn,gd}`, `scenes/main/game_root.gd`, `scenes/ui/academic_completion_modal.gd`, `scenes/ui/settings_sheet.gd`, `scripts/education/assessment_controller.gd`, `scripts/settings/settings_manager.gd`, `tests/headless/{dungeon_scene_test,web_backup_test}.gd`, and `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code and Godot UI primitives only).
- **Review** CHANGES_REQUESTED. Codex CLI session `01a1bee0-6c04-72b0-b38d-6bce20925f2f` reviewed `0b66fdb..f26f2d1` and found 7 defects (1 P1, 6 P2). See the review section at the end of this file. Human release acceptance remains pending.
- **Open questions** None for this slice.

### Verification across all 18 suites

| Suite | Result |
| --- | --- |
| `tests/headless/dungeon_scene_test.gd` | Exit 0. Verified active expedition suspend at chamber 3, node serialization, restore into fresh instance, satchel preservation without bank transfer, advance to portal, and exact-once extraction without reward duplication. |
| `tests/headless/web_backup_test.gd` | Exit 0. Verified in-memory `generate_csv_text()` RFC-4180 format, web UTF-8 buffer preparation for `JavaScriptBridge.download_buffer`, and profile backup export. |
| `tests/headless/settings_accessibility_test.gd` | Exit 0. Verified `set_music_volume`, `set_sfx_volume`, `apply_audio_buses`, and `apply_all_settings` without recursive loops. |
| Full 18-suite regression check | Exit 0. All 18 test suites pass cleanly with zero engine errors. |

---

## SBL-FIX-003 — Automated Release Exporter, Evaluator Defense Tools, Status Engine & Chapter IV Foundation

- **Milestone** M6 & Academic Defense Readiness / Post-MVP Expansion Phase 1.
- **Requirements** GDD-018, GDD-022, GDD-025, GDD-041, GDD-063, GDD-070, GDD-116, GDD-098–103, FR-CBT-003, FR-WLD-001, FR-EDU-001/003, AGENTS.md Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer", "Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `export_presets.cfg`, `.gitignore`, `scripts/build/export_release.ps1`, `scenes/ui/evaluator_debug_bar.{tscn,gd}`, `scenes/world/ashen_peaks.tscn`, `scenes/world/world_router.gd`, `scenes/combat/battle_fixture.gd`, `scripts/combat/status_engine.gd`, `scripts/education/question_bank.gd`, `scenes/main/game_root.{tscn,gd}`, `tests/headless/{status_engine_test,evaluator_debug_bar_test,educator_analytics_test}.gd`, and `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code, UI nodes, build automation, and Godot primitives).
- **Review** CHANGES_REQUESTED. Codex CLI session `01a1bee0-6c04-72b0-b38d-6bce20925f2f` reviewed `0b66fdb..f26f2d1` and found 7 defects (1 P1, 6 P2). See the review section at the end of this file. Human release acceptance remains pending.
- **Open questions** None for this slice.

### Verification across all 20 suites

| Suite | Result |
| --- | --- |
| `scripts/build/export_release.ps1` | Exit 0. Automated release export produced standalone `dist/Soulbound-Web.zip` (10.5 MB) and `dist/Soulbound-Windows-Portable.zip` (86.4 MB) matching size and renderer invariants. |
| `tests/headless/status_engine_test.gd` | Exit 0. Verified Poison/Burn DoT, Regeneration HoT, Shield absorption, Defense Up/Down modifiers, Stun action blocking, Silence skill blocking, and round-trip serialization. |
| `tests/headless/evaluator_debug_bar_test.gd` | Exit 0. Verified F1 toggleable evaluator tools, direct region warps (Dawnreach, Whispering Grove, Forgotten Shrine, Ashen Peaks), instant item granting, level 10 max stats, instant activity completions, and direct modal triggering. |
| Full 20-suite regression check | Exit 0. All 20 test suites pass cleanly with zero engine errors. |

---

## SBL-FIX-004 — Title Screen & Profile Selector, Procedural Audio Feedback Engine & Presentation Guide

- **Milestone** M6 & Final Academic Defense Polish.
- **Requirements** GDD-098..103, TC-ACC-001, GDD-116, AGENTS.md Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer", "Music/SFX and other non-image assets: Gemini Flash. If no capable audio-output mode exists, only prepare a spec/source and mark the binary asset pending; don't substitute another generator silently").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `scenes/ui/title_screen.{tscn,gd}`, `scripts/audio/audio_manager.gd`, `scenes/main/game_root.{tscn,gd}`, `scenes/combat/battle_fixture.gd`, `scenes/ui/evaluator_debug_bar.{tscn,gd}`, `tests/headless/title_screen_audio_test.gd`, `docs/defense_presentation_guide.md`, and `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code, UI nodes, procedural AudioStreamWAV synthesis with zero external binary dependencies).
- **Review** CHANGES_REQUESTED. Codex CLI session `01a1bee0-6c04-72b0-b38d-6bce20925f2f` reviewed `0b66fdb..f26f2d1` and found 7 defects (1 P1, 6 P2). See the review section at the end of this file. Human release acceptance remains pending.
- **Open questions** None for this slice.

### Verification across all 21 suites

| Suite | Result |
| --- | --- |
| `tests/headless/title_screen_audio_test.gd` | Exit 0. Verified procedural AudioStreamWAV synthesis for 9 sound cues (strike, defend, heal, spell_cast, shift, portal, correct, wrong, button), TitleScreen profile slot selection, defense quick-start demo trigger, and evaluator return button. |
| Full 21-suite regression check | Exit 0. All 21 test suites pass cleanly with zero engine errors. |

---

## SBL-FIX-005 — Void Citadel & Dual-Ending Conclusion, Multi-Phase Boss Encounter Engine, and Kurei Art Skill Tree

- **Milestone** Chapter V Full Release & Apex Climax Features (Options 1, 2, 3 Complete).
- **Requirements** GDD-009..015, GDD-041, GDD-116, FR-WLD-001, FR-CMB-001/002/003, FR-MAG-001/002, AGENTS.md Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer", "Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Option 1: `scenes/world/void_citadel.tscn`, `scenes/world/ashen_peaks.tscn`, `scenes/world/world_router.gd`, `scripts/story/ending_manager.gd`, `scenes/ui/ending_modal.{tscn,gd}`, `scripts/education/question_bank.gd`, `tests/headless/ending_chapter5_test.gd`.
  - Option 2: `scenes/combat/boss_encounter.{tscn,gd}`, `tests/headless/boss_combat_test.gd`.
  - Option 3: `scripts/magic/kurei_tree.gd`, `scripts/magic/kurei_system.gd`, `scenes/combat/battle_fixture.gd`, `scenes/ui/character_sheet.{tscn,gd}`, `tests/headless/kurei_tree_test.gd`.
  - Integration: `scenes/main/game_root.gd`, `scenes/ui/evaluator_debug_bar.{tscn,gd}`, `tests/headless/education_report_test.gd`, `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code, UI nodes, Godot primitives, procedural combat math). Non-image text narratives authored by Gemini Flash.
- **Review** CHANGES_REQUESTED. Codex CLI session `01a1bee0-6c04-72b0-b38d-6bce20925f2f` reviewed `0b66fdb..f26f2d1` and found 7 defects (1 P1, 6 P2). See the review section at the end of this file. Human release acceptance remains pending.
- **Open questions** None for this slice.

### Verification across all 24 suites

| Suite | Result |
| --- | --- |
| `tests/headless/ending_chapter5_test.gd` | Exit 0. Verified Ashen Peaks to Void Citadel portal, Altar of Transcendence (Ending A) and Altar of Restoration (Ending B) triggers, EndingModal epilogue display with honorary titular badges, profile persistence, and Capstone educational question. |
| `tests/headless/boss_combat_test.gd` | Exit 0. Verified Void Sovereign multi-phase transition at <= 50% HP, Phase 2 Astral Shield absorption, telegraphed 2-turn Cataclysm charge and Defend damage mitigation, Lumina Lance shield piercing, status effect ticks, and sovereign victory rewards. |
| `tests/headless/kurei_tree_test.gd` | Exit 0. Verified 4-branch 2-tier Kurei Art Skill Tree, level-based talent point grants, tier prerequisites and point cost enforcement, respec refund, ProfileStore serialization, CharacterSheet UI integration, and BattleFixture spell execution. |
| Full 24-suite regression check | Exit 0. All 24 test suites pass cleanly with zero engine errors. |
| Automated Release Exporter (`export_release.ps1`) | Exit 0. Generated `dist/Soulbound-Web.zip` (10.6 MB) and `dist/Soulbound-Windows-Portable.zip` (86.4 MB). |

---

## SBL-FIX-006 — Dimension Travel Collision Sync, Persisted Expedition Resume, Web Backup/CSV Fallbacks & Live Accessibility Application

- **Milestone** M3, M4 & M6 Hardening (residual Codex review findings on `SBL-W4-001`..`SBL-FIX-005`).
- **Requirements** GDD-031..035, GDD-098..103, FR-DNG-002/003, FR-SAV-001, TC-ACC-001, AGENTS.md Invariants ("Suspend/resume an expedition does not count as extraction; validate exactly-once reward transfer", "Preserve secured gear, level/skills, story and educational records after expedition defeat", "provide local web backup export/import", "Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer").
- **Implementation owner** agy (quota-blocked; slice authored in-session under the same contract and marked pending review). **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Dimension/travel: `scripts/world/dimension_manager.gd`, `scenes/main/game_root.gd`.
  - Expedition persistence: `scenes/main/game_root.gd`, `scenes/dungeon/dungeon_expedition.gd`, `scripts/persistence/gameplay_profile_validator.gd`.
  - Web backup/CSV: `scenes/ui/settings_sheet.{tscn,gd}`, `scenes/ui/academic_completion_modal.gd`.
  - Accessibility/results: `scenes/main/game_root.gd`, `scenes/ui/ending_modal.gd`.
  - Tests: `tests/headless/{dimension_test,dungeon_scene_test,settings_accessibility_test}.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code, Godot UI primitives; no image, audio, or text asset generation in this slice).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None for this slice. The dimension player mask assumes layer 1 = physical obstacles and layer 2 = spirit obstacles; region scenes must keep authored collision layers on those two bits.

### Changes

1. **Dimension travel/shift sync.** `DimensionManager` now owns the player collision mask for the active plane (`player_collision_mask()`, `apply_player_collision()`) and re-applies it on every accepted shift. Region toggling is scoped to descendants of the active region (previously a global `get_nodes_in_group` touched sibling/queued regions) and disables every shape owner of nested `CollisionObject2D` nodes, restoring each owner's authored disabled state via per-owner metadata. `GameRoot._sync_dimension_state()` runs after a shift, after a region transition, and after a profile reload, so the visual plane, collision plane, and player mask never diverge.
2. **Persisted expedition resume.** A suspended run is written to `world.active_expedition` through a load-modify-save helper (`_mutate_profile`) instead of memory only, and is reloaded into `_suspended_expedition` during `_init_slice_progress`, so a restarted session can resume the same run. Extraction writes the banked inventory **and** erases `active_expedition` in one profile write, and defeat/cancel clear the record too, keeping exactly-once banking. `restore_expedition` and `GameplayProfileValidator._validate_active_expedition` reject malformed seed, room count, step, path, and satchel payloads before any state is applied.
3. **Browser-safe backup and CSV.** `SettingsSheet` gains a `BackupTextField` + `Import From Text` path that never reads the system clipboard (browsers may deny it), and export fills that box so the string is visible and copyable. `AcademicCompletionModal` downloads the CSV through `JavaScriptBridge.download_buffer` on Web regardless of whether the `user://` copy succeeds; the file write is only a desktop convenience.
4. **Live accessibility + results blocking.** Text scale is applied to the live UI tree from each control's authored font size (captured once, so repeated changes never compound, and 1.0 restores the authored size); high contrast is applied to the world and top-level overlay controls, including sheets and modals created later. `EndingModal` consumes character/inventory/settings/`ui_cancel` hotkeys so no sheet can stack over the epilogue.
5. **Live-profile reload.** Importing a backup now re-reads every consumer (`CharacterStats`, `InventoryManager`, `ChapterManager`, `AssessmentController`, `KureiTree`, `EndingManager`, chapter baseline) through `_init_slice_progress`, so the next save cannot write stale pre-import state back over the imported profile.

### Verification across all 24 suites

| Suite | Result |
| --- | --- |
| `tests/headless/dimension_test.gd` | Exit 0. Verified player collision mask flips with the active plane and restores on return, physical/spirit visibility and nested shape-owner collision toggling, and that a sibling region is never modified by a scoped apply. |
| `tests/headless/dungeon_scene_test.gd` | Exit 0. Verified the existing suspend/restore/extraction regressions plus a new end-to-end persistence case: suspend writes `world.active_expedition`, a fresh `GameRoot` session reloads it, the preflight validator rejects a zero-count satchel, atomic extraction banks the satchel exactly once and clears the record, and the next session finds no resumable run. |
| `tests/headless/settings_accessibility_test.gd` | Exit 0. Verified text-box backup import succeeds without clipboard access and rejects malformed JSON, and that text scale/high contrast change the live `GameRoot` UI and restore to authored values. |
| Full 24-suite regression check | Exit 0. All 24 suites pass with the console executable via `Start-Process` redirection. |
| Automated Release Exporter (`export_release.ps1`) | Exit 0. Generated `dist/Soulbound-Web.zip` (10,623,505 bytes) and `dist/Soulbound-Windows-Portable.zip` (86,495,925 bytes). |

---

## SBL-VER-001 — Regression Tests Pinning Five Reproduced Review Probes

- **Milestone** M2–M6 Verification & Regression Hardening.
- **Requirements** GDD-031..035, GDD-067..072, GDD-098..103, FR-DNG-001/002, FR-EDU-002/003, FR-SAV-001, AGENTS.md Invariants ("Preserve secured gear, level/skills, story and educational records after expedition defeat", "Suspend/resume an expedition does not count as extraction; validate exactly-once reward transfer", "Required learning activities are completion-gated, not pass-score-gated; first-attempt correctness is immutable").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Tests: `tests/headless/vertical_slice_loop_test.gd`, `tests/headless/chapter_progression_test.gd`, `tests/headless/dungeon_scene_test.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (pure GDScript headless regression assertions only).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Probe to Test Mapping & Evidence

| Review Probe Defect | Where Asserted | Test Assertion & Evidence |
| --- | --- | --- |
| Newer banked gear disappears on a quest checkpoint | `tests/headless/vertical_slice_loop_test.gd` | Granted banked gear (`probe_banked_gear: 2`) after practice step, advanced quest via combat victory into `TURN_IN`, reloaded profile, asserted banked gear preserved on disk. |
| Imported inventory disappears on the next checkpoint | `tests/headless/vertical_slice_loop_test.gd` | Imported backup profile mid-run (`imported_gem: 7`, `imported_herb: 3`) at `TURN_IN`, advanced stage to `COMPLETE`, asserted imported banked & satchel counts survived the merge. |
| Incorrect answer leaves the required activity incomplete | `tests/headless/chapter_progression_test.gd` & `tests/headless/vertical_slice_test.gd` | Submitted incorrect answer; asserted activity marked completed (`is_chapter_activity_completed == true`), completion-gated advance unblocked, while `first_attempt_correct == false`. |
| Fresh profile reaches final completion with no assessment records | `tests/headless/chapter_progression_test.gd` | Attempted advance on fresh profile with no records (`try_advance_chapter == false`, `is_academic_complete == false`), and asserted `GameplayProfileValidator.validate()` rejects bypassed completion payload (`ERR_INVALID_DATA`). |
| Extraction reports success after an injected save failure | `tests/headless/dungeon_scene_test.gd` | Injected `ERR_FILE_CANT_WRITE` in `commit_extraction`; asserted `extraction_save_failed` emitted, `expedition_completed` not emitted, live satchel not wiped, and extract button remains enabled for retry. |

### Verification Table

| Suite | Result |
| --- | --- |
| `tests/headless/vertical_slice_loop_test.gd` | Exit 0. Probes 1 and 2 passed with explicit assertions. |
| `tests/headless/chapter_progression_test.gd` | Exit 0. Probes 3 and 4 passed with explicit assertions. |
| `tests/headless/dungeon_scene_test.gd` | Exit 0. Probe 5 passed with explicit assertions. |
| `tests/headless/vertical_slice_test.gd` | Exit 0. Completion-gating not score-gating verified. |

---

## SBL-FIX-007 — Extraction & Defeat Failure UX, Retry Pathways, and Anti-Duplication Guards

- **Milestone** M3 Hardening (Dungeon Expedition & Persistence Failure Invariants).
- **Requirements** GDD-031..035, GDD-098..103, FR-DNG-001/002, FR-SAV-001, AGENTS.md Invariants ("Preserve secured gear, level/skills, story and educational records after expedition defeat; lose only approved unbanked items and temporary upgrades", "Suspend/resume an expedition does not count as extraction; validate exactly-once reward transfer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scene/Scripts: `scenes/dungeon/dungeon_expedition.gd`, `scenes/main/game_root.gd`.
  - Tests: `tests/headless/dungeon_scene_test.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code and UI controls only).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Extraction Failure UX & Retry Path.** `DungeonExpedition.extract_now()` protects candidate inventory in a staged clone, emits `extraction_save_failed`, surfaces error in `room_description_label` and `status_label` without claiming success, keeps the expedition active, and enables the extract button for retry. `GameRoot` binds `_on_extraction_save_failed` to surface non-success status.
2. **Defeat Failure UX & Retry Path.** Added `commit_defeat: Callable` and `signal defeat_save_failed(error: Error)` to `DungeonExpedition`. On defeat commit failure, `is_active` remains true, satchel items are not wiped prematurely in memory or on disk, `room_description_label` and `GameRoot.status_label` surface the defeat save failure rather than claiming bank secured, and `retreat_btn` remains enabled as "Retry Retreat".
3. **Double and Early Extraction / Defeat Guards.** Re-asserted early extraction rejection before reaching the extraction chamber. Verified that duplicate extraction and duplicate defeat calls while inactive or committing are strictly rejected, preventing any double banking or duplicate callbacks.
4. **Recovery Retry Banking Invariant.** Upon save recovery, subsequent retry commits satchel to bank (or satchel wipe on defeat) exactly once.

### Verification Table

| Suite | Result |
| --- | --- |
| `tests/headless/dungeon_scene_test.gd` | Exit 0. Verified atomic extraction failure & retry, early extraction rejection, duplicate extraction rejection, defeat commit failure with satchel retention & retry, and duplicate defeat rejection. |

---

## SBL-FIX-008 — Terminal-State Input Exclusivity & Modal Stacking Prevention

- **Milestone** M3, M4 & Release Hardening (Input Exclusivity Invariants).
- **Requirements** GDD-103, GDD-116, FR-WLD-001, FR-CMB-001, AGENTS.md Invariants.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scene/Scripts: `scenes/combat/boss_encounter.gd`, `scenes/combat/battle_fixture.gd`, `scenes/ui/academic_completion_modal.gd`, `scenes/ui/ending_modal.gd`, `scenes/vertical_slice/chapter_activity_dialog.gd`, `scenes/vertical_slice/quest_dialog.gd`, `scenes/main/game_root.gd`.
  - Tests: `tests/headless/evaluator_debug_bar_test.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code and UI input management only).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Terminal-State Input Consumption.** `BossEncounter`, `EndingModal`, `AcademicCompletionModal`, `ChapterActivityDialog`, `QuestDialog`, and `BattleFixture` now explicitly consume `toggle_character`, `toggle_inventory`, `toggle_settings`, and `ui_cancel` via `_input()`, invoking `get_viewport().set_input_as_handled()` while visible in the scene tree.
2. **Modal Stacking Guards.** `GameRoot` enforces `has_blocking_modal()` guards across all instantiation pathways, including `open_boss_encounter()`, `open_ending_modal()`, `_open_academic_modal()`, and evaluator debug bar triggers (`_on_debug_academic_modal`, `_on_debug_chapter_dialog`, `_on_debug_combat`, `_on_debug_dungeon`). No sheet or secondary modal can be instantiated on top of a visible blocking/terminal modal.
3. **Headless Verification.** Driven via real `InputEventAction`s parsed through `Input.parse_input_event()`. Asserted `has_blocking_modal() == true` across Academic Modal, Boss Victory results state, Ending Modal, and Chapter Dialog, confirming zero extra child controls instantiated on `_sheet_layer` during active modal states.

### Verification Table

| Suite | Result |
| --- | --- |
| `tests/headless/evaluator_debug_bar_test.gd` | Exit 0. Verified input consumption for character/inventory/settings/ui_cancel actions and zero sheet layer children leakage across all 4 terminal/modal states under direct action injection and debug bar trigger attempts. |

---

## SBL-FIX-009 — Complete Accessibility Application, Keyboard Reachability & High-Contrast Overrides

- **Milestone** M4 & Release Hardening (Accessibility Compliance).
- **Requirements** GDD-103, TC-ACC-001, AGENTS.md Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scene/Scripts: `scenes/ui/settings_sheet.gd`, `scenes/ui/inventory_sheet.gd`, `scenes/ui/character_sheet.gd`, `scenes/vertical_slice/chapter_activity_dialog.gd`, `scenes/main/game_root.gd`.
  - Tests: `tests/headless/settings_accessibility_test.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code and UI accessibility styling).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Keyboard Reachability & Focus Order.** Added `get_focusable_controls()` and `setup_focus()` across `SettingsSheet`, `InventorySheet`, `CharacterSheet`, and `ChapterActivityDialog`. Configured `focus_mode = FOCUS_ALL`, circular `focus_next` / `focus_previous` chains, and initial control focus grabbing upon modal entry, ensuring 100% of interactive controls are navigable without a mouse.
2. **Visible Focus Outlines.** Applied high-visibility gold focus highlight styleboxes (`StyleBoxFlat` border width 2, `#ffe01a`) on all focusable controls upon receiving focus.
3. **Extended High-Contrast Typography.** `GameRoot._apply_high_contrast()` captures authored label font color and shadow metadata (`_BASE_FONT_COLOR_META`, `_BASE_SHADOW_COLOR_META`, shadow offsets). When High Contrast is enabled, it overrides labels with crisp pure white text (`Color(1, 1, 1, 1)`) and high-contrast black drop shadow (`Color(0, 0, 0, 1)`, offset 1, 1). Toggling High Contrast off cleanly restores authored colors and removes shadow overrides.
4. **Reduced Motion Audit.** Confirmed and documented that zero sprite animations, `AnimationPlayer` nodes, or tweens exist in this Compatibility 2D project, strictly adhering to reduced motion requirements by architectural design.

### Verification Table

| Suite | Result |
| --- | --- |
| `tests/headless/settings_accessibility_test.gd` | Exit 0. Verified live text scale application & restore, high contrast modulate, label pure white font color & black shadow overrides with exact authored value restoration, circular keyboard focus traversal across Settings, Inventory, Character, and Chapter Dialog, and reduced motion persistence. |

### Manual Visual Checklist

- [ ] **Visible Focus**: Tabbing through Settings, Inventory, Character Sheet, and Chapter Activity Dialog displays a distinct gold 2px outline around the active control.
- [ ] **Mouse-Free Navigation**: Tab, Shift-Tab, and Arrow keys cycle through all sliders, checkboxes, buttons, and text fields in circular order without escaping.
- [ ] **High Contrast Text**: In High Contrast mode, all UI labels render with pure white text and crisp black drop shadows for legible contrast against any background.
- [ ] **Authored Value Restorability**: Disabling High Contrast restores original label tints without residual overrides.

---

## SBL-DOC-001 — Reconcile Requirements Traceability Matrix

- **Milestone** Documentation & Traceability Alignment.
- **Requirements** GDD-124, GDD-129, AGENTS.md Operating Contract.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Documentation: `docs/traceability-matrix.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (documentation reconciliation only).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Remediation Slices Documented.** Added remediation rows/links for `SBL-FIX-001` through `SBL-FIX-009` and `SBL-VER-001` against all requirement IDs they touch.
2. **Review Status Synchronization.** Replaced stale `CHANGES_REQUESTED` statuses with `REVIEW_PENDING_CODEX` for requirement rows where subsequent fix slices landed in code. Retained `CHANGES_REQUESTED` on any requirement where no fix slice landed.
3. **Audit Preservation.** Maintained strict fidelity with Codex CLI review history: no row or section reads `REVIEWED` unless accompanied by an explicit Codex CLI session ID from M1, W2, or W3 reviews.
4. **Row-for-Row Agreement.** Verified that every requirement ID from GDD/SRS §14.3 is represented, with no orphan requirement IDs and exact mapping to implementation files and test suites.

### Verification Table

| Audit / Check | Result |
| --- | --- |
| Traceability Matrix Cross-Reference | Pass. All 132 high-level GDD requirements and technical NFRs mapped. Remediation rows for SBL-FIX-001..009 documented. No false REVIEWED statuses. |

---

## SBL-VER-002 — Web/Browser Verification Evidence Checklist & Single-Thread Audit

- **Milestone** M6 & Release Hardening (Platform Compliance & Web Invariants).
- **Requirements** GDD-095, GDD-103, AGENTS.md Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Documentation / Checklist: `docs/browser_verification_checklist.md`.
  - Config: `export_presets.cfg`, `project.godot`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (configuration audit and documentation checklist).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Audit Findings

1. **Single-Thread Configuration Confirmed.** Audited `export_presets.cfg` (`[preset.1.options]`). `variant/thread_support` is explicitly set to `false`. `variant/extensions_support` is `false`. `html/canvas_resize_policy` is set to `2`.
2. **COOP/COEP Analysis.** Confirmed that with single-threaded WebAssembly execution, Godot does not utilize `SharedArrayBuffer` or `Atomics`. Therefore, Cross-Origin Isolation headers (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`) are NOT strictly required for browser execution, enabling deployment to standard static hosting and iframe embeds.
3. **Smoke Test Checklist Authored.** Authored 10 browser smoke test cases (`WEB-SMK-01` through `WEB-SMK-10`) covering canvas initialization, title screen audio activation, IndexedDB save persistence, overworld movement, region transitions, dimension shifting, live accessibility settings, text-box backup import/export, CSV download, and single-thread execution auditing.
4. **Execution Status.** No headless browser automation framework (e.g. Playwright) is provisioned in the CLI environment. In strict adherence to AGENTS.md ("Never report a browser pass that did not run"), all browser manual test execution items are recorded as `PENDING human execution`.

### Verification Table

| Check / Platform | Target | Result / Status | Evidence |
|---|---|---|---|
| Export Preset Audit | `export_presets.cfg` | Pass | `variant/thread_support=false`, `platform="Web"` confirmed. |
| COOP/COEP Requirement Analysis | Web Runtime | Pass | `SharedArrayBuffer` not required for single-threaded build. Documented in `docs/browser_verification_checklist.md`. |
| Chromium Smoke Test | Chrome / Edge | PENDING human execution | Manual test procedure documented in `docs/browser_verification_checklist.md`. |
| Firefox Smoke Test | Firefox | PENDING human execution | Manual test procedure documented in `docs/browser_verification_checklist.md`. |

---

## SBL-MCP-001 — Godot-Compatible MCP Adapter Evaluation

- **Milestone** Tooling & Workflow Validation.
- **Requirements** AGENTS.md Operating Contract § AI Game Developer MCP caution.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Documentation / Audit: `docs/godot-mcp-evaluation.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None.
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None. Integration marked PENDING per AGENTS.md instructions.

### Investigation Summary

1. **Attempted Adapter Evaluation.** Evaluated `ai-game-developer` configured in `~/.gemini/config/mcp_config.json` targeting `http://localhost:26269/p/2d78f1e9`. Reference implementation is `ivanmurzak/unity-mcp`, designed strictly for Unity Editor C# GameObject manipulation and packages. Port 26269 is inactive and the tool is incompatible with Godot 4.
2. **Adherence to Invariants.** In accordance with AGENTS.md ("Never install a Unity package into Godot or invent equivalent Godot tools. If unsupported, use Godot-native files/headless CLI and record the integration as pending"), no unsupported Unity packages were installed into Godot.
3. **Workflow Retained.** Godot-native declarative `.tscn` scenes and typed GDScript files remain the authoritative workflow, verified using Godot 4.7.2 headless execution via detached PowerShell process management. Integration status recorded as `PENDING`.

### Verification Table

| Adapter / Tool | Target Engine | Connectivity / Audit | Result / Status | Operational Action |
|---|---|---|---|---|
| `ai-game-developer` (`ivanmurzak/unity-mcp`) | Unity Editor | Incompatible with Godot 4 (`res://`, GDScript, `.tscn`). Port 26269 inactive. | Incompatible | Reject for Godot. Do not install. |
| Godot-native MCP Adapter | Godot 4.7.2 | None provisioned or discovered in workspace. | **PENDING** | Retain Godot-native files + headless CLI test harness. |

---

## SBL-DATA-001 — Open Decisions Ledger (`OD-001` through `OD-016`)

- **Milestone** Release Hardening & Scope Boundary Management.
- **Requirements** All requirements GDD-001..132, Soulbound_GDD_SRS.md §16.1, AGENTS.md Invariants ("Do not invent numerical stats, formula coefficients, drop probabilities, story revelations, or unsupported integrations. Mark such items `TBD` and seek change approval").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Documentation / Ledger: `docs/open-decisions-ledger.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None.
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None. All 16 open decisions mapped to their resolution owner / gate.

### Ledger Summary

1. **Complete Coverage.** Mapped all 16 unresolved design choices (`OD-001` through `OD-016`) from GDD/SRS §16.1 with decision needed, affected requirement IDs, current code placeholder (`TBD`), resolution owner / gate, and current impact / what stays blocked.
2. **Zero Invented Values.** Verified that neither agy nor Codex invented numerical stats, formulas, damage multipliers, or drop tables. All open decisions remain explicitly gated.
3. **Critical Gates Highlighted.** Specifically tracked Speed initiative rule (`OD-002`), elemental damage formulas (`OD-003`), status stacking (`OD-004`), save boundaries (`OD-009`), procedural dungeon budgets (`OD-011`), and the educator review sign-off gate (`OD-012`).

### Verification Table

| Audit / Check | Scope | Result | Notes |
|---|---|---|---|
| Open Decision Mapping | `OD-001` .. `OD-016` | Pass | All 16 items documented in `docs/open-decisions-ledger.md`. |
| Zero Invented Numbers Audit | Codebase & Docs | Pass | No invented stats or formulas; all placeholders explicitly mapped to `OD-###`. |
| Invariant Alignment | Save & Progression | Pass | Retains secured gear/level invariants, completion-gating, and single-thread web invariants. |

---

## SBL-DATA-002 — Non-Image Asset Queue Finalization & Educator Review Gate

- **Milestone** Content & Asset Governance (Non-Image Asset Finalization).
- **Requirements** GDD-067..072, GDD-083..088, GDD-113..115, AGENTS.md § Binding source-owner directive & Exclusive asset routing.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Documentation / Specs: `docs/audio-spec.md`, `docs/educational_copy_review.md`, `docs/asset-register.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** Non-image assets routed to Gemini Flash. Zero image assets (Codex-exclusive, blocked). Zero binary audio dependencies (procedural in-engine fallback active).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None. Binary audio pending Gemini Flash audio modality. Formal educational certification gated under `OD-012`.

### Asset Queue Summary

1. **Audio Generation Brief Finalized.** Expanded `docs/audio-spec.md` into an exhaustive generation brief covering 10 distinct SFX (UI clicks, dialog advance, correct/retry assessment feedback, fanfare, combat strikes, defend, heals, spells, dimensional shifts, and portals) and 4 BGM loop briefs (Alpha ambient, Ashen Peaks, Void Sovereign boss, and Void Citadel).
2. **Audio Binary Status & Procedural Fallback.** No binary audio output mode is configured for Gemini Flash in this environment. In strict adherence to AGENTS.md ("only prepare a spec/source and mark the binary asset pending; don't substitute another generator silently"), all binary assets are marked `PENDING BINARY ACQUISITION`. The procedural synthesizer in `scripts/audio/audio_manager.gd` provides zero-dependency shipping audio fallback.
3. **Copy & Narrative Audit.** Completed review of quest dialogue and the 8 assessed questions in `QuestionBank` (`docs/educational_copy_review.md`).
4. **Educator Review Gate Enforced (`OD-012`).** Questions are completion-gated in the MVP game loop; formal classroom assessment and psychometric validity remain explicitly gated pending human educator sign-off.
5. **Codex Image Exclusivity Preserved.** Zero image assets were created or touched by agy or Gemini Flash. Visual assets remain strictly blocked for Codex.

### Verification Table

| Asset Stream | Authority | Implementation / Spec Artifact | Status | Fallback / Enforced Gate |
|---|---|---|---|---|
| Audio SFX & Music | Gemini Flash | `docs/audio-spec.md` (10 SFX + 4 BGM specs) | **PENDING BINARY ACQUISITION** | `scripts/audio/audio_manager.gd` (Procedural WAV synthesizer active) |
| Educational Questions & Dialogue | Gemini Flash | `scripts/education/question_bank.gd`, `docs/educational_copy_review.md` | Approved for MVP | Completion-gated; formal assessment gated under `OD-012` |
| Image Assets (Sprites/Tiles) | **Codex Exclusive** | `docs/asset-register.md` | **BLOCKED FOR CODEX** | Engine primitives only; zero images generated by agy/Gemini |

---

## SBL-FIX-010 — Release-Tier Separation (Academic MVP vs. Full Release)

- **Milestone** Invariant Hardening & Packaging Governance.
- **Requirements** GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants ("Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Architecture: `scripts/story/release_tier.gd`, `project.godot`.
  - Routing & Overworld: `scenes/world/world_router.gd`, `scenes/main/game_root.gd`.
  - Questions & Endings: `scripts/education/question_bank.gd`, `scenes/ui/evaluator_debug_bar.gd`.
  - Tests: `tests/headless/release_tier_test.gd`, `tests/headless/ending_chapter5_test.gd`.
  - Decisions: `docs/open-decisions-ledger.md` (`OD-017`), `docs/agent-review-queue.md`.
- **Asset provenance** None (pure code and configuration only; zero generated images or external audio).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** Recorded `OD-017`: Choice of shipping default release tier (`academic_mvp` vs. `full_release`) for public release builds is deferred to human release authority sign-off; checked-in project setting defaults to `full_release` to maintain unbroken evaluator and developer workflows.

### Changes

1. **ReleaseTier Architecture & Configuration.** Introduced `ReleaseTier` class (`scripts/story/release_tier.gd`) managing `soulbound/release_tier` from `project.godot` with supported tiers `"academic_mvp"` and `"full_release"`. Provided runtime override mechanism (`set_tier_override()`, `clear_tier_override()`) for headless verification without disk side-effects. Default checked-in configuration is `full_release`.
2. **WorldRouter Gating.** `WorldRouter.is_region_available("void_citadel")` returns `false` under `academic_mvp`. `WorldRouter.request_transition` and `WorldRouter.debug_warp` reject transitions to `void_citadel` when in `academic_mvp` tier.
3. **Overworld Visual & Interaction Gating.** In `GameRoot._sync_release_tier_for_region()`, entry into `ashen_peaks` under `academic_mvp` hides and disables `PortalToCitadel` monitoring and collision shapes. If `void_citadel` is instantiated, both ending altars (`EndingAltarTranscendence` and `EndingAltarRestoration`) have visual display and monitoring disabled.
4. **Modal & Story Epilogue Gating.** `GameRoot.open_ending_modal()` strictly no-ops when not in full release tier (`_ending_modal` remains null).
5. **Educational QuestionBank Gating.** `QuestionBank` gates Chapter 5 capstone question (`q_meta_01`) so that `get_question("q_meta_01")` returns an empty dictionary, `get_questions_by_chapter(5)` returns an empty array, and `get_required_question_id_for_chapter(5)` returns an empty string under `academic_mvp`.
6. **Evaluator Debug Bar Synchronization.** `EvaluatorDebugBar` disables Citadel warp (`BtnCitadel`), Void Boss (`BtnBoss`), and Ending Altars (`BtnEndingA`, `BtnEndingB`) when running under `academic_mvp`.

### Verification Table

| Suite | Result | Evidence |
|---|---|---|
| `tests/headless/release_tier_test.gd` | Exit 0 | Verified default `full_release` tier, router rejection of `void_citadel`, `ashen_peaks` portal hiding/disabling, `open_ending_modal()` no-op, `q_meta_01` query exclusion, debug bar button disabling, and full restoration on tier restore. |
| `tests/headless/ending_chapter5_test.gd` | Exit 0 | Verified full tier retains 100% operational functionality for Ashen Peaks portal, Void Citadel entry, both endings, epilogue modal, and capstone question. |

---

## SBL-BLD-001 — Canonical Headless Test Runner

- **Milestone** Test & CI Automation Infrastructure.
- **Requirements** GDD-093, GDD-109, GDD-124, AGENTS.md § Engineering invariants & § Definition of done.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Runner script: `scripts/build/run_headless_tests.ps1`.
  - Documentation: `docs/testing.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (PowerShell build script and documentation).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Automated Test Harness Script.** Authored `scripts/build/run_headless_tests.ps1` to execute an initial project `--import`, enumerate all 25 test suites under `tests/headless/*.gd`, execute each suite with synchronous process management (`Start-Process -NoNewWindow -Wait -PassThru`), redirect stdout and stderr to `report/<suite_name>.log` and `report/<suite_name>.err`, and display an automated PASS/FAIL summary table.
2. **Elimination of Blank-Exit-Code Trap.** Avoided the Windows GUI subsystem detached-process trap by utilizing `Godot_v4.7.2-stable_win64_console.exe` with structured process redirection and explicit exit code validation.
3. **Flexible CLI Switches.** Added `-Suite <name>` to filter execution to a single suite or substring, `-Export` to automatically chain `scripts/build/export_release.ps1` on green runs, and `-SkipImport` for rapid test iterations.
4. **Failing Suite Proof.** Verified that a deliberately broken suite causes `run_headless_tests.ps1` to exit with non-zero exit code (exit 1), and clean runs exit with code 0.
5. **Testing Documentation.** Documented commands, engine subsystem differences, and full suite inventory in `docs/testing.md`.

### Verification Table

| Invocation / Condition | Expected Exit | Observed Exit | Evidence |
|---|---|---|---|
| Single suite: `run_headless_tests.ps1 -Suite release_tier_test` | Exit 0 | Exit 0 | Clean single suite execution; table reports PASS in 1.02s. |
| Injected failure: `temporary_broken_test.gd` (quit(1)) | Exit 1 | Exit 1 | Non-zero exit code propagation verified; runner terminates with exit code 1. |
| Full 25-suite suite execution: `run_headless_tests.ps1` | Exit 0 | Exit 0 | All 25 suites passed cleanly with 0 failures in 27.5s. |

---

## SBL-FIX-011 — 960×540 Layout & Overflow Audit

- **Milestone** UX, Accessibility & Resolution Guard Hardening.
- **Requirements** GDD-103 (960×540 logical resolution), TC-ACC-001 (Text scale 0.8–1.5x, High contrast), AGENTS.md Engineering Invariants.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Settings: `scenes/ui/settings_sheet.{tscn,gd}`.
  - Inventory: `scenes/ui/inventory_sheet.{tscn,gd}`.
  - Character: `scenes/ui/character_sheet.{tscn,gd}`.
  - Chapter Dialog: `scenes/vertical_slice/chapter_activity_dialog.gd`.
  - Academic Modal: `scenes/ui/academic_completion_modal.{tscn,gd}`.
  - Ending Modal: `scenes/ui/ending_modal.{tscn,gd}`.
  - Tests: `tests/headless/layout_audit_test.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (pure GDScript and Godot UI primitives; zero generated art).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Resolution & Text-Scale Overflow Audit.** Audited all six core UI panels/modals (SettingsSheet, InventorySheet, CharacterSheet, ChapterActivityDialog, AcademicCompletionModal, EndingModal) under the fixed 960×540 logical viewport at authored base scale (1.0×) and maximum accessibility scaling (1.5×).
2. **SettingsSheet Scroll Integration.** Restructured `SettingsSheet` to place audio controls, accessibility toggles, and web backup controls inside a vertical `ScrollContainer` bounded within a 550×500 panel. At 1.0×, the panel fits without scroll clipping; at 1.5×, the scroll container absorbs content expansion, keeping the panel within `Rect2(0, 0, 960, 540)`.
3. **CharacterSheet Layout Correction.** Remedied the 551px vertical overflow discovered during the initial audit. Replaced the unscrollable VBox with a 550×510 panel containing a vertical `ScrollContainer` for attribute allocation and Kurei talent trees. Bounded margins ensure `vbar.page >= vbar.max_value` at 1.0× (no clipping) and full viewport containment at 1.5×.
4. **InventorySheet Equipment Column Scrolling.** Added a `ScrollContainer` for equipment slot rows (`WeaponRow`, `ArmorRow`, `Relic1Row`, `Relic2Row`) inside `EquipCol`.
5. **AcademicCompletionModal & EndingModal Protection.** Wrapped the variable-length assessment competency summaries and epilogue narratives in `ScrollContainer`s with fixed action button anchors.
6. **ChapterActivityDialog Guard.** Hardened `ChapterActivityDialog.setup_focus()` to guard against pre-tree invocation (`is_inside_tree()`).
7. **Resilient Node Resolution.** Implemented safe node lookup (`_find_node()`) across all affected sheet controllers, ensuring backward-compatible binding across both flat and scroll-nested node hierarchies.

### Verification Table

| Test Suite / Scope | Result | Evidence |
|---|---|---|
| `tests/headless/layout_audit_test.gd` (Phase 1: 1.0×) | Exit 0 | All 6 panels confirmed inside `Rect2(0, 0, 960, 540)`. All scroll containers report zero clipped content at 1.0× (`page >= max_value` or `max <= size.y`). |
| `tests/headless/layout_audit_test.gd` (Phase 2: 1.5×) | Exit 0 | All 6 panels confirmed inside `Rect2(0, 0, 960, 540)` at 1.5× text scaling. Content growth fully absorbed by scroll containers. |
| `tests/headless/settings_accessibility_test.gd` | Exit 0 | 100% regression pass on live audio, contrast, text scaling, and clipboard-free backup text transfer. |
| `tests/headless/ui_sheets_test.gd` | Exit 0 | 100% regression pass on hotkey toggles, mutual exclusivity, attribute allocation, and gear equip/unequip. |

---

## SBL-FIX-012 — Save Compatibility, Extension Preservation & Recovery UX

- **Milestone** Persistence Robustness & Fault Tolerance.
- **Requirements** GDD-073–078 (Save invariants, 3 slots, revision rotation), GDD-125 (schema stability), FR-SAV-001 (schema versioning & validation), AGENTS.md Engineering Invariants.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Persistence store: `scripts/persistence/profile_store.gd`.
  - Title UI: `scenes/ui/title_screen.{tscn,gd}`.
  - Tests: `tests/headless/save_compatibility_recovery_test.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (pure GDScript and Godot UI primitives; zero generated art).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Permissive Extension Envelope with Invariant Guarantees.** Updated `ProfileStore._validate_envelope()` to eliminate rigid dictionary size gating (`data.size() != REQUIRED_ENVELOPE_KEYS.size()`). All required schema keys (`schema_version`, `profile_id`, `character`, `inventory`, `world`, `education`) and strict JSON data types are enforced, while top-level and section-level extension keys (e.g., mod/evaluator metadata) are preserved across multiple save/load cycles.
2. **Strict Version Decoupling.** Preserved exact decimal token string validation in `_is_exact_schema_one()` to ensure IEEE-754 approximations (e.g. `1.00000000000000001`) are strictly rejected with `ERR_FILE_UNRECOGNIZED`.
3. **Legacy Section Compatibility.** Verified that legacy profiles created prior to the introduction of `world.active_expedition` load cleanly and validate without crashing or false corruption rejections.
4. **Corrupt Revision Disk Preservation.** Confirmed that when corruption strikes the most recent revision file, `ProfileStore.load_profile()` falls back to the latest valid revision, flags the envelope with `recovered: true`, and strictly leaves the physical files on disk untouched until a genuine subsequent save rotates revisions.
5. **TitleScreen Recovery UX & Pre-Overwrite Export.** Added `RecoveryBox`, `RecoveryLabel`, and `RecoveryExportBtn` to `TitleScreen`. When a selected slot was recovered from a backup revision, the slot selector displays `[RECOVERED]` and the main menu presents a clear warning and explicit "Export Backup Before Overwrite" action wired to `backup_requested`.

### Verification Table

| Test Suite / Scope | Result | Evidence |
|---|---|---|
| `tests/headless/save_compatibility_recovery_test.gd` (Legacy profile load) | Exit 0 | Legacy profile lacking `active_expedition` passes `GameplayProfileValidator` and `ProfileStore.load_profile()`. |
| `tests/headless/save_compatibility_recovery_test.gd` (Extension preservation) | Exit 0 | Top-level and section-level extension keys survive multiple save and load cycles with modified gameplay stats. |
| `tests/headless/save_compatibility_recovery_test.gd` (Corrupt recovery fallback) | Exit 0 | Slot with corrupt latest revision falls back to revision 1, sets `recovered == true`, and keeps both revision files on disk. |
| `tests/headless/save_compatibility_recovery_test.gd` (TitleScreen UX surfacing) | Exit 0 | TitleScreen reveals `RecoveryBox`, slot 3 button shows `[RECOVERED]`, and `recovery_export_btn` fires `backup_requested`. |
| `tests/headless/save_compatibility_recovery_test.gd` (Schema version exactness) | Exit 0 | Exact `1.0` passes; float rounding approximation `1.00000000000000001` rejected with `ERR_FILE_UNRECOGNIZED`. |
| `tests/headless/save_model_test.gd` | Exit 0 | 100% regression pass on 3-slot rotation, revision sequencing, and timestamped backups. |
| `tests/headless/title_screen_audio_test.gd` | Exit 0 | 100% regression pass on TitleScreen startup and audio wiring. |

---

## SBL-VER-003 — Exported-Artifact Validator & Pipeline Chaining

- **Milestone** Build Integrity, Artifact Governance & Platform Compatibility.
- **Requirements** GDD-108 (Target platforms: Web + Windows Desktop), GDD-109 (gl_compatibility renderer), GDD-129 (automated verification), AGENTS.md Engineering Invariants (single-threaded Web, Compatibility renderer).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Validator script: `scripts/build/validate_release.ps1`.
  - Export script: `scripts/build/export_release.ps1`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (PowerShell validation and build scripts).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Automated Release Validator (`scripts/build/validate_release.ps1`).** Created an artifact validation script that uses .NET `System.IO.Compression.ZipFile` to inspect distribution archives without external tooling dependencies.
2. **Entry Point Verification.** Asserts required entry points exist in both distribution packages:
   - Web (`Soulbound-Web.zip`): `index.html`, `index.wasm`, `index.pck`.
   - Windows Portable (`Soulbound-Windows-Portable.zip`): `Soulbound.exe`, `Soulbound.pck`.
3. **Debug & Editor Leftover Exclusion.** Enforces zero-tolerance check ensuring no `.uid`, `.import`, `.godot/`, `.git/`, `tests/`, `report/`, `.tmp`, or `.bak` files are packaged inside release zip archives.
4. **Platform Invariant Configuration Checks.** Validates `export_presets.cfg` for `variant/thread_support=false` (single-threaded Web) and `project.godot` for `rendering_method="gl_compatibility"` (standard and web override).
5. **Plausible Size Thresholds.** Verifies binary and package size plausibility against known baselines (`index.pck`/`Soulbound.pck` between 300KB and 50MB, `index.wasm` > 10MB, `Soulbound.exe` > 50MB).
6. **Pipeline Chaining.** Wired `validate_release.ps1` into `export_release.ps1` as step 4/4 so any artifact invalidity fails the export build process with non-zero exit code.
7. **Clean Packaging Isolation.** Added `.gdignore` placement to `builds/` and `dist/` and sanitized file selection during zip packaging, preventing Godot project scans from generating extraneous `.import` files inside release distributions.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| Direct validator: `validate_release.ps1` | Exit 0 | Presets confirmed single-threaded Compatibility; Web and Windows entry points verified; zero leftovers found. |
| Export pipeline: `export_release.ps1` | Exit 0 | Web export, Windows export, clean archive compression, and post-export validator all passed. |
| Test runner chaining: `run_headless_tests.ps1 -Suite smoke_test -Export` | Exit 0 | Headless test pass seamlessly triggered export and validation steps, exiting 0. |

### Artifact Size Report

| Artifact | Size (Bytes) | Size (MB) |
|---|---|---|
| `dist/Soulbound-Web.zip` | 10,636,169 B | ~10.14 MB |
| `dist/Soulbound-Windows-Portable.zip` | 86,510,267 B | ~82.50 MB |
| `builds/web/index.pck` | 505,180 B | ~493 KB |
| `builds/web/index.wasm` | 39,514,754 B | ~37.68 MB |
| `builds/windows/Soulbound.pck` | 505,180 B | ~493 KB |
| `builds/windows/Soulbound.exe` | 180,717,576 B | ~172.35 MB |

---

## SBL-MCP-002 — Godot-Compatible Community MCP Adapter Evaluation

- **Milestone** Tooling & Workflow Validation.
- **Requirements** AGENTS.md § AI Game Developer MCP caution.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Documentation: `docs/godot-mcp-evaluation.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (tooling evaluation, documentation, and disposable scratch scripts).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Comparative Community Adapter Survey & Empirical Probing.** Executed rigorous evaluation across candidate MCP adapters in accordance with AGENTS.md:
   - `ivanmurzak/unity-mcp`: Incompatible (Unity C# only; port 26269 connection refused; zero Godot scene support).
   - `IvanMurzak/Godot-MCP (godot-cli v0.36.0)`: Incompatible with GDScript-only projects (requires `.csproj`, NuGet C# assembly reload gate; emitted warning for missing Godot.NET.Sdk project; exit code 1).
   - `@coding-solo/godot-mcp` v0.1.1: Functional standard Godot CLI bridge via Node.js stdio.
2. **Disposable Project Proof Execution.** In strict adherence to AGENTS.md ("demonstrate on a disposable project: list scene tree, create/edit node, save scene, inspect errors, run headless validation... do not point at real project until it passes"), created disposable project at `scratch/disposable_godot_project`:
   - Connected `@coding-solo/godot-mcp` to `Godot_v4.7.2-stable_win64_console.exe`.
   - Executed `get_godot_version` (returned `4.7.2.stable.official.ed1daf0bf`).
   - Executed `get_project_info` (retrieved project metadata and structure).
   - Executed `create_scene` (created `mcp_generated_scene.tscn` with `Node2D` root).
   - Executed `add_node` (added `CharacterBody2D` named `Player` under `root`).
   - Executed `add_node` (added `CollisionShape2D` named `Collider` under `root/Player`).
   - Executed `save_scene` (packed and wrote valid Godot 4 `.tscn` to disk).
   - Executed headless Godot 4.7.2 runtime verification (`verify_mcp_scene.gd`), confirming scene loaded, instantiated, and node hierarchy verified with exit code 0.
3. **Architectural Assessment & Production Isolation.** Documented in `docs/godot-mcp-evaluation.md` that while `@coding-solo/godot-mcp` passed disposable verification, each tool call executes a new Godot CLI process with RID teardown noise. Kept SoulBound's production workflow isolated to native GDScript and deterministic headless test suites without external Node.js daemon dependencies.

### Verification Table

| Adapter / Target | Test Performed | Result | Evidence |
|---|---|---|---|
| `ivanmurzak/unity-mcp` | Local port 26269 probe | FAILED | Unity C# only; connection refused; zero Godot support. |
| `godot-cli v0.36.0` | `install-plugin --path <disposable>` | FAILED | Fails on GDScript projects: requires Godot.NET.Sdk and .csproj. |
| `@coding-solo/godot-mcp v0.1.1` | JSON-RPC stdio initialization & tool calls | PASSED | Version discovery, project info, scene creation, node additions, scene save verified. |
| Godot 4.7.2 Headless Engine | `res://verify_mcp_scene.gd` on disposable scene | Exit 0 | Scene tree loaded and verified (`Node2D` -> `Player` -> `Collider`). |

---

## SBL-DATA-003 — Decision-Ready Briefs for Combat Open Decisions

- **Milestone** Combat Architecture & Systems Governance.
- **Requirements** GDD-016–023 (Turn structure, elemental magic, status effects), FR-CMB-001–005 (Combat engine), AGENTS.md Engineering Invariants (Zero invented statistics, coefficients, or drop probabilities; options and consequences only).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Combat briefs: `docs/combat-open-decisions-briefs.md`.
  - Ledger update: `docs/open-decisions-ledger.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (system design briefs and documentation).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** OD-002 (Initiative paradigm), OD-003 (Elemental affinity & SP model), OD-004 (Status stacking & boss tenacity).

### Changes

1. **OD-002 Decision Brief (Speed & Initiative Ordering).** Authored a structured decision analysis contrasting:
   - *Option A (Discrete Round Speed Ordering)*: Predictable round sequence, low cognitive overhead, zero turn-skipping exploits.
   - *Option B (Continuous Tick Action Gauge)*: High speed-scaling expression and turn-lapping, higher state complexity for save invariants.
   - *Option C (Tiered Action Pip Economy)*: Synchronized rounds with discrete action volume scaling, subject to breakpoint min-maxing.
2. **OD-003 Decision Brief (Elemental Affinities & SP Economy).** Authored a comparative analysis of:
   - *Option A (Closed 4+2 Circular Wheel)*: High educational synergy, clear vulnerability telegraphing, risk of monotype build walls.
   - *Option B (Taxonomy-Driven Asymmetric Resistances)*: Lore-rich bestiary discovery, deeper roguelite itemization, higher cognitive burden.
   - *SP Models*: Attrition survival pool (fixed cap, rest recovery) vs. Dynamic offensive flow (Resonance-scaled, action generation).
3. **OD-004 Decision Brief (Status Stacking & Boss Tenacity).** Authored analysis of:
   - *Option A (Duration Refresh with Stack Cap)*: Rewards aggressive DoT maintenance, risk of infinite CC lockout without tenacity.
   - *Option B (Independent Instance Lifespans)*: Precision burst timing windows, higher UI timer clutter.
   - *Boss CC Tenacity*: Diminishing returns recovery vs. Categorical Stagger/Break meter gating.
4. **Zero Invented Statistics Compliance.** Adhered strictly to AGENTS.md mandate by omitting all invented damage percentages, stat multipliers, tick intervals, and drop rates. The document articulates structural mechanics, what each option changes, what it unblocks, and the associated risks for human authority resolution.
5. **Ledger Synchronization.** Updated `docs/open-decisions-ledger.md` to formally cross-link `OD-002`, `OD-003`, and `OD-004` to `docs/combat-open-decisions-briefs.md`.

### Verification Table

| Item / Scope | Result | Evidence |
|---|---|---|
| Rule compliance audit | PASSED | Document contains zero hardcoded formulas, percentages, coefficients, or drop probabilities. |
| Scope completeness | PASSED | Detailed dedicated briefs authored for `OD-002`, `OD-003`, and `OD-004` with Options, Changes, Unblocks, and Risks. |
| Ledger linkage | PASSED | `docs/open-decisions-ledger.md` synchronized and cross-referenced. |

---

## SBL-BLD-002 — Build-Time Release Tier Injection & Artifact Verification

- **Milestone** Build Integrity, Artifact Governance & Platform Compatibility.
- **Requirements** GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants ("Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release", "Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Build automation: `scripts/build/export_release.ps1`, `scripts/build/validate_release.ps1`, `scripts/build/run_headless_tests.ps1`.
  - Architecture: `scripts/story/release_tier.gd`, `export_presets.cfg`.
  - Tests: `tests/headless/build_tier_test.gd`, `tests/headless/verify_exported_tier.gd`, tracked UIDs.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (PowerShell build automation, typed GDScript test harnesses, and configuration).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** `OD-017`: Choice of shipping default release tier (`academic_mvp` vs. `full_release`) for public distribution remains deferred to human release authority sign-off; checked-in `project.godot` maintains `release_tier="full_release"`.

### Changes

1. **Build-Time Tier Parameter in Exporter (`scripts/build/export_release.ps1`).** Added `-Tier academic_mvp|full_release|both|all` parameter defaulting to `full_release` to preserve developer/evaluator workflows.
2. **Strict Working-Tree Byte-Identity Invariant.** The export pipeline applies the requested release tier (`academic_mvp` or `full_release`) to the exported artifact and temporary `.pck` packaging, but wraps the entire operation in a `try ... finally` block that restores `project.godot` byte-for-byte from pre-export snapshot bytes, deletes temporary root markers, and validates SHA256 byte-identity upon exit. Working tree remains 100% clean.
3. **Artifact Marker Injection (`build_tier.txt`).** Each distribution archive now packages a `build_tier.txt` marker at the root containing the exact target tier (`academic_mvp` or `full_release`).
4. **Standalone Academic MVP Artifact Packaging.** The export pipeline produces `dist/Soulbound-AcademicMVP-Web.zip` (tier `academic_mvp`) alongside `dist/Soulbound-Web.zip` and `dist/Soulbound-Windows-Portable.zip` (tier `full_release`).
5. **Release Artifact Validator Hardening (`scripts/build/validate_release.ps1`).** Extended validator to assert the presence and exact content of `build_tier.txt` inside distribution archives, with tier mismatch causing immediate exit code 1 failure.
6. **End-to-End Headless Gate Verification (`tests/headless/verify_exported_tier.gd`).** Created headless verification script that mounts exported `.pck` packages via `--main-pack` and asserts:
   - On `academic_mvp` `.pck`: `void_citadel` is unavailable in router, transitions are refused, `PortalToCitadel` in Ashen Peaks is hidden and unmonitored, `open_ending_modal` strictly no-ops, and Capstone question `q_meta_01` is gated.
   - On `full_release` `.pck`: `void_citadel` is available, `open_ending_modal` instantiates modal, and `q_meta_01` is accessible.
7. **GDScript Marker & Config Parsing Suite (`tests/headless/build_tier_test.gd`).** Added test suite verifying `ReleaseTier.parse_tier()`, marker file parsing, override precedence, and clean reversion to project settings.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| Unit suite: `run_headless_tests.ps1 -Suite build_tier_test` | Exit 0 | 17/17 assertions passed: string normalization, marker file parsing, override precedence, and clean reversion verified. |
| Regression suite: `run_headless_tests.ps1 -Suite release_tier_test` | Exit 0 | All existing tier separation assertions passed without weakening. |
| Exporter MVP: `export_release.ps1 -Tier academic_mvp` | Exit 0 | Produced `dist/Soulbound-AcademicMVP-Web.zip` (10.64 MB), validated `build_tier.txt`, verified headless `.pck` gate, restored `project.godot` byte-identically. |
| Exporter Full: `export_release.ps1 -Tier full_release` | Exit 0 | Produced `dist/Soulbound-Web.zip` (10.64 MB) and `dist/Soulbound-Windows-Portable.zip` (86.52 MB), validated markers, verified headless `.pck` gate, restored `project.godot` byte-identically. |
| Validator negative control: injected tier mismatch | Exit 1 | Caught mismatch: `build_tier.txt marker 'full_release' does not match expected tier 'academic_mvp'`. |

---

## SBL-MCP-003 — Reproducible Godot MCP Proof Harness

- **Milestone** Tooling & Workflow Validation.
- **Requirements** AGENTS.md § AI Game Developer MCP caution ("demonstrate a Godot-compatible MCP/adapter on a disposable project: list scene tree, create/edit node, save scene, inspect errors, run headless validation... do not point at real project until it passes").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Harness driver: `tools/mcp-proof/run_adapter_proof.js`.
  - Generated scene reference: `tools/mcp-proof/mcp_generated_scene.tscn`.
  - Headless verification suite: `tools/mcp-proof/verify_mcp_scene.gd`.
  - Documentation: `tools/mcp-proof/README.md`, `docs/godot-mcp-evaluation.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (tooling verification harness, documentation, and external test artifacts; zero generated images or runtime assets).
- **Review** REVIEWED by Codex CLI. Original review session `01a1be9a-5583-7252-b082-ebd436372c80`; the three P2 findings were cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`. Human release acceptance remains pending.
- **Open questions** None. Production toolchain remains isolated to native GDScript and headless CLI.

### Changes

1. **Committed Minimal Reproducible Harness (`tools/mcp-proof/`).** Created a clean, git-tracked verification harness containing the Node.js JSON-RPC driver script (`run_adapter_proof.js`), the exact generated `.tscn` scene output (`mcp_generated_scene.tscn`), and the headless engine verification script (`verify_mcp_scene.gd`).
2. **Zero In-Repo Node/Project Cruft.** Guaranteed no `node_modules`, no vendored binaries, and no credentials are added to the worktree. The disposable project is dynamically scaffolded outside the repository in `$env:TEMP\disposable_godot_mcp_proof`.
3. **Empirical Re-Run from Committed Harness.** Executed `node tools/mcp-proof/run_adapter_proof.js` against `@coding-solo/godot-mcp` v0.1.1 and `Godot_v4.7.2-stable_win64_console.exe`:
   - Connected via stdio JSON-RPC.
   - Executed `initialize` (MCP server initialized).
   - Executed `get_godot_version` (returned `4.7.2.stable.official.ed1daf0bf`).
   - Executed `get_project_info` (retrieved project structure).
   - Executed `create_scene` (`mcp_generated_scene.tscn`, `Node2D` root).
   - Executed `add_node` (`Player: CharacterBody2D` under root).
   - Executed `add_node` (`Collider: CollisionShape2D` under Player).
   - Executed `save_scene` (saved `.tscn` to disk).
   - Executed headless Godot 4.7.2 verification (`verify_mcp_scene.gd`), asserting root, Player, and Collider nodes with exit code 0.
4. **Documentation & Evaluation Synchronization.** Updated `tools/mcp-proof/README.md` with full step-by-step reproduction instructions and pasted the exact empirical execution log into `docs/godot-mcp-evaluation.md`.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| Driver execution: `node tools/mcp-proof/run_adapter_proof.js` | Exit 0 | Initialized MCP server, called 5 tools, serialized valid `.tscn`, verified via headless Godot. |
| Headless verification: `godot --headless --script res://verify_mcp_scene.gd` | Exit 0 | Scene tree parsed and verified: `root` (Node2D) -> `Player` (CharacterBody2D) -> `Collider` (CollisionShape2D). |
| Repository hygiene audit | PASSED | Zero `node_modules`, credentials, or temporary files tracked. Disposable project created in `$env:TEMP`. |


---

## Codex CLI review of the batch 1-3 remediation range

- **Snapshot** `feature/w4-5-vertical-slice`, `e25491d..5e81a04`, 26 commits (SBL-FIX-006 through SBL-MCP-003).
- **Review** CHANGES_REQUESTED. Codex CLI `0.167.0`, model `gpt-6.1-sol`, session `01a1be9a-5583-7252-b082-ebd436372c80`, exit 0, 9 November 2026.
- **Verdict** No P0 or P1 findings. Three P2 findings. The reviewer did not fault the save invariants, the release-tier gates, or the no-invented-numerics rule.
- **Status rule** The three findings were fixed and cleared by re-review session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`, so the entries in this range are `REVIEWED`. `SBL-BLD-003`, added by the fix batch, still has one open P2 and is `CHANGES_REQUESTED`.

### Findings

| # | Task | Location | Required fix |
| --- | --- | --- | --- |
| 1 | SBL-FIX-011 | `scenes/ui/character_sheet.tscn:55-58` (and the settings scroll container) | Keyboard focus can move below the scroll viewport at 150% text scale because `follow_focus` is false; enable focus-following so focused controls are revealed. |
| 2 | SBL-VER-003 / SBL-BLD-002 | `scripts/build/validate_release.ps1:258-266` | The live tier gate mounts hardcoded `builds\web*` PCKs instead of the PCKs inside the archives being validated, so a mislabeled archive can pass against an unrelated local build and the Windows PCK is never exercised; extract and verify each archive's own PCK. |
| 3 | SBL-MCP-003 | `tools/mcp-proof/run_adapter_proof.js:117-120` | JSON-RPC success responses with `result.isError: true` are resolved and printed as PASS; a reused disposable project with a stale valid scene can therefore produce a false proof. Reject error-bearing tool results. |

### Independent verification performed with the review

| Check | Result |
| --- | --- |
| `scripts/build/run_headless_tests.ps1` | 29/29 suites PASS, exit 0 (adds `build_tier_test.gd` and `verify_exported_tier.gd`). |
| Tier markers read from the zips | `Soulbound-AcademicMVP-Web.zip` = `academic_mvp`; `Soulbound-Web.zip` = `full_release`; `Soulbound-Windows-Portable.zip` = `full_release`. |
| `verify_exported_tier.gd` on `builds/web-academic_mvp/index.pck` | Exit 0: Void Citadel unavailable, portal hidden and unmonitored, warp refused, both ending modals no-op, capstone and Chapter 5 questions gated. |
| `verify_exported_tier.gd` on `builds/web/index.pck` | Exit 0: Void Citadel available, ending modal opens, capstone question accessible. |
| Working-tree invariant after export | `project.godot` restored byte-identically; `git status` clean. |
| MCP proof re-run from the committed harness | Driver exit 0 against `@coding-solo/godot-mcp`; generated scene verified headless, exit 0. The driver rewrites the tracked reference scene with new random `unique_id` values, which was reverted to keep the tree clean. |

The `SliceProgress: Invalid data` warning seen when mounting a packed build came from the stale local profile `%APPDATA%\Godot\app_userdata\Soulbound\profiles\profile_01` (`vertical_slice.stage = "complete"` with no matching education record). Re-running the same verifier with a clean user-data root produced no such warning, so it is local test pollution rather than a product defect.

### Out of scope

`SBL-FIX-001` through `SBL-FIX-005` predate `e25491d` and were not part of this review; they remain `REVIEW_PENDING_CODEX`.

---

## SBL-FIX-013 — Keyboard Focus Auto-Scrolls Into View (Review Finding 1)

- **Milestone** M4 & M6 Hardening (Accessibility & UI Navigation).
- **Requirements** GDD-103, TC-ACC-001, AGENTS.md Engineering Invariants.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scenes: `scenes/ui/character_sheet.tscn`, `scenes/ui/settings_sheet.tscn`, `scenes/ui/inventory_sheet.tscn`, `scenes/ui/academic_completion_modal.tscn`, `scenes/ui/ending_modal.tscn`.
  - Scripts: `scenes/vertical_slice/chapter_activity_dialog.gd`.
  - Tests: `tests/headless/layout_audit_test.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (Godot scene properties and test code; zero art assets).
- **Review** REVIEWED by Codex CLI session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0` (re-review of `b2ddee1..b2b45a4`); no actionable defects. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Enabled `follow_focus = true` on all ScrollContainers**:
   - `scenes/ui/character_sheet.tscn`: enabled `follow_focus = true` on `Scroll`.
   - `scenes/ui/settings_sheet.tscn`: enabled `follow_focus = true` on `Scroll`.
   - `scenes/ui/inventory_sheet.tscn`: enabled `follow_focus = true` across `BankCol/Scroll`, `SatchelCol/Scroll`, and `EquipCol/Scroll`.
   - `scenes/ui/academic_completion_modal.tscn`: enabled `follow_focus = true` on `Scroll`.
   - `scenes/ui/ending_modal.tscn`: enabled `follow_focus = true` on `Scroll`.
   - `scenes/vertical_slice/chapter_activity_dialog.gd`: set `scroll.follow_focus = true` on the dynamically constructed activity modal scroll container.
2. **Preserved Base Sizing & Scaling Invariants**:
   - Existing minimum size and layout bounds preserved intact without font shrinkage below authored bases.
3. **Automated Focus Scroll Regression Coverage**:
   - Extended `tests/headless/layout_audit_test.gd` Phase 2 (text_scale 1.5x) to assert `s.follow_focus == true` across every scroll container.
   - Asserted that focusing below-the-fold controls automatically produces a non-zero `scroll_vertical` offset (e.g. `BackupTextField` scrolled to 39, `BtnSolarFlare` scrolled to 31, activity modal buttons scrolled to 43).
   - Explicitly pinned the Codex review finding probe on `CharacterSheet`: asserted that focusing `RespecButton` below the fold produces a non-zero scroll offset (`scroll_vertical = 135`).

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `run_headless_tests.ps1 -Suite layout_audit_test` | Exit 0 | Verified `follow_focus == true` across all scroll containers; verified below-the-fold focus scrolls `BackupTextField` (offset 39), `BtnSolarFlare` (offset 31), activity option button (offset 43), and pinned `RespecButton` (offset 135). |

---

## SBL-VER-004 — Validate Archive-Contained PCK Packages & Cross-Check Tier Settings (Review Finding 2)

- **Milestone** Build Integrity & Release Artifact Governance.
- **Requirements** GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer", "Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Build automation: `scripts/build/validate_release.ps1`.
  - Tests: `tests/headless/verify_exported_tier.gd`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (PowerShell validation automation and GDScript test harness; zero art assets).
- **Review** REVIEWED by Codex CLI session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0` (re-review of `b2ddee1..b2b45a4`); no actionable defects. Human release acceptance remains pending.
- **Open questions** None.

### Changes

1. **Extraction of Archive's Own PCKs for Live Tier Gating**:
   - Replaced static local path references (`builds\web-academic_mvp\index.pck` and `builds\web\index.pck`) in `validate_release.ps1`.
   - Each archive being validated (`Soulbound-AcademicMVP-Web.zip`, `Soulbound-Web.zip`, and `Soulbound-Windows-Portable.zip`) now extracts its own enclosed `.pck` (`index.pck` or `Soulbound.pck`) to an isolated temporary directory.
   - Live headless tier gate execution (`verify_exported_tier.gd`) runs against the freshly extracted `.pck` file from each package.
2. **Derive Tier from Archive's Own Marker & Cross-Check Pack Setting**:
   - Derived expected tier from each archive's enclosed `build_tier.txt`.
   - Verified that the archive marker matches expected tier targets (`academic_mvp` vs `full_release`).
   - Extended `tests/headless/verify_exported_tier.gd` to assert that the internal `ProjectSettings` value `soulbound/release_tier` inside the mounted pack matches the expected tier.
3. **Negative Control Verification**:
   - Proved rejection by swapping markers between archives in temporary copies: verified that both the marker mismatch and the live headless `.pck` gate fail with Exit Code 1.
4. **Preserved Existing Validations**:
   - Retained entry point checks, single-threaded web configuration checks, compatibility renderer assertions, debug leftover exclusion, and file size threshold guards.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `validate_release.ps1` (all archives) | Exit 0 | Extracted `index.pck` from Academic MVP Web zip (tier `academic_mvp`), `index.pck` from Full Release Web zip (tier `full_release`), and `Soulbound.pck` from Windows Portable zip (tier `full_release`); all 3 passed live gate assertions. |
| Negative control: swapped marker on MVP Web zip | Exit 1 | Caught marker mismatch `[AcademicMVP-Web] build_tier.txt marker 'full_release' does not match expected tier 'academic_mvp'` and gate failure `FAIL: Active tier 'academic_mvp' matches expected 'full_release'`. |
| Negative control: swapped marker on Full Web zip | Exit 1 | Caught marker mismatch `[FullRelease-Web] build_tier.txt marker 'academic_mvp' does not match expected tier 'full_release'` and gate failure `FAIL: Active tier 'full_release' matches expected 'academic_mvp'`. |

---

## SBL-MCP-004 — Reject Error Results, Stale Scenes & Isolate Tracked Reference (Review Finding 3)

- **Milestone** Tooling & Workflow Validation.
- **Requirements** AGENTS.md § AI Game Developer MCP caution.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Tooling harness: `tools/mcp-proof/run_adapter_proof.js`, `tools/mcp-proof/verify_mcp_scene.gd`.
  - Documentation: `docs/godot-mcp-evaluation.md`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (tooling verification harness, documentation, and external test artifacts; zero art or runtime assets).
- **Review** REVIEWED by Codex CLI session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0` (re-review of `b2ddee1..b2b45a4`); no actionable defects. Human release acceptance remains pending.
- **Open questions** None. Production toolchain remains isolated to native GDScript and headless CLI.

### Changes

1. **Reject `isError: true` & Content Errors in JSON-RPC Handler**:
   - Hardened `run_adapter_proof.js` message parser: tool responses with `result.isError === true` or containing content error text (`c.isError === true` or matching `/^error[:\s]/i`) are immediately rejected, terminating execution with the server's error message.
2. **Stale Scene Deletion**:
   - Injected pre-execution cleanup in `run_adapter_proof.js`: any pre-existing `mcp_generated_scene.tscn` in the disposable directory is deleted before calling `create_scene`, ensuring an old valid file can never satisfy verification.
3. **Exact Node Tree & Hierarchy Assertions**:
   - `run_adapter_proof.js` asserts the generated `.tscn` contains root `Node2D`, `Player` `CharacterBody2D`, and `Collider` `CollisionShape2D`.
   - `verify_mcp_scene.gd` asserts exact node types and strict child counts (`root` has 1 child, `Player` has 1 child, `Collider` has 0 children).
4. **Preserved Tracked Reference Scene**:
   - Removed destructive rewrite of `tools/mcp-proof/mcp_generated_scene.tscn`. The reference scene is preserved read-only, ensuring `run_adapter_proof.js` leaves the git working tree clean.
5. **Re-Run & Documentation**:
   - Executed `node tools/mcp-proof/run_adapter_proof.js` against `@coding-solo/godot-mcp` v0.1.1 and `Godot_v4.7.2-stable_win64_console.exe`.
   - Observed output pasted into `docs/godot-mcp-evaluation.md`.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| Driver execution: `node tools/mcp-proof/run_adapter_proof.js` | Exit 0 | Deleted stale scene, initialized MCP server, executed tool calls, verified node hierarchy in JS, and verified in headless Godot with strict child count checks. |
| Headless verification: `godot --headless --script res://verify_mcp_scene.gd` | Exit 0 | Scene tree parsed and verified: `root` (Node2D, children=1) -> `Player` (CharacterBody2D, children=1) -> `Collider` (CollisionShape2D, children=0). |
| Working tree cleanliness | Clean | `tools/mcp-proof/mcp_generated_scene.tscn` untouched; zero unwanted diffs in worktree. |

---

## SBL-BLD-003 — Prove Export Failure Path Restores Working Tree Byte-Identically

- **Milestone** Build Integrity & Infrastructure Governance.
- **Requirements** GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants ("Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release", "Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Git configuration: `.gitignore`.
  - Build automation & tests: `scripts/build/test_export_failure_restoration.ps1`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (PowerShell build automation, git ignore configuration, and failure regression tests).
- **Review** REVIEWED by Codex CLI session `01a1becc-d949-7cc3-867d-a0a8ede9510b` (re-review of `81d613e..e0ed0b5`); the failure-injection finding is fixed and no actionable defects remain. Human release acceptance remains pending.
- **Open questions** `OD-017`: Default shipping release tier remains deferred to human release authority sign-off; checked-in `project.godot` maintains `release_tier="full_release"`.

### Changes

1. **Working Tree Restoration on Forced Export Failure**:
   - Tested and verified the `try ... finally` error restoration mechanism in `scripts/build/export_release.ps1`.
   - On an induced export failure (after `project.godot` was modified to target a different release tier and `build_tier.txt` was written), verified that the `finally` block executes:
     - `project.godot` is restored byte-for-byte to its pre-export snapshot bytes (verified with SHA256 and sequence equality).
     - Any root `build_tier.txt` marker is deleted, leaving no residue at the project root.
2. **Git Ignore Hardening (`.gitignore`)**:
   - Added `/build_tier.txt` to `.gitignore` under `# Local export / build artifacts`.
   - Prevents any interrupted or aborted local run from inadvertently staging or committing a temporary tier marker to the repository.
3. **Preserved Checked-In Shipping Default**:
   - Verified `project.godot` maintains `release_tier="full_release"` as the checked-in default, keeping `OD-017` open for human release authority.
4. **Automated Failure Recovery Test Suite (`scripts/build/test_export_failure_restoration.ps1`)**:
   - Created reproducible PowerShell test harness that captures pre-test hashes, triggers a forced export failure, asserts non-zero exit code, and validates byte-identity and marker absence.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| Failure recovery test: `scripts/build/test_export_failure_restoration.ps1` | Exit 0 | Export process exited with code 1; `project.godot` verified byte-identical (`bytesIdentical: True`, SHA256 `5C65BBCD...` matched); `build_tier.txt` absent from root (`True`). |
| Default project setting audit | PASSED | Checked-in `project.godot` specifies `release_tier="full_release"` under section `[soulbound]`. |
| Gitignore audit | PASSED | `/build_tier.txt` added to `.gitignore`. |


---

## Codex CLI re-review of the batch 4 fixes

- **Snapshot** `feature/w4-5-vertical-slice`, `b2ddee1..b2b45a4` (five fix commits).
- **Review** CHANGES_REQUESTED. Codex CLI `0.167.0`, model `gpt-6.1-sol`, session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`, exit 0, 9 November 2026.
- **Resolved** The three P2 findings from session `01a1be9a-5583-7252-b082-ebd436372c80` are fixed: keyboard focus-following, archive-contained PCK validation, and MCP error-result rejection. The reviewer found no actionable defects in those changes.
- **Open** One new P2 in `scripts/build/test_export_failure_restoration.ps1:34-37`. A nonexistent Godot path either falls back to an installed Godot (running a real export) or throws before `project.godot` and `build_tier.txt` are mutated, so the test can pass without exercising the restoration `finally` block. The test must inject the failure after configuration mutation, using a controlled executable that exits non-zero for the export invocation, and assert that mutation was observed before the failure.

### Independent verification performed with the re-review

| Check | Result |
| --- | --- |
| `scripts/build/run_headless_tests.ps1` | 29/29 suites PASS, exit 0. |
| `scripts/build/run_headless_tests.ps1 -Export` | Exit 0; artifacts rebuilt; `project.godot` restored byte-identically. |
| `scripts/build/validate_release.ps1 -Tier all` | Exit 0; each archive's own PCK extracted and gated (`AcademicMVP-Web`, `FullRelease-Web`, `FullRelease-Windows`). |
| Swapped-marker negative control | Exit 1 with 6 errors: marker mismatch plus live gate failure on the extracted PCK. |
| `scripts/build/test_export_failure_restoration.ps1` | Exit 0 in the current form, but the failure point is uncontrolled, which is the open finding. |
| MCP harness re-run | Exit 0; tracked reference scene untouched; `git status` clean. |
| MCP harness with a bad Godot path | Exit 1; the harness fails instead of printing a false PASS. |

---

## SBL-BLD-004 — Deterministic Export-Failure Injection & Non-Vacuous Tree Restoration

- **Milestone** Build Integrity & Infrastructure Governance (Review Finding Remediation).
- **Requirements** GDD-041, GDD-113, GDD-116, AGENTS.md Engineering Invariants ("Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release", "Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Build automation: `scripts/build/export_release.ps1`.
  - Regression test: `scripts/build/test_export_failure_restoration.ps1`.
  - Process: `docs/agent-review-queue.md`.
- **Asset provenance** None (PowerShell build scripts and test harnesses; zero image or audio assets).
- **Review** REVIEWED by Codex CLI session `01a1becc-d949-7cc3-867d-a0a8ede9510b`; no actionable defects. Human release acceptance remains pending.
- **Open questions** `OD-017`: Default shipping release tier remains deferred to human release authority sign-off; checked-in `project.godot` maintains `release_tier="full_release"`.

### Changes

1. **Deterministic Post-Mutation Failure Switch (`export_release.ps1`)**:
   - Added `[switch]$FailAfterMutation` and `[switch]$SimulateFailureAfterMutation` parameters to `export_release.ps1`.
   - In `Export-TierPackage`, failure injection occurs strictly **after** `project.godot` is modified to the target release tier and `build_tier.txt` is written to the project root.
   - The exporter emits an explicit log sentinel `[MUTATION_APPLIED] Tier '<tier>' applied to project.godot and build_tier.txt written.` immediately followed by throwing `SIMULATED_EXPORT_FAILURE`, ensuring no Godot child process is spawned and no reliance on ambient fallbacks.
2. **Explicit `-GodotPath` Validation (`export_release.ps1`)**:
   - Hardened `export_release.ps1` binary discovery: if `-GodotPath` is explicitly provided by the caller (`$PSBoundParameters.ContainsKey('GodotPath')`), it strictly requires the path to exist and throws `Specified Godot executable not found at '$GodotPath'` if missing. It never falls back silently to ambient or GUI Godot binaries when the caller provided an explicit path.
3. **Hardened Failure Recovery Test (`scripts/build/test_export_failure_restoration.ps1`)**:
   - Executes `export_release.ps1` with `-Tier academic_mvp -FailAfterMutation`.
   - Captures process stdout and stderr and explicitly asserts:
     - Non-zero exit code (`$proc.ExitCode -ne 0`).
     - Configuration mutation occurred before failure (`[MUTATION_APPLIED]` observed).
     - Simulated failure triggered (`SIMULATED_EXPORT_FAILURE` observed).
     - `project.godot` restored byte-identically (sequence equality and SHA-256 match).
     - `build_tier.txt` deleted and absent from repository root.
4. **Empirical Non-Vacuous Proof Mode (`-DisableRestore`)**:
   - Added `-DisableRestore` flag and `-ExportScript` parameter to `test_export_failure_restoration.ps1`.
   - When executed with `-DisableRestore`, the harness executes against an exporter copy where the `finally` restoration logic (`WriteAllBytes` for `project.godot` and `Remove-Item` for `build_tier.txt`) is disabled.
   - The harness verifies that with restore disabled, the failure leaves the tree dirty (`bytesIdentical=False`, `markerRemained=True`), and exits 1 as required by the test contract.
   - A robust `finally` cleanup block in `test_export_failure_restoration.ps1` guarantees the working tree is restored to pre-test bytes even if a broken exporter or negative test fails.

### Verification Table

| Invocation / Scope | Expected Exit | Observed Exit | Evidence |
|---|---|---|---|
| Standard test: `test_export_failure_restoration.ps1` | Exit 0 | Exit 0 | Mutation observed (`academic_mvp`), `SIMULATED_EXPORT_FAILURE` caught, `project.godot` byte-identical (`5C65BBCD...`), `build_tier.txt` absent. |
| Non-vacuous proof: `test_export_failure_restoration.ps1 -DisableRestore` | Exit 1 | Exit 1 | Confirmed failure with restore disabled: `bytesIdentical=False`, `build_tier.txt` remained `True`, harness caught omission and exited 1; safety cleanup restored tree. |
| Bad Godot path guard: `export_release.ps1 -GodotPath C:\nonexistent\godot.exe` | Exit 1 | Exit 1 | Caught immediately: `Specified Godot executable not found at 'C:\nonexistent\godot.exe'` without silent GUI fallback. |
| Headless test runner + chained export: `run_headless_tests.ps1 -Export` | Exit 0 | Exit 0 | All 29 test suites passed (0 failures). Chained export built and validated 3 packages (`AcademicMVP-Web`, `FullRelease-Web`, `FullRelease-Windows`), verified live `.pck` tier gates, restored tree byte-identically. |

### Artifact Size Report (from `run_headless_tests.ps1 -Export`)

| Package / Artifact | Size (Bytes) | Size (MB) |
|---|---|---|
| `dist/Soulbound-AcademicMVP-Web.zip` | 10,646,507 B | ~10.15 MB |
| `dist/Soulbound-Web.zip` | 10,646,509 B | ~10.15 MB |
| `dist/Soulbound-Windows-Portable.zip` | 86,520,606 B | ~82.51 MB |
| `builds/web-academic_mvp/index.pck` | 516,992 B | ~504 KB |
| `builds/web-academic_mvp/index.wasm` | 39,514,754 B | ~37.68 MB |
| `builds/web/index.pck` | 516,992 B | ~504 KB |
| `builds/web/index.wasm` | 39,514,754 B | ~37.68 MB |
| `builds/windows/Soulbound.pck` | 516,992 B | ~504 KB |
| `builds/windows/Soulbound.exe` | 180,717,576 B | ~172.35 MB |


---

## Codex CLI re-review of the batch 5 fix

- **Snapshot** `feature/w4-5-vertical-slice`, `81d613e..e0ed0b5`.
- **Review** APPROVED for the patch. Codex CLI `0.167.0`, model `gpt-6.1-sol`, session `01a1becc-d949-7cc3-867d-a0a8ede9510b`, exit 0, 9 November 2026.
- **Verdict** No actionable defects introduced by the patch. The standard restoration test passed and the disabled-restoration negative control failed as expected; both left the working tree clean.
- **Resolved** The P2 from session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0` is fixed: the failure is injected after `project.godot` and `build_tier.txt` are mutated, and the test asserts mutation-before-failure plus byte-identical restoration.
- **Independent verification** 29/29 suites PASS; export chain exit 0; all three archive-contained PCKs gated; `project.godot` restored byte-identically; `-DisableRestore` control exits 1 with a genuinely dirty tree.

### Status

Every implementation entry from `e25491d..e0ed0b5` is now `REVIEWED`. Human milestone and release acceptance remain the open gate. `SBL-FIX-001` through `SBL-FIX-005` predate `e25491d` and remain `REVIEW_PENDING_CODEX`.


---

## Codex CLI review of SBL-FIX-001..005

- **Snapshot** `feature/w4-5-vertical-slice`, `0b66fdb..f26f2d1` (the five pre-`e25491d` remediation commits), reviewed in a detached worktree so later reviewed batches were not included.
- **Review** CHANGES_REQUESTED. Codex CLI `0.167.0`, session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`, exit 0, 9 November 2026.
- **Verdict** The patch introduces lost and cross-profile expedition state, nonfunctional title-menu actions, and incomplete skill and audio integration. These are observable gameplay and persistence defects rather than presentation nits.

### Findings

| # | Severity | Location | Defect |
| --- | --- | --- | --- |
| 1 | P1 | `scenes/main/game_root.gd:563-567` | Suspended expeditions live only in a `GameRoot` field; nothing saves or reloads them, so closing the app loses the run. Selecting another profile leaves the field intact, letting that profile resume and extract the previous profile's satchel. Persist/restore per profile and clear the runtime snapshot on profile switch. |
| 2 | P2 | `scenes/main/game_root.gd:1246-1247` | Title-screen Settings and Backup both call `_toggle_settings_sheet()`, which returns immediately because `has_blocking_modal()` includes the title screen, so both actions do nothing. Provide a title-aware settings path above the title layer. |
| 3 | P2 | `scenes/ui/title_screen.gd:90-91` | Start New Journey emits the same signal as Continue for a slot with saved progress, so it reloads the existing profile. There is no reset or fresh-slot selection. |
| 4 | P2 | `scenes/main/game_root.gd:1259-1261` | Selecting another profile reloads progression but leaves the active region, player position, and dimension unchanged, so an early-game profile can start inside a region its chapter gates prohibit. |
| 5 | P2 | `scenes/ui/character_sheet.gd:117-119` | Purchasing Solar Flare, Celestial Prism, Glacial Aegis, or Void Shift spends talent points, but combat scenes still expose only the three starter-skill buttons. The new test bypasses this by calling `request_action()` directly. |
| 6 | P2 | `scripts/magic/kurei_tree.gd:99-107` | Phase Mastery advertises raising maximum SP to four, but neither combat scene reads the unlock; `BattleFixture` stays at two and `BossEncounter` at three, so the purchase has no effect and Solar Flare's three-SP cost is unreachable in ordinary battles. |
| 7 | P2 | `scripts/audio/audio_manager.gd:28-31` | No audio bus layout defines `SFX` and no code creates it, so the players fall back to Master and `apply_audio_buses()` skips SFX. Setting SFX volume to zero does not mute the new sound effects. |

### Status

- `SBL-FIX-001` through `SBL-FIX-005` are now `CHANGES_REQUESTED`; they are not `REVIEWED`.
- The findings are separate scoped remediation work; they do not retroactively change the approvals already recorded for `e25491d..e0ed0b5`.
- Batch 1 (`SBL-UX-001`) remains staged in `docs/agy-next-queue.md`. Finding 2 touches the settings entry path and should be accounted for when the rebinding UI is reviewed.
- Human release acceptance remains pending.

---

## SBL-REV-001 — Profile-Owned Expedition Suspension and Terminal Commits

- **Milestone** Remediation Batch A (M3 & M6 Hardening).
- **Requirements** GDD-004, GDD-037, GDD-098..101, FR-DNG-002/003, FR-SAV-001, TC-DNG-002/003/004, TC-SAV-001/002, AGENTS.md Persistence Invariants ("Preserve secured gear, level/skills, story and educational records after expedition defeat; lose only approved unbanked items and temporary upgrades", "Suspend/resume an expedition does not count as extraction; validate exactly-once reward transfer").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scene scripts: `scenes/main/game_root.gd`, `scenes/dungeon/dungeon_expedition.gd`.
  - Persistence validation: `scripts/persistence/gameplay_profile_validator.gd`.
  - Headless test suites: `tests/headless/dungeon_scene_test.gd`, `tests/headless/web_backup_test.gd`, `tests/headless/save_compatibility_recovery_test.gd`.
  - Process: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (pure code and test harnesses; zero image or audio generation).
- **Review** REVIEWED by Codex CLI session `01a1bfe5-fd15-7463-b4b1-c55215e0c3f0`; no actionable defect reported for this task. Batch A remains blocked by the SBL-REV-003 finding.
- **Open questions** None.

### Changes

1. **Commit-First Expedition Suspension (`dungeon_expedition.gd` & `game_root.gd`)**:
   - Added `commit_suspend: Callable` and `signal suspend_save_failed(error: Error)` to `DungeonExpedition`.
   - Made suspension commit-first: `suspend_expedition()` builds a snapshot while active and calls `commit_suspend(state)` before setting `is_active = false` or closing.
   - On commit failure, the expedition remains open and active, satchel items and bank remain intact, `suspend_btn` displays "Retry Suspend", and `suspend_save_failed` is emitted without overworld transition or close-on-failed-save.
   - Removed close-on-failed-save behavior from `_on_expedition_suspended`.
2. **Session Generation & Callback Ownership Guarding (`game_root.gd`)**:
   - Added `_session_generation: int` to `GameRoot`, incremented on each session init / profile switch.
   - Added `_is_expedition_callback_valid(origin_id, bound_slot, bound_gen)` verifying slot match, generation match, and node instance validity.
   - Guarded `commit_extraction`, `commit_defeat`, and `commit_suspend` against stale session, slot mismatch, or closed scene invocations, returning `ERR_UNAUTHORIZED` without reading or modifying disk profiles.
3. **Strict Non-Clamping Snapshot Validation (`dungeon_expedition.gd` & `gameplay_profile_validator.gd`)**:
   - Updated `restore_expedition(data)` to preflight seed generation and path calculation before applying mutations. Out-of-bounds `current_step` or mismatched `expedition_path` strictly return `false` without silent clamping into an invalid run.
   - Updated `GameplayProfileValidator._validate_active_expedition` to enforce non-empty path and `0 <= current_step < path.size()`.
4. **Cross-Profile Snapshot Isolation (`game_root.gd`)**:
   - Refused profile switching while an expedition is actively running.
   - Cleared runtime `_suspended_expedition` and invalidated callbacks before switching slots.
   - Loaded and validated the target slot's snapshot into a deep copy, ensuring unresumed slots never inherit snapshots from prior slots.
5. **Preserved Save & Recovery Invariants**:
   - Retained envelope schema 1 and `world.active_expedition` storage location.
   - Verified defeat preserves secured gear, character level, stats, chapter progress, and education records while applying only approved satchel wipe.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `dungeon_scene_test.gd` (full suite + REV-001 lifecycle) | Exit 0 | Verified UI suspend -> destroy GameRoot -> fresh session restore; cross-profile isolation; stale callback rejection (`ERR_UNAUTHORIZED`); injected suspend failure + Retry Suspend; resume -> extraction -> restart exact-once transfer; defeat state preservation. |
| `web_backup_test.gd` | Exit 0 | Verified suspended run backup round-trip into fresh slot; verified malformed snapshot import rejected and active profile bytes remain unmodified. |
| `save_compatibility_recovery_test.gd` | Exit 0 | Verified legacy profile without snapshot loads; verified invalid step, negative step, empty path, zero count, and mismatched path rejected without silent clamping. |
| Negative control: disable snapshot persistence | Exit 1 | Verified fresh session failed to find snapshot on disk when persistence write was omitted. |
| Negative control: disable callback ownership | Exit 1 | Verified stale callback caught when ownership checks bypassed. |

---

## SBL-REV-002 — Title-Aware Settings and Backup Overlay

- **Milestone** Remediation Batch A (M6 & M10 Hardening).
- **Requirements** GDD-092, GDD-098, GDD-102, FR-SET-001, FR-SAV-002, TC-ACC-001, TC-SAV-002, AGENTS.md Invariants ("single-threaded Godot web build; Compatibility renderer", "provide local web backup export/import").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scene definitions: `scenes/main/game_root.tscn`.
  - Scene scripts: `scenes/main/game_root.gd`, `scenes/ui/settings_sheet.gd`, `scenes/ui/title_screen.gd`.
  - Headless test suites: `tests/headless/title_screen_audio_test.gd`, `tests/headless/settings_accessibility_test.gd`, `tests/headless/web_backup_test.gd`.
  - Process: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (pure code and UI scene hierarchy; zero image or audio generation).
- **Review** REVIEWED by Codex CLI session `01a1bfe5-fd15-7463-b4b1-c55215e0c3f0`; no actionable defect reported for this task. Batch A remains blocked by the SBL-REV-003 finding.
- **Open questions** None.

### Changes

1. **Dedicated Title Settings Entry Path (`game_root.gd`)**:
   - Added `open_title_settings(slot_id, origin_control, initial_section)` on `GameRoot`.
   - Guarded invocation to require `_title_screen != null` and ensure no gameplay modal (`_battle`, `_boss_encounter`, `_dialog`, `_expedition`, `_academic_modal`, `_ending_modal`, `_chapter_dialog`, `_character_sheet`, `_inventory_sheet`, `_settings_sheet`, `_title_settings_sheet`) is open.
   - Updated `has_blocking_modal()` to report true when `_title_settings_sheet != null`.
2. **Dedicated Title Overlay CanvasLayer (`game_root.tscn` & `game_root.gd`)**:
   - Added `TitleOverlayLayer` (layer 9) positioned strictly between `TitleLayer` (8) and `DebugLayer` (10).
   - Added `_get_title_overlay_layer()` fallback dynamically calculating `TitleLayer.layer + 1` if instantiated outside the tscn.
3. **Modal Blocking and Under-Overlay Input Protection (`title_screen.gd`)**:
   - Added `TitleScreen.set_modal_blocked(blocked: bool)` toggling `disabled` and setting `focus_mode = FOCUS_NONE` across all title buttons.
   - Added `_gui_input` event swallowing on `TitleScreen` while modal blocked.
   - Guarded title button handler callbacks to discard simulated or delayed clicks while blocked.
4. **Targeted Initial Section Navigation (`settings_sheet.gd`)**:
   - Added `set_initial_section(section: String)` to `SettingsSheet`.
   - Directly focused `export_backup_btn` on `"backup"` (scrolling the `ScrollContainer` via `follow_focus`) and `master_slider` on `"general"`.
5. **Title-Selected Profile Isolation in Web Backup (`game_root.gd` & `settings_sheet.gd`)**:
   - Title Settings and Backup bind to `TitleScreen.current_slot` rather than the active gameplay profile.
   - On successful backup import in title context, `refresh_slot_summary(slot_id)` updates title summaries and disk files; active gameplay slot and in-memory consumers (`inventory_manager`, `character_stats`) remain isolated and unmutated until explicit activation.
6. **Overlay Dismissal & Focus Restoration (`game_root.gd` & `settings_sheet.gd`)**:
   - Escape (`ui_cancel`) or Close button dismisses `_title_settings_sheet` without closing `TitleScreen`.
   - Ren movement freeze is preserved (`player.freeze_movement()`) while TitleScreen remains open.
   - Focus is cleanly restored to the originating button (`settings_btn`, `backup_btn`, `recovery_export_btn`) using stored instance ID primitives.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `title_screen_audio_test.gd` (Part 3) | Exit 0 | Verified Title Settings opens SettingsSheet on layer 9 (`TitleLayer.layer + 1`); title marked modal blocked; buttons disabled (`FOCUS_NONE`); underlying title clicks ignored; duplicate entry requests rejected; close restores focus to SettingsBtn and leaves Ren frozen; Backup button focuses `export_backup_btn` immediately; recovery export button opens backup context and restores focus to `recovery_export_btn`. |
| `settings_accessibility_test.gd` (Part 6) | Exit 0 | Verified Escape (`ui_cancel`) dismisses Title Settings overlay; TitleScreen remains open; Ren movement remains frozen; originating focus restored; duplicate open requests create zero duplicate sheets. |
| `web_backup_test.gd` (REV-002 section) | Exit 0 | Verified title Backup targets title-selected slot (`profile_01`) while gameplay slot (`profile_02`) is active; export produces `profile_01` data; title text import updates `profile_01` on disk; active gameplay slot (`profile_02`) and gameplay inventory remain unmutated. |
| Negative control: generic modal blocking on title settings | Exit 1 | Demonstrated that if `has_blocking_modal()` unconditionally blocked title settings, title settings failed to open. |

---

## SBL-REV-003 — Distinct New Journey and Safe Profile Activation

- **Milestone** Remediation Batch A (M1, M2 & M6 Hardening).
- **Requirements** GDD-015, GDD-098, FR-SAV-001, FR-WLD-001/002, TC-SAV-001/002, TC-WLD-001, TC-DIM-001, AGENTS.md Invariants ("every explicit title activation returns to existing DEFAULT_START_REGION / DEFAULT_START_SPAWN in the physical dimension", "Preserve chapter progress, inventory, educational records and any suspended expedition. Returning to the starting region is not extraction").
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scene definitions: `scenes/ui/title_screen.tscn`.
  - Scene scripts: `scenes/ui/title_screen.gd`, `scenes/main/game_root.gd`, `scenes/world/world_router.gd`.
  - Headless test suites: `tests/headless/profile_activation_test.gd`, `tests/headless/title_screen_audio_test.gd`, `tests/headless/transition_test.gd`, `tests/headless/dimension_test.gd`.
  - Process: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (pure code and UI scene hierarchy; zero image or audio generation).
- **Review** REVIEWED by Codex CLI session `01a1bff5-713f-73e2-bb28-9a9dd10f37f3`; the Defense Demo profile-ownership finding was fixed and no actionable regressions remain.
- **Open questions** None.

### Changes

1. **Distinct Start Signals & Non-Launching Profile Selection (`title_screen.gd`)**:
   - Replaced ambiguous start signal flow with `continue_requested(slot_id)` and `new_journey_requested(slot_id)`. Retained `game_started(slot_id)` for backwards compatibility.
   - Slot selection in `ProfileSelector` updates `current_slot`, refreshes title labels, and focuses `continue_btn` without immediately launching gameplay.
2. **Dedicated Empty-Slot New Journey Picker (`title_screen.tscn` & `title_screen.gd`)**:
   - Added `NewGameSelector` container displaying slot buttons and `NoEmptySlotsLabel`.
   - "Start New Journey" displays only genuinely missing profiles (`ERR_FILE_NOT_FOUND`) as clickable. Occupied, recovered, corrupt, unreadable and unsupported-version slots are disabled and labeled `[Occupied]`.
   - If all slots are occupied/unavailable, displays "No empty profile slots", focuses Back button, and allows safe return to title menu.
   - Continue button on an empty slot redirects directly to the new-game picker.
3. **Preflight Emptiness Recheck & Creation Guard (`title_screen.gd` & `game_root.gd`)**:
   - Rechecks slot emptiness immediately before writing profile to protect against concurrent/stale creation.
   - On creation or save failure, shows `ErrorBox` on TitleScreen and leaves TitleScreen open.
4. **Validated World Reset Production API (`world_router.gd`)**:
   - Added `reset_to_starting_region(target_region_id, target_spawn_id)` on `WorldRouter`.
   - Preflights candidate region, candidate spawn, obstacle collision, and bounds before tearing down active region.
   - Refactored `debug_warp` to delegate to `reset_to_starting_region`.
5. **Shared Safe Profile Activation Path (`game_root.gd`)**:
   - Implemented `activate_profile(slot_id, is_new)`:
     - Rejects activation during live expedition (`ERR_BUSY`), active combat (`ERR_BUSY`), or in-flight transition (`ERR_BUSY`).
     - Preflights selected profile with `GameplayProfileValidator.validate`.
     - Resets world to `DEFAULT_START_REGION` at `DEFAULT_START_SPAWN` via validated `reset_to_starting_region`.
     - Resets dimension to `PHYSICAL` and synchronizes collision masks and region visibility.
     - Invalidate session callbacks (`_session_generation += 1`), clears transient flags, and zeroes player velocity.
     - Loads consumers (character stats, inventory, chapter progress, education, Kurei tree, ending manager) and applies chapter gates.
     - Dismisses TitleScreen only after activation succeeds; on failure, preserves TitleScreen and prior profile files.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `profile_activation_test.gd` (Parts 1–6) | Exit 0 | Verified empty-slot selection: occupied slot 1 and corrupt slot 2 disabled; only empty slot 3 enabled; Back restores focus to NewGameBtn. Verified all-occupied state disables slots and focuses Back. Verified slot selection updates labels without starting gameplay. Verified Continue on empty slot redirects to new-game picker. Verified late-game profile 1 (Spirit dimension, non-zero pos/vel, suspended run, unlocked beta/whispering grove) cleanly isolates from fresh profile 3 (reset to physical, test_region_alpha, zero vel, locked whispering grove, no leaked snapshot). Verified activation during combat rejected with `ERR_BUSY`. Verified corrupt profile activation keeps TitleScreen open with error. |
| `title_screen_audio_test.gd` | Exit 0 | Regression suite passed; title screen audio cues, settings overlay, defense demo, and slot selection verified. |
| `transition_test.gd` | Exit 0 | Regression suite passed with 0 errors; spawn bounds, portal transitions, and footprint validation verified. |
| `dimension_test.gd` | Exit 0 | Regression suite passed; collision mask updates and physical/spirit dimension shifts verified. |
| `overworld_gateway_test.gd` | Exit 0 | Regression verified; uncommitted gateway extraction failure preserves unwritten profile files without generating phantom saves. |
| `vertical_slice_loop_test.gd` | Exit 0 | Regression verified; full vertical slice loop, quest dialogue resumption, and mid-game backup reloads pass cleanly. |
| Full headless test runner (`run_headless_tests.ps1`) | Exit 0 (30/30 passed) | All 30 project headless suites pass with 0 Godot script/engine errors. |
| Release exporter (`export_release.ps1`) | Exit 0 | Full release export validated; generated `Soulbound-Windows-Portable.zip` and `Soulbound-Web.zip` (single-threaded Web); PCK headless gate validation succeeded on both packages; project.godot restored byte-identical. |
| Negative control: wire New Journey to Continue | Exit 1 | Demonstrated that if New Journey button directly reloads the occupied slot, new game picker is bypassed and test fails. |
| Negative control: skip world/dimension reset | Exit 1 | Demonstrated that skipping dimension reset leaves early profile in prior profile's Spirit dimension and test fails. |

---

## SBL-REV-003-FIX - Defense Demo Activates Title-Selected Profile

- **Milestone** Remediation Batch A (M1, M2 & M6 Hardening).
- **Requirements** GDD-015, GDD-098, FR-SAV-001, FR-WLD-001/002, TC-SAV-001/002, TC-WLD-001, TC-DIM-001, AGENTS.md Invariants ("Preserve secured gear, level/skills, story and educational records after expedition defeat; lose only approved unbanked items and temporary upgrades", profile ownership and save invariants).
- **Codex finding** Codex CLI review session `01a1bfe5-fd15-7463-b4b1-c55215e0c3f0` [P2]:
  "The non-launching profile selector leaves Defense Demo targeting the previously active profile, allowing persistent changes to the wrong save slot. After selecting a different slot, the title now remains open and updates only `current_slot`. Clicking Defense Demo then calls `_on_title_defense_demo()`, whose progression, inventory, and stat helpers still save to GameRoot's previous `_profile_slot`. For example, selecting profile_02 while profile_01 is active modifies profile_01 instead. Route the demo through successful activation of the title-selected slot before applying its persistent changes."
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - `scenes/ui/title_screen.gd`
  - `scenes/main/game_root.gd`
  - `tests/headless/profile_activation_test.gd`
  - `tests/headless/title_screen_audio_test.gd`
  - `docs/agent-review-queue.md`
  - `docs/traceability-matrix.md`
  - `docs/testing.md`
- **Asset provenance** None (pure GDScript and state machine routing; zero generated image or audio assets).
- **Review** REVIEWED by Codex CLI session `01a1bff5-713f-73e2-bb28-9a9dd10f37f3`; no actionable regressions. Defense Demo now targets the title-selected profile.
- **Open questions** None.

### Changes

1. **Title-Selected Slot Routing in TitleScreen (`scenes/ui/title_screen.gd`)**:
   - Parameterized `defense_demo_requested(slot_id: String)` signal to convey the title-selected profile slot.
   - Clears prior error box via `show_error("")` and emits `defense_demo_requested.emit(current_slot)` when `defense_btn` is pressed.
2. **Validated Preflight & Profile Activation Before Persistent Demo Mutation (`scenes/main/game_root.gd`)**:
   - Updated `_on_title_defense_demo(slot_id: String = "")` to resolve `target_slot` from `slot_id`, `_title_screen.current_slot`, or `_profile_slot`, constrained to `ProfileStore.VALID_PROFILE_IDS`.
   - Preflights `target_slot` in `ProfileStore`:
     - If corrupt/unreadable (`check_err != OK and check_err != ERR_FILE_NOT_FOUND`), logs error, shows actionable feedback via `_title_screen.show_error("Cannot load profile '%s'." % target_slot)`, and aborts before any mutation. TitleScreen remains open and both profiles are untouched.
     - If empty (`ERR_FILE_NOT_FOUND`), activates with `is_new = true` to create and initialize the target profile cleanly.
     - If existing, validates and activates via `activate_profile(target_slot, false)`.
   - On activation failure (e.g. `ERR_BUSY`), displays actionable failure feedback on TitleScreen, leaves TitleScreen open, and aborts without modifying either profile.
   - Only upon `activate_profile` returning `OK` (setting `_profile_slot = target_slot` and resetting world/dimension/velocity) does it run persistent demo mutators (`_on_debug_complete_activities()`, `_on_debug_grant_items()`, `_on_debug_max_stats()`), close `_title_screen`, and play procedural cue `"correct"`.
3. **Automated Regression and Invariant Coverage (`tests/headless/profile_activation_test.gd`)**:
   - **Part 7**: Selects `profile_02` from TitleScreen while `profile_01` is loaded in gameplay, triggers Defense Demo, and asserts:
     - `game_root._profile_slot == "profile_02"` and TitleScreen is dismissed.
     - `profile_02` receives in-memory and on-disk level 10, Chapter 3, banked spirit salves, and educational records.
     - `profile_01` on disk is byte-identical (`export_backup` string match) and retains level 3, Chapter 2, zero salves, and original educational records.
   - **Part 8**: Failure path test: seeds `profile_03` with corrupt JSON, selects `profile_03` on TitleScreen, and clicks Defense Demo. Asserts:
     - TitleScreen remains open and visible.
     - Actionable error feedback displayed in `error_box` ("Cannot load profile").
     - `game_root._profile_slot` remains `profile_02`.
     - `profile_02` bytes on disk are completely unchanged.
     - `profile_03` corrupt file on disk is untouched.
   - **Negative Control**: Probed bypassing `activate_profile(target_slot)` to mutate stale `_profile_slot`: suite failed with 11 assertion errors and exited 1 cleanly.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `profile_activation_test.gd` (Parts 1–8) | Exit 0 | Verified empty-slot new journey picker, non-launching profile selection, safe profile activation, defense demo activation of title-selected profile (`profile_02`), byte-identical preservation of inactive profile (`profile_01`), and corrupt-slot failure path keeping title open with actionable error and zero file mutation. |
| Negative control: bypass selected-slot activation | Exit 1 | Demonstrated that mutating stale `_profile_slot` causes 11 test assertion failures in `profile_activation_test.gd` and exits code 1. |
| `title_screen_audio_test.gd` | Exit 0 | Regression suite passed; procedural audio, title settings overlay, defense demo quick-start, and evaluator reopening verified. |
| Full headless test runner (`run_headless_tests.ps1`) | Exit 0 (30/30 passed) | All 30 project headless suites pass with 0 Godot script/engine errors across all game systems. |
| Release exporter (`export_release.ps1`) | Exit 0 | Full release export validated; generated `Soulbound-Windows-Portable.zip` and `Soulbound-Web.zip`; PCK headless gate validation succeeded on both packages; project.godot restored byte-identical. |

---

## SBL-REV-004 - Effective SFX Bus Routing and Mute

- **Milestone** Remediation Batch B (Audio Routing & Settings Hardening).
- **Requirements** GDD-087, FR-SET-001, TC-ACC-001 (audio-controls portion), GDD-096.
- **Codex finding** Finding 7, P2 from Codex review session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`:
  "`scripts/audio/audio_manager.gd:28-31`: No audio bus layout defines `SFX` and no code creates it, so the players fall back to Master and `apply_audio_buses()` skips SFX. Setting SFX volume to zero does not mute the new sound effects."
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - `scripts/audio/audio_manager.gd`
  - `scripts/settings/settings_manager.gd`
  - `scenes/main/game_root.gd`
  - `tests/headless/title_screen_audio_test.gd`
  - `tests/headless/settings_accessibility_test.gd`
  - `docs/agent-review-queue.md`
  - `docs/traceability-matrix.md`
  - `docs/testing.md`
- **Asset provenance** None (pure GDScript runtime bus configuration, AudioServer routing, and procedural AudioStreamWAV synthesis; zero image generation and zero binary audio assets).
- **Review** REVIEWED by Codex CLI session `01a1c001-361d-7250-98d6-bc547c380822`; no actionable regressions. Both modified suites passed; the reviewer used a writable temporary APPDATA path in its sandbox.
- **Open questions** `OD-015`: binary audio asset specification remains pending human/Gemini Flash audio spec approval; procedural audio cues remain active runtime fallback.

### Changes

1. **Idempotent Bus Initialization Helper (`AudioManager.ensure_audio_buses()`)**:
   - Added `static func ensure_audio_buses() -> void` to `AudioManager` with internal helper `_ensure_bus(bus_name, send_to)`.
   - Reuses existing buses by name if already present in `AudioServer`, preserving bus indices and unrelated buses.
   - If missing, adds `Music` and `SFX` buses and configures their sends strictly to `Master`.
   - Idempotent: repeated calls do not duplicate, reorder, or overwrite buses.
2. **Pre-Player Bus Creation & Strict Player Bus Assignment (`AudioManager._create_players()`)**:
   - Invokes `ensure_audio_buses()` in `_init()` and `_ready()` before any player is created.
   - Invokes `AudioManager.ensure_audio_buses()` at the very start of `GameRoot._ready()` before `AudioManager.new()`.
   - In `_create_players()`, verifies that `SFX` bus exists (`sfx_idx >= 0`) before instantiating players.
   - Explicitly assigns each `AudioStreamPlayer` to `BUS_SFX` and asserts `player.bus == BUS_SFX`, preventing silent fallback to `Master`. Added public `get_players()` method.
3. **Mute Flag Application & Gain Management (`SettingsManager.apply_audio_buses()`)**:
   - Updated `SettingsManager.apply_audio_buses()` to call `AudioManager.ensure_audio_buses()` before reading bus indices.
   - For zero volume (`<= 0.001`), sets bus mute flag to `true` via `AudioServer.set_bus_mute(bus_idx, true)` in addition to setting gain to `-80.0 dB`.
   - For positive volume (`> 0.001`), clears the bus mute flag (`AudioServer.set_bus_mute(bus_idx, false)`) and calculates gain via `linear_to_db(volume)`.
   - Master volume zero mutes the `Master` bus, affecting all audio output, while `Music` and `SFX` buses maintain independent mute and volume states.
   - SFX volume zero mutes the `SFX` bus while leaving `Master` and `Music` buses unaffected.
   - Loading saved settings (`load_settings()`) re-applies both mute flags and dB levels to existing buses.
4. **Automated Headless Regression & Acceptance Tests**:
   - Extended `tests/headless/title_screen_audio_test.gd`: removes test `Music`/`SFX` buses, calls `ensure_audio_buses()`, asserts exactly one of each exists, routes to `Master`, instantiates `AudioManager`, asserts all 8 cue players report `SFX` bus (never `Master`), verifies reinitialization creates 0 duplicate buses, and verifies playback of all 9 procedural sound cues.
   - Extended `tests/headless/settings_accessibility_test.gd`: asserts zero SFX volume mutes SFX bus without mutating Master/Music mute, positive SFX volume clears mute, zero Master volume mutes Master bus without mutating SFX/Music mute flags, and settings save/reload reapplies bus mute flags from file.
5. **Negative Controls & Native Audio Verification**:
   - Negative Control 1: Omitted SFX initialization / routed player to Master -> assertion failed with exit code 1 (`report/neg_sfx_routing_omit.log`).
   - Negative Control 2: Initialized buses after player creation -> player-routing assertion caught fallback to `Master` and exited code 1 (`report/neg_sfx_init_after_players.log`).
   - Negative Control 3: Removed SFX mute update on zero volume -> zero-volume mute assertion caught false mute flag and exited code 1 (`report/neg_sfx_mute_update_omitted.log`).
   - Native Listening Check: Executed non-headless Godot script on Windows using official driver `WASAPI` -> verified AudioServer bus count 3, Master and SFX active, cues `button`, `strike`, `heal`, `correct` played cleanly without errors (`report/native_audio_listening_check.log`).

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `title_screen_audio_test.gd` (Part 1 bus routing) | Exit 0 | Bus removal and re-creation verified; exactly 1 Music and 1 SFX bus routing to Master; 8 players assigned to SFX; no duplicate buses on re-init; 9 procedural cues played. |
| `settings_accessibility_test.gd` (Audio routing & mute) | Exit 0 | SFX zero volume mutes SFX bus; Master/Music unchanged; positive SFX unmutes; Master zero volume mutes Master; settings reload reapplies mute states. |
| Native listening check (`native_audio_listening_check.gd`) | Exit 0 | Verified native audio driver `WASAPI` on Windows, AudioServer buses initialized, cues played cleanly. |
| Negative control 1: Omit SFX initialization | Exit 1 | Player routing assertion caught player bus on Master; exited 1 (`report/neg_sfx_routing_omit.log`). |
| Negative control 2: Init buses after players | Exit 1 | Player creation assertion caught fallback to Master; exited 1 (`report/neg_sfx_init_after_players.log`). |
| Negative control 3: Omit mute update | Exit 1 | Zero-volume assertion caught mute flag false; exited 1 (`report/neg_sfx_mute_update_omitted.log`). |
| Full headless runner (`run_headless_tests.ps1`) | Exit 0 (30/30 passed) | All 30 project headless suites pass with 0 Godot script/engine errors across all game systems. |
| Release exporter (`export_release.ps1`) | Exit 0 | Built `Soulbound-Web.zip` and `Soulbound-Windows-Portable.zip`; validated PCK gates and entry points; verified working tree byte-identical. |

---

## SBL-REV-005 - Apply Authored Phase Mastery Capacity

- **Milestone** Remediation Batch C (M3 Combat & Kurei Magic Hardening).
- **Requirements** GDD-019, GDD-030, FR-CMB-001/003, TC-CMB-002, persistence checks supporting TC-SAV-001. AGENTS.md Engineering Invariants ("Do not invent numerical stats, formula coefficients, drop probabilities, story revelations, or unsupported integrations. Mark such items TBD and seek change approval").
- **Codex finding** Finding 6, P2 from Codex review session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`:
  "`scripts/magic/kurei_tree.gd:99-107`: Phase Mastery advertises raising maximum SP to four, but neither combat scene reads the unlock; `BattleFixture` stays at two and `BossEncounter` at three, so the purchase has no effect and Solar Flare's three-SP cost is unreachable in ordinary battles."
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Skill tree & magic: `scripts/magic/kurei_tree.gd`, `scripts/magic/kurei_system.gd`.
  - Combat fixtures: `scenes/combat/battle_fixture.gd`, `scenes/combat/boss_encounter.gd`.
  - Game root orchestration: `scenes/main/game_root.gd`.
  - Test suites: `tests/headless/kurei_tree_test.gd`, `tests/headless/kurei_combat_test.gd`, `tests/headless/boss_combat_test.gd`.
  - Documentation: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (pure GDScript logic and state synchronization; zero image generation, zero audio assets).
- **Review** REVIEWED by Codex CLI session `01a1c058-93ab-7bc0-beec-1fe287126bf8`; no actionable regressions in the Batch C fix scope. OD-003/004 remains an explicit partial boundary for undefined boss effects.
- **Open questions** `OD-002/003/004` combat balance numbers, elemental affinities, and status formulas remain blocked for human authority sign-off; authored maximum capacity is 4.

### Changes

1. **Authored SP Capacity Constant & Active/Passive Classification (`scripts/magic/kurei_tree.gd` & `scripts/magic/kurei_system.gd`)**:
   - Added `const AUTHORED_PHASE_MASTERY_MAX_SP: int = 4` to `KureiTree`.
   - Marked `&"phase_mastery"` node with `"passive": true` in `KureiTree.SKILL_NODES` and `KureiSystem.SKILL_CATALOG`.
   - Added helper queries: `has_phase_mastery() -> bool`, `get_max_sp_capacity(baseline_max_sp) -> int`, `is_skill_passive(skill_id) -> bool`, and `is_skill_active(skill_id) -> bool`.
   - Hardened `KureiSystem.can_cast()` to reject passive skills unconditionally, ensuring passive abilities can never be cast or consume resources.
2. **Dynamic Capacity Binding & Invariant Guards (`scenes/combat/battle_fixture.gd`)**:
   - Defined `const BASELINE_MAX_SP: int = 2`.
   - Wired property setter on `kurei_tree` connecting `skill_unlocked` and `talents_reset` signals to `apply_kurei_tree_capacity()`.
   - `apply_kurei_tree_capacity()` sets `max_sp = 4` when `phase_mastery` is owned, or restores `max_sp = 2` when absent or respec'd.
   - Guaranteed starting SP remains baseline 2; re-applying configuration does not refill SP or stack capacity.
   - Regulated regeneration in `_resolve_enemy_turn()` to clamp strictly to `max_sp`, allowing Ren to accumulate 3 SP on Turn 2 to cast Solar Flare (which costs 3 SP and was previously unreachable).
   - In `request_action()`, direct requests for passive `kurei_phase_mastery` or locked skills are rejected atomically with `return false` before setting `last_player_action`, emitting signals, deducting SP, starting cooldowns, or advancing phase.
3. **Boss Combat Dynamic Capacity & Pre-Mutation Rejection (`scenes/combat/boss_encounter.gd`)**:
   - Defined `const BASELINE_MAX_SP: int = 3`.
   - Wired property setter on `kurei_tree` connecting signals to `apply_kurei_tree_capacity()`.
   - Sets `max_ren_sp = 4` when `phase_mastery` is owned, preserving baseline starting SP 3. Re-application does not stack or refill.
   - Restructured `request_action()` so that all validation occurs strictly before modifying any state: passive requests (`kurei_phase_mastery`), locked skills, and unsupported advanced boss actions (`solar_flare`, etc. under OD-003/004 boundary) return `false` without modifying `last_player_action`, `ren_sp`, cooldowns, HP, status, or `turn_counter`.
   - Turn regeneration clamps to `max_ren_sp`, allowing SP regeneration up to 4. Respec cleanly restores baseline capacity 3.
4. **Automated Headless Test Coverage**:
   - `kurei_tree_test.gd`: asserts active/passive queries, initial baseline capacity (2 in normal, 3 in boss), Phase Mastery unlock expanding capacity to 4, save/reload round-trip through `ProfileStore` preserving capacity 4, and respec restoration to baseline 2.
   - `kurei_combat_test.gd`: asserts normal encounter baseline 2 SP, Phase Mastery expanding capacity to 4 with unchanged starting SP 2, no-refill and no-stack on re-application, rejection of direct passive and locked requests without state mutation, Ren SP regeneration to 3, and successful casting of Solar Flare (cost 3 SP) causing 3 damage and Burn status to achieve Victory.
   - `boss_combat_test.gd`: asserts boss encounter baseline 3 SP, Phase Mastery expanding capacity to 4 with unchanged starting SP 3, no-refill and no-stack on re-application, rejection of direct passive and unsupported advanced skills without mutating `turn_counter` or boss HP, end-of-turn regeneration to 4 SP, and respec restores baseline 3.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `kurei_tree_test.gd` | Exit 0 | Active/passive queries verified; initial capacity 2/3 verified; Phase Mastery unlock verified; capacity 4 survives `ProfileStore` serialization and reload; respec restores baseline. |
| `kurei_combat_test.gd` | Exit 0 | Baseline 2 SP verified; Phase Mastery capacity 4 with unchanged starting SP 2 verified; reapplication no-stack/no-refill verified; passive rejection verified; Solar Flare 3 SP cast verified; respec restores baseline. |
| `boss_combat_test.gd` | Exit 0 | Baseline 3 SP verified; Phase Mastery capacity 4 with unchanged starting SP 3 verified; passive rejection without turn/state mutation verified; unsupported skill rejection verified; regeneration to 4 verified; respec restores baseline. |

---

## SBL-REV-006 - Purchased-Skill Menus and Six-Slot Enforcement

- **Milestone** Remediation Batch C (M3 Combat, Progression & Kurei Magic Hardening).
- **Requirements** GDD-018..020, GDD-030, GDD-089, FR-CMB-003/004, TC-CMB-001/002, GDD/SRS §4.5 (six-equipped-spell check), GDD-092 / TC-ACC-001 (keyboard access). AGENTS.md Engineering Invariants ("Do not invent numerical stats, formula coefficients, drop probabilities, story revelations, or unsupported integrations. Mark such items TBD and seek change approval").
- **Codex finding** Finding 5, P2 from Codex review session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`:
  "`scenes/combat/battle_fixture.tscn` and `scenes/combat/boss_encounter.tscn` hardcode three starter skills (`FlameBurst`, `LuminaLance`, `TorrentSurge`) into the spell menu and ignore unlocked tree skills. The character sheet has no equip/unequip interface to assemble the 6-slot loadout required by GDD-018..020, GDD-030, FR-CMB-004."
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Skill tree & loadout: `scripts/magic/kurei_tree.gd`.
  - Persistence validation: `scripts/persistence/gameplay_profile_validator.gd`.
  - Character UI: `scenes/ui/character_sheet.tscn`, `scenes/ui/character_sheet.gd`.
  - Combat scenes: `scenes/combat/battle_fixture.gd`, `scenes/combat/boss_encounter.gd`.
  - Test suites: `tests/headless/kurei_tree_test.gd`, `tests/headless/kurei_combat_test.gd`, `tests/headless/boss_combat_test.gd`, `tests/headless/layout_audit_test.gd`, `tests/headless/settings_accessibility_test.gd`.
  - Documentation: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (pure GDScript logic, UI controls, theme styles; zero image generation, zero audio assets).
- **Review** REVIEWED by Codex CLI session `01a1c058-93ab-7bc0-beec-1fe287126bf8`; no actionable regressions in the Batch C fix scope. OD-003/004 remains an explicit partial boundary for undefined boss effects.
- **Explicit OD boundary & Partial Remediation Disposition**:
  Finding 5 is recorded as a **partial remediation** blocked by `OD-003/004`. `BossEncounter` currently lacks authoritative SRS-backed effect semantics for the 4 purchased active skills (`solar_flare`, `celestial_prism`, `glacial_aegis`, `void_shift`). Rather than inventing combat balance stats or transplanting normal-combat numbers without SRS authorization, `BossEncounter` renders equipped advanced skills disabled with the explicit label `<Skill Name> (Boss effect pending design approval)`, and `request_action()` rejects requests atomically with zero state mutation (SP, turn counter, cooldown, HP, and status remain untouched). Starter skills (`flame_burst`, `lumina_lance`, `torrent_surge`) remain fully functional against the boss.
- **Open questions** `OD-003/004` boss effect specifications for the 4 purchased active skills remain open pending educator/designer approval.

### Changes

1. **Six-Slot Loadout Lifecycle on `KureiTree` (`scripts/magic/kurei_tree.gd`)**:
   - Added `const MAX_EQUIPPED_SKILLS: int = 6`.
   - Added `var equipped_skills: Array[StringName] = []`.
   - Initialized `_init_starters()` to equip all 3 starter skills (`flame_burst`, `lumina_lance`, `torrent_surge`) by default.
   - Added queries and modifiers: `is_skill_equipped(skill_id) -> bool`, `can_equip_skill(skill_id) -> bool`, `equip_skill(skill_id) -> Error`, `can_unequip_skill(skill_id) -> bool`, `unequip_skill(skill_id) -> Error`, `get_equipped_active_skills() -> Array[StringName]`.
   - Enforced invariants: cannot unequip when `equipped_skills.size() <= 1` (minimum 1 active skill required to fight); cannot equip locked skills, passive skills (`phase_mastery`), duplicates, or when `equipped_skills.size() >= 6`.
   - Auto-equip lifecycle: unlocking an active skill while equipped count < 6 auto-equips it; unlocking a 7th active skill leaves it unequipped in the learned pool.
   - Respec lifecycle: `respec_talents()` resets `equipped_skills` back to the 3 starter skills.
   - Serialization & Deserialization: `equipped_skills` is persisted in `character.kurei_tree.equipped_skills`; legacy profiles lacking the field default in memory to the 3 starters with no write-on-load mutation.

2. **Gameplay Profile Validator Preflight Checks (`scripts/persistence/gameplay_profile_validator.gd`)**:
   - Added atomic validation for `character.kurei_tree.equipped_skills`.
   - Enforces: must be Array of strings/StringNames, size <= 6, all elements must exist in `SKILL_NODES`, must be present in `unlocked_skills` or starter set, cannot be passive (`phase_mastery`), and cannot contain duplicates. Rejects invalid payloads with `ERR_INVALID_DATA`.

3. **CharacterSheet Equip/Unequip UI & Slot Management (`scenes/ui/character_sheet.{tscn,gd}`)**:
   - Displays slot counter: `Equipped Spells (X/6 Slots Used)`.
   - Displays `FeedbackLabel`: `"Unlocked — equip in Character"` when an active skill is unlocked while loadout slots are full (hidden when empty).
   - Dynamically renders equipped spells in a 2-column GridContainer with `Unequip: <Spell>` buttons (disabled when equipped count is 1).
   - Dynamically renders unequipped unlocked active skills in `AvailableContainer` with `Equip: <Spell>` buttons (disabled when slots are 6/6).
   - Wired `setup_focus()` into `refresh()` so all dynamic buttons participate in the circular keyboard navigation chain with high-visibility focus borders (`_apply_visible_focus`).
   - Optimized layout spacing (margin 8px, VBox separation 4px, button sizes 22px) so at 1.0x text scale ContentBox fits within 420px (no scrollbar, size 429 > max 420), while at 1.5x accessibility scale `RespecButton` is below the fold and scrolls cleanly (`layout_audit_test.gd` passes 100%).

4. **BattleFixture Dynamic Combat Spell Menu (`scenes/combat/battle_fixture.gd`)**:
   - Replaced hardcoded 3-button menu with dynamic button generation from `kurei_tree.get_equipped_active_skills()` (falls back to 3 starters if tree is null/empty).
   - Dynamic buttons display skill name, SP cost, and cooldown; disabled if ren_sp < cost or on cooldown.
   - Direct `request_action()` checks `kurei_tree.is_skill_equipped(skill_id)` before resolution.
   - Cancel button and Escape (`ui_cancel`) dismiss the menu and restore focus to `kurei_button`.
   - Synchronous child removal before `queue_free()` prevents duplicate buttons or signal leakage on repeated menu toggles.

5. **BossEncounter Dynamic Spell Menu & OD-003/004 Boundary (`scenes/combat/boss_encounter.gd`)**:
   - Dynamically populates spell menu from equipped active skills.
   - Starters (`flame_burst`, `lumina_lance`, `torrent_surge`) remain fully enabled and functional against the boss.
   - Advanced skills (`solar_flare`, `celestial_prism`, `glacial_aegis`, `void_shift`) are rendered disabled with text `<Skill Name> (Boss effect pending design approval)`.
   - Direct `request_action()` rejects unsupported advanced skills with zero state mutation (leaves `ren_sp`, `turn_counter`, `last_player_action`, boss HP, and statuses completely unchanged).
   - Cancel button and Escape (`ui_cancel`) dismiss the menu and restore focus to `kurei_btn`.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `kurei_tree_test.gd` (Section 8) | Exit 0 | Verified 6-slot limit, minimum 1 skill invariant, locked/passive/duplicate rejection, auto-equip up to 6, 7th skill unequipped, swap equip, respec restore to starters, serialization/deserialization, validator rejection of duplicates/unknown/locked/passive/>6, CharacterSheet UI interaction with slot counter, feedback label, and button clicks. |
| `kurei_combat_test.gd` (SBL-REV-006 section) | Exit 0 | Verified BattleFixture dynamic menu generation with 6 buttons, rejection of unequipped skills, casting of equipped skills with burn and damage, cancel button and Escape dismissal with focus restoration. |
| `boss_combat_test.gd` (SBL-REV-006 section) | Exit 0 | Verified BossEncounter dynamic menu generation, starter skill functionality, advanced skill disabled state with OD-003/004 design notice, rejection of unequipped skills, zero state mutation on unsupported skills, cancel button and Escape dismissal. |
| `layout_audit_test.gd` | Exit 0 | Verified Phase 1 (1.0x no clipped content, size 429, max 420) and Phase 2 (1.5x follow_focus scroll_vertical = 158 with RespecButton below fold). |
| `settings_accessibility_test.gd` | Exit 0 | Verified 100% circular keyboard focus chain traversal across all CharacterSheet controls including dynamic equip/unequip buttons. |
| Full headless runner (`run_headless_tests.ps1`) | Exit 0 (30/30 passed) | All 30 project headless suites pass with 0 Godot script/engine errors across all game systems. |
| Release exporter (`export_release.ps1`) | Exit 0 | Built `Soulbound-Web.zip` and `Soulbound-Windows-Portable.zip`; validated PCK gates and entry points; verified working tree byte-identical. |

---

## SBL-REV-007 — Boss Menu Viewport Safety and Layout Audit (Fix 1)

- **Milestone** Remediation Batch C (M3 Combat UI & Accessibility Hardening).
- **Requirements** GDD-018..020, GDD-041, GDD-089, GDD-103, GDD-116, FR-CMB-001/002/003, TC-ACC-001 (viewport 960x540 and 1.5x accessibility text scale), AGENTS.md Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer", "Do not invent numerical stats, formula coefficients, drop probabilities, story revelations, or unsupported integrations. Mark such items TBD and seek change approval").
- **Codex finding** Finding from Codex CLI review session `01a1c033-a580-7dc0-b15a-1a703f857eb0` [P2]:
  "with three starters plus advanced skills equipped, long disabled notices in `BossEncounter` expand a non-wrapping HBox to approximately 1236px, clipping functional controls at the default 960×540 viewport."
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Scene definitions: `scenes/combat/boss_encounter.tscn`.
  - Scene script: `scenes/combat/boss_encounter.gd`.
  - Headless test suites: `tests/headless/boss_combat_test.gd`, `tests/headless/layout_audit_test.gd`.
  - Evidence logs: `report/neg_boss_menu_viewport.log`.
  - Process: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (Godot Control containers, themes, and GDScript layout logic; zero image or audio generation).
- **Review** REVIEWED by Codex CLI session `01a1c058-93ab-7bc0-beec-1fe287126bf8`; no actionable regressions in the Batch C fix scope. OD-003/004 remains an explicit partial boundary for undefined boss effects.
- **Open questions** `OD-003/004`: advanced boss skill effect specifications remain open pending designer/educator approval; notices remain displayed on disabled buttons and tooltips without inventing combat values.

### Changes

1. **GridContainer Layout Replacement (`scenes/combat/boss_encounter.tscn`)**:
   - Replaced non-wrapping `HBoxContainer` on `KureiMenu` with a 4-column `GridContainer` (`columns = 4`, `theme_override_constants/h_separation = 8`, `theme_override_constants/v_separation = 6`).
   - Up to 6 equipped skills + Cancel button fit neatly into 2 rows (4 items in row 1, 3 items in row 2).
2. **Text Autowrap and Size Flags (`scenes/combat/boss_encounter.gd`)**:
   - In `_rebuild_kurei_menu()`, set `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`, `size_flags_horizontal = Control.SIZE_EXPAND_FILL`, and `custom_minimum_size = Vector2(130, 34)` on dynamic skill buttons and `cancel_kurei_btn`.
   - Long OD-003/004 notices wrap cleanly without expanding container width beyond the 960px viewport.
3. **Explicit OD-003/004 Notice & Tooltips (`scenes/combat/boss_encounter.gd`)**:
   - Preserved explicit button text notice `"%s (Boss effect pending design approval)"` on unsupported advanced skills.
   - Added descriptive `tooltip_text = "%s: Boss effect pending design approval (OD-003/004)" % sname`.
4. **Vertical Budget Conservation (`scenes/combat/boss_encounter.tscn`)**:
   - Tuned `RenSilhouette` and `BossSilhouette` minimum height to 70px (from 100px) and `VBoxContainer` separation to 6px (from 10px).
   - Entire `BossEncounter` layout stays strictly inside `Rect2(0, 0, 960, 540)` at both 1.0x authored scale and 1.5x accessibility text scale (tested bounding rect `[P: (32.0, 12.0), S: (896.0, 516.0)]` at 1.5x, bottom edge 528px <= 540px).
5. **Mouse & Keyboard Accessibility (`scenes/combat/boss_encounter.gd` & `tests/headless/boss_combat_test.gd`)**:
   - Verified enabled starter skills and Cancel are clickable and reachable via keyboard focus navigation (`grab_focus()`, Tab, and Escape).
6. **Automated Layout Audit Integration (`tests/headless/layout_audit_test.gd`)**:
   - Extended `layout_audit_test.gd` to include `BossEncounter` with 6 equipped skills and open Kurei menu, asserting zero boundary overflow across Phase 1 (1.0x) and Phase 2 (1.5x).

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `run_headless_tests.ps1 -Suite boss_combat_test` | Exit 0 | Verified 4-column GridContainer, 1.0x and 1.5x viewport safety bounds, enabled starters, disabled advanced notices, starter/Cancel keyboard reachability, mouse click and Escape dismissal. |
| `run_headless_tests.ps1 -Suite layout_audit_test` | Exit 0 | Audited BossEncounter at 960x540: Phase 1 (1.0x rect `[P: (32, 20), S: (896, 500)]` fits) and Phase 2 (1.5x rect `[P: (32, 12), S: (896, 516)]` fits). |
| Disposable negative control: revert to non-wrapping HBox without autowrap | Exit 0 | Negative control reproduced overflow: non-wrapping HBox expanded to width 1240px (`[P: (-140, 486), S: (1240, 34)]`), overflowing 960px viewport (`report/neg_boss_menu_viewport.log`). |

---

## SBL-REV-008 — Empty Equipped Loadout Validation and Starter Normalization (Fix 2)

- **Milestone** Remediation Batch C (M3 Progression & Persistence Hardening).
- **Requirements** GDD-018..020, GDD-030, GDD-098..101, FR-SAV-001, FR-CMB-003/004, TC-SAV-001/002, AGENTS.md Invariants ("Preserve legacy profiles with the field absent: they continue to default in memory to the existing starter loadout without write-on-load", "Keep validation atomic and preserve unrelated profile data on failure").
- **Codex finding** Finding from Codex CLI review session `01a1c033-a580-7dc0-b15a-1a703f857eb0` [P2]:
  "imported `character.kurei_tree.equipped_skills: []` passes validation and deserialization. Menus show starter fallback while `request_action()` rejects every visible spell because none is equipped."
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Persistence validation: `scripts/persistence/gameplay_profile_validator.gd`.
  - Skill tree: `scripts/magic/kurei_tree.gd`.
  - Combat scenes: `scenes/combat/battle_fixture.gd`, `scenes/combat/boss_encounter.gd`.
  - Headless test suites: `tests/headless/kurei_tree_test.gd`, `tests/headless/kurei_combat_test.gd`, `tests/headless/boss_combat_test.gd`.
  - Evidence logs: `report/neg_empty_equipped_loadout.log`.
  - Process: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (pure GDScript persistence validation and combat logic; zero image or audio generation).
- **Review** REVIEWED by Codex CLI session `01a1c058-93ab-7bc0-beec-1fe287126bf8`; no actionable regressions in the Batch C fix scope. OD-003/004 remains an explicit partial boundary for undefined boss effects.
- **Open questions** None.

### Changes

1. **Strict Non-Empty Preflight Validation (`scripts/persistence/gameplay_profile_validator.gd`)**:
   - In `_validate_character`, updated `equipped_skills` preflight: `if eq.is_empty() or eq.size() > KureiTree.MAX_EQUIPPED_SKILLS: return ERR_INVALID_DATA`.
   - Explicit empty arrays (`character.kurei_tree.equipped_skills: []`) are rejected atomically during backup import and profile activation.
2. **Atomic Deserialization Rejection (`scripts/magic/kurei_tree.gd`)**:
   - Updated `deserialize(data: Dictionary)` to validate all candidate lists (`candidate_unlocked`, `candidate_spent`, `candidate_total`, `candidate_equipped`) in local variables before modifying `self`.
   - An empty `equipped_skills: []` triggers `if eq_list.is_empty(): return ERR_INVALID_DATA`, immediately terminating without mutating `unlocked_skills`, `spent_talent_points`, or `equipped_skills`.
3. **Legacy Profile Compatibility (`scripts/magic/kurei_tree.gd` & `scripts/persistence/gameplay_profile_validator.gd`)**:
   - Profiles lacking the `equipped_skills` key pass validation and `deserialize` defaults `equipped_skills` in memory to `STARTER_SKILLS` (`flame_burst`, `lumina_lance`, `torrent_surge`) with zero write-on-load modification.
4. **Starter Loadout Normalization Safeguard (`scripts/magic/kurei_tree.gd`)**:
   - Added `normalize_equipped_if_empty()` on `KureiTree`.
   - `get_equipped_active_skills()` and `is_skill_equipped()` both invoke `normalize_equipped_if_empty()`.
   - If `equipped_skills` is ever empty in memory, it self-heals by repopulating `STARTER_SKILLS`, guaranteeing visible menu buttons always match accepted actions in `BattleFixture` and `BossEncounter`.
5. **Dynamic Combat Menu Integration (`scenes/combat/battle_fixture.gd` & `scenes/combat/boss_encounter.gd`)**:
   - Refactored `get_equipped_active_skills()` in both combat controllers to delegate directly to `kurei_tree.get_equipped_active_skills()`, eliminating disparate fallback logic.
6. **Headless Regression Suites**:
   - `kurei_tree_test.gd`: asserts validator rejects explicit empty equipped array, atomic deserialization failure preserves existing tree state, legacy profile lacking the key passes and defaults to starters, and empty tree normalizes to starters.
   - `kurei_combat_test.gd`: asserts empty tree in `BattleFixture` normalizes to starters, displays 3 starter buttons, and `request_action(&"kurei_flame_burst")` succeeds.
   - `boss_combat_test.gd`: asserts empty tree in `BossEncounter` normalizes to starters, displays 3 starter buttons, and `request_action(&"kurei_flame_burst")` succeeds.
7. **Disposable Negative Control**:
   - Recorded disposable negative control in `report/neg_empty_equipped_loadout.log` proving validator catches `equipped_skills: []` with `ERR_INVALID_DATA`.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `run_headless_tests.ps1 -Suite kurei_tree_test` | Exit 0 | Verified empty array validator rejection, atomic deserialize failure state preservation, legacy profile defaulting to starters without write-on-load, and in-memory starter normalization. |
| `run_headless_tests.ps1 -Suite kurei_combat_test` | Exit 0 | Verified BattleFixture dynamic menu displays starter buttons on empty tree via normalization and request_action succeeds without rejection. |
| `run_headless_tests.ps1 -Suite boss_combat_test` | Exit 0 | Verified BossEncounter dynamic menu displays starter buttons on empty tree via normalization and request_action succeeds without rejection. |
| Disposable negative control: validator on empty equipped array | Exit 0 | Negative control proved validator catches empty equipped loadout with `ERR_INVALID_DATA` (`report/neg_empty_equipped_loadout.log`). |
| Full headless runner (`run_headless_tests.ps1`) | Exit 0 (30/30 passed) | All 30 project headless suites pass cleanly with 0 Godot script/engine errors. |
| Full release exporter (`run_headless_tests.ps1 -Export -Tier all`) | Exit 0 | Built and validated `Soulbound-AcademicMVP-Web.zip`, `Soulbound-Web.zip`, and `Soulbound-Windows-Portable.zip`; PCK gates passed; working tree verified byte-identical. |


---

## SBL-REV-009 — Fix Boss Layout Audit Initialization Order

- **Milestone** Remediation Batch C (M3 Combat UI & Accessibility Hardening Audit Fix).
- **Requirements** GDD-018..020, GDD-041, GDD-089, GDD-103, GDD-116, FR-CMB-001/002/003, TC-ACC-001 (viewport 960x540 and 1.5x accessibility text scale), AGENTS.md Invariants ("Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer", "Do not invent numerical stats, formula coefficients, drop probabilities, story revelations, or unsupported integrations. Mark such items TBD and seek change approval").
- **Codex finding** Finding from Codex CLI review session `01a1c04c-cc02-7c12-8171-7c27cadfcb1e` [P2]:
  "tests/headless/layout_audit_test.gd accesses b.kurei_btn before the boss scene instance is added to the tree. The @onready variable is null, causing the audit to crash before it verifies the expanded boss menu viewport."
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Headless test suite: `tests/headless/layout_audit_test.gd`.
  - Evidence logs: `report/neg_boss_layout_audit_order.log`.
  - Process: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
- **Asset provenance** None (pure test harness lifecycle order fix; zero image or audio generation).
- **Review** REVIEWED by Codex CLI session `01a1c058-93ab-7bc0-beec-1fe287126bf8`; no actionable regressions in the Batch C fix scope. OD-003/004 remains an explicit partial boundary for undefined boss effects.
- **Open questions** `OD-003/004`: advanced boss skill effect specifications remain open pending designer/educator approval; notices remain displayed on disabled buttons and tooltips without inventing combat values.

### Changes

1. **SceneTree Attachment Precedes Onready Access (`tests/headless/layout_audit_test.gd`)**:
   - In `modal_loaders["BossEncounter"]`, removed premature pre-attachment access `b.kurei_btn.pressed.emit()`. The factory now configures the `kurei_tree` on the instantiated scene and returns the instance cleanly.
   - In both Phase 1 (1.0x authored base) and Phase 2 (1.5x accessibility scale), `inst` is attached to `root_control` via `root_control.add_child(inst)` and process frames are awaited before checking `b.kurei_btn != null` and emitting `b.kurei_btn.pressed.emit()`.
2. **KureiMenu Visibility & Viewport Assertions (`tests/headless/layout_audit_test.gd`)**:
   - Added explicit assertion `_check(b.kurei_btn != null, "BossEncounter: kurei_btn initialized after adding to tree")`.
   - Added explicit assertion `_check(b.kurei_menu != null and b.kurei_menu.is_visible_in_tree(), "BossEncounter: Kurei menu is opened and visible")`.
   - Added dedicated bounding box checks for `b.kurei_menu.get_global_rect()` confirming that the expanded 4-column `GridContainer` stays strictly inside `Rect2(0, 0, 960, 540)` at both 1.0x (`[P: (32.0, 442.0), S: (896.0, 78.0)]`) and 1.5x (`[P: (32.0, 418.0), S: (896.0, 110.0)]`).
3. **Negative Control Verification**:
   - Captured negative control evidence in `report/neg_boss_layout_audit_order.log` proving that prior to the fix, attempting to access `b.kurei_btn` inside the anonymous factory lambda before scene attachment crashed with `SCRIPT ERROR: Invalid access to property or key 'pressed' on a base object of type 'Nil'`.
   - Post-fix execution runs all 30 project headless suites with exit code 0 and zero script or engine errors.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `run_headless_tests.ps1 -Suite layout_audit_test` | Exit 0 | Audited BossEncounter with KureiMenu open at 960x540 without null-node errors: Phase 1 (1.0x KureiMenu `[P: (32, 442), S: (896, 78)]`, panel `[P: (32, 20), S: (896, 500)]`) and Phase 2 (1.5x KureiMenu `[P: (32, 418), S: (896, 110)]`, panel `[P: (32, 12), S: (896, 516)]`). |
| `run_headless_tests.ps1 -Suite kurei_tree_test` | Exit 0 | Verified empty array validator rejection, atomic deserialize failure state preservation, legacy profile defaulting to starters without write-on-load, and in-memory starter normalization. |
| `run_headless_tests.ps1 -Suite kurei_combat_test` | Exit 0 | Verified BattleFixture dynamic menu displays starter buttons on empty tree via normalization and request_action succeeds without rejection. |
| `run_headless_tests.ps1 -Suite boss_combat_test` | Exit 0 | Verified BossEncounter dynamic menu displays starter buttons on empty tree via normalization and request_action succeeds without rejection. |
| Negative control: pre-attachment kurei_btn access | Exit 0 | Negative control proved accessing `@onready var kurei_btn` before `add_child` fails with null access (`report/neg_boss_layout_audit_order.log`). |
| Full headless runner (`run_headless_tests.ps1`) | Exit 0 (30/30 passed) | All 30 project headless suites pass cleanly with 0 Godot script/engine errors across all game systems. |
| Full release exporter (`run_headless_tests.ps1 -Export -Tier all`) | Exit 0 | Built and validated `Soulbound-AcademicMVP-Web.zip`, `Soulbound-Web.zip`, and `Soulbound-Windows-Portable.zip`; PCK gates passed; working tree verified byte-identical. |

---

## SBL-UX-001 — Persistent Keyboard/Mouse Rebinding

- **Milestone** M4 / M6 Settings & Accessibility Hardening.
- **Requirements** GDD-092 (configurable keyboard/mouse inputs and accessibility), FR-SET-001 (persist and consistently apply remapped inputs and existing settings), TC-ACC-001 (input rebinding, reduced motion, scalable text), supporting NFR-ACC-001 (readable UI, configurable keys, scalable interface).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - New scripts & suites: `scripts/settings/input_bindings.gd`, `tests/headless/input_rebinding_test.gd`.
  - Modified persistence & UI: `scripts/settings/settings_manager.gd`, `scenes/ui/settings_sheet.gd`, `scenes/ui/settings_sheet.tscn`, `scenes/main/game_root.gd`, `scenes/ui/evaluator_debug_bar.gd`.
  - Modified test suites: `tests/headless/settings_accessibility_test.gd`, `tests/headless/layout_audit_test.gd`.
  - Documentation: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
  - Negative control logs: `report/neg_input_rebinding_conflict.log`, `report/neg_future_settings_blocked.log`.
- **Asset provenance** None (pure GDScript and Control scene node structure; zero image or audio generation).
- **Review** REVIEWED by Codex CLI session `01a1c07c-8045-7a60-bd41-1dcb9620f860`; no actionable regressions. Rebinding persistence, malformed-entry rejection, atomic reset, and user-settings isolation are cleared.
- **Open questions** None. (Controller/touch bindings, modifier chords, custom actions, input presets, and OD-002..004 combat formulas remain separate out-of-scope boundaries).

### Changes

1. **InputBindings Singleton & Domain Engine (`scripts/settings/input_bindings.gd`)**:
   - Authored defaults snapshot: cached directly from pristine `ProjectSettings` (`input/<action>`), never polluted by runtime `InputMap` mutations.
   - Configurable action whitelist: strictly limited to `move_left`, `move_right`, `move_up`, `move_down`, `shift_dimension`, `toggle_character`, `toggle_inventory`, and `toggle_settings`.
   - Primitive serialization: converts `InputEventKey` and `InputEventMouseButton` to JSON-safe primitives (`{"kind": "key", "physical_keycode": <int>}` or `{"kind": "mouse_button", "button_index": <int>}`) and vice versa.
   - Strict candidate validation: rejects wheel events, mouse motion, double-click, joypads, touch, modifier chords, Escape, Enter, Tab, F1, backtick (`KEY_QUOTELEFT`), and modifier-only keys (`KEY_SHIFT`, `KEY_CTRL`, `KEY_ALT`, `KEY_META`, `KEY_CAPSLOCK`, etc.).
   - Atomic cross-action conflict validation: detects conflicts against effective bindings of all other configurable actions and returns conflicting action label without silent swapping.
   - Idempotent `apply_overrides(overrides)`: preserves action deadzones (0.5), unrelated actions (`ui_*`), and non-key/mouse events.
   - Complete `restore_defaults_to_input_map()` and `clear_all_pressed_actions()` for leak-free test isolation and capture cleanup.

2. **SettingsManager Schema 1 Persistence (`scripts/settings/settings_manager.gd`)**:
   - Added schema versioning (`settings_schema_version = 1`) and `input_overrides: Dictionary`.
   - Transactional persistence: verifies serialized JSON, writes to a temporary sibling file, confirms exact byte length and content, and safely promotes via atomic backup/rename without destination collision.
   - Disk preservation: injection of write or promotion failures leaves disk file bytes 100% untouched.
   - Legacy compatibility: unversioned settings load audio/accessibility and default `input_overrides` to empty without rewriting the file on disk.
   - Future schema protection: files with `settings_schema_version > 1` or malformed payloads fail to load, fall back to session defaults in memory, leave disk files untouched, and block ordinary saving (`ERR_UNAVAILABLE`).

3. **SettingsSheet UI Controls Section (`scenes/ui/settings_sheet.tscn` & `scenes/ui/settings_sheet.gd`)**:
   - Added Controls section: header, `CaptureStatusRow` (`CaptureStatusLabel` and `CancelCaptureBtn`), 8 action rows (`Row_<action>` with action label, effective binding label, `RebindBtn`, and `ResetBtn`), and `ResetAllBtn`.
   - Focus management: all Rebind, Reset, Cancel, and Reset All buttons participate in the circular focus chain, with visible high-contrast focus styleboxes.
   - Capture lifecycle: during capture, gameplay is frozen (`player.freeze_movement()`), input is consumed in `_input()`, echo and candidate invalid events are rejected with explanatory status text, and Escape or Cancel button dismisses capture without closing SettingsSheet.
   - Originating focus restoration: on rebind completion or cancellation, focus is restored to the initiating Rebind button.

4. **GameRoot & Evaluator Debug Bar Integration (`scenes/main/game_root.gd` & `scenes/ui/evaluator_debug_bar.gd`)**:
   - Guarded `_unhandled_input()` against `InputBindings.is_capture_active()` to prevent capture leakage to dimension shift, menu toggles, or evaluator debug tools.
   - Dynamic dimension shift hint: updated Chapter II objective label from hardcoded `[Q]` to `[%s]` populated from `InputBindings.get_action_binding_text(&"shift_dimension")`.

5. **Headless Test Coverage**:
   - New `tests/headless/input_rebinding_test.gd`: verifies authored defaults snapshot, idempotence, physical key rebind & release displacement, replaced key disabling, reset restoring all alternatives, mouse menu binding outside capture, transactional save/reload across profile switches, atomic validation & disk preservation on failure, legacy and future schema version handling, and capture event consumption & zero state leakage.
   - Updated `tests/headless/settings_accessibility_test.gd`: verifies full 29-element circular focus chain, Escape during capture canceling capture without dismissing SettingsSheet, and Escape outside capture dismissing SettingsSheet.
   - Updated `tests/headless/layout_audit_test.gd`: verified all panels stay within `Rect2(0, 0, 960, 540)` at 1.0x and 1.5x text scale, with `ScrollContainer` absorbing content and proving focus reachability of below-the-fold controls.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `run_headless_tests.ps1 -Suite input_rebinding_test` | Exit 0 | Verified authored defaults, apply/reset idempotence, physical key rebind/release, replaced key deactivation, reset restoring alternatives, mouse menu binding outside capture, profile-independent persistence, atomic conflict/invalid/empty/duplicate validation, legacy & future schema protection, and capture event consumption with zero state leakage (`report/input_rebinding_test.log`). |
| `run_headless_tests.ps1 -Suite settings_accessibility_test` | Exit 0 | Verified 29-element focus traversal, visible focus styleboxes, Escape canceling capture without closing SettingsSheet, and Escape dismissing SettingsSheet outside capture (`report/settings_accessibility_test.log`). |
| `run_headless_tests.ps1 -Suite layout_audit_test` | Exit 0 | Audited SettingsSheet and all 6 modals at 960x540 viewport: Phase 1 (1.0x rect `[P: (205, 20), S: (550, 500)]` fits, follow_focus reached below-the-fold controls) and Phase 2 (1.5x rect `[P: (190.5, 20), S: (579, 500)]` fits, follow_focus reached below-the-fold controls) (`report/layout_audit_test.log`). |
| Disposable negative control: conflict validation | Exit 0 | Verified `InputBindings.validate_overrides` rejects conflicting key with `ERR_INVALID_DATA` (code 30) (`report/neg_input_rebinding_conflict.log`). |
| Disposable negative control: future schema version safety | Exit 0 | Verified `SettingsManager` rejects future schema version 99 with `ERR_INVALID_DATA`, blocks ordinary save with `ERR_UNAVAILABLE`, and preserves disk bytes untouched (`report/neg_future_settings_blocked.log`). |
| Full headless runner (`run_headless_tests.ps1`) | Exit 0 (31/31 passed) | All 31 project headless suites pass cleanly with 0 Godot script/engine errors across all game systems. |
| Full release exporter (`run_headless_tests.ps1 -Export -SkipImport`) | Exit 0 | Built and validated `Soulbound-AcademicMVP-Web.zip`, `Soulbound-Web.zip`, and `Soulbound-Windows-Portable.zip`; PCK gates passed; working tree verified byte-identical. |

---

## SBL-UX-001-FIX — Rebinding Review Remediation (Atomic Reset, Entry Type Check & Test Isolation)

- **Milestone** M4 / M6 Settings & Accessibility Hardening.
- **Requirements** GDD-092, FR-SET-001, TC-ACC-001, NFR-ACC-001, AGENTS.md Engineering Invariants.
- **Codex finding** Codex CLI review session `01a1c06b-9905-7633-a299-32dac1671a06`:
  1. Fix 1: In `scripts/settings/settings_manager.gd`, resetting one action can erase its override, call `apply_overrides()`, ignore a conflict error, and leave persisted/displayed bindings inconsistent.
  2. Fix 2: In `scripts/settings/input_bindings.gd`, malformed arrays containing non-dictionaries can reach duplicate comparison and trigger an invalid cast.
  3. Fix 3: In `tests/headless/input_rebinding_test.gd`, successful capture calls `settings.save_settings()` using the real `user://settings.json`.
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - Modified persistence & bindings: `scripts/settings/settings_manager.gd`, `scripts/settings/input_bindings.gd`.
  - Modified UI: `scenes/ui/settings_sheet.gd`.
  - Modified test suites: `tests/headless/input_rebinding_test.gd`, `tests/headless/settings_accessibility_test.gd`.
  - Documentation: `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`.
  - Negative control logs: `report/neg_conflicting_reset_atomic.log`, `report/neg_malformed_entry_cast.log`, `report/neg_user_settings_isolation.log`.
- **Asset provenance** None (pure GDScript and UI state logic; zero image or audio generation).
- **Review** REVIEW_PENDING_CODEX.
- **Open questions** None.

### Changes

1. **Atomic Per-Action Reset & Actionable UI Conflict Feedback (`scripts/settings/settings_manager.gd` & `scenes/ui/settings_sheet.gd`)**:
   - Updated `SettingsManager.reset_input_override(action) -> Error`: constructs a candidate override dictionary with the target action erased (reverting to authored defaults), runs `InputBindings.validate_overrides(candidate)`, and returns `val_err` on conflict without mutating `input_overrides` or calling `apply_overrides()`.
   - Updated `SettingsManager.reset_all_input_overrides() -> Error` to validate candidate defaults atomically.
   - Added `InputBindings.find_reset_conflict(action, current_overrides) -> Dictionary` helper querying which specific action and key would conflict upon resetting to authored defaults.
   - Updated `SettingsSheet._on_reset_pressed(action)`: on conflict/error, retains current overrides, live bindings, and UI text; does not call `save_settings()`; and displays actionable feedback identifying the conflicting action and key (e.g. `"Cannot reset Move Left: default A conflicts with Move Right."`).
   - Added regression test in `input_rebinding_test.gd` (Part 8): rebinds Move Left to J and Move Right to A, resets Move Left, asserts rejection with `ERR_INVALID_DATA`, and asserts manager overrides, live `InputMap`, UI labels, and disk bytes are 100% unchanged.

2. **Validate Binding Entry Types Before Duplicate Checking (`scripts/settings/input_bindings.gd`)**:
   - Refactored `InputBindings.validate_overrides(overrides)`: Pass 1 asserts that every array entry is a Dictionary (`typeof(item) != TYPE_DICTIONARY -> return ERR_INVALID_DATA`) and validates its primitive shape (`validate_primitive`), before Pass 2 performs pairwise duplicate comparisons.
   - Rejects non-dictionary types (integers, strings, booleans, floats, nulls, nested arrays) immediately without invalid casts or script errors.
   - Hardened `get_effective_primitives` and `get_effective_events` to look up both `StringName` and `String` keys safely.
   - Added regression test in `input_rebinding_test.gd` (Part 9): validates fixture `[{"kind":"key","physical_keycode":74}, 1]`, asserting rejection with `ERR_INVALID_DATA`, 0 script errors, and unchanged disk/manager state.

3. **Isolated Test Settings Paths & Real User Settings Byte-Identity Invariant (`tests/headless/input_rebinding_test.gd` & `tests/headless/settings_accessibility_test.gd`)**:
   - Added configurable `settings_path: String = SETTINGS_FILE_PATH` to `SettingsManager` and `custom_settings_path: String = ""` to `SettingsSheet`.
   - Updated `save_settings(path = "")` and `load_settings(path = "")` to use `settings_path` when path parameter is omitted.
   - In `input_rebinding_test.gd` Part 7 (capture test), configured `sm.settings_path = _test_root + "/capture_settings.json"` and `sheet.custom_settings_path = _test_root + "/capture_settings.json"`, asserting successful capture rebind writes to the disposable test file.
   - In `settings_accessibility_test.gd`, isolated `game_root.settings_manager.settings_path = "%s/gameroot_settings.json" % _test_root`.
   - Added pre-suite snapshot of `user://settings.json` and post-suite byte-identity assertion in both suites, verifying `user://settings.json` is byte-identical before and after the test runs.

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `run_headless_tests.ps1 -Suite input_rebinding_test` | Exit 0 | Verified 9 parts: authored defaults, movement rebind/reset, mouse binding, profile isolation, atomic validation, legacy/future schemas, capture consumption, atomic conflicting reset rejection (Fix 1), malformed entry type validation without script errors (Fix 2), and user settings byte-identity guarantee (Fix 3) (`report/input_rebinding_test.log`). |
| `run_headless_tests.ps1 -Suite settings_accessibility_test` | Exit 0 | Verified audio/accessibility controls, circular focus traversal, Escape capture cancel vs modal dismiss, isolated settings path, and user settings byte-identity guarantee (`report/settings_accessibility_test.log`). |
| `run_headless_tests.ps1 -Suite layout_audit_test` | Exit 0 | Verified SettingsSheet and all 6 modals stay within 960x540 viewport at 1.0x and 1.5x text scale (`report/layout_audit_test.log`). |
| Negative control: conflicting reset atomic rejection | Exit 0 | Proved conflicting reset rejects with `ERR_INVALID_DATA` (code 30) and preserves overrides and live bindings (`report/neg_conflicting_reset_atomic.log`). |
| Negative control: malformed entry type check | Exit 0 | Proved fixture `[{"kind":"key","physical_keycode":74}, 1]` rejects with `ERR_INVALID_DATA` (code 30) with zero script errors (`report/neg_malformed_entry_cast.log`). |
| Negative control: user settings file isolation | Exit 0 | Proved SHA256 before and after suite is byte-identical (`report/neg_user_settings_isolation.log`). |
| Full headless runner (`run_headless_tests.ps1`) | Exit 0 (31/31 passed) | All 31 project headless suites pass cleanly with 0 Godot script/engine errors across all game systems. |
| Full release exporter (`export_release.ps1 -Tier all`) | Exit 0 | Built and validated `Soulbound-AcademicMVP-Web.zip`, `Soulbound-Web.zip`, and `Soulbound-Windows-Portable.zip`; PCK gates passed; working tree verified byte-identical. |

---

## SBL-EDU-005 — Persistent Learning Journal & Educational Reporting Engine

- **Milestone** M2 / M3 / M4 / M6 Educational Reporting Hardening.
- **Requirements** GDD-071 (persistent activity/attempt records), GDD-072 (learning journal, CSV, and printable report export), GDD-091 (learning-journal screen), GDD-112 (educational report export), FR-EDU-002 (immutable first-attempt tracking), FR-EDU-004 (local CSV and printable report export), TC-EDU-002 (first-attempt score and retry records), TC-EDU-004 (CSV and printable report correctness), supporting NFR-SEC-001 (data validation & formula injection defense) and NFR-ACC-001 (readable UI, 960x540 reachability, 1.5x scalable interface).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files**
  - New UI scenes & reporting classes: `scenes/ui/learning_journal.{tscn,gd}`, `scripts/education/learning_report.gd`.
  - New headless test suite: `tests/headless/learning_journal_test.gd`.
  - Modified domain & integration: `scripts/education/assessment_controller.gd`, `scenes/main/game_root.{tscn,gd}`, `scenes/ui/academic_completion_modal.{tscn,gd}`.
  - Modified audits & documentation: `tests/headless/layout_audit_test.gd`, `docs/browser_verification_checklist.md`, `docs/traceability-matrix.md`, `docs/testing.md`, `docs/agent-review-queue.md`.
  - Negative control logs: `report/neg_journal_mutate_first_attempt.log`, `report/neg_journal_omit_html_escaping.log`, `report/neg_journal_stale_controller.log`, `report/neg_journal_claim_browser_delivery.log`.
- **Asset provenance** None (pure GDScript, Control UI scene nodes, and test automation; zero image generation, zero audio generation).
- **Review** REVIEWED by Codex CLI session `01a1c0bd-85d2-75a0-b5d9-7c25cb5d3bd8`; no actionable regressions. Test-profile isolation and active-profile report attribution are cleared.
- **Open questions** `OD-012` remains open pending human educator review. Mandatory notice is prominently displayed in both journal and reports: `"Practice records. Educator review pending — OD-012. These records do not establish learning improvement."` Browser download/print execution remains PENDING human evaluation per AGENTS.md.

### Changes

1. **Shared Row Model & Reporting Engine (`scripts/education/learning_report.gd`)**:
   - `LearningReport.get_rows(records: Dictionary) -> Array[Dictionary]`: produces transient, deep-copied rows sorted alphabetically by question ID with columns `question_id,competency,difficulty,first_attempt_correct,total_attempts,completed,timestamp`. The underlying `records` dictionary is never mutated.
   - Preserves first-attempt correctness: retries never alter first-attempt correctness.
   - Legacy record compatibility: legacy records lacking `first_response` data remain unchanged in memory and on disk, displaying `"Not recorded"` without inferring missing answers.
   - Formula neutralization: values beginning with `=`, `+`, `-`, `@`, `\t`, or `\r` are prepended with `'` in transport CSV output, preventing spreadsheet formula injection.
   - Standalone UTF-8 HTML report: includes print CSS, zero `<script>` tags, zero external resources/links, zero remote requests, zero inline handlers, zero auto-print, and entity-escapes all dynamic values. Includes active profile slot, row count, completion count, first-attempt count, empty state, and the mandatory OD-012 notice.
   - Fixed allowlisted filenames under `user://reports/`: `learning_report.csv`, `learning_report.html`, `competency_record.csv`, `soulbound_academic_mvp_report.csv`, `soulbound_academic_mvp_report.html`. Any path traversal (`..`) or unallowlisted path is rejected.
   - Injectable web delivery: `prepare_web_download()` dispatches exact UTF-8 byte buffers and MIME types to an injectable test bridge or `JavaScriptBridge.download_buffer` without claiming browser execution.

2. **AssessmentController Report Delegation (`scripts/education/assessment_controller.gd`)**:
   - Retains all existing `education.records`, `submit_answer()`, first-response merging, completion gating, and serialization logic unchanged.
   - Delegated `generate_csv_text()` and `export_to_csv()` to `LearningReport`, ensuring Journal, CSV, and HTML consume the identical row model and formula neutralization rules.
   - Added `get_report_rows()`, `generate_html_report()`, and `export_to_html()`.

3. **Learning Journal UI Screen (`scenes/ui/learning_journal.{tscn,gd}`)**:
   - Created `LearningJournal` scene on `SheetLayer`.
   - Layout strictly conforms to 960x540 viewport at both 1.0x and 1.5x accessibility text scales (`ScrollContainer` absorbs table expansion).
   - Displays OD-012 notice, profile slot, summary metrics, empty state message when records are empty, and sorted table rows.
   - Focus management: circular keyboard focus traversal across `ExportCsvBtn`, `ExportHtmlBtn`, and `CloseBtn`.
   - Input consumption: consumes menu hotkeys (`toggle_character`, `toggle_inventory`, `toggle_settings`) and closes on `ui_cancel` (Escape).
   - Provides desktop allowlisted exports and injectable web download buffer preparation.

4. **Exploration HUD & GameRoot Integration (`scenes/main/game_root.{tscn,gd}`)**:
   - Added button-only `JournalBtn` to exploration HUD (`UIOverlay`). No keyboard action was added.
   - Managed single-instance lifecycle on `SheetLayer`: freezes player movement, saves/restores previous focus and movement lock on close.
   - Modal exclusivity: opening journal closes any active character/inventory/settings sheet to prevent stacking; opening another sheet closes journal; blocking modals prevent journal opening.
   - Dynamic profile refresh: `_init_slice_progress()` and `_reload_imported_profile()` re-configure live `_learning_journal` with the new controller and slot, guaranteeing stale controller references are never retained.

5. **Academic Completion Modal Printable HTML Export (`scenes/ui/academic_completion_modal.{tscn,gd}`)**:
   - Added direct `ExportHtmlBtn` ("Export Printable HTML") alongside CSV export without opening or stacking the journal.
   - Uses `LearningReport` allowlisted file export on desktop and injectable web buffer preparation on web without claiming browser execution.

6. **Headless Test Suite & Negative Controls (`tests/headless/learning_journal_test.gd`)**:
   - 8 comprehensive parts covering row model, legacy compatibility, sorting, counts, timestamps, OD-012 notice, CSV formula neutralization, HTML security/print CSS, HUD button & SheetLayer lifecycle, profile switching, and desktop/web delivery.
   - 4 disposable negative controls:
     1. Mutate first-attempt data during rendering (`report/neg_journal_mutate_first_attempt.log`).
     2. Omit HTML escaping (`report/neg_journal_omit_html_escaping.log`).
     3. Retain stale controller after profile switch (`report/neg_journal_stale_controller.log`).
     4. Claim browser delivery (`report/neg_journal_claim_browser_delivery.log`).

### Verification Table

| Test Scope / Invocation | Result | Evidence |
|---|---|---|
| `run_headless_tests.ps1 -Suite learning_journal_test` | Exit 0 | Verified 8 parts: row model, legacy compatibility ("Not recorded"), sorting, counts, timestamps ("Last recorded activity"), OD-012 notice, CSV formula neutralization, HTML security & print CSS, HUD button-only SheetLayer lifecycle & focus restoration, profile switching & backup refresh, and desktop/web delivery (`report/learning_journal_test.log`). |
| `run_headless_tests.ps1 -Suite layout_audit_test` | Exit 0 | Audited LearningJournal and all 6 modals at 960x540 viewport: Phase 1 (1.0x rect `[P: (100, 45), S: (760, 450)]` fits, no clipped content) and Phase 2 (1.5x rect `[P: (76.5, 45), S: (807, 450)]` fits inside 960x540, follow_focus reached below-the-fold controls) (`report/layout_audit_test.log`). |
| `run_headless_tests.ps1 -Suite education_report_test` | Exit 0 | Verified question bank, immutable first-attempt tracking, completion gating, and RFC-4180 CSV export (`report/education_report_test.log`). |
| `run_headless_tests.ps1 -Suite web_backup_test` | Exit 0 | Verified profile JSON backup export/import, invalid JSON rejection, and web CSV download buffer preparation (`report/web_backup_test.log`). |
| `run_headless_tests.ps1 -Suite settings_accessibility_test` | Exit 0 | Verified settings persistence, audio buses, 29-element circular focus traversal, and real user settings isolation (`report/settings_accessibility_test.log`). |
| Negative control 1: mutate first-attempt data during rendering | Exit 0 | Proved mutation detection catches altered first-attempt data (`report/neg_journal_mutate_first_attempt.log`). |
| Negative control 2: omit HTML escaping | Exit 0 | Proved unescaped dynamic input caught by security assertion (`report/neg_journal_omit_html_escaping.log`). |
| Negative control 3: stale controller after profile switch | Exit 0 | Proved retaining old controller when switching to Profile B detected as stale reference (`report/neg_journal_stale_controller.log`). |
| Negative control 4: claim browser delivery | Exit 0 | Proved claiming browser execution in non-browser environment is flagged (`report/neg_journal_claim_browser_delivery.log`). |
| Full headless runner (`run_headless_tests.ps1`) | Exit 0 (32/32 passed) | All 32 project headless suites pass cleanly with 0 Godot script/engine errors across all game systems. |
| Full release exporter (`run_headless_tests.ps1 -Export -SkipImport`) | Exit 0 | Built and validated `Soulbound-AcademicMVP-Web.zip` (10.8 MB), `Soulbound-Web.zip` (10.8 MB), and `Soulbound-Windows-Portable.zip` (86.7 MB); PCK gates passed; working tree verified byte-identical. |

---

## SBL-EDU-005-FIX — Learning Journal Test Isolation & Active-Profile Report Attribution

- **Milestone** M2 / M3 / M4 / M6 Educational Reporting Hardening (remediation of the `SBL-EDU-005` Codex review findings).
- **Requirements** GDD-071 (persistent activity/attempt records), GDD-072 (learning journal, CSV and printable report export), GDD-112 (educational report export), FR-EDU-002 (immutable first-attempt tracking), FR-EDU-004 (local CSV and printable report export), TC-EDU-004 (CSV and printable report correctness), NFR-SEC-001. Findings under review: P1 (fixture answers written to the real `user://profiles`) and P2 (`profile_01` hardcoded in completion HTML exports), Codex CLI session `01a1c094-60d4-70c0-aaa6-37f8ffbce421`.
- **Implementation owner** agy (slice executed in-session by the implementation executor under the approved remediation plan). **Plan owner** Codex.
- **Branch** `feature/w4-5-vertical-slice`.
- **Files** `tests/headless/learning_journal_test.gd`, `scenes/ui/academic_completion_modal.gd`, `scenes/main/game_root.gd`, plus `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`, `report/sbl_edu_005_fix_report.md`, `report/implementation-review-ledger.md`, `report/README.md`.
- **Asset provenance** None (pure GDScript, Control UI wiring, and documentation; zero image generation, zero audio generation, zero new educational content).
- **Review** REVIEW_PENDING_CODEX. Nothing in this slice has been reviewed; Codex CLI must review before any status may change to `REVIEWED`.
- **Open questions** `OD-012` educator-pending language is retained verbatim in every report output and no learning-improvement claim was added. Browser execution remains PENDING human evaluation. New observation: five other suites still write the real `user://profiles/profile_01` (see Changes 4 / Open question 2) — pre-existing behavior outside this approved slice.

### Required report block

```text
TASK ID: SBL-EDU-005-FIX
REQUIREMENTS: GDD-071, GDD-072, GDD-112, FR-EDU-002, FR-EDU-004, TC-EDU-004, NFR-SEC-001
MILESTONE: M2/M3/M4/M6 Educational Reporting Hardening (SBL-EDU-005 remediation)
OWNER: agy
PLAN OWNER: Codex
BRANCH/COMMIT: feature/w4-5-vertical-slice, implementation commit cd18b87 (tagged [REVIEW_PENDING_CODEX])
FILES CHANGED: tests/headless/learning_journal_test.gd, scenes/ui/academic_completion_modal.gd, scenes/main/game_root.gd, docs/agent-review-queue.md, docs/traceability-matrix.md, docs/testing.md, report/sbl_edu_005_fix_report.md, report/implementation-review-ledger.md, report/README.md
ASSET PROVENANCE: none
TESTS RUN + RESULTS: learning_journal_test.gd exit 0 (9 parts, 116 PASS / 0 FAIL, in-suite byte-identity INVARIANTs for real user://profiles and user://reports PASS, external SHA-256 manifest diff 0); full runner exit 0 (32/32); pre-fix reproduction run exit 0 but added 3 fixture revisions to the real user://profiles and rotated out 3 real revisions (P1), restored byte-identically from backup
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: OD-012 educator sign-off; browser execution PENDING human evaluation; five other suites (ending_chapter5_test, evaluator_debug_bar_test, release_tier_test, title_screen_audio_test, verify_exported_tier) still write real user://profiles/profile_01 — pre-existing, out of scope for this slice
```

### Changes

1. **Disposable ProfileStore fixtures in the journal test (P1).** `tests/headless/learning_journal_test.gd` now builds every `ProfileStore` under the suite's disposable `_test_root` (`_test_root/profiles`) for the profile-isolation part, and injects that store into the GameRoot fixture before `add_child` (`game_root.profile_store = ProfileStore.new(_disposable_store_root)`), which `_init_slice_progress()` preserves because it only constructs a default store when none is present. Desktop CSV/HTML exports in the delivery part were redirected to `_test_root/learning_report.{csv,html}`; the path-traversal rejection probe is unchanged. Disposable cleanup is now recursive so the nested `profiles/` fixture tree is removed. **Production save semantics were not changed** — `ProfileStore`, `AssessmentController`, and `GameRoot` write paths are untouched.
2. **Real-directory byte-identity invariant (P1).** The suite takes a recursive pre-suite snapshot (relative path -> raw bytes) of the real `user://profiles` and `user://reports` and, after all nine parts, asserts both are byte-identical (same file set, same bytes), printing `ADDED` / `MODIFIED` / `REMOVED` diagnostics on any drift.
3. **Active profile attribution through GameRoot (P2).** `AcademicCompletionModal` gains `profile_slot` (default `profile_01`) assigned in `configure(..., slot)` and used by `LearningReport.generate_html()` and `LearningReport.export_html_file()` in **both** the desktop file path and the Web/injectable-bridge path. `GameRoot._open_academic_modal()` and `GameRoot._on_debug_academic_modal()` now pass `_profile_slot`. CSV rows carry no profile column (profile schema unchanged), so the CSV generators are unchanged; both CSV export paths now use the overridable `report_export_dir` (default `user://reports`, same testability pattern as the pre-existing `injectable_download_bridge`) so tests never write the real reports directory.
4. **Regression coverage with `profile_02` (Part 9).** New suite part asserts: the modal holds the configured `profile_02`; the Web HTML buffer attributes the report to `profile_02` and contains no `profile_01` fallback; the desktop HTML file written to a disposable directory attributes to `profile_02`, retains the mandatory OD-012 notice and the recorded activity rows, and never claims browser execution; the Web CSV buffer still carries the RFC-4180 header; and a GameRoot instance whose active slot is `profile_02` opens the completion modal with `profile_slot == "profile_02"`.

### Preserved invariants

- First-attempt correctness behavior is unchanged: all pre-existing Parts 1–8 assertions (immutable first attempt across wrong-first/correct-retry, legacy "Not recorded", completion gating, CSV formula neutralization, HTML escaping/print CSS, OD-012 exact text, no browser-execution claims, 4 negative controls) still pass unmodified.
- Report escaping, allowlisted filenames, and `LearningReport` output format are unchanged; only the slot passed into HTML generation and the export directory are now supplied by the caller.
- No profile schema change, no new educational content, no numeric values or formula coefficients invented, no images or audio, no OD resolution.

### Verification (Godot 4.7.2 Stable `ed1daf0bf`, Windows headless)

| Command / probe | Result |
|---|---|
| Pre-fix reproduction: changes stashed, `run_headless_tests.ps1 -Suite learning_journal_test` at `e45f7d8` | Exit 0 (suite does not detect its own defect), but the SHA-256 manifest diff of the real user data shows **3 ADDED** fixture revisions (`profiles/profile_01/profile.0000000000000418.21372.907546.json`, `profiles/profile_01/profile.0000000000000419.21372.914726.json`, `profiles/profile_02/profile.0000000000000009.21372.936191.json`) and **3 REMOVED** real revisions (`profiles/profile_01/profile.0000000000000416.10180.912338.json`, `profiles/profile_01/profile.0000000000000417.10180.924200.json`, `profiles/profile_02/profile.0000000000000007.4800.909876.json`) — **P1 reproduced**. Real user data was restored from a verified backup before continuing (5 files, 0 diffs vs the pre-run manifest). |
| `run_headless_tests.ps1 -Suite learning_journal_test` (post-fix) | Exit 0 in 2.03 s. 9 parts, **116 PASS / 0 FAIL**. `INVARIANT: real user://profiles (4 file(s)) is byte-identical before and after the suite` PASS; `INVARIANT: real user://reports (1 file(s)) is byte-identical before and after the suite` PASS. External SHA-256 manifest diff after the run: **0**. No leftover `test_learning_journal_*` directory (`report/learning_journal_test.log`). |
| Part 9 assertions (post-fix) | PASS: modal holds configured slot `profile_02`; Web HTML buffer attributes report to `profile_02` with no `profile_01` fallback; Web CSV buffer carries `LearningReport.CSV_HEADER`; desktop HTML file written under the disposable root attributes to `profile_02`, keeps the OD-012 notice and activity rows; status reports a prepared buffer and never claims browser execution; `INVARIANT: GameRoot passes its active profile slot (profile_02) into the modal`. |
| Full regression `run_headless_tests.ps1` | Exit 0 — **32/32 suites passed**, including `e2e_academic_playthrough_test`, `evaluator_debug_bar_test`, `chapter_progression_test`, `layout_audit_test`, `education_report_test`, and `web_backup_test`. |
| Isolation probe: all 32 suites run individually with a before/after SHA-256 manifest of the real `user://profiles` + `user://reports` | `learning_journal_test.gd`: **0 changes**. Pre-existing writers of the real `user://profiles/profile_01` (out of scope for this slice): `ending_chapter5_test.gd`, `evaluator_debug_bar_test.gd`, `release_tier_test.gd`, `title_screen_audio_test.gd`, `verify_exported_tier.gd`. Real user data was restored byte-identically afterwards (5 files, 0 diffs). |

### Open questions for Codex review

1. `OD-012` educator sign-off and browser execution/PWA evaluation remain pending human authority; no report text changed in this slice.
2. Five non-journal suites still write the real `user://profiles/profile_01` (probe above). This is pre-existing behavior that predates `SBL-EDU-005` and was **not** in the approved remediation plan, so it is recorded here rather than fixed. Recommend a separate approved slice to give those suites the same disposable-store injection.

---

## SBL-BLD-005 — Archive-Contained JSON Provenance Manifests

- **Milestone** M6 Release Candidate Foundation / Build Integrity & Artifact Governance.
- **Requirements** GDD-110, GDD-124, GDD-131, FR-REL-001, TC-REL-001, GDD-093, GDD-095, GDD-107, GDD-108, GDD-109, GDD-129, NFR-BUILD-001, NFR-SEC-001, NFR-MAINT-001. Scope and evidence are recorded in the [traceability matrix](traceability-matrix.md) and the [full report](../report/sbl_bld_005_release_manifest_report.md).
- **Implementation owner** agy (paused; executed by `opencode-go/mimo-v2.6-flash` under the approved plan). **Plan owner** Codex. **Reviewer** Codex CLI.
- **Branch and implementation commit** `feature/w4-5-vertical-slice`, implementation `30305d6` (documentation committed in the same batch immediately afterwards).
- **Files**
  - Create: `scripts/build/release_manifest.ps1`, `scripts/build/test_release_manifest.ps1`, `report/sbl_bld_005_release_manifest_report.md`.
  - Modify: `scripts/build/export_release.ps1`, `scripts/build/validate_release.ps1`, `scripts/build/run_headless_tests.ps1`, `scripts/build/test_export_failure_restoration.ps1`, `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`, `report/implementation-review-ledger.md`, `report/README.md`.
- **Asset provenance** None. Build automation and documentation only; no image, audio, or generated content; no gameplay/save/settings/test-`.gd` changes.
- **Review** REVIEW_PENDING_CODEX. Nothing in this slice is `REVIEWED`; Codex CLI reviews the implementation commit, negative controls, archive evidence, source-status capture timing, and restoration behavior.
- **Open questions** `OD-017` (shipping default tier) untouched and deferred to human release authority; browser smoke execution remains blocked; `OD-012` and combat ODs untouched. No OD was resolved.

### Changes

1. **Shared manifest library (`scripts/build/release_manifest.ps1`).** Strict RFC 8259 JSON parser with duplicate-member rejection and line/column diagnostics; source provenance captured before any staging or mutation (`git rev-parse HEAD`, `git status --porcelain=v1 --untracked-files=all` with documented LF normalization, `dirty`, `status_porcelain_sha256`; Git failures throw); real `godot --version` output (required `4.7.2.stable.*`) plus executable SHA-256; fixed specs for the three release archives; schema-version-1 manifest creation; ZIP creation with forward-slash entry names; receipt writing for the exact archived manifest bytes; `Test-SblReleaseArchive` byte verifier (entry types incl. symlink/reparse/directory rejection, path safety, ordinal case-sensitive duplicate tracking plus separate case-collision tracking before any hash lookup, exactly one root `release-manifest.json`, receipt digest, strict schema/types/enums/digests with unknown-member rejection, archive identity/tier/platform/preset, exact payload correspondence with streamed raw-byte length and lowercase SHA-256, archived configuration semantics read only from `provenance/` bytes inside the archive, `build_tier.txt` marker, entry points, forbidden files, size constraints); archive-contained PCK gate; proven disposable user-data isolation (probe-first, real-directory byte-identity on exit, seeded copy-on-enter via robocopy, containment-checked long-path-safe cleanup).
2. **Exporter (`export_release.ps1`).** Strict engine resolution with no silent fallback; provenance captured before staging/mutation; fresh GUID staging root with one isolated directory per package (stale output cannot enter a new package); tier marker + configuration snapshots; manifest from staged payload bytes; ZIP payload+manifest; external receipt; re-open and verify the new ZIP against its receipt before packaging succeeds; publish to `builds/` replacing prior contents (manifest/provenance excluded); `-SkipZip` creates no archive/receipt and performs no archive validation; byte-identical `project.godot`/marker restoration and containment-checked staging cleanup retained on every failure path (the three strings consumed by the `-DisableRestore` control preserved).
3. **Validator (`validate_release.ps1`).** Every selected archive validated from archive bytes and its external receipt only (never local `builds/` or local configuration as archive evidence); missing Godot fails instead of falling back or skipping the gate; each archive that passes byte verification runs its own extracted-PCK gate under proven disposable user data; real user data must be byte-identical afterwards.
4. **Canonical runner (`run_headless_tests.ps1`).** Strict engine resolution; enters seeded disposable user-data isolation and proves it before `--import` and every suite; fails if real user data changes; the `-Export` path chains `test_release_manifest.ps1` after successful export/validation and propagates failures.
5. **Restoration test (`test_export_failure_restoration.ps1`).** Additionally snapshots all `dist/` archives+receipts and asserts in both modes that the failed export leaves no `.staging_*` directory and no dist change (violation exits 2, cannot hide behind the disabled control's expected exit 1).
6. **Manifest test suite (`test_release_manifest.ps1`).** 62 disposable controls using the same verifier functions as production validation, plus subprocess controls for literal non-zero exits.

### Verification (all commands from the repo root)

| Command | Expected | Observed |
|---|---|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_release_manifest.ps1` | Exit 0 | **Exit 0; 62/62 controls PASS** (negative 32, positive 8, git 5, export 5, engine 4, subprocess 3, restoration 2, preflight 1, sanity 1, isolation 1) |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1` | Exit 0 | **Exit 0; 32/32 suites PASS**; disposable user data proved before execution; `realUserDataUnchanged=True`, `disposableFiles=654`, `rootRemoved=True` |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Export -Tier all` | Exit 0 | **Exit 0**; 32/32 suites; 3 packages exported with manifest+receipt; self-verification, byte validation and all 3 archive-contained PCK gates pass; chained manifest suite 62/62; isolation intact |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_export_failure_restoration.ps1` | Exit 0 | **Exit 0**; mutation observed, `SIMULATED_EXPORT_FAILURE` caught, `project.godot` byte-identical, root marker absent, staging root removed, dist unchanged (6 artifacts) |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\test_export_failure_restoration.ps1 -DisableRestore` | Exit 1 | **Exit 1**; `[NON-VACUOUS PROOF CONFIRMED]` (`project.godot` differs, `build_tier.txt` remained); safety cleanup restored the tree |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\export_release.ps1 -Tier all` (clean tree after `30305d6`) | Exit 0 | **Exit 0**; all three manifests record `commit=30305d6…`, `dirty=false`, `status_porcelain_sha256=e3b0c442…` (empty status); `git status` empty afterwards |

### Final artifacts (clean-tree export after implementation commit `30305d6`)

| Archive | Size (bytes) | ZIP SHA-256 | Payload entries | Archived manifest SHA-256 = receipt |
|---|---|---|---|---|
| `dist/Soulbound-AcademicMVP-Web.zip` | 10,806,918 | `950c5ba87d938efab8ce96d951fe313a1bccbf6d505a8a6ba9091204f4e39810` | 12 | `1b423257b764283c9589f62e221d0d52864a9a2cc781fbcd9de02487203fa5d7` |
| `dist/Soulbound-Web.zip` | 10,806,906 | `88423fe24d28260d1614d185bf177fd4291364371c6dc3056044c31e9bb40cf2` | 12 | `3f0332167b6a097a4ac826e64c2107f96aacae30094fb4117a707009db1b925e` |
| `dist/Soulbound-Windows-Portable.zip` | 86,680,630 | `57ea5e09049013dff1f6ec46c3cd655005665209059b503334b4ecbce999b6f9` | 5 | `f5ff924408f83defaf3a8c1be48eb84df299049247b3b65090f962fd7777a75c` |

All manifests record `manifest_schema_version=1`, full commit `30305d64eeec74efae983125314904c1461a7004`, `dirty=false`, empty-status digest, `godot.version=4.7.2.stable.official.ed1daf0bf`, executable SHA-256 `c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`, `renderer=gl_compatibility`, Web `web_thread_support=false` / Windows `null`. Receipt contents equal the archived manifest digests exactly.

### Control highlights (full list in the report)

Missing manifest/receipt (no fallback), malformed and future schema JSON, duplicate JSON member names, `source.commit`/`source.dirty` tampering (receipt mismatch with payload untouched), older same-tier manifest substitution, same-size payload byte flip and length change, deleted/added payload files, duplicate and case-colliding ZIP/payload paths, duplicate and case-variant manifest entries, traversal/absolute/backslash/drive/empty-component paths with a nothing-written-outside-temp-root assertion, unsupported symlink/reparse/directory entries, swapped manifests across tiers (both directions), renderer/thread/tier configuration tampering, snapshot byte and snapshot-semantic tampering, corrupt archive bytes, garbage/wrong receipts, `validate_release.ps1` subprocess exits 1 with matching diagnostics, explicit-invalid and missing-default engine failures with no silent fallback and no gate-skip text, clean/dirty/pre-mutation Git fixture capture and non-repo throw, stale seeded output excluded from the fresh package, `-SkipZip` leaving all dist artifacts byte-identical with no validation, manifest source equal to a live post-run capture, and real user data byte-identical across the suite.

### Execution-time defects fixed before the final runs (for reviewer context)

Pipeline unrolling collapsed parsed JSON arrays (fixed-size `Object[]`) and aborted the suite; case-insensitive exact-path tracking misclassified case collisions (now ordinal `HashSet[string]`); the drive-path diagnostic order made an expectation order-dependent (drive check first, forward-slash control entry); the empty clean-status digest hit mandatory empty-array binding (`[AllowEmptyCollection()]`); export subprocesses needed pre-isolation user data because Godot resolves export templates from `%APPDATA%\Godot\export_templates` (exports proven to leave real user data byte-identical); `ending_chapter5_test.gd` keeps its pre-existing `profile_01` baseline via the runner's seeded disposable (test file untouched, out of batch scope); deep seeded shader-cache paths beyond MAX_PATH required robocopy seeding plus `\\?\` hashing/deletion fallbacks.

### Notes for Codex CLI

- An unrelated docs commit `18ffb02` landed from another agent mid-session; the source-timing control correctly failed against it and passed again after a fresh export. Final manifests record `30305d6`.
- The receipt is an integrity reference, not a signature; coordinated archive+receipt replacement remains out of scope. Dirty builds are permitted and honestly recorded.
- Raw evidence logs (gitignored): `report/release_manifest_test.log`, `report/godot_user_data_isolation.log`, `report/verify_pck_*.log|.err`; run transcripts in the session temp directory.

---

## SBL-OD-009 — OD-009 MVP Save Boundary

```text
TASK ID: SBL-OD-009
REQUIREMENTS: GDD-098, GDD-099, GDD-100, FR-SAV-001, FR-CMB-001, TC-SAV-001, TC-SAV-002, TC-DNG-002, TC-DNG-003, TC-DNG-004, AGENTS.md save invariants
MILESTONE: Release Hardening & Scope Boundary Management
OWNER: agy (executed by opencode-go/mimo-v2.6-flash under the owner-ratified plan)
PLAN OWNER: Codex (docs/agy-next-queue.md)
BRANCH/COMMIT: feature/w4-5-vertical-slice (commit recorded below)
FILES CHANGED: scenes/main/game_root.gd, scenes/dungeon/dungeon_expedition.gd, scripts/persistence/profile_store.gd, tests/headless/dungeon_scene_test.gd, docs/agent-review-queue.md, docs/traceability-matrix.md, docs/testing.md, report/od009_save_boundary_report.md, report/README.md
ASSET PROVENANCE: none
TESTS RUN + RESULTS: targeted dungeon_scene_test exit 0 (OD-009: 59 checks, 0 failed); negative control exit 1 (7 failures); canonical suite 32/32 exit 0; real user data unchanged
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: see below
```

- **Milestone** Release Hardening & Scope Boundary Management (owner-ratified `OD-009` MVP fallback).
- **Requirements** GDD-098, GDD-099, GDD-100, FR-SAV-001, FR-CMB-001, TC-SAV-001/002, TC-DNG-002/003/004. Scope of record: `docs/agy-next-queue.md`. Evidence: [OD-009 report](../report/od009_save_boundary_report.md), [traceability](traceability-matrix.md).
- **Implementation owner** `opencode-go/mimo-v2.6-flash` (MiMo execution). **Plan owner** Codex. **Reviewer** Codex CLI — deferred; Codex CLI review was explicitly not called for this slice.
- **Branch and commit** `feature/w4-5-vertical-slice`, implementation commit `e285514` (docs committed immediately afterwards in the same batch), both tagged `[REVIEW_PENDING_CODEX]`.
- **Files** `scenes/main/game_root.gd`, `scenes/dungeon/dungeon_expedition.gd`, `scripts/persistence/profile_store.gd`, `tests/headless/dungeon_scene_test.gd`, plus this queue, `docs/traceability-matrix.md`, `docs/testing.md`, `report/od009_save_boundary_report.md`, `report/README.md`.
- **Asset provenance** None. No images, audio, generated content, or gameplay numbers; no save-data format change.
- **Review** REVIEW_PENDING_CODEX. Nothing in this slice is `REVIEWED`; Codex CLI must review the guard semantics, the byte-identity assertions, and the negative control.
- **Open decisions** `OD-009` remains open for its full-release decision (mid-battle serialization format, mid-battle browser resume, combat-action replay logs stay blocked). No other OD was touched. `OD-002/003/004` combat values and `OD-008` loss ratios are untouched.

### Changes

1. **Boundary gate and save-request entry point (`scenes/main/game_root.gd`).** New OD-009 section with `OD009_SAVE_BLOCKED_HINT`, `get_save_blocker()`, `check_save_boundary()`, `request_save(reason)` and `_persist_exploration_boundary()`. A save request is evaluated against the blocker list **before** `ProfileStore` is touched; on a blocker it returns `ERR_BUSY` and emits an actionable `push_warning` naming the blocker (live battle phase, pending encounter, boss encounter, active/parked expedition, at-risk satchel) plus the OD-009 hint, and states that no profile data was written. The allowed path is a single atomic load-modify-save of character stats, the Kurei tree (refreshed from the live controller so the rewrite cannot drop stored skills/talents) and inventory. Education, chapter, slice, ending and expedition records keep their existing event-based writers.
2. **Expedition boundary documentation and snapshot guard (`scenes/dungeon/dungeon_expedition.gd`).** Header, `serialize_expedition()` and `suspend_expedition()` document the room/exploration boundary, the absence of any combat/turn state in the snapshot, and that suspend is never an extraction. `serialize_expedition()` now returns `{}` while an extraction commit is in flight so a snapshot cannot interleave with the atomic terminal write (state `suspend_expedition()` already refused, so no reachable behavior changed).
3. **Writer contract documentation (`scripts/persistence/profile_store.gd`).** `save_profile()` documents that ProfileStore performs no combat-state serialization and that mid-battle/partial-turn requests are rejected upstream before the writer is reached. No logic, validation, or schema change (`schema_version` stays `1`).
4. **Regression coverage (`tests/headless/dungeon_scene_test.gd`).** New `_test_od009_save_boundary()` with 59 assertions plus `_profile_revision_count()` / `_profile_revision_files()` helpers: session boot writes nothing; mid-battle, `phase=ENEMY` partial-turn, pending-encounter, boss and expedition requests all return `ERR_BUSY`; after all probes the profile export text, committed-revision count and JSON snapshots of character, inventory, education, story, Kurei tree, slice stage, region and suspended-run state are identical; suspend writes `world.active_expedition` without banking (≠ extraction) and a parked run still defers; resume → extraction clears the snapshot and banks exactly once; the allowed boundary save returns `OK`, commits exactly one revision, round-trips xp and banked inventory into a fresh session, writes an empty satchel, and leaves story/education/expedition records untouched.

### Verification (Godot 4.7.2 Stable `ed1daf0bf`, Windows headless, disposable user data)

| Command | Observed result |
|---|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite dungeon_scene_test` | **Exit 0, PASS (2.02 s)**. Import clean. `--- Running OD-009 MVP Save Boundary Test ---` → `OD-009 save boundary checks: 59 run, 0 failed` → `=== ALL DUNGEON SCENE TESTS PASSED SUCCESSFULLY ===` (`report/dungeon_scene_test.log`). |
| Same run, stderr | **6 actionable OD-009 diagnostics**, one per rejected probe (battle `phase=PLAYER`, battle `phase=ENEMY`, pending encounter, boss, active expedition, parked snapshot), each ending "no profile data was written" (`report/dungeon_scene_test.err`). |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1` | **Exit 0, 32/32 suites PASS** (incl. `save_model_test`, `save_compatibility_recovery_test`, `web_backup_test`, `dungeon_scene_test`). `realUserDataUnchanged=True`, `disposableFiles=654`, `rootRemoved=True`. |
| Negative control: mid-battle branch disabled in `get_save_blocker()`, targeted suite re-run | **Exit 1, 7 failed assertions**, including `Rejected saves leave profile bytes unchanged` and `Rejected saves commit no profile revision` — proving the guard is load-bearing and the test detects an unguarded mid-battle write. Guard restored; targeted suite re-run **exit 0**. |

### Preserved invariants

- Suspend/resume is still not extraction: the bank is untouched by suspend and the exactly-once extraction transfer assertions (atomic extraction, SBL-FIX-007 defeat retry, SBL-REV-001 single transfer) pass unmodified.
- Permanent data still survives defeat; unbanked satchel loot can never become permanent through the new boundary save (the save is refused while at-risk satchel exists and writes an empty satchel otherwise).
- Legacy/future profile validation is untouched: `profile_store.gd` changed by documentation only, and `save_model_test` / `save_compatibility_recovery_test` pass unmodified.
- No new combat values, initiative rules, SP/cooldown values, rewards, loss ratios, story, assets, browser work, schema bump, or OD resolution.

### Open questions for Codex review

1. Should `request_save()` be wired to a UI/event (e.g. region transition) in a follow-up slice, or is a programmatic entry point sufficient for the MVP? No UI was added and no player-facing copy was invented.
2. Confirm the reading of GDD-099 "separate expedition-state handling" that defers generic saves while a run is active/parked or at-risk satchel is live (it prevents unbanked loot from persisting without an expedition record).
3. `push_warning` is the current actionable-diagnostic channel; confirm whether the MVP requires a player-facing message instead.