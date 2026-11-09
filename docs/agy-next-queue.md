# agy Next Work Queue — Remediation Batch A (SBL-REV-001..003)

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

Source: Codex CLI review session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`, range `0b66fdb..f26f2d1`, verdict `CHANGES_REQUESTED` (7 findings).

## Contract and baseline

- **Platform:** Godot 4.7.2 Stable, GDScript, Compatibility renderer, Windows portable and single-threaded Web.
- No image or audio asset generation. Do not change existing procedural cue synthesis.
- No invented story, balance, drops, rewards, SP costs, damage values, cooldowns or status rules.
- Preserve all previously reviewed fixes. The current tree already contains persistence helpers absent from the reviewed snapshot; verify their behavior before changing them.
- One commit per task, on the current feature branch. Record the exact base and resulting commit.
- Every task updates `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, and `docs/testing.md`.
- Record review findings by number. Do not mark a finding resolved solely because a helper exists or a direct method-call test passes.
- Browser smoke execution, shipping `OD-017`, educator `OD-012` and asset production remain blocked.
- Do not implement or rebase staged `SBL-UX-001` into these commits.
- **This is remediation Batch A of three.** Batch B (`SBL-REV-004`, SFX bus) and Batch C (`SBL-REV-005/006`, SP + purchased skills) follow after Codex review. Do not start them.

## Task order

`SBL-REV-001` -> `SBL-REV-002` -> `SBL-REV-003`. They share session ownership and modal behavior.

---

## SBL-REV-001 — Profile-owned expedition suspension and terminal commits

**Findings:** 1, P1.

**Important:** reviewed commit `e25491d` (SBL-FIX-006) already added `_persist_active_expedition()`, `_load_active_expedition()` and a persisted-resume regression test. Do **not** rebuild those. Verify them, then close the remaining gaps below: close-on-failed-save, stale callback ownership, and cross-profile isolation.

**Requirements**

- AGENTS.md persistence invariants.
- GDD-004, GDD-037, GDD-098..101.
- FR-DNG-002/003, FR-SAV-001.
- TC-DNG-002/003/004, TC-SAV-001/002.

**Dependencies**

- Current reviewed persistence, validation and extraction/defeat failure handling.
- Implement before profile/title activation changes.

**Files to change**

- `scenes/main/game_root.gd`
- `scenes/dungeon/dungeon_expedition.gd`
- `scripts/persistence/gameplay_profile_validator.gd`
- `tests/headless/dungeon_scene_test.gd`
- `tests/headless/web_backup_test.gd`
- `tests/headless/save_compatibility_recovery_test.gd`

**Data model and migration**

- Retain profile envelope schema `1`.
- Reuse existing optional `world.active_expedition`; do not introduce a second snapshot location.
- Preserve the existing snapshot fields: `is_active`, `seed`, `room_count`, `current_step`, `expedition_path`, `satchel_items`.
- Missing `active_expedition` means no suspended run. Legacy profiles remain readable without a write-on-load migration.
- Validate the entire snapshot before applying any inventory or dungeon mutation.
- Require a valid generated layout/path and an in-range step. Do not silently clamp invalid imported progress into a different valid run.
- Do not serialize mid-battle state: **OD-009 remains blocked**.
- Bind runtime expedition callbacks to the profile slot, session generation and originating expedition instance. These are runtime ownership checks, not new saved balance data.

**Implementation**

1. Verify `_persist_active_expedition()` and `_load_active_expedition()` against the current tree. Preserve working reviewed behavior.
2. Clear the runtime snapshot and invalidate old expedition callbacks **before** activating a different profile.
3. Load the selected slot's validated snapshot into a deep copy. Never preserve the previous slot's snapshot when the selected slot has none.
4. Make suspension commit-first:
   - Add a `commit_suspend` callable and a suspend-failure signal/path consistent with existing extraction/defeat handling.
   - Build a snapshot while the expedition remains active.
   - Persist it into the owning profile through a load-modify-save operation.
   - Only after success mark the scene suspended, publish the runtime snapshot and close it.
   - On failure, keep the expedition open and active, retain loot/progress and offer Retry Suspend.
   - Remove the current close-on-failed-save behavior.
