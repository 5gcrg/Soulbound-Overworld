# Implementation, Review, and Findings Ledger

Canonical report index for the Codex → agy → verification → Codex CLI workflow.
The detailed task records remain in `docs/agent-review-queue.md`; raw command
evidence is retained in the `report/` log files linked below.

The tagged remaining-work inventory is maintained in
`report/unimplemented-work-inventory.md`.

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

## Batch C review

- **Evidence:** `report/codex_review_batchC.log`.
- **Session:** `01a1c033-a580-7dc0-b15a-1a703f857eb0`.
- **Range:** `293602e..HEAD`.
- **Independent targeted verification:** Kurei tree, normal combat, boss combat, UI sheets, and layout suites passed.
- **Verdict:** `CHANGES_REQUESTED`; two P2 findings.
- **Findings:** (1) expanded boss notices in a non-wrapping HBox clip functional controls at 960×540; (2) imported `equipped_skills: []` passes validation/deserialization, leaving fallback-visible spells unusable because requests reject unequipped skills.
- **Disposition:** Batch C remains unreviewed. `OD-003/004` boss-effect mapping remains separately blocked and unchanged.

## Batch C fix re-review

- **Evidence:** `report/codex_rereview_batchC_fixes.log`.
- **Session:** `01a1c04c-cc02-7c12-8171-7c27cadfcb1e`.
- **Range:** `1f5e6da..HEAD`.
- **Independent targeted verification:** Kurei tree, normal combat, boss combat, and layout suites were run; Codex reproduced a null-node crash in the added boss-layout audit path.
- **Verdict:** `CHANGES_REQUESTED`; one P2 test-order defect.
- **Finding:** `tests/headless/layout_audit_test.gd` accesses `b.kurei_btn` before `root_control.add_child(inst)`, so the `@onready` node is null and the claimed boss viewport coverage is not actually executed.
- **Disposition:** Stage a focused test-order fix, then re-run the layout and full suites and obtain Codex re-review. `OD-003/004` remains unchanged.

## Batch C fix re-review approval

- **Evidence:** `report/codex_rereview_rev009.log`.
- **Session:** `01a1c058-93ab-7bc0-beec-1fe287126bf8`.
- **Range:** `bac4346..4f35aae`.
- **Independent targeted verification:** layout, boss combat, normal combat, and Kurei tree suites passed.
- **Verdict:** `APPROVED`; no actionable regressions. Godot 4.7.2 layout audit passed at both text scales.
- **Disposition:** Batch C (`SBL-REV-005/006` plus fixes `SBL-REV-007..009`) is `REVIEWED`. The only remaining combat boundary is the explicitly blocked OD-003/004 boss-effect mapping.

## SBL-UX-001 review

- **Evidence:** `report/codex_review_ux001.log`.
- **Session:** `01a1c06b-9905-7633-a299-32dac1671a06`.
- **Range:** `b4c12cc..4b19977`.
- **Independent targeted verification:** input rebinding, settings/accessibility, and layout suites passed.
- **Verdict:** `CHANGES_REQUESTED`; three P2 findings.
- **Findings:** per-action reset can erase an override before a conflicting candidate is validated; malformed binding entries can reach duplicate checking before type validation and trigger an invalid cast; the capture test writes to the real `user://settings.json` instead of an isolated test path.
- **Disposition:** Stage a focused fix. Do not proceed to the learning journal or provenance manifest until the fix is reviewed.

## SBL-UX-001 fix re-review approval

- **Evidence:** `report/codex_rereview_ux001_fixes.log`.
- **Session:** `01a1c07c-8045-7a60-bd41-1dcb9620f860`.
- **Range:** `8a6f23a..2e5d8b6`.
- **Independent targeted verification:** input rebinding, settings/accessibility, and layout suites passed.
- **Verdict:** `APPROVED`; no actionable regressions. Codex confirmed atomic reset, malformed-entry rejection, and byte-identical user-settings isolation.
- **Disposition:** `SBL-UX-001` is `REVIEWED`. The next approved slice is `SBL-EDU-005`.

