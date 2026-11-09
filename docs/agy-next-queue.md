# agy Next Work Queue — Remediation Batch C (SBL-REV-005/006)

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Position

- Remediation Batch A and Batch B are `REVIEWED`.
- Batch B review session: `01a1c001-361d-7250-98d6-bc547c380822`.
- This is the final remediation batch for findings 5–6. `SBL-UX-001` resumes only after this batch is reviewed and the boss-effect boundary is explicitly recorded.
- No image generation or binary audio generation.

## SBL-REV-005 — Apply authored Phase Mastery capacity

**Finding:** 6, P2 from Codex review session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`.

### Requirements

- GDD-019, GDD-030.
- FR-CMB-001/003.
- TC-CMB-002; persistence checks supporting TC-SAV-001.
- Do not invent `FR-MAG-*` IDs; none are authoritative.

### Files

- `scripts/magic/kurei_tree.gd`
- `scenes/combat/battle_fixture.gd`
- `scenes/combat/boss_encounter.gd`
- `scenes/main/game_root.gd`
- `tests/headless/kurei_tree_test.gd`
- `tests/headless/kurei_combat_test.gd`
- `tests/headless/boss_combat_test.gd`
- `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`

### Rules

- No save schema change; derive from existing `phase_mastery` ownership.
- Use exactly the already-authored maximum SP value **4**.
- Preserve each encounter's current baseline maximum and starting SP when mastery is absent.
- Mastery changes maximum capacity only; it must not refill SP, reset cooldowns, or stack on reapplication.
- Existing regeneration clamps to the effective maximum.
- Passive is not castable or equippable; direct attempts reject without mutation.
- Do not change initial SP, costs, cooldowns, regeneration rules, initiative, status values, or other combat numbers (`OD-002/003/004` remain blocked).

### Acceptance

- Saved mastery survives reload and reports authored capacity 4.
- Normal and boss encounters retain their existing no-mastery baselines.
- Mastery gives maximum 4 with unchanged starting SP.
- Reapplying configuration does not refill or stack.
- Respec/profile switching restores the correct derived capacity.
- Locked/passive requests reject without action, SP, cooldown, HP/status, or turn-counter mutation.

## SBL-REV-006 — Purchased-skill menus and six-slot enforcement

**Finding:** 5, P2. This task may only partially close the finding where boss-effect semantics are undefined.

### Requirements

- GDD-018..020, GDD-030, GDD-089.
- FR-CMB-003/004.
- TC-CMB-001/002; six-equipped-spell check from GDD/SRS §4.5.
- Supporting GDD-092 / TC-ACC-001 for keyboard access.

### Files

- `scripts/magic/kurei_tree.gd`
- `scripts/magic/kurei_system.gd`
- `scripts/persistence/gameplay_profile_validator.gd`
- `scenes/ui/character_sheet.gd`, `scenes/ui/character_sheet.tscn`
- `scenes/combat/battle_fixture.gd`, `scenes/combat/battle_fixture.tscn`
- `scenes/combat/boss_encounter.gd`, `scenes/combat/boss_encounter.tscn`
- `scenes/main/game_root.gd`
- `tests/headless/kurei_tree_test.gd`, `tests/headless/kurei_combat_test.gd`, `tests/headless/boss_combat_test.gd`
- `tests/headless/ui_sheets_test.gd`, `tests/headless/layout_audit_test.gd`
- `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`

### Data model

- Retain profile schema 1.
- Add optional `character.kurei_tree.equipped_skills` containing unique ordered active unlocked IDs, maximum six.
- Passive `phase_mastery` never occupies a slot.
- Legacy data without the field defaults in memory to the existing three starter skills; no write-on-load migration.
- Reject unknown, locked, duplicate, passive, malformed, or seventh-slot arrays atomically.
- New purchases auto-equip only if a slot is available; otherwise report `Unlocked — equip in Character`.
- Respec restores the existing starter loadout.
- Failed persistence does not claim success or discard unrelated profile fields.

### Implementation and UI

- Add active/passive classification and stable skill-ID queries.
- Add Equip/Unequip controls in Character UI with six-slot feedback.
- Populate normal and boss menus from equipped/unlocked active IDs; remove the hardcoded three-button limitation.
- Bind buttons to actual IDs and preserve existing authored names, costs, cooldowns, and implemented normal-combat effects.
- Disable invalid-phase, insufficient-SP, cooldown, and unsupported-effect buttons.
- Validate again inside `request_action()` before any mutation.
- Rebuilding menus must not duplicate buttons or signals.
- Preserve keyboard focus and Cancel behavior at 960x540 and text scales 1.0/1.5.

### Explicit OD boundary

`BossEncounter` currently lacks handlers for the four purchased active skills. Unless an authoritative existing mapping is found:

- Show equipped advanced boss skills disabled with `Boss effect pending design approval`.
- Reject direct requests without SP, cooldown, HP/status, turn, or action-marker mutation.
- Do not transplant normal-combat damage, shield, or status values into boss combat.
- Record this as a **partial remediation**, blocked by `OD-003/004`; do not claim finding 5 fully resolved.

### Acceptance and negative controls

- Purchase through Character UI, equip, save/reload, and verify the selected skill appears in the next normal encounter menu.
- Full loadout leaves a seventh purchase unlocked but unequipped with clear feedback.
- Each supported purchased skill is activated through its button exactly once with existing effects.
- Boss starter actions remain functional; unsupported advanced actions are disabled/rejected with no mutation.
- Locked, unequipped, passive, unknown, insufficient-SP, and cooldown requests reject atomically.
- Legacy loadout, duplicate/seventh/passive/unknown validation, respec, profile switching, and persistence are covered.
- Repeated menu opening creates no duplicate controls/signals.
- `layout_audit_test.gd` covers title/Character/combat focus and 960x540 / 1.0/1.5 layout.
- Disposable negative controls must fail when passive configuration is omitted, menus remain hardcoded, six-slot validation is removed, or unsupported boss actions mutate state.

## Verification and reporting

- Run targeted tree, Character UI, normal combat, boss combat, and layout suites.
- Run `scripts/build/run_headless_tests.ps1` and record the actual count.
- Run `scripts/build/run_headless_tests.ps1 -Export -Tier all`.
- Retain export-restoration positive and disabled-restoration negative controls.
- Record artifact hashes/sizes and all negative-control exits in `report/`.
- Add one queue entry per task with `REVIEW: REVIEW_PENDING_CODEX` and the blocked boss-effect disposition.
- Commit suffix `[REVIEW_PENDING_CODEX]`.
- Codex CLI reviews findings 5–6 before `SBL-UX-001` resumes.

## Human-gated / out of scope

- `OD-002/003/004` combat numbers and undefined boss mappings.
- `OD-009` mid-battle persistence.
- Shipping tier `OD-017`, browser smoke, educator `OD-012`, image generation, and binary audio.

Use `scripts/agy/run_next_queue.ps1`.
