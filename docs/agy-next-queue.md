# agy Next Work Queue — Batch 1 (SBL-UX-001)

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Execution contract

- Target: **Godot 4.7.2 Stable, GDScript, Compatibility renderer, Windows portable and single-threaded Web**.
- No generated images, audio, question content, dialogue, or story content.
- Preserve existing save invariants and completion gates.
- Use an isolated feature branch, record base/commit hashes, update traceability and review evidence, and end as `REVIEW_PENDING_CODEX`.
- Do not rerun SBL-BLD-004 as unfinished work: it is REVIEWED.
- Use authoritative IDs from `Soulbound_GDD_SRS.md`; do not copy conflicting descriptions or nonexistent FR IDs from older queue entries.
- Browser smoke execution remains blocked. Do not report anything as browser execution.
- Update `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, and `docs/testing.md`.
- Record actual tests and results, not anticipated passes. Preserve human acceptance gates.
- This is Batch 1 of three. Do not start Batch 2 (SBL-EDU-005) or Batch 3 (SBL-BLD-005); they follow after Codex review of this batch.

## Batch 1 — SBL-UX-001: Persistent keyboard/mouse rebinding

### Requirements

- GDD-092: configurable keyboard/mouse inputs and accessibility.
- FR-SET-001: persist and consistently apply remapped inputs and existing settings.
- TC-ACC-001: input rebinding and accessible settings.
- Supporting NFR-ACC-001.

### Dependencies

- Existing reviewed focus-following, layout and modal-exclusivity behavior.
- No OD resolution required for the scoped binding mechanism.
- Codex CLI review of `SBL-FIX-001..005` has been requested separately; record its session ID when it lands. Do not treat this task as reviewed.

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

**Do not change existing input defaults in `project.godot`.**

### Settings data model

Keep settings at `user://settings.json`, shared across profiles. Introduce settings schema version `1`, independent of profile-save schema `1`.

New fields, alongside existing audio/accessibility fields:

```json
{
  "settings_schema_version": 1,
  "input_overrides": {
    "move_left": [
      {
        "kind": "key",
        "physical_keycode": 65
      }
    ],
    "toggle_inventory": [
      {
        "kind": "mouse_button",
        "button_index": 3
      }
    ]
  }
}
```

Rules:

- An absent action means "use all authored defaults."
- An override replaces only that action's keyboard/mouse events.
- Preserve its deadzone, other event types, and every unrelated action.
- Store primitive JSON values only; never serialize `InputEvent` objects.
- Scope configurable actions to:
  - `move_left`, `move_right`, `move_up`, `move_down`
  - `shift_dimension`
  - `toggle_character`, `toggle_inventory`, `toggle_settings`
- Do not create a new interaction action or convert unrelated hardcoded controls in this slice.
- Capture creates one event per action override. Reset restores the action's complete authored keyboard/mouse event list, including alternate movement keys.
- Accept physical keyboard keys without modifier chords and mouse buttons Left/Right/Middle. Exclude wheel, motion, double-click semantics, joypad and touch.
- Reserve Escape, Enter/keypad Enter, Tab, modifier-only keys, F1 and backtick for existing cancellation/navigation/evaluator behavior. Reject Ctrl/Alt/Meta/Shift chords.
- Reject a candidate event already used by another configurable action's effective keyboard/mouse bindings. Display the conflicting action; do not silently swap or clear either action.
- Existing overlaps with Godot UI navigation defaults are preserved; do not rewrite `ui_*` actions.
- Validate the whole binding override set before applying it. Unknown action IDs, unsupported event kinds, empty event lists, invalid key/button values, duplicate events or conflicts reject the override set.
- Legacy settings without a version load existing settings and default bindings. Merely loading does not rewrite the file.
- Malformed or unsupported future-version settings must remain untouched on disk. Use session defaults, show an error, and reject persistence through the ordinary save path. An explicit "Reset settings file" action is out of scope.

### Implementation

1. Implement `InputBindings` with:
   - A deep-copied snapshot of authored defaults from `ProjectSettings` input definitions, not from an already overridden global `InputMap`.
   - Override validation, effective-event calculation, binding display text, conflict detection, application and reset.
   - Public capture-active state usable by input consumers.
2. Integrate into `SettingsManager` serialization/deserialization and `apply_all_settings()`.
   - Load/apply before gameplay begins.
   - Avoid repeatedly recapturing current InputMap state as defaults.
3. Make binding persistence transactional:
   - Validate candidate settings.
   - Write and verify a temporary settings file.
   - Promote with recoverable previous-file handling.
   - Only publish the new binding state after successful persistence.
   - On failure, keep prior bindings and show an error.
   - Complete an interrupted settings-write recovery without silently replacing an unsupported-version file.