## SBL-EDU-005 review

- **Evidence:** `report/codex_review_edu005.log`.
- **Session:** `01a1c094-60d4-70c0-aaa6-37f8ffbce421`.
- **Range:** `738f56b..5ff4760`.
- **Independent targeted verification:** learning journal, education report, web backup, settings/accessibility, and layout suites passed.
- **Verdict:** `CHANGES_REQUESTED`; one P1 and one P2.
- **Findings:** the journal test writes fixture answers to the real `user://profiles` instead of a disposable ProfileStore root; completion HTML exports hardcode `profile_01` instead of receiving the active slot.
- **Disposition:** agy pauses. Present the remediation plan to the project owner before MiMo execution.

## SBL-EDU-005 fix re-review approval

- **Evidence:** `report/codex_rereview_edu005_fix.log`.
- **Session:** `01a1c0bd-85d2-75a0-b5d9-7c25cb5d3bd8`.
- **Range:** `e45f7d8..426630a`.
- **Independent targeted verification:** journal, report, backup, settings/accessibility, and layout suites passed.
- **Verdict:** `APPROVED`; no actionable regressions.
- **Disposition:** `SBL-EDU-005` is `REVIEWED`. agy remains paused pending the next approved plan.

## Batch C audit order fix (SBL-REV-009)

- **Task:** `SBL-REV-009` (Fix boss layout audit initialization order).
- **Implementation:** agy (`tests/headless/layout_audit_test.gd`).
- **Evidence:** `report/neg_boss_layout_audit_order.log`.
- **Targeted verification:** `layout_audit_test.gd`, `kurei_tree_test.gd`, `kurei_combat_test.gd`, `boss_combat_test.gd` all passed (exit 0).
- **Full verification:** 30/30 headless suites passed with zero script or engine errors; automated release exporter succeeded across all tiers (`run_headless_tests.ps1 -Export -Tier all`).
- **Review status:** `REVIEW_PENDING_CODEX` awaiting Codex CLI re-review.

## SBL-EDU-005-FIX remediation (test isolation & active-profile report attribution)

- **Evidence:** `report/sbl_edu_005_fix_report.md`, `report/learning_journal_test.log`.
- **Queue entry:** `docs/agent-review-queue.md` → `SBL-EDU-005-FIX`.
- **Implementation commit:** `cd18b87` (tagged `[REVIEW_PENDING_CODEX]`).
- **Implementation:** `tests/headless/learning_journal_test.gd`, `scenes/ui/academic_completion_modal.gd`, `scenes/main/game_root.gd`.
- **Targeted verification:** `learning_journal_test.gd` exit 0 (9 parts, 116 PASS / 0 FAIL); in-suite byte-identity INVARIANTs for the real `user://profiles` (4 files) and `user://reports` (1 file) PASS; external SHA-256 manifest diff 0; no leftover disposable directory.
- **Pre-fix reproduction:** with the fix stashed at `e45f7d8` the suite exited 0 but ADDED 3 fixture revisions to the real `user://profiles` and REMOVED 3 real revisions (P1 reproduced); real user data was restored byte-identically from a verified backup (5 files, 0 diffs) before the fix was re-applied.
- **Full verification:** 32/32 headless suites passed with exit 0 on Godot 4.7.2 Stable.
- **Review status:** `REVIEW_PENDING_CODEX` awaiting Codex CLI re-review of session `01a1c094-60d4-70c0-aaa6-37f8ffbce421` findings P1 and P2. Nothing in this slice is `REVIEWED`.
- **Open observation:** `ending_chapter5_test.gd`, `evaluator_debug_bar_test.gd`, `release_tier_test.gd`, `title_screen_audio_test.gd`, and `verify_exported_tier.gd` still write the real `user://profiles/profile_01` (pre-existing, outside the approved remediation plan; a separate approved slice is recommended).

## SBL-BLD-005 implementation (archive-contained JSON provenance manifests)

