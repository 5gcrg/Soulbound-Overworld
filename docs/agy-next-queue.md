# agy Next Work Queue — SBL-EDU-005

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Position

- Batches A–C and `SBL-UX-001` are `REVIEWED`.
- `SBL-UX-001` approval session: `01a1c07c-8045-7a60-bd41-1dcb9620f860`.
- Implement only this learning-journal/report slice. The provenance manifest follows after Codex review.

## Requirements

- GDD-071: persistent activity/attempt records.
- GDD-072: learning journal, CSV, and printable report.
- GDD-091: learning-journal screen.
- GDD-112: educational report export.
- FR-EDU-002/004, TC-EDU-002/004, supporting NFR-SEC-001 and NFR-ACC-001.

## Dependencies and boundaries

- Use existing `AssessmentController.records` and immutable first-response data.
- No profile schema bump, migration, or new saved report cache.
- `OD-012` remains unresolved: retain explicit educator-review-pending language and make no claims of learning improvement, mastery, validity, or accreditation.
- Browser download/print execution remains pending; test only an injectable delivery boundary.
- Do not add questions, explanations, rubrics, scoring, analytics, names, LMS/network integration, story, images, or audio assets.

## Files

Create:

- `scenes/ui/learning_journal.gd`
- `scenes/ui/learning_journal.tscn`
- `scripts/education/learning_report.gd`
- `tests/headless/learning_journal_test.gd`

Change only as needed:

- `scripts/education/assessment_controller.gd`
- `scenes/main/game_root.gd`, `scenes/main/game_root.tscn`
- `scenes/ui/academic_completion_modal.gd`, `.tscn`
- `tests/headless/education_report_test.gd`
- `tests/headless/web_backup_test.gd`
- `tests/headless/settings_accessibility_test.gd`
- `tests/headless/layout_audit_test.gd`
- `docs/browser_verification_checklist.md`
- `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`

## Data and report rules

- Read only existing `education.records`; do not alter `submit_answer()`, first-response merging, completion logic, or save validation.
- Expose deep-copied transient rows sorted by question ID with the existing CSV columns:
  `question_id,competency,difficulty,first_attempt_correct,total_attempts,completed,timestamp`.
- Preserve first-attempt correctness; do not infer missing historical answers.
- Label timestamp as “Last recorded activity”; do not call it completion time.
- Journal, CSV, and HTML consume the same row model.
- CSV remains RFC-4180 compatible and neutralizes formula-leading text in transport output.
- HTML is standalone UTF-8 with print CSS, no scripts/external resources/remote requests/inline handlers/auto-print, and escapes all dynamic values.
- Include: active profile slot, row count, completion/first-attempt counts, empty state, and exactly:
  `Practice records. Educator review pending — OD-012. These records do not establish learning improvement.`

## UI and delivery

- Add a button-only Learning Journal entry to the exploration HUD; no new keyboard action.
- One journal instance on `SheetLayer`; freeze movement, consume menu hotkeys/Escape, prevent stacking, and restore prior focus/lock on close.
- Refresh on every open and after profile switch or successful backup import; never retain a replaced controller reference.
- Academic completion keeps CSV export and gains direct printable HTML export without stacking the journal.
- Desktop delivery writes fixed allowlisted filenames under `user://reports/` and reports success only after writing.
- Web delivery uses injectable `JavaScriptBridge.download_buffer` preparation with UTF-8 bytes/MIME; do not claim browser execution.
- Keep controls reachable at 960×540 and text scales 1.0/1.5.

## Acceptance and negative controls

- Wrong-first/correct-retry rows agree across journal, CSV, and HTML; first response remains unchanged.
- Legacy records lacking first-response data remain unchanged and display “Not recorded”.
- Sorting, counts, timestamps, CSV escaping/formula neutralization, HTML escaping, empty reports, and OD-012 notice are tested.
- Profile A → B → A shows only the selected profile; import refreshes successful data and preserves old rows on failed import.
- Journal open/close preserves serialized controller/profile bytes, movement lock, modal exclusivity, and focus.
- Injectable delivery receives exact UTF-8 bytes, fixed filenames, and MIME types; desktop write failure gives actionable feedback without success.
- Disposable negative controls: mutate first-attempt data during rendering, omit HTML escaping, use stale controller after profile switch, or claim browser delivery; each must fail its assertion.

## Verification

- Run `education_report_test.gd`, `learning_journal_test.gd`, `web_backup_test.gd`, settings, and layout suites.
- Run `scripts/build/run_headless_tests.ps1`; record actual count.
- Run export validation if build-affecting changes occur.
- Record all logs and evidence in `report/`.
- Commit suffix `[REVIEW_PENDING_CODEX]`; add task report and traceability/testing updates.
- Codex CLI reviews first-attempt preservation, escaping, profile refresh, accessibility, and explicit OD-012 status.

Use `scripts/agy/run_next_queue.ps1`.
