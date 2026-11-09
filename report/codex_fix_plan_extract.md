OPEN QUESTIONS:
```

Only Codex CLI review with recorded session evidence may mark implementation `REVIEWED`. **SBL-UX-001 resumes after 
this remediation is reviewed and the blocked remainder of finding 5 is explicitly resolved or accepted for deferral by 
the appropriate authority.**
tokens used
154,306
Split this into **three remediation batches**: profile/title integrity first, audio routing second, combat integration third. Review each batch before proceeding. Keep **SBL-UX-001 staged and paused** until the seven findings are closed or explicitly dispositioned by Codex and the relevant decision owner.

One limitation prevents promising seven fully non-gated fixes: the current `BossEncounter` lacks effect handlers for the four purchased active skills. Wiring their buttons is straightforward; choosing their boss damage/status behavior can require OD-003/004. The queue below marks that boundary explicitly.

No files were modified.

---

# agy remediation queue ΓÇö SBL-FIX-001..005 review

## Contract and baseline

- **Review source:** Codex CLI session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`, range `0b66fdb..f26f2d1`, verdict `CHANGES_REQUESTED`.
- **Plan owner:** Codex.
- **Implementation owner:** agy.
- **Reviewer:** Codex CLI. agy does not review its own implementation.
- **Platform:** Godot 4.7.2 Stable, GDScript, Compatibility renderer, Windows portable and single-threaded Web.
- No image or audio asset generation. Do not change existing procedural cue synthesis.
- No invented story, balance, drops, rewards, SP costs, damage values, cooldowns or status rules.
- Preserve all previously reviewed fixes. The current tree already contains persistence helpers absent from the reviewed snapshot; verify their behavior before changing them.
- Use separate commits per task on isolated feature branches. Record exact bases and resulting commits.
- Every task updates:
  - `docs/agent-review-queue.md`
  - `docs/traceability-matrix.md`
  - `docs/testing.md`
- Record review findings by number. Do not mark a finding resolved solely because a helper exists or a direct method-call test passes.
- Browser smoke execution, shipping OD-017, educator OD-012 and asset production remain blocked.
- Do not implement or rebase staged SBL-UX-001 into these commits.

## Ordering

| Batch | Tasks | Purpose |
|---|---|---|
| A | SBL-REV-001 ΓåÆ 002 ΓåÆ 003 | Close the P1 persistence/profile leak, then repair title access and profile activation. These share session ownership and modal behavior. |
| B | SBL-REV-004 | Repair SFX routing independently, with no combat-design dependency. |
| C | SBL-REV-005 ΓåÆ 006 | Apply the existing passive value first, then wire purchased active skills and the six-slot limit. Record any missing boss-effect semantics as blocked. |

Codex CLI reviews each batch before the next batch starts. Findings within a batch receive fixes and re-review before dependent work proceeds.

## SBL-REV-001 ΓÇö Profile-owned expedition suspension and terminal commits

**Findings:** 1, P1.

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
- Preserve the existing snapshot fields:
  - `is_active`
  - `seed`
  - `room_count`
  - `current_step`
  - `expedition_path`
  - `satchel_items`
- Missing `active_expedition` means no suspended run. Legacy profiles remain readable without a write-on-load migration.
- Validate the entire snapshot before applying any inventory or dungeon mutation.
- Require a valid generated layout/path and an in-range step. Do not silently clamp invalid imported progress into a different valid run.
- Do not serialize mid-battle state: **OD-009 remains blocked**.
- Bind runtime expedition callbacks to the profile slot, session generation and originating expedition instance. These are runtime ownership checks, not new saved balance data.

**Implementation**

1. Verify `_persist_active_expedition()` and `_load_active_expedition()` against the current tree. Preserve working reviewed behavior.
2. Clear runtime snapshot and invalidate old expedition callbacks **before** activating a different profile.
3. Load the selected slotΓÇÖs validated snapshot into a deep copy. Never preserve the previous slotΓÇÖs snapshot when the selected slot has none.
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
- New dungeon grammar or room budgets: OD-011 remains unchanged.

