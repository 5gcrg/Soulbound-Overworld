# Implementation, Review, and Findings Ledger

Canonical report index for the Codex → agy → verification → Codex CLI workflow.
The detailed task records remain in `docs/agent-review-queue.md`; raw command
evidence is retained in the `report/` log files linked below.

## Operating roles

- **Codex/OpenCode:** plans, coordinates, inspects diffs, runs independent verification, and records review evidence.
- **agy:** implementation only; it must not approve or mark work `REVIEWED`.
- **Codex CLI:** independent code reviewer; only a recorded Codex CLI session may mark work `REVIEWED`.
- **Human:** approves scope changes, open decisions, milestone acceptance, and release.
- **Images:** Codex-exclusive; no image generation is routed to agy.
- **Gemini Flash:** non-image assets when explicitly required; no unsupported asset substitution.

## Current state — 9 November 2026

- Branch: `feature/w4-5-vertical-slice`.
- Last committed implementation: `a833610` (`SBL-REV-001`, `REVIEW_PENDING_CODEX`).
- agy is actively implementing remediation Batch A; current uncommitted work includes `scenes/main/game_root.tscn` for `SBL-REV-002`.
- `SBL-UX-001` is staged but paused until remediation Batch A is reviewed.
- Human gates remain pending: `OD-017`, browser smoke, `OD-012`, combat ODs, binary audio, and image assets.

## Codex plans and reviews

| Scope | Session / evidence | Verdict or status |
|---|---|---|
| Batches 1–3 recommendation | `report/codex_next_slice.log`; session `01a1bed9-3c6b-7420-b620-875ba8032576` | Three non-gated slices recommended: rebinding, learning journal, provenance manifest. |
| Batches 1–3 implementation plan | `report/codex_next_plan.log`, `report/codex_next_plan_extract.md`; same session | Split into three sequential batches with review checkpoints. |
| Existing batches `e25491d..5e81a04` | `report/codex_review_e25491d.log`; session `01a1be9a-5583-7252-b082-ebd436372c80` | `CHANGES_REQUESTED`; three P2 findings. |
| Batch 4 fixes | `report/codex_rereview_batch4.log`; session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0` | Three findings cleared; one P2 remained in failure injection. |
| Batch 5 fix | `report/codex_rereview_batch5.log`; session `01a1becc-d949-7cc3-867d-a0a8ede9510b` | `APPROVED`; no actionable defects. |
| `SBL-FIX-001..005` review | `report/codex_review_fix001_005.log`; session `01a1bee0-6c04-72b0-b38d-6bce20925f2f` | `CHANGES_REQUESTED`; seven findings: one P1 and six P2. |
| Remediation plan | `report/codex_fix_plan.log`, `report/codex_fix_plan_extract.md`; session `01a1bed9-3c6b-7420-b620-875ba8032576` | Three remediation batches: profile/title, audio routing, combat integration. |

## Findings disposition

The complete task-level records and exact finding text are in
`docs/agent-review-queue.md`, especially the sections headed:

- `Codex CLI review of SBL-FIX-001..005`
- `SBL-REV-001` through `SBL-REV-003`

Finding 1 is partially present in the reviewed HEAD because `e25491d` already
added persisted `world.active_expedition` storage and reload tests. The current
remediation verifies and hardens commit-first suspension, stale callback
ownership, and cross-profile isolation rather than introducing a second save
location. Finding 5's missing boss-effect mapping remains explicitly blocked by
`OD-003/004`; it must not be represented as fully resolved without an approved
mapping.

## Implementation history

All implementation commits use `[REVIEW_PENDING_CODEX]` until a Codex CLI
session records approval. The authoritative task entries, changed-file lists,
test matrices, and statuses are in `docs/agent-review-queue.md`.

| Commit / range | Work | Review status |
|---|---|---|
| `43f4666..f26f2d1` | `SBL-FIX-001..005` | `CHANGES_REQUESTED`, session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`. |
| `e25491d..e0ed0b5` | Reviewed implementation batches 1–5, 23 tasks | `REVIEWED`; sessions recorded above. |
| `f25744e` | Recorded seven findings and staged rebinding | Documentation only; remediation required first. |
| `9a8b9d7` | Staged remediation Batch A | `REVIEW_PENDING_CODEX`. |
| `a833610` | `SBL-REV-001`, profile-owned expedition suspension | `REVIEW_PENDING_CODEX`; Codex review pending. |

## Verification evidence

The following evidence is recorded in `report/` and referenced by the task
entries:

- Prior approved baseline: 29/29 headless suites, export chain, archive PCK
  validation, swapped-marker negative control, MCP proof, and restoration
  controls.
- `SBL-REV-001` targeted evidence: `dungeon_scene_test.log`,
  `web_backup_test.log`, `save_compatibility_recovery_test.log`,
  `neg_persist.log`, and `neg_owner.log`.
- Current Batch A full-suite and Codex re-review are **pending** until agy
  finishes `SBL-REV-002` and `SBL-REV-003`.

## Batch A Codex review

- **Evidence:** `report/codex_review_batchA.log`.
- **Session:** `01a1bfe5-fd15-7463-b4b1-c55215e0c3f0`.
- **Range:** `2596420..HEAD`.
- **Independent verification:** 30/30 suites passed, exit 0 (`report/independent_batchA_full_suite.log`).
- **Verdict:** `CHANGES_REQUESTED`.
- **Finding:** P2 in `scenes/ui/title_screen.gd`: after selecting a different slot while the title remains open, Defense Demo still applies its persistent progression/inventory/stat changes through the previously active `GameRoot._profile_slot`. The selected slot must be successfully activated before the demo mutates persistent state.
- **Disposition:** `SBL-REV-001` and `SBL-REV-002` have no actionable findings from this review. `SBL-REV-003` remains `CHANGES_REQUESTED`; Batch B and Batch C are paused until the fix and re-review.

## Batch A review-fix re-review

- **Evidence:** `report/codex_review_rev003_fix.log`.
- **Session:** `01a1bff5-713f-73e2-bb28-9a9dd10f37f3`.
- **Range:** `dff0abc..5456d7a`.
- **Verdict:** `APPROVED`; no actionable regressions.
- **Resolved:** Defense Demo now activates the title-selected profile before applying persistent changes and safely rejects corrupt profiles. The targeted profile activation and title/audio suites passed.
- **Disposition:** Batch A is now `REVIEWED`. Batch B may proceed; Batch C remains ordered after Batch B review.

## Batch B review

- **Evidence:** `report/codex_review_rev004.log`.
- **Session:** `01a1c001-361d-7250-98d6-bc547c380822`.
- **Range:** `80056ed..979c432`.
- **Independent verification:** `title_screen_audio_test.gd` and `settings_accessibility_test.gd` passed; full implementation evidence records 30/30 suites and export success.
- **Verdict:** `APPROVED`; no actionable regressions. Codex noted only that its sandbox needed a writable temporary APPDATA path for the settings suite.
- **Disposition:** Batch B is `REVIEWED`. Batch C may proceed. `OD-015` remains open; no binary audio was generated.

## Rule

Every future implementation, review, finding, negative control, and disposition
must add either a task entry in `docs/agent-review-queue.md` plus a linked raw
log in `report/`, or an update to this ledger that links to those records.
No work may be called `REVIEWED` without a Codex CLI session ID.
