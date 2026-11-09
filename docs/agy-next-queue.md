# agy Next Work Queue — Batch C Review Fixes

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Position

- Batch A and Batch B are `REVIEWED`.
- Batch C (`SBL-REV-005/006`) was independently tested but Codex review session `01a1c033-a580-7dc0-b15a-1a703f857eb0` found two P2 defects.
- Fix both defects before resuming `SBL-UX-001` or starting any further feature batch.
- Preserve the explicit `OD-003/004` boundary for undefined boss effects; do not invent mappings or combat values.

## Fix 1 — Boss menu viewport safety

Codex finding: with three starters plus advanced skills equipped, long disabled notices in `BossEncounter` expand a non-wrapping HBox to approximately 1236px, clipping functional controls at the default 960×540 viewport.

Required:

- Keep the expanded boss menu usable at 960×540 and text scales 1.0/1.5.
- Use a wrapping/grid layout, constrained labels, tooltips, or a separate notice area; do not remove the OD-003/004 notice.
- Keep enabled starter skills and Cancel reachable by mouse and keyboard.
- Do not invent new combat values or boss effects.

Likely files:

- `scenes/combat/boss_encounter.gd`
- `scenes/combat/boss_encounter.tscn`
- `tests/headless/boss_combat_test.gd`
- `tests/headless/layout_audit_test.gd`

## Fix 2 — Empty equipped loadout validation

Codex finding: imported `character.kurei_tree.equipped_skills: []` passes validation and deserialization. Menus show starter fallback while `request_action()` rejects every visible spell because none is equipped.

Required:

- Reject an explicit empty equipped array consistently in `GameplayProfileValidator` and deserialization, or normalize it to the authored starter loadout before activation.
- Preserve legacy profiles with the field absent: they continue to default in memory to the existing starter loadout without write-on-load.
- Keep validation atomic and preserve unrelated profile data on failure.
- Add a regression test proving malformed empty loadout cannot produce a visible-but-unusable menu.

Likely files:

- `scripts/persistence/gameplay_profile_validator.gd`
- `scripts/magic/kurei_tree.gd`
- `tests/headless/kurei_tree_test.gd`
- `tests/headless/kurei_combat_test.gd`
- `tests/headless/boss_combat_test.gd`

## Verification

- Run targeted tree/combat/boss/layout suites.
- Run `scripts/build/run_headless_tests.ps1` and record the actual count.
- Run `scripts/build/run_headless_tests.ps1 -Export -Tier all`.
- Run disposable negative controls: revert viewport constraint and accept empty loadout; each must fail its regression assertion.
- Record all evidence in `report/`.
- Update `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, and `docs/testing.md`.
- Commit with `[REVIEW_PENDING_CODEX]` and report the OD-003/004 partial boundary.

## Out of scope

- Undefined advanced boss effects (`OD-003/004`).
- Rebinding (`SBL-UX-001`) until this fix is reviewed.
- Shipping, browser smoke, educator approval, image generation, binary audio, or new balance/story content.

Use `scripts/agy/run_next_queue.ps1`.