## SBL-REV-002 ΓÇö Title-aware Settings and Backup overlay

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
- Title Settings/Backup uses the **titleΓÇÖs selected slot**, which may differ from the currently loaded gameplay slot.

**Implementation**

1. Keep ordinary gameplay `_toggle_settings_sheet()` guards.
2. Add an explicit title-settings entry path accepting:
   - Selected slot.
   - Opening control for focus restoration.
   - Initial section: general settings or backup.
3. Allow this path only when the title is the sole blocking screen and no settings instance is already open.
4. Add a dedicated title-overlay `CanvasLayer` above `TitleLayer`; derive its layer from `TitleLayer.layer + 1`.
5. Disable title controls/input while the overlay is open. Prevent evaluator/menu hotkeys from opening another screen above it.
6. Route title Settings, Backup and recovery-export actions through this path.
7. For Backup, focus/reveal the backup controls immediately.
8. A successful title-context import refreshes title summaries for the selected slot. Do not activate that slot or replace hidden gameplay consumers until explicit activation.
9. Closing returns to the title and restores the originating controlΓÇÖs focus.
10. Do not unfreeze Ren while the title remains visible.
11. Preserve existing gameplay-context import/reload behavior.

**UI/focus**

- Exactly one title settings overlay.
- Escape closes the overlay, leaving the title open.
- Mouse events cannot activate title controls underneath it.
- Recovery export opens the selected recovered slotΓÇÖs backup context.

**Top risk**

Treating the title-selected slot as the active gameplay slot can import into or export the wrong profile.

**Out of scope**

- Input rebinding, new settings fields, title redesign.
- Browser clipboard/download execution.
- Changing global modal policy to allow arbitrary stacking.

## SBL-REV-003 ΓÇö Distinct new journey and safe profile activation

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

- ΓÇ£Start New JourneyΓÇ¥ opens a slot picker showing which slots are empty.
- Only a genuinely missing profile is selectable for new-game creation.
- Occupied, recovered, corrupt, unreadable and unsupported-version slots are not empty.
- If all slots are occupied/unavailable, show ΓÇ£No empty profile slotsΓÇ¥ and retain Back/Continue.
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
   - Preflight the existing default region/spawn using the routerΓÇÖs collision/bounds validation.
   - Reject activation during a live expedition, unresolved encounter or transition.
   - Invalidate previous session callbacks and clear transient state.
   - Load the selected profileΓÇÖs consumers and suspended snapshot.
   - Replace/reset the region through a validated router path, not a production call to evaluator `debug_warp()`.
   - Set physical dimension and synchronize collision masks/region visibility.
   - Reset velocity, stale interaction references, pending callbacks and transition reservations.
   - Rebind fixtures and apply that profileΓÇÖs chapter/release gates.
   - Dismiss the title only after successful activation.
7. If activation fails, retain the title and prevent playable access to a partially activated scene. Preserve the prior profileΓÇÖs files.
8. Keep settings global; profile activation must not reset audio/accessibility preferences.

**UI/focus**

- Separate picker modes for profile selection and new-game empty-slot selection.
- Back returns to the initiating title button.
- Disabled occupied slots remain clearly labeled.
- Errors do not close the title or strand focus.
- No nested overwrite modal.

**Top risk**

Resetting the world and loading the profile in the wrong order can expose a playable scene with another profileΓÇÖs gates, dimension or suspended inventory.

**Out of scope**

- Overwriting/deleting occupied profiles.
- Persistent exact-location resume, new checkpoint policy or mid-combat resume: OD-009.
- Changing the existing default starting region or story.
- Fast travel and new unlock rules.

## SBL-REV-004 ΓÇö Effective SFX bus routing and mute

**Findings:** 7, P2.

**Requirements**

- GDD-087.
- FR-SET-001.
- TC-ACC-001, audio-controls portion.
- Supporting GDD-096.

