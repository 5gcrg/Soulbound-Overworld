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
- **Branch and base** `feature/w2-overworld-transitions` based on reviewed M1 `50b01a9`. Initial implementation `90760a1`.
- **Files** `project.godot`, `scenes/main/game_root.*`, `scenes/player/player.*`, `scenes/world/`, `tests/headless/{smoke_test,transition_test}.gd`, tracked script UIDs, and the audit, traceability matrix, and asset register.
- **Asset provenance** None. The two technical regions and player use Godot primitives. The slice creates no save data.
- **Review** CHANGES_REQUESTED.
- **Open questions** Story map content and story-specific access rules are future work. Waypoint fast travel, combat, and the save model are separate slices.

Run the Godot project from the editor. Move with WASD or the arrow keys and walk into a marked portal to cross between Alpha and Beta. The movement speed is an editor-tunable test value.

### Overworld verification

| Command | Latest observed result |
| --- | --- |
| `godot --version` | Exit 0. Godot 4.7.2 Stable, official build `ed1daf0bf`. |
| `godot --headless --path . --import` | Exit 0. No Godot errors. |
| `godot --headless --path . --fixed-fps 60 --quit-after 120` | Exit 0. Alpha started at its valid marker. |
| `godot --headless --path . --script tests/headless/smoke_test.gd --fixed-fps 60 --quit-after 300` | Exit 0. M1 smoke regression and overworld startup passed. |
| `godot --headless --path . --script tests/headless/transition_test.gd --fixed-fps 60 --quit-after 600` | Exit 0. Movement, wall collision, real portal signals in both directions, duplicate requests, and spawn rejection and rollback checks passed. |

Two temporary probes also exited 0. One sent physical W, Right, Down, and A key events to walk through both portals with the same player. The other freed the originating portal before deferred dispatch and confirmed the current region was preserved and the router released its reservation.

### Overworld review history

- Codex CLI reviewed `90760a1` (session `01a1bb7c-fdca-7d03-8459-234bf85b9399`). It requested a supported physics API, valid candidate and starting spawn checks, atomic request reservation, collision-state preservation, and corrections to the physics-frame test harness and signal observations.
- agy authored the repair in the managed worktree. Codex ran the Godot checks and recorded the startup failure that remained after the first repair.
- agy repaired off-tree marker resolution, validated the player collision footprint against destination shapes, and hardened the portal signal and stale-request handling. Local verification passed on Godot 4.7.2 Stable.
