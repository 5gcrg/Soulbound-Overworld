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

## SBL-W4-001 — One-region vertical slice progress and loop integration

- **Milestone** M2, Week 4–5.
- **Requirements** GDD-067, GDD-068, GDD-069, GDD-071, GDD-098–100, GDD-119, FR-QST-001, FR-EDU-002/003, FR-SAV-001 (partial), TC-EDU-002/003, TC-SAV-001. Scope and evidence are recorded in the [traceability matrix](traceability-matrix.md).
- **Implementation owner** agy. **Plan owner** Codex.
- **Branch and initial implementation** `feature/w4-5-vertical-slice`. Baseline `b427fed`.
- **Files** `scripts/vertical_slice/slice_progress.gd`, `scenes/vertical_slice/quest_dialog.{tscn,gd}`, `scenes/main/game_root.{tscn,gd}`, `scenes/world/test_region_alpha.tscn`, `tests/headless/vertical_slice_test.gd`, `tests/headless/vertical_slice_loop_test.gd`, tracked UIDs, and documentation in `docs/`.
- **Asset provenance** None (visuals use Godot UI and ColorRect primitives; educational prompt text authored per Gemini Flash non-image specification).
- **Review** REVIEW_PENDING_CODEX. Codex CLI execution returned usage limit exhaustion (`ERROR: You’ve hit your usage limit... try again at 4:15 AM`). Governed by AGENTS.md Rule 5. Local verification passed 100% cleanly across all 6 test suites.
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

