# agy Next Work Queue

Plan owner: Codex. Implementation owner: agy. **agy never reviews.** Codex CLI is the only reviewer; while it is unavailable, agy implements and every commit stays `REVIEW_PENDING_CODEX`.

## Current position

- `SBL-FIX-006` is committed at `e25491d` and **not reviewed**: dimension collision/travel sync, persisted expedition resume, clipboard-free backup import, Web CSV download, live text scale/contrast, ending-modal input blocking.
- The Codex CLI batch verdict on `SBL-W4-001`..`SBL-FIX-005` was `CHANGES_REQUESTED` (8 P1, 13 P2). Most code findings are addressed by `SBL-FIX-001`..`SBL-FIX-006`; several are addressed but **not yet pinned by a regression test**, which is what the next slice is for.
- agy quota is exhausted (`RESOURCE_EXHAUSTED 429`). Start at Task 1 when it resets; do not re-litigate completed slices.

## Hard constraints for every task below

1. Godot 4.7.2 Stable, Compatibility renderer, GDScript, Windows portable + single-threaded Web.
2. Do not invent stats, coefficients, drop rates, story reveals, or integrations. Mark `TBD` and record the blocking `OD-###`.
3. No image generation (Codex-exclusive). No silent substitution of another generator for audio.
4. Preserve save-state invariants: secured gear/level/skills/story/education survive defeat; suspend is not extraction; reward transfer is exactly-once.
5. Each task ends with the AGENTS.md report block, a commit suffixed `[REVIEW_PENDING_CODEX]`, and an entry in `docs/agent-review-queue.md`.
6. Never mark work reviewed, never write `REVIEWED`, never skip human release sign-off.

## Task 1 — SBL-VER-001: pin the five reproduced probe failures with regression tests

The batch review reproduced five concrete failures. Audit each against the current tree; where no automated assertion exists, add one that fails if the defect returns. Do not rewrite working code just to match the old report.

| Probe | Where to assert |
| --- | --- |
| Newer banked gear disappears on a quest checkpoint | `tests/headless/vertical_slice_loop_test.gd`: grant banked gear after the practice step, advance the quest, reload the profile, assert the gear is still banked. |
| Imported inventory disappears on the next checkpoint | Same suite: import a backup profile mid-run, advance a stage, assert imported banked/satchel counts survive the merge. |
| Incorrect answer leaves the required activity incomplete | `tests/headless/vertical_slice_test.gd` or the chapter suite: answer incorrectly, assert the activity is completion-gated (completable) while `first_attempt_correct` stays `false`. |
| Fresh profile reaches final completion with no assessment records | Chapter progression suite: attempt final completion on a fresh profile, assert it is refused. |
| Extraction reports success after an injected save failure | `tests/headless/dungeon_scene_test.gd`: inject a failing `commit_extraction`, assert `extraction_save_failed` fires, `expedition_completed` does not, and the satchel is unchanged. |

Acceptance: all suites green, each probe has a named assertion, and the queue entry lists probe → test mapping.

## Task 2 — SBL-FIX-007: extraction and defeat failure UX

- On `extraction_save_failed`, the expedition must stay open (or reopen) with a retry path and must not show a success status.
- On defeat, a failed save must not claim the satchel was secured; surface the error and keep the run retryable.
- Assert double-extraction and early-extraction requests are rejected without banking twice.

Acceptance: headless test injects failures, asserts no success text, no bank duplication, and that a retry after recovery banks exactly once.

## Task 3 — SBL-FIX-008: terminal-state input exclusivity

- Boss encounter results, ending modal, academic completion modal, and chapter dialog must all consume `toggle_character`, `toggle_inventory`, `toggle_settings`, and `ui_cancel` while visible.
- Assert no sheet or second modal can be instantiated on top of a results state, including via the evaluator debug bar.

Acceptance: one test drives real `InputEventAction`s and asserts `has_blocking_modal()` plus zero extra children on the sheet layer.

## Task 4 — SBL-FIX-009: finish accessibility application

- Text scale and high contrast already apply to the live tree; add keyboard reachability: focus order, visible focus, and every button reachable without a mouse in Settings, Inventory, Character, and the chapter dialog.
- Confirm reduced motion is honored where any animation exists; if none exists, document that explicitly instead of adding fake animation.
- Extend high contrast beyond `modulate` where labels lose legibility (font color/shadow overrides), keeping authored values restorable.

Acceptance: headless assertions for focus traversal and restore-to-authored values; a short manual visual checklist for the rest. `TC-ACC-001`, GDD-103.

## Task 5 — SBL-DOC-001: reconcile the traceability matrix

- Add remediation rows/links for `SBL-FIX-001`..`SBL-FIX-006` against the requirement IDs they touch.
- Replace stale `CHANGES_REQUESTED` review status with `REVIEW_PENDING_CODEX` where a later fix slice already landed, and keep `CHANGES_REQUESTED` where nothing landed.
- No status may read `REVIEWED` without a Codex CLI session ID.

Acceptance: matrix and review queue agree row-for-row; no orphan requirement IDs.

## Task 6 — SBL-VER-002: Web/browser verification evidence

- Produce a Chromium and a Firefox smoke checklist: load, title screen, profile select, region transition, dimension shift, settings, backup export/import via text box, CSV download, single-thread confirmation.
- Verify the Web preset is single-threaded and document required COOP/COEP headers if any are needed.
- Record results as **pending human execution** unless a browser automation tool is actually available. Never report a browser pass that did not run.

Acceptance: checklist committed, export preset flags verified in `export_presets.cfg`, results table with explicit `PENDING` rows.

## Task 7 — SBL-MCP-001: Godot-compatible MCP proof

Per AGENTS.md, prove a Godot-capable MCP/adapter on a **disposable** project: list scene tree, create/edit a node, save the scene, inspect errors, run headless validation, collect evidence. The referenced Unity plugin is not acceptable evidence. If no Godot-compatible adapter exists, record `PENDING` and keep using Godot-native files plus the headless CLI.

Acceptance: evidence bundle or a documented `PENDING` with the attempted adapters named.

## Task 8 — SBL-DATA-001: open-decisions ledger

Create one table for `OD-001`..`OD-016`: decision needed, affected requirement IDs, current placeholder in code (`TBD`), who must decide, and what stays blocked. Do not fill any value yourself. Include the unresolved balance coefficients, initiative rule, save boundaries, and the educator review gate (`OD-012`).

Acceptance: every `TBD` in code maps to an `OD-###`; no invented numbers.

## Task 9 — non-image asset queue (Gemini Flash, not agy-authored)

- Audio: finalize `docs/audio-spec.md` into a generation brief; if no Gemini Flash audio-output mode exists, mark the binaries `PENDING` and keep the procedural SFX as the shipping fallback.
- Text: quest/dialogue/item/description copy review, and educator sign-off on assessed questions (`OD-012`) before any assessed use.

Image assets (sprites, icons, tilesets, portraits, textures, image-based animation frames) stay **blocked for Codex** and must never be routed to agy or Gemini Flash.

## Suggested order

1. Task 1 (regression proof) and Task 5 (docs) — cheap, closes review noise.
2. Tasks 2 and 3 — remaining correctness/input findings.
3. Task 4 — accessibility completeness.
4. Task 6 and Task 7 — verification gates, may stay `PENDING` with evidence.
5. Task 8 and Task 9 — decision and asset ledger, unblocks human acceptance.

Codex CLI review of `e25491d` and everything queued must happen before any of this is represented as reviewed.