5. Preserve unrelated profile sections and inventory ownership while saving the snapshot. Suspension must not bank the satchel.
6. Restore only after snapshot validation succeeds. If restoration fails, surface an error and retain the stored snapshot; do not silently start a fresh run over it.
7. Keep extraction and defeat transactional:
   - Extraction writes the banked inventory and removes `active_expedition` in one profile revision.
   - Defeat writes the approved satchel loss and removes the snapshot in one revision.
   - Publish live success only after that write succeeds.
8. Reject callbacks from a previous slot/session/closed scene before reading or writing the active profile.
9. Do not allow profile switching/title activation to discard a live expedition implicitly. Require the existing suspend/retreat route first.
10. Preserve duplicate/early extraction guards and failure retry behavior.

**UI/focus**

- Suspend failure remains inside the expedition.
- Focus the retry button; keep Retreat and existing valid navigation available.
- No success message or overworld return on failed suspension.
- Do not introduce a second modal over the expedition.

**Top risk**

A stale callable can write the old run into the newly selected profile even after clearing `_suspended_expedition`. Test callback ownership, not only snapshot clearing.

**Out of scope**

- Mid-turn saves, new run rewards, coin/EXP retention policy, recovery mechanics.
- Rollback-proof protection against deliberate import of an older valid backup.
- New dungeon grammar or room budgets: `OD-011` remains unchanged.

---

## SBL-REV-002 — Title-aware Settings and Backup overlay

**Findings:** 2, P2.

**Requirements**

- GDD-092, GDD-098, GDD-102.
- FR-SET-001, FR-SAV-002.
- TC-ACC-001, TC-SAV-002.

**Dependencies**

- SBL-REV-001.
- Existing SettingsSheet backup controls and focus-following behavior.

**Files to change**

- `scenes/main/game_root.gd`
- `scenes/main/game_root.tscn`
- `scenes/ui/title_screen.gd`
- `scenes/ui/settings_sheet.gd`
- `tests/headless/title_screen_audio_test.gd`
- `tests/headless/settings_accessibility_test.gd`
- `tests/headless/web_backup_test.gd`

**Data model**

- No settings or profile schema change.
- Title Settings/Backup uses the **title's selected slot**, which may differ from the currently loaded gameplay slot.

**Implementation**

1. Keep ordinary gameplay `_toggle_settings_sheet()` guards.
2. Add an explicit title-settings entry path accepting: selected slot, opening control for focus restoration, and initial section (general settings or backup).
3. Allow this path only when the title is the sole blocking screen and no settings instance is already open.
4. Add a dedicated title-overlay `CanvasLayer` above `TitleLayer`; derive its layer from `TitleLayer.layer + 1`.
5. Disable title controls/input while the overlay is open. Prevent evaluator/menu hotkeys from opening another screen above it.
6. Route title Settings, Backup and recovery-export actions through this path.
7. For Backup, focus/reveal the backup controls immediately.
8. A successful title-context import refreshes title summaries for the selected slot. Do not activate that slot or replace hidden gameplay consumers until explicit activation.
9. Closing returns to the title and restores the originating control's focus.
10. Do not unfreeze Ren while the title remains visible.
11. Preserve existing gameplay-context import/reload behavior.

**UI/focus**

- Exactly one title settings overlay.
- Escape closes the overlay, leaving the title open.
- Mouse events cannot activate title controls underneath it.
- Recovery export opens the selected recovered slot's backup context.

**Top risk**

Treating the title-selected slot as the active gameplay slot can import into or export the wrong profile.

**Out of scope**

- Input rebinding, new settings fields, title redesign.
- Browser clipboard/download execution.
- Changing global modal policy to allow arbitrary stacking.

---

## SBL-REV-003 — Distinct new journey and safe profile activation

**Findings:** 3 and 4, P2.

**Requirements**

