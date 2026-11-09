# agy Next Work Queue — SBL-UX-001

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Position

- Remediation Batches A, B, and C are `REVIEWED`.
- Batch C approval: Codex session `01a1c058-93ab-7bc0-beec-1fe287126bf8`.
- `SBL-UX-001` is now unblocked and is the next approved non-gated slice.
- Do not start the learning journal or provenance manifest until this batch is independently verified and Codex-reviewed.

## SBL-UX-001 — Persistent keyboard/mouse rebinding

### Requirements

- GDD-092: configurable keyboard/mouse inputs and accessibility.
- FR-SET-001: persist and consistently apply remapped inputs and existing settings.
- TC-ACC-001: input rebinding and accessible settings.
- Supporting NFR-ACC-001.

### Files

Create:

- `scripts/settings/input_bindings.gd`
- `tests/headless/input_rebinding_test.gd`

Change:

- `scripts/settings/settings_manager.gd`
- `scenes/ui/settings_sheet.gd`
- `scenes/ui/settings_sheet.tscn`
- `scenes/main/game_root.gd`
- `scenes/ui/evaluator_debug_bar.gd`
- `tests/headless/settings_accessibility_test.gd`
- `tests/headless/layout_audit_test.gd`
- `docs/agent-review-queue.md`
- `docs/traceability-matrix.md`
- `docs/testing.md`

Do **not** change authored defaults in `project.godot`.

### Settings model

Keep global `user://settings.json`, independent from profile schema. Add:

```json
{
  "settings_schema_version": 1,
  "input_overrides": {
    "move_left": [{"kind": "key", "physical_keycode": 65}]
  }
}
```

Allow only `move_left`, `move_right`, `move_up`, `move_down`, `shift_dimension`, `toggle_character`, `toggle_inventory`, and `toggle_settings`.

- Absent action means authored defaults.
- Preserve deadzones, unrelated actions, `ui_*` actions, and non-key/mouse events.
- Store primitive JSON values, never `InputEvent` objects.
- Physical keys without modifier chords; mouse Left/Right/Middle only.
- Reject wheel, motion, double-click, joypad, touch, modifier chords, Escape, Enter, Tab, F1, backtick, and modifier-only keys.
- Reject conflicts with another configurable action; show the conflicting action without silently swapping.
- Validate the entire override set atomically.
- Legacy unversioned settings load defaults without rewriting.
- Malformed/future-version settings remain untouched, use session defaults, show an error, and cannot be saved through the ordinary path.

### Implementation rules

1. Snapshot authored defaults from `ProjectSettings` input definitions, not an already-overridden `InputMap`.
2. Implement validation, effective-event calculation, display text, conflicts, apply/reset, and public capture-active state.
3. Load/apply before gameplay begins and avoid recapturing overridden state as defaults.
4. Make persistence transactional: validate, write/verify a temporary file, promote safely, and publish state only after success.
5. Add a Controls section: action label, effective binding, Rebind, Reset, Reset All, capture status, and Cancel Capture.
6. During capture, freeze gameplay; consume candidate, rejected, repeated, cancellation, activation, and release events. Escape cancels capture without closing Settings.
7. Prevent captured movement/menu/dimension/evaluator events from moving Ren, changing dimension, opening sheets, or opening evaluator tools. Clear pressed state on completion/cancel.
8. Restore focus to the initiating Rebind button and preserve existing modal exclusivity.
9. Show the effective dimension binding instead of a hardcoded `[Q]` hint.

### Acceptance matrix

- New `input_rebinding_test.gd`: defaults match authored inputs; apply/reset are idempotent; unrelated/UI actions and deadzones are unchanged.
- Physical movement rebind works after release; replaced key stops working; reset restores all alternatives.
- Mouse menu binding works outside capture.
- Save/reload restores identical effective events and remains shared across profile switches.
- Conflict, invalid action, empty array, bad kind/value, duplicate, and write/promotion failure reject atomically with disk bytes unchanged.
- Legacy settings load without rewriting; future-version settings remain untouched and ordinary save fails.
- Rebind activation, echo, Escape, Cancel, movement, menu, dimension, and evaluator events are consumed without state leakage.
- Existing `settings_accessibility_test.gd` remains green; outside capture Escape closes Settings normally.
- `layout_audit_test.gd` proves controls fit and remain focus-reachable at 960×540 and text scales 1.0/1.5.
- Tests restore global `InputMap` state and use disposable settings paths.

### Out of scope / blocked

- Controller/touch bindings, modifier chords, custom actions, input presets.
- Combat redesign (`OD-002/003/004`), profile schema changes, shipping tier, browser smoke, images, binary audio, and educator approval.

### Verification

- Run targeted rebinding, settings, and layout suites.
- Run `scripts/build/run_headless_tests.ps1`; record actual count.
- Run `scripts/build/run_headless_tests.ps1 -Export` if build-affecting changes occur.
- Record all negative controls and logs in `report/`.
- Commit suffix `[REVIEW_PENDING_CODEX]`; add queue/report/traceability/testing records.
- Codex CLI reviews persistence recovery, InputMap preservation, conflict behavior, focus, and event leakage before the next slice.

Use `scripts/agy/run_next_queue.ps1`.