- **Task:** `SBL-BLD-005` — queue entry in `docs/agent-review-queue.md`; full evidence in
  `report/sbl_bld_005_release_manifest_report.md`.
- **Implementation commit:** `30305d6` on `feature/w4-5-vertical-slice` (documentation committed
  in the same batch immediately afterwards). `REVIEW_PENDING_CODEX`; nothing is `REVIEWED`.
- **Files:** created `scripts/build/release_manifest.ps1`, `scripts/build/test_release_manifest.ps1`;
  modified `scripts/build/{export_release,validate_release,run_headless_tests,test_export_failure_restoration}.ps1`
  plus `docs/{agent-review-queue,traceability-matrix,testing}.md` and this ledger.
- **Asset provenance:** none. No OD was resolved; `OD-017`, browser smoke, `OD-012`, combat ODs
  remain open.
- **Verification (all exit as required):** `test_release_manifest.ps1` **62/62 controls, exit 0**;
  `run_headless_tests.ps1` **32/32 suites, exit 0** with seeded disposable user data proved before
  execution (`realUserDataUnchanged=True`, `disposableFiles=654`, `rootRemoved=True`);
  `run_headless_tests.ps1 -Export -Tier all` **exit 0** (3 packages exported with manifest +
  external receipt, self-verification, byte validation, 3 archive-contained PCK gates, chained
  manifest suite 62/62); `test_export_failure_restoration.ps1` **exit 0** (byte-identical
  restoration, staging removed, dist unchanged) and `-DisableRestore` **exit 1**
  (non-vacuous proof confirmed).
- **Final artifacts (clean-tree export after `30305d6`; manifests record `dirty=false`, commit
  `30305d6`, empty-status digest):**
  `Soulbound-AcademicMVP-Web.zip` 10,806,918 B `950c5ba8…39810`, manifest/receipt `1b423257…3fa5d7`;
  `Soulbound-Web.zip` 10,806,906 B `88423fe2…40cf2`, manifest/receipt `3f033216…b925e`;
  `Soulbound-Windows-Portable.zip` 86,680,630 B `57ea5e09…b6f9`, manifest/receipt `f5ff9244…7a75c`
  (full hashes in the report).