- GDD-015, GDD-098.
- FR-SAV-001, FR-WLD-001/002.
- TC-SAV-001/002, TC-WLD-001, TC-DIM-001.

**Dependencies**

- SBL-REV-001/002.

**Files to change**

- `scenes/ui/title_screen.gd`
- `scenes/ui/title_screen.tscn`
- `scenes/main/game_root.gd`
- `scenes/world/world_router.gd`
- `tests/headless/title_screen_audio_test.gd`
- `tests/headless/transition_test.gd`
- `tests/headless/dimension_test.gd`

Create:

- `tests/headless/profile_activation_test.gd`

**Chosen new-game behavior**

Use **empty-slot selection**, with no overwrite operation in this remediation.

- "Start New Journey" opens a slot picker showing which slots are empty.
- Only a genuinely missing profile is selectable for new-game creation.
- Occupied, recovered, corrupt, unreadable and unsupported-version slots are not empty.
- If all slots are occupied/unavailable, show "No empty profile slots" and retain Back/Continue.
- No deletion, overwrite confirmation or profile-reset API is needed.

**Data model**

- Retain profile schema `1`.
- Create new profiles through `ProfileStore.new_profile()` and existing initialization paths.
- Do not create new default story/progression values.
- Do not add saved position/dimension data in this task.
- Choose the reviewer-permitted fallback: **every explicit title activation returns to existing `DEFAULT_START_REGION` / `DEFAULT_START_SPAWN` in the physical dimension**.
- Preserve chapter progress, inventory, educational records and any suspended expedition. Returning to the starting region is not extraction.

**Implementation**

1. Replace the ambiguous start signal flow with distinct new-game and continue requests.
2. Slot selection updates title selection and summaries only; it does not automatically start gameplay.
3. Continue activates the selected existing profile. For an empty selected slot, direct the player to the explicit new-game picker.
4. Recheck slot emptiness immediately before creating a new profile; reject if it became occupied.
5. Create and validate the new profile successfully before dismissing the title. On write failure, remain on the title and show the error.
6. Implement a shared profile-activation path:
   - Preflight the selected profile with existing gameplay validation.
   - Preflight the existing default region/spawn using the router's collision/bounds validation.
   - Reject activation during a live expedition, unresolved encounter or transition.
   - Invalidate previous session callbacks and clear transient state.
   - Load the selected profile's consumers and suspended snapshot.
   - Replace/reset the region through a validated router path, not a production call to evaluator `debug_warp()`.
   - Set physical dimension and synchronize collision masks/region visibility.
   - Reset velocity, stale interaction references, pending callbacks and transition reservations.
   - Rebind fixtures and apply that profile's chapter/release gates.
   - Dismiss the title only after successful activation.
7. If activation fails, retain the title and prevent playable access to a partially activated scene. Preserve the prior profile's files.
8. Keep settings global; profile activation must not reset audio/accessibility preferences.

**UI/focus**

- Separate picker modes for profile selection and new-game empty-slot selection.
- Back returns to the initiating title button.
- Disabled occupied slots remain clearly labeled.
- Errors do not close the title or strand focus.
- No nested overwrite modal.

**Top risk**

Resetting the world and loading the profile in the wrong order can expose a playable scene with another profile's gates, dimension or suspended inventory.

**Out of scope**

- Overwriting/deleting occupied profiles.
- Persistent exact-location resume, new checkpoint policy or mid-combat resume: `OD-009`.
- Changing the existing default starting region or story.
- Fast travel and new unlock rules.

---

## Acceptance matrix

All tests use disposable profile roots and restore global AudioServer/test state. UI-path assertions must activate controls through mouse/keyboard input where the finding concerns user access; direct helper calls alone are insufficient.