**Dependencies**

- Batch A reviewed.
- No asset-generation capability required.

**Files to change**

- `scripts/audio/audio_manager.gd`
- `scripts/settings/settings_manager.gd`
- `scenes/main/game_root.gd`
- `tests/headless/title_screen_audio_test.gd`
- `tests/headless/settings_accessibility_test.gd`

**Data model**

- No settings schema change.
- Reuse existing `master_volume`, `music_volume`, `sfx_volume`.
- Bus creation is runtime configuration, not a generated audio asset.

**Implementation**

1. Add an idempotent bus-initialization helper callable before player creation and before settings application.
2. Ensure `Music` and `SFX` buses exist and route to `Master`.
   - Reuse existing buses by name.
   - Do not duplicate/reorder or overwrite unrelated buses.
3. Invoke initialization before `AudioManager` creates its players.
4. Assign every cue player to `SFX` and verify the bus exists; do not accept fallback to Master.
5. Apply loaded settings after buses exist and before user-triggered playback.
6. For zero volume, use the bus mute flag as well as existing gain handling. Positive volume clears that settings-controlled mute flag.
7. Master affects all output; Music and SFX remain independent.
8. Preserve existing cue streams, synthesis, gain constants and cache behavior.

**UI/focus**

- Existing sliders and focus order only.
- No new controls or playback assets.

**Top risk**

Players may retain Master routing if the SFX bus is created after they initialize, making slider values appear correct without affecting playback.

**Out of scope**

- New cues, music, synthesis changes, mixing balance.
- Binary audio acquisition: OD-015 remains pending.
- Browser audio-unlock certification.

## SBL-REV-005 ΓÇö Apply authored Phase Mastery capacity

**Findings:** 6, P2.

**Requirements**

- GDD-019, GDD-030.
- FR-CMB-001/003.
- TC-CMB-002; persistence checks supporting TC-SAV-001.
- No `FR-MAG-*` IDs: those do not exist in the authoritative SRS.

**Dependencies**

- Batch B reviewed.
- Existing saved skill unlocks.
- Implement before SBL-REV-006.

**Files to change**

- `scripts/magic/kurei_tree.gd`
- `scenes/combat/battle_fixture.gd`
- `scenes/combat/boss_encounter.gd`
- `scenes/main/game_root.gd`
- `tests/headless/kurei_tree_test.gd`
- `tests/headless/kurei_combat_test.gd`
- `tests/headless/boss_combat_test.gd`

**Data model**

- No save schema change.
- Derive the passive from existing `phase_mastery` ownership.
- Put the **already-advertised maximum SP value, 4**, in one structured passive definition. Make the description and encounter configuration use that source.
- Do not store derived encounter maximum SP back into the permanent profile.

**Implementation**

1. Add a read-only passive-capacity query using the existing unlock.
2. Configure both encounter types before their first UI refresh/action.
3. Without mastery, preserve each encounterΓÇÖs existing baseline maximum and starting SP.
4. With mastery, set maximum SP to exactly `4`.
5. Preserve existing starting SP; increasing maximum capacity is not authorization to refill SP.
6. Reapplying configuration must not add capacity repeatedly, refill spent SP or reset cooldowns.
7. Existing regeneration uses the effective maximum.
8. A fresh encounter after respec/profile switching derives the selected profileΓÇÖs current ownership.
9. Exclude the passive from castable actions; attempting to cast it must reject without spending an action or changing state.

**UI/focus**

- Existing SP labels display the effective maximum.
- No new passive button in the battle grid.

**Top risk**

Applying a ΓÇ£maximum SPΓÇ¥ passive as a refill or additive bonus creates unintended resources and changes balance.

**Out of scope / blocked**

- Changing initial SP, regeneration, costs or cooldowns: OD-003.
- Initiative and status changes: OD-002/004.
- Other new passive effects.

## SBL-REV-006 ΓÇö Purchased-skill menus and six-slot enforcement

**Findings:** 5, P2.

