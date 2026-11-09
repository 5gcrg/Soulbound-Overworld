# agy Next Work Queue — Batch C Review Fix

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## SBL-REV-009 — Fix boss layout audit initialization order

Codex CLI review session `01a1c04c-cc02-7c12-8171-7c27cadfcb1e` found a P2 in the Batch C fix audit:

`tests/headless/layout_audit_test.gd` accesses `b.kurei_btn` before the boss scene instance is added to the tree. The `@onready` variable is null, causing the audit to crash before it verifies the expanded boss menu viewport.

### Required change

- Add the boss instance to `root_control` before accessing `@onready` controls or opening the Kurei menu.
- Await/process the scene initialization as required by the existing test harness.
- Preserve cleanup and global state restoration.
- Keep the actual viewport assertions for 960x540 and text scales 1.0/1.5.
- Do not weaken or remove the boss-menu layout coverage.

### Files

- `tests/headless/layout_audit_test.gd`
- `docs/agent-review-queue.md`
- `docs/traceability-matrix.md`
- `docs/testing.md`

### Verification

- Run `layout_audit_test.gd` and confirm the boss viewport audit executes without null-node errors.
- Run `kurei_tree_test.gd`, `kurei_combat_test.gd`, and `boss_combat_test.gd`.
- Run `scripts/build/run_headless_tests.ps1` and record the actual suite count.
- Run `scripts/build/run_headless_tests.ps1 -Export -Tier all`.
- Record logs and any negative-control evidence in `report/`.
- Commit with `[REVIEW_PENDING_CODEX]`.
- Do not mark Batch C reviewed; Codex CLI must re-review this fix.

### Boundaries

- Preserve the already-fixed boss viewport layout and empty-loadout validation.
- Preserve the explicit OD-003/004 boundary; do not implement undefined boss effects or invent combat values.
- Do not resume `SBL-UX-001` until Codex clears this fix.
- No images, binary audio, browser smoke, shipping, educator approval, or other human-gated work.

Use `scripts/agy/run_next_queue.ps1`.
