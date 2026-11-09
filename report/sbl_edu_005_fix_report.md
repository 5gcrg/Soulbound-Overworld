# SBL-EDU-005-FIX — Learning Journal Test Isolation & Active-Profile Report Attribution

- **Date** 9 November 2026
- **Branch** `feature/w4-5-vertical-slice`
- **Review status** `REVIEW_PENDING_CODEX` — nothing here is reviewed; Codex CLI session `01a1c094-60d4-70c0-aaa6-37f8ffbce421` findings P1/P2 are remediated and awaiting re-review.
- **Queue entry** [`docs/agent-review-queue.md`](../docs/agent-review-queue.md) → `SBL-EDU-005-FIX`
- **Ledger** [`implementation-review-ledger.md`](implementation-review-ledger.md)

## Findings remediated

| ID | Finding (Codex CLI session `01a1c094-60d4-70c0-aaa6-37f8ffbce421`) | Disposition |
|---|---|---|
| P1 | `tests/headless/learning_journal_test.gd` writes fixture answers to the real `user://profiles` because `ProfileStore.new()` receives no disposable test root; risk of corrupting immutable first-attempt records. | Fixed: disposable store root, injected into the GameRoot fixture, disposable CSV/HTML export paths, and an in-suite byte-identity invariant over the real `user://profiles` and `user://reports`. |
| P2 | `scenes/ui/academic_completion_modal.gd` hardcodes `profile_01` in completion HTML exports instead of using the active profile slot. | Fixed: active slot passed from `GameRoot` through `configure()` and used by both desktop and Web HTML generation; regression-covered with `profile_02`. |

## Required AGENTS.md report block

```text
TASK ID: SBL-EDU-005-FIX
REQUIREMENTS: GDD-071, GDD-072, GDD-112, FR-EDU-002, FR-EDU-004, TC-EDU-004, NFR-SEC-001
MILESTONE: M2/M3/M4/M6 Educational Reporting Hardening (SBL-EDU-005 remediation)
OWNER: agy
PLAN OWNER: Codex
BRANCH/COMMIT: feature/w4-5-vertical-slice — implementation commit recorded in report/implementation-review-ledger.md (both commits tagged [REVIEW_PENDING_CODEX])
FILES CHANGED: tests/headless/learning_journal_test.gd, scenes/ui/academic_completion_modal.gd, scenes/main/game_root.gd, docs/agent-review-queue.md, docs/traceability-matrix.md, docs/testing.md, report/sbl_edu_005_fix_report.md, report/implementation-review-ledger.md, report/README.md
ASSET PROVENANCE: none
TESTS RUN + RESULTS: learning_journal_test.gd exit 0 (9 parts, 116 PASS / 0 FAIL; in-suite INVARIANTs byte-identical for real user://profiles (4 files) and user://reports (1 file); external SHA-256 manifest diff 0; no leftover test_learning_journal_* directory); full runner exit 0 (32/32 suites); pre-fix reproduction exit 0 but ADDED 3 fixture revisions to the real user://profiles and REMOVED 3 real revisions (P1 reproduced), restored byte-identically (5 files, 0 diffs); suite-isolation probe shows learning_journal_test writes 0 bytes to real user data while 5 other suites pre-existingly write real user://profiles/profile_01
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: OD-012 educator sign-off pending; browser execution PENDING human evaluation; five other suites still write real user://profiles/profile_01 (pre-existing, out of scope for this slice — see probe below)
```

## Implementation summary

1. **P1 — test isolation (`tests/headless/learning_journal_test.gd`)**
   - `_disposable_store_root = _test_root/profiles`; the profile-isolation part now uses `ProfileStore.new(_disposable_store_root)`.
   - The GameRoot fixture receives that store before `add_child` (`game_root.profile_store = ProfileStore.new(_disposable_store_root)`); `_init_slice_progress()` keeps a pre-supplied store and only builds a default `user://profiles` store when none is present.
   - Desktop CSV/HTML exports in the delivery part target `_test_root/learning_report.{csv,html}`; the path-traversal rejection probe (`user://reports/../evil.exe`) is unchanged and still writes nothing.
   - Recursive pre-suite snapshots (relative path → raw bytes) of the real `user://profiles` and `user://reports`, with post-suite byte-identity assertions (`ADDED`/`MODIFIED`/`REMOVED` diagnostics on drift).
   - Disposable cleanup is now recursive so nested fixture trees are removed.
   - **No production save semantics changed**: `ProfileStore`, `AssessmentController`, and `GameRoot` write paths are untouched.
