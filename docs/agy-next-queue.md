# Next Work Queue — Approved OD-005/006/007/008 Progression and Economy

Executor: `opencode-go/mimo-v2.6-flash`. Codex CLI review deferred.

**Status (11 Nov 2026):** implemented in implementation commit `0c16720` on `feature/w4-5-vertical-slice`
(docs recorded in the immediately following docs commit). New suite `tests/headless/progression_economy_test.gd`
(201 checks) plus targeted/canonical/export/restoration gates all exit 0; four negative controls exit 1 and
were restored. Evidence: [`report/od005_006_007_008_progression_economy_report.md`](../report/od005_006_007_008_progression_economy_report.md)
and the [queue entry](agent-review-queue.md#sbl-od-005006007008---owner-approved-progression--economy-batch).
Review status: `REVIEW_PENDING_CODEX` (Codex CLI not called).

## Approved specifications

### OD-005 progression

- Level cap 30.
- XP to next level: `100 × current level`.
- Level-up reward: 2 attribute points.
- Attribute allocation: +1 to Vitality, Resonance, Agility, or Focus.
- Kurei talent points: existing `max(0, level - 1)` rule.
- No negative XP or level loss on defeat.
- Capability/access rewards are preferred over raw stat inflation.

### OD-006 gear/refinement

- Five tiers: Common, Uncommon, Rare, Epic, Legendary.
- No random affix rolls in the academic MVP.
- Refinement is deterministic and cannot destroy an item.
- Character progression owns new capabilities; gear owns specialization/magnitude.
- Refinement cost: `base_item_cost × next_tier_index`.
- Use the existing authored item cost table; do not invent additional item values.

### OD-007 inventory/currency

- 20 inventory slots in the MVP.
- Maximum stack size 99 for stackable consumables/materials.
- Equipped gear and banked items are secured.
- Expedition satchel items remain at risk until extraction.
- No inventory expansion in the academic MVP.
- Banked Spirit Coins are secured; satchel currency follows satchel-loss policy.
- No tokens, PvP economy, monetization, or trading.

### OD-008 defeat

- Defeat loses all unbanked satchel contents.
- Defeat preserves banked items, equipped gear, level, skills, story, and education.
- No consolation EXP or currency.
- Extraction transfers the satchel exactly once and clears its persisted snapshot.
- Failed persistence leaves the run open for retry.

## Requirements

- GDD-024..030, GDD-034/035.
- FR-PRG-001/002, FR-INV-001/002, FR-DNG-002, FR-SAV-001.
- TC-PRG-001, TC-INV-001/002, TC-DNG-003/004, TC-SAV-001.

## Acceptance

- Progression formula/level cap/attribute allocation and save tests pass.
- Deterministic refinement and tier behavior pass without random affix generation.
- Inventory capacity/stack/bank/satchel boundaries pass.
- Defeat preserves permanent data and loses only approved satchel data.
- Extraction/defeat retry and exactly-once tests remain green.
- Canonical suite and export/restoration gates pass with disposable user data.
- Update docs/report and commit `[REVIEW_PENDING_CODEX]`; do not mark reviewed.

## Boundaries

- No new story, images, audio, browser work, PvP, monetization, or additional ODs.
- Preserve OD-009 save boundaries and completed OD-002/003/004 combat behavior.