**Requirements**

- GDD-018..020, GDD-030, GDD-089.
- FR-CMB-003/004.
- TC-CMB-001/002; six-equipped-spell check from GDD/SRS ┬º4.5.
- Supporting GDD-092 / TC-ACC-001 for keyboard access.

**Dependencies**

- SBL-REV-005.
- Do not implement undefined boss-effect semantics.

**Files to change**

- `scripts/magic/kurei_tree.gd`
- `scripts/magic/kurei_system.gd`
- `scripts/persistence/gameplay_profile_validator.gd`
- `scenes/ui/character_sheet.gd`
- `scenes/ui/character_sheet.tscn`
- `scenes/combat/battle_fixture.gd`
- `scenes/combat/battle_fixture.tscn`
- `scenes/combat/boss_encounter.gd`
- `scenes/combat/boss_encounter.tscn`
- `scenes/main/game_root.gd`
- `tests/headless/kurei_tree_test.gd`
- `tests/headless/kurei_combat_test.gd`
- `tests/headless/boss_combat_test.gd`
- `tests/headless/ui_sheets_test.gd`
- `tests/headless/layout_audit_test.gd`

**Data model and migration**

There are seven authored active tree skills. Exposing all seven simultaneously would violate the six-equipped limit.

- Add optional `equipped_skills` under existing `character.kurei_tree`.
- Retain profile envelope schema `1`.
- Store an ordered array of unique active, unlocked skill IDs, maximum six.
- Passive `phase_mastery` never occupies a slot.
- Legacy tree data without this field defaults in memory to the existing three starter skills. Persist on the next successful relevant save; no write-on-load.
- Reject malformed explicit arrays, duplicate IDs, locked/unknown/passive IDs and a seventh slot.
- New purchases auto-equip only when a slot is available; otherwise show ΓÇ£Unlocked ΓÇö equip in Character.ΓÇ¥
- Respec restores the existing starter loadout.
- Save loadout with the tree through the existing profile merge path. Failed persistence must not claim success or discard unrelated profile fields.

**Implementation**

1. Add active/passive classification and stable ordered skill-ID queries.
2. Add Equip/Unequip controls for unlocked active skills in the existing Character Kurei section.
3. Enforce the six-slot limit in both UI and model APIs.
4. Replace the hardcoded three-button battle menus with a grid populated from the equipped, unlocked active IDs.
5. Bind each button to its actual skill ID. Display authored name, existing cost/cooldown and unavailable reason.
6. Disable buttons when:
   - Not the playerΓÇÖs valid action phase.
   - Insufficient SP or cooldown active.
   - Skill is not supported by the encounterΓÇÖs effect implementation.
7. Validate again inside `request_action()` before mutating SP, cooldowns, action markers or menu state.
   - Unknown, locked, unequipped, passive and unsupported skills reject atomically.
   - Add the missing boss ownership check.
8. Preserve existing starter effect behavior and existing implemented `BattleFixture` advanced effects.
9. Do not parse effect values from descriptions or equate `base_power` with fixture HP pips.
10. Open Kurei with focus on the first enabled skill or Cancel. Cancel returns focus to Kurei without consuming a turn. After casting, restore appropriate action/result focus.
11. Ensure repeated menu rebuilds do not duplicate controls or signal connections.
12. Configure both normal and evaluator-created encounters from the current profileΓÇÖs tree/loadout.

**Explicit OD boundary**

The inspected `BossEncounter.request_action()` implements only starter effects. The four purchased active skills currently lack boss handlers.

- Populate their equipped menu entries, but show them **disabled with ΓÇ£Boss effect pending design approvalΓÇ¥** until an authoritative existing boss mapping is supplied.
- Reject their direct action requests without resource/action mutation.
- Do not transplant BattleFixture damage pips, shield strengths or status durations into boss combat by assumption.
- **OD-003/004 block the missing boss-effect mapping.**
- This is a partial remediation of finding 5, not closure. Record the blocked remainder and do not mark all seven findings resolved.
- If an existing approved mapping is found, cite its exact source and reuse it unchanged; otherwise preserve the block.