| Task / suite | Required assertions |
|---|---|
| REV-001 — `dungeon_scene_test.gd` | Suspend via UI, destroy the entire GameRoot, create a fresh session for the same slot: seed, path, step and satchel match; bank unchanged. |
| Same | A suspends, B activates with no run: B has no resumable A snapshot. Returning to A restores A's run. Also test two slots with different saved runs. |
| Same | Retain an A expedition callback, activate B, invoke stale callback: rejected; both profiles' bytes/inventories unchanged. |
| Same | Inject suspend write failure: expedition remains active/open; satchel and bank unchanged; retry succeeds and only then closes. |
| Same | Resume -> extraction -> restart: reward transferred once, snapshot absent; repeated extraction/stale callbacks cannot bank again. |
| Same | Inject extraction/defeat write failure: prior snapshot remains, no false success; retry commits exactly once. |
| Same | Defeat preserves secured gear, level/skills, story and education while applying only existing approved satchel loss. |
| Same / `web_backup_test.gd` | Backup round-trip preserves the selected slot's suspended run. Malformed snapshot import fails without modifying active profile bytes. |
| `save_compatibility_recovery_test.gd` | Legacy profile without snapshot loads; invalid step/path/count is rejected without partial restore or silent clamping. |
| REV-002 — `title_screen_audio_test.gd` | Click title Settings and Backup: one visible settings sheet above title; Backup reveals correct section; underlying title buttons do not activate. |
| Same / `web_backup_test.gd` | Title selects B while gameplay A is loaded: export/import context is B; A remains unchanged. |
| `settings_accessibility_test.gd` | Escape closes overlay only, title remains, Ren stays frozen, originating focus restored; repeated entry creates no duplicates. |
| REV-003 — `profile_activation_test.gd` | Occupied slot -> New Journey does not emit Continue or reload old progress; picker enables only genuinely empty slots. |
| Same | All occupied/unavailable: no destructive action, Back remains reachable. Corrupt/future/unreadable slots are not presented as empty. |
| Same | Empty slot creation failure leaves title open and other slots byte-identical. Recheck occupancy before creation. |
| Same | Activate early-profile B while A was in late-region/spirit state: default region/spawn, physical dimension, zero velocity, correct collision and B gates; no A snapshot or transient flags. |
| Same | Activation failure leaves no playable partially activated world and no profile corruption. |
| `transition_test.gd` / `dimension_test.gd` | Default spawn passes existing footprint checks; dimension visuals/masks agree; locked-region transition still rejects. |

## Negative controls

Run only against disposable copies; never alter tracked production files for fault injection.

- Disable snapshot persistence: fresh-session suspend/resume test must fail.
- Disable slot/session callback ownership: cross-profile stale-callback test must fail.
- Restore generic title modal rejection: title Settings access test must fail.
- Wire New Journey to Continue again: new-game test must fail.
- Skip world/dimension reset: early-profile activation test must fail.

Record the expected and observed nonzero exits and the failing assertion for each negative control.

## Verification and reporting

After this batch:

1. Run the affected persistence, title, activation, transition, dimension and backup suites.
2. Run the full canonical runner: `scripts/build/run_headless_tests.ps1`. Paste the actual suite count.
3. Perform native title/settings/new-slot focus checks and record what was observed.
4. One queue entry per task in `docs/agent-review-queue.md` with requirements, files, asset provenance, verification table, `REVIEW: REVIEW_PENDING_CODEX`, open questions.
5. Commit suffix `[REVIEW_PENDING_CODEX]`; emit the AGENTS.md report block.
6. Codex CLI reviews findings 1-4, including stale callbacks, failed suspension, selected-slot backup context and safe world activation.

## Human-gated — do not attempt

- Shipping default tier (`OD-017`), browser smoke execution, image assets (Codex-only), binary audio (Gemini Flash), educator sign-off (`OD-012`), combat design ODs 002/003/004, narrative/story reveals, mid-battle persistence (`OD-009`).

## Rules unchanged

Godot 4.7.2 Stable, Compatibility renderer, GDScript, Windows portable + single-threaded Web; no invented numbers or story; save invariants preserved; `[REVIEW_PENDING_CODEX]`; no `REVIEWED` without a Codex session ID.

Use `scripts/agy/run_next_queue.ps1` (it reads `docs/agy-dispatch-prompt.md`).
