# agy Next Work Queue — SBL-UX-001 Review Fixes

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

Codex review: session `01a1c06b-9905-7633-a299-32dac1671a06`, range `b4c12cc..4b19977`.

## Fix 1 — Per-action reset must be atomic

In `scripts/settings/settings_manager.gd`, resetting one action can erase its override, call `apply_overrides()`, ignore a conflict error, and leave persisted/displayed bindings inconsistent.

- Build a candidate override dictionary with the action reset to authored defaults.
- Validate the complete candidate before mutating current overrides or `InputMap`.
- On conflict/error, retain current overrides, live bindings, UI text, and disk bytes; show actionable feedback.
- Add a regression test: rebind Move Left to J and Move Right to A, reset Move Left, assert rejection and unchanged state.

## Fix 2 — Validate binding entry types before duplicate checking

In `scripts/settings/input_bindings.gd`, malformed arrays containing non-dictionaries can reach duplicate comparison and trigger an invalid cast.

- Validate every entry is a dictionary and has an allowed primitive shape before pairwise comparisons or casts.
- Reject malformed arrays with `ERR_INVALID_DATA` (or existing validation error) without mutation.
- Add a regression fixture such as `[{"kind":"key","physical_keycode":74}, 1]` and assert nonzero/rejection without script errors or accepted settings.

## Fix 3 — Isolate capture tests from real user settings

In `tests/headless/input_rebinding_test.gd`, successful capture calls `settings.save_settings()` using the real `user://settings.json`.

- Redirect the test manager/settings path to a disposable test directory, or snapshot and restore the original settings bytes in a guaranteed cleanup block.
- Prove the real user settings file is byte-identical before and after the suite.
- Keep InputMap restoration and temporary test data cleanup.

## Files

- `scripts/settings/settings_manager.gd`
- `scripts/settings/input_bindings.gd`
- `scenes/ui/settings_sheet.gd` only if needed for test-path injection
- `tests/headless/input_rebinding_test.gd`
- `tests/headless/settings_accessibility_test.gd` only if needed
- `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`

## Verification

- Run input rebinding, settings/accessibility, and layout suites.
- Run `scripts/build/run_headless_tests.ps1` and record the actual count.
- Confirm malformed entries reject without script errors.
- Confirm conflicting reset leaves live and persisted state unchanged.
- Confirm the real user settings file is byte-identical after tests.
- Record negative controls/logs in `report/`.
- Commit with `[REVIEW_PENDING_CODEX]`; Codex CLI must re-review before proceeding.

## Boundaries

- Preserve all eight action allowlists, authored defaults, schema version 1, transactional persistence, and capture event consumption.
- No new input actions, controller/touch support, combat ODs, images, binary audio, browser smoke, or release decisions.

Use `scripts/agy/run_next_queue.ps1`.