**Top risk**

A newly visible button can spend SP and advance the boss turn while doing nothing, or expose more than six active spells. Pin both through UI-driven tests.

**Out of scope**

- New damage/status implementations or balance changes.
- New skills, refunds/repricing, elemental charts or initiative.
- Loadout changes during an encounter.
- Story or educational content.

## Full acceptance matrix

All tests use disposable profile roots and restore global AudioServer/test state. UI-path assertions must activate controls through mouse/keyboard input where the finding concerns user access; direct helper calls alone are insufficient.

| Task / suite | Required assertions |
|---|---|
| REV-001 ΓÇö `dungeon_scene_test.gd` | Suspend via UI, destroy the entire GameRoot, create a fresh session for the same slot: seed, path, step and satchel match; bank unchanged. |
| Same | A suspends, B activates with no run: B has no resumable A snapshot. Returning to A restores AΓÇÖs run. Also test two slots with different saved runs. |
| Same | Retain an A expedition callback, activate B, invoke stale callback: rejected; both profilesΓÇÖ bytes/inventories unchanged. |
| Same | Inject suspend write failure: expedition remains active/open; satchel and bank unchanged; retry succeeds and only then closes. |
| Same | Resume ΓåÆ extraction ΓåÆ restart: reward transferred once, snapshot absent; repeated extraction/stale callbacks cannot bank again. |
| Same | Inject extraction/defeat write failure: prior snapshot remains, no false success; retry commits exactly once. |
| Same | Defeat preserves secured gear, level/skills, story and education while applying only existing approved satchel loss. |
| Same / `web_backup_test.gd` | Backup round-trip preserves the selected slotΓÇÖs suspended run. Malformed snapshot import fails without modifying active profile bytes. |
| `save_compatibility_recovery_test.gd` | Legacy profile without snapshot loads; invalid step/path/count is rejected without partial restore or silent clamping. |
| REV-002 ΓÇö `title_screen_audio_test.gd` | Click title Settings and Backup: one visible settings sheet above title; Backup reveals correct section; underlying title buttons do not activate. |
| Same / `web_backup_test.gd` | Title selects B while gameplay A is loaded: export/import context is B; A remains unchanged. |
| `settings_accessibility_test.gd` | Escape closes overlay only, title remains, Ren stays frozen, originating focus restored; repeated entry creates no duplicates. |
| REV-003 ΓÇö `profile_activation_test.gd` | Occupied slot ΓåÆ New Journey does not emit Continue or reload old progress; picker enables only genuinely empty slots. |
| Same | All occupied/unavailable: no destructive action, Back remains reachable. Corrupt/future/unreadable slots are not presented as empty. |
| Same | Empty slot creation failure leaves title open and other slots byte-identical. Recheck occupancy before creation. |
| Same | Activate early-profile B while A was in late-region/spirit state: default region/spawn, physical dimension, zero velocity, correct collision and B gates; no A snapshot or transient flags. |
| Same | Activation failure leaves no playable partially activated world and no profile corruption. |
| `transition_test.gd` / `dimension_test.gd` | Default spawn passes existing footprint checks; dimension visuals/masks agree; locked-region transition still rejects. |
| REV-004 ΓÇö `title_screen_audio_test.gd` | Remove test Music/SFX buses, initialize: exactly one of each, routed to Master before cue players initialize; every player reports SFX. Reinitialize: no duplicates. |
| `settings_accessibility_test.gd` | SFX zero sets SFX muted; Master/Music unchanged. Positive SFX unmutes. Master zero mutes all through Master. Reload applies settings to existing buses. |
| REV-005 ΓÇö `kurei_tree_test.gd` | Saved mastery ownership survives reload; query yields authored maximum 4; passive is not castable/equippable. |
| `kurei_combat_test.gd` / `boss_combat_test.gd` | No mastery retains each existing baseline; mastery gives maximum 4 with unchanged starting SP. Reapply after spending SP: no refill or stacking. Existing regeneration clamps to 4. Fresh encounter after respec restores baseline. |
| REV-006 ΓÇö `kurei_tree_test.gd` | Legacy default loadout; equip/unequip persistence; seventh/duplicate/locked/passive/unknown ID rejects without mutation; respec removes purchased loadout entries. |
| `ui_sheets_test.gd` | Purchase through Character UI, equip, save/reload: selected skill appears in the next encounter menu. Full loadout leaves purchase unlocked but unequipped with clear feedback. |
| `kurei_combat_test.gd` | Each purchased active skill can be reached/activated through its button in an appropriately prepared fixture; existing effect executes, SP/cooldown/action change exactly once. |
| `boss_combat_test.gd` | Starter buttons remain functional. Missing advanced boss handlers produce disabled entries/reason; direct requests reject with SP, cooldown, HP/status, turn counter and action markers unchanged. Mark finding 5 remainder blocked. |
| Both combat suites | Locked/unequipped/passive requests reject before mutation; insufficient SP/cooldown rejects; repeated menu opening has no duplicate buttons/signals. |
| `layout_audit_test.gd` | Title picker, Character loadout controls and both combat grids fit/scroll at 960├ù540 and text scale 1.0/1.5; focus reaches every enabled action/Cancel. |