4. Add a Controls section inside the settings scroll container:
   - Action label, effective binding text, Rebind button, Reset button.
   - Reset All Controls button.
   - Capture instruction/status label and Cancel Capture button.
5. During capture:
   - Freeze gameplay as for the existing settings sheet.
   - Consume captured, rejected, repeated and cancellation events.
   - Escape cancels capture without closing Settings.
   - Mouse activation of Cancel Capture cancels rather than binding that click.
   - Do not capture the click/key that activated Rebind.
   - Wait for the candidate's release before applying the new binding.
   - Clear affected pressed action state; prevent held input leaking when Settings closes.
   - Restore focus to the initiating Rebind button.
6. Guard evaluator input while capture is active so rejected F1/backtick events cannot open evaluator tools.
   - Gate other active settings/title input paths before they react to capture events.
   - Do not rely solely on `_unhandled_input()` consumption: global input state and earlier `_input()` consumers also need protection.
7. Update the existing hardcoded dimension hint in `GameRoot` to display the effective binding instead of `[Q]`.
8. Preserve current close behavior outside capture and existing mutual exclusivity with character/inventory sheets.

### UI/focus

- Entry: existing Settings entry points.
- Focus order includes every new button; scroll follows focus.
- Capture is a state within Settings, not a second freely stackable sheet.
- Escape once cancels capture; a subsequent Escape closes Settings.
- Reset failures retain previous effective bindings.
- No binding edits modify a profile or `project.godot`.

### Acceptance matrix

| Suite | Required assertions |
|---|---|
| `input_rebinding_test.gd` | Default snapshot matches authored defaults; applying/resetting twice is idempotent. Unrelated and `ui_*` actions, deadzones and non-key/mouse events remain unchanged. |
| Same | Rebind a movement action using physical `InputEventKey`; after release/new press the new key moves Ren and replaced keys do not. Reset restores all original alternatives. |
| Same | Mouse-button binding triggers the intended menu action outside capture. |
| Same | Successful save followed by a fresh manager restores identical effective events. Settings are shared across profile switches. |
| Same | Conflict rejection leaves both actions, serialized settings and disk bytes unchanged. |
| Same | Invalid action, empty array, bad event kind/value and duplicate event reject atomically. |
| Same | Legacy settings load defaults without rewriting; future-version input leaves disk untouched and ordinary save fails. |
| Same | Inject settings write/promotion failure: no published binding change; a valid previous settings revision remains recoverable. |
| Same | Rebind activation event is ignored. Echoes do not commit. Escape/Cancel cancels without changing settings or closing the sheet. |
| Same | Capture movement/menu/dimension/evaluator keys: position, dimension, sheet count and evaluator visibility remain unchanged. Release is consumed and no stuck action remains. |
| `settings_accessibility_test.gd` | Existing audio/accessibility persistence still works; outside capture Escape closes Settings normally. |
| `layout_audit_test.gd` | Controls fit/scroll at 960x540 and 1.0/1.5 text scale; every binding/reset/cancel control is reachable and revealed by focus. |

Tests must restore global InputMap state in cleanup and use disposable settings paths.

### Top risk

Input consumption can stop scene callbacks while leaving global pressed-action state active. Verify actual movement over physics frames and held-key release behavior, not only callback counts.

### Out of scope / blocked

- Controller/touch bindings, modifier chords, user-defined actions, input presets.
- Combat action redesign: OD-002/003/004 blocked.
- Browser-reserved shortcut certification and browser smoke execution blocked.
- Changing authored defaults, shipping tier or profile schema.

### Review checkpoint

Run targeted suites, then the full canonical headless runner. Perform a native visual check of capture, conflict feedback and keyboard focus. Codex CLI reviews persistence recovery, InputMap preservation and event leakage before Batch 2.

## Verification and reporting

- Run `scripts/build/run_headless_tests.ps1` and paste the actual suite count.
- Run `scripts/build/run_headless_tests.ps1 -Export` when the change affects the build; paste exit code and artifact sizes.
- One queue entry in `docs/agent-review-queue.md` with requirements, files, asset provenance, verification table, `REVIEW: REVIEW_PENDING_CODEX`, open questions.
- Commit suffix `[REVIEW_PENDING_CODEX]`; emit the AGENTS.md report block.

## Human-gated — do not attempt

- Shipping default tier (`OD-017`), browser smoke execution, image assets (Codex-only), binary audio (Gemini Flash), educator sign-off (`OD-012`), combat design ODs 002/003/004, narrative/story reveals.

## Rules unchanged

Godot 4.7.2 Stable, Compatibility renderer, GDScript, Windows portable + single-threaded Web; no invented numbers or story; save invariants preserved; `[REVIEW_PENDING_CODEX]`; no `REVIEWED` without a Codex session ID.

Use `scripts/agy/run_next_queue.ps1` (it reads `docs/agy-dispatch-prompt.md`).
