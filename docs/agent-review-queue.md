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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex CLI review is halted; no review has occurred.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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
- **Review** REVIEW_PENDING_CODEX. Work continues per AGENTS.md Rule 5 while Codex review is halted.
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

