**Negative controls**

Run only against disposable copies; never alter tracked production files for fault injection.

- Disable snapshot persistence: fresh-session suspend/resume test must fail.
- Disable slot/session callback ownership: cross-profile stale-callback test must fail.
- Restore generic title modal rejection: title Settings access test must fail.
- Wire New Journey to Continue again: new-game test must fail.
- Skip world/dimension reset: early-profile activation test must fail.
- Omit SFX initialization or route a player to Master: routing test must fail.
- Omit passive configuration from either encounter: that encounterΓÇÖs maximum-SP assertion must fail.
- Revert to three hardcoded spell buttons: purchased-skill UI test must fail.
- Remove action validation for unsupported/unequipped skills: no-mutation assertions must fail.

Record expected and observed nonzero exits and the failing assertion for each negative control.

## Verification and Codex review checkpoints

**After Batch A**

1. Run the affected persistence, title, activation, transition, dimension and backup suites.
2. Run the full canonical headless runner.
3. Perform native title/settings/new-slot focus checks.
4. Codex reviews findings 1ΓÇô4, including stale callbacks, failed suspension, selected-slot backup context and safe world activation.

**After Batch B**

1. Run audio/title and settings suites, then the full runner.
2. Perform a native listening check using existing cues: SFX zero is silent; restoring volume restores cues.
3. Headless bus assertions are routing evidence, not proof of audible output.
4. Codex reviews finding 7 and confirms no asset-generation changes.

**After Batch C**

1. Run tree, Character UI, normal combat, boss combat and layout suites, then the full runner.
2. Run existing export validation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build/run_headless_tests.ps1 -Export -Tier all
```

3. Retain existing export-restoration positive and disabled-restoration negative controls.
4. Codex reviews findings 5ΓÇô6, including the exact authored capacity `4`, six-slot enforcement and UI-driven casting.
5. Record finding 5 as blocked/partial if advanced boss effects still require OD-003/004. Do not conceal this with disabled buttons or report seven findings closed.
6. Browser execution and human release acceptance remain pending.

Every task emits:

```text
TASK ID:
REQUIREMENTS:
MILESTONE:
OWNER: agy
PLAN OWNER: Codex
BRANCH/COMMIT:
FILES CHANGED:
ASSET PROVENANCE: none
TESTS RUN + RESULTS:
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS:
```

Only Codex CLI review with recorded session evidence may mark implementation `REVIEWED`. **SBL-UX-001 resumes after this remediation is reviewed and the blocked remainder of finding 5 is explicitly resolved or accepted for deferral by the appropriate authority.**