- **Execution-time defects fixed before the final runs:** JSON-array pipeline unrolling
  (fixed-size `Object[]` abort), case-insensitive exact-path tracking (case collisions
  misclassified as duplicates), drive-path check order (order-dependent expectation), empty
  clean-status digest vs mandatory empty-array binding, export templates hidden by disposable
  user data (exporter subprocesses restored to pre-isolation env, real data proven unchanged),
  `ending_chapter5_test.gd` baseline `profile_01` dependency satisfied via the runner's seeded
  disposable (test file untouched), and MAX_PATH-safe robocopy seeding plus `\\?\` hash/delete
  fallbacks.
- **Observation:** an unrelated docs commit `18ffb02` from another agent landed mid-session; the
  source-timing control caught the mismatch and passed again after a fresh export.

## SBL-OD-013 implementation (OD-013 performance evidence, owner-ratified)

- **Task:** `SBL-OD-013` — queue entry in `docs/agent-review-queue.md`; scope in
  `docs/agy-next-queue.md`; ratification in `report/od013-ratification.md`; evidence in
  `report/od013_performance_report.md` and `report/od013_performance_evidence.json`.
- **Implementation:** executor `opencode-go/mimo-v2.6-flash` (MiMo) under the agy contract;
  plan owner Codex/OpenCode. Codex CLI review **deferred by instruction** — committed
  `[REVIEW_PENDING_CODEX]`; nothing here is `REVIEWED`.
- **Files:** created `scripts/build/performance_evidence.ps1`,
  `scripts/build/test_performance_evidence.ps1`, `report/od013_performance_report.md`,
  `report/od013_performance_evidence.json`; modified `scripts/build/run_headless_tests.ps1`
  (canonical `-Export` chain only), `docs/browser_verification_checklist.md`,
  `docs/testing.md`, `docs/traceability-matrix.md`, `docs/agent-review-queue.md`, and this
  ledger. `export_release.ps1` and `validate_release.ps1` were deliberately left unchanged so
  the existing export, archive/PCK, manifest, save, and restoration gates stay byte-identical;
  the OD-013 gate is chained from the canonical runner instead, because writing tracked report
  files inside the exporter would break the manifest source-provenance timing control
  (`test_release_manifest.ps1` control [9]).
- **Asset provenance:** none. No image/audio/text asset generation, no OD resolved, no
  numerical gameplay value invented (`build_size_budget` recorded as `null`).
- **Verification (actual results, all run on this machine):**

| Command | Exit | Observed result |
|---|---|---|
| `scripts\build\test_performance_evidence.ps1` | 0 | **24/24 controls PASS** (52.7 s): headless capture of all five scenes, windowed rendered capture, below-target fixture WARN + exit 0, fallback-band WARN on target only, at-target PASS, missing engine / non-Godot executable / wrong version / incompatible renderer / multi-threaded Web all exit non-zero with no artifacts written, no size budget, gate wiring, browser checklist pending, git status unchanged during controls. |
| `scripts\build\run_headless_tests.ps1` | 0 | **32/32 headless suites PASS** (65.2 s); disposable user data proved (`realUserDataUnchanged=True`, 654 files, root removed). |
| `scripts\build\run_headless_tests.ps1 -Export -Tier all` | 0 | Canonical release gate (211.2 s): 32/32 suites, `ALL RELEASE ARTIFACTS AND PRESETS VALIDATED SUCCESSFULLY`, **62/62 manifest controls**, chained performance evidence (5 scenes PASS, exit 0), isolation proof `realUserDataUnchanged=True`. |
| `scripts\build\test_export_failure_restoration.ps1` | 0 | Deterministic export failure path verified; tree restored byte-identically; staging removed; dist unchanged. |
| `scripts\build\test_export_failure_restoration.ps1 -DisableRestore` | 1 (expected) | Non-vacuous proof: with restore disabled the run fails as specified. |
| `scripts\build\performance_evidence.ps1 -CaptureMode both` | 0 | **10/10 scene rows PASS** (29.8 s): headless 128.0–144.9 avg FPS (min 57.8–138.0) at 6.9–7.8 ms average frames; windowed native rendered 239.9–240.1 avg FPS (min 185.4–200.9) at ~4.17 ms on the AMD Radeon RX590 GME / 240 Hz display. This is the committed evidence snapshot. |

- **Evidence snapshot (committed):** `report/od013_performance_evidence.json`
  (schema `sbl-od013-performance-evidence/1`) and `report/od013_performance_report.md` —
  reference machine (Windows 11 Pro 10.0.26300 build 26300, AMD Ryzen 7 5700X 8C/16T,
  23.9 GB RAM, AMD Radeon RX590 GME), Godot `4.7.2.stable.official.ed1daf0bf`
  (exe SHA-256 `c8f0a6bc…6643`), `gl_compatibility` standard + Web, single-threaded Web preset,
  60 FPS target / 30 FPS fallback, `build_size_budget = null`, browser evidence
  `PENDING_HUMAN_EXECUTION` with `acceptance_claimed = false`.
- **Provenance note:** the canonical `-Export` gate run above executed while this slice's own
  changes were still uncommitted, so that run's `dist/` manifests record `source.dirty=true`;
  the manifest-vs-live timing control still passed (digests equal). Re-run the gate after merge
  for clean-provenance release artifacts.
- **Open questions:** `docs/open-decisions-ledger.md` still shows OD-013 as `TBD` (file outside
  this slice's approved modification list); browser smoke/manual profiling remain human-gated;
  see the queue entry for the `export_release.ps1` chaining question.

## Rule

Every future implementation, review, finding, negative control, and disposition
must add either a task entry in `docs/agent-review-queue.md` plus a linked raw
log in `report/`, or an update to this ledger that links to those records.
No work may be called `REVIEWED` without a Codex CLI session ID.