2. **P2 — active profile attribution (`scenes/ui/academic_completion_modal.gd`, `scenes/main/game_root.gd`)**
   - `AcademicCompletionModal.profile_slot` (default `profile_01`) is assigned by `configure(..., slot)` and used by `LearningReport.generate_html()` / `export_html_file()` on both the desktop file path and the Web/injectable-bridge path.
   - `GameRoot._open_academic_modal()` and `GameRoot._on_debug_academic_modal()` pass `_profile_slot`.
   - CSV rows carry no profile column (profile schema unchanged), so CSV generation is unchanged; both CSV export paths now use the overridable `report_export_dir` (default `user://reports`) — the same testability pattern as the pre-existing `injectable_download_bridge` — so tests never write the real reports directory.
3. **Regression coverage (Part 9, `profile_02`)** — modal Web HTML buffer and desktop HTML file must attribute to `profile_02` and contain no `profile_01`; OD-012 notice, activity rows, and "no browser execution claim" retained; GameRoot's debug modal path must carry `profile_slot == "profile_02"`.

## Preserved invariants

- First-attempt correctness behavior unchanged; all pre-existing Parts 1–8 assertions pass unmodified (immutable first attempt across wrong-first/correct-retry, legacy "Not recorded", completion gating, CSV formula neutralization, HTML escaping/print CSS, exact OD-012 notice text, no browser-execution claims, 4 negative controls).
- Report escaping, allowlisted filenames, and `LearningReport` output format unchanged.
- No profile schema change, no new educational content, no invented numeric values, no images/audio, no OD resolution.

## Verification evidence (Godot 4.7.2 Stable `ed1daf0bf`, Windows headless)

### 1. Pre-fix reproduction of P1 (changes stashed; HEAD `e45f7d8`)

```text
run_headless_tests.ps1 -Suite learning_journal_test  ->  PASS (exit 0)
SHA-256 manifest diff of the real user data vs the pre-run snapshot:
  ADDED    profiles/profile_01/profile.0000000000000418.21372.907546.json
  ADDED    profiles/profile_01/profile.0000000000000419.21372.914726.json
  ADDED    profiles/profile_02/profile.0000000000000009.21372.936191.json
  REMOVED  profiles/profile_01/profile.0000000000000416.10180.912338.json
  REMOVED  profiles/profile_01/profile.0000000000000417.10180.924200.json
  REMOVED  profiles/profile_02/profile.0000000000000007.4800.909876.json
```

The suite exits 0 while silently rotating fixture data into the real `user://profiles` (ProfileStore retains only the two newest revisions, so real revisions were dropped). Real user data was restored from a verified backup before any further work: `restored files: 5; diffs vs baseline: 0`.

### 2. Post-fix targeted run

```text
run_headless_tests.ps1 -Suite learning_journal_test  ->  PASS (exit 0, 2.03 s)
Pre-suite snapshot: 4 file(s) in user://profiles, 1 file(s) in user://reports
[Part 9] Testing Academic Completion Modal active-profile attribution (profile_02)...
  PASS: Modal holds configured active profile slot profile_02
  PASS: Web HTML buffer attributes report to profile_02
  PASS: Web HTML buffer does not fall back to hardcoded profile_01
  PASS: Desktop HTML report attributes report to profile_02
  PASS: INVARIANT: GameRoot passes its active profile slot (profile_02) into the modal
  PASS: INVARIANT: real user://profiles (4 file(s)) is byte-identical before and after the suite
  PASS: INVARIANT: real user://reports (1 file(s)) is byte-identical before and after the suite
ALL LEARNING JOURNAL & REPORTING TESTS PASSED (0 FAILURES)   (116 PASS / 0 FAIL, 9 parts)
```

External SHA-256 manifest check after the run: `post-fix files: 5; diffs vs baseline: 0`. No leftover `test_learning_journal_*` directory.

### 3. Full regression

```text
run_headless_tests.ps1  ->  Exit 0, Total: 32 | Passed: 32 | Failed: 0
```

Includes `e2e_academic_playthrough_test`, `evaluator_debug_bar_test`, `chapter_progression_test`, `layout_audit_test`, `education_report_test`, and `web_backup_test`, which exercise the modified modal/GameRoot paths.

### 4. Isolation probe (all 32 suites, before/after SHA-256 manifest of real `user://profiles` + `user://reports`)

| Suite | Real user-data changes |
|---|---|
| `learning_journal_test.gd` | **0** (post-fix) |
| `ending_chapter5_test.gd` | 4 (rotates `profiles/profile_01` revisions) |
| `evaluator_debug_bar_test.gd` | 4 |
| `release_tier_test.gd` | 2 |
| `title_screen_audio_test.gd` | 4 |
| `verify_exported_tier.gd` | 2 |
| other 26 suites | 0 |

The five writers are **pre-existing behavior outside this approved remediation plan**; they are recorded as an open question in the queue entry and were not changed. Real user data was restored byte-identically after the probe (5 files, 0 diffs).

## Boundaries respected

- No profile schema change; no new educational content; `OD-012` educator-pending language retained verbatim; no learning-improvement claims; no browser-execution claims; no images or audio; no OD resolution; production save semantics untouched.
