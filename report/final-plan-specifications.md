# Final Plan Specifications — SoulBound OD Roadmap

**Tag:** `OWNER_DIRECTION_APPROVED_VALUES_TBD`  
**Date:** 10 November 2026  
**Executor:** MiMo after value ratification  
**Review:** Codex CLI deferred

## Design direction approved for planning

- Readable tactical combat over added combat complexity.
- Capability-first progression over raw stat inflation.
- Meaningful push/extract decisions using the existing risk loop.
- Branch-and-reconverge narrative to control content scope.
- Dungeon mastery as persistent knowledge/access rather than unbounded power.

All numeric values, formulas, probabilities, durations, thresholds, content
quantities, and boss-effect mappings remain `TBD`.

## Stage 1 — Tactical combat clarity

### OD-002 initiative

Implement after ratification:

- Visible next-actor order in the battle HUD.
- Deterministic display of current effective order.
- Safe update point when a ratified speed effect changes order.
- No ATB, extra turns, or new speed formula unless explicitly approved.

Files after approval: combat scenes/HUD, initiative service if needed, combat tests.

### OD-003 elemental/Kurei design

Implement after ratification:

- Six-element metadata and readable role descriptions.
- Data-driven weakness/effect registry.
- Formula and resource application using only approved values.
- Normal and boss combat use the same approved definitions where applicable.
- Unsupported boss effects remain disabled rather than invented.

Files after approval: Kurei definitions/system, combat scenes, configuration,
tests, UI tooltips.

### OD-004 status design

Implement after ratification:

- Explicit per-status policy: replace, refresh, stack, or convert.
- Deterministic duration/expiry events.
- Cleansing and resistance behavior from approved rules.
- Clear status UI and regression tests.

Files after approval: status engine, combat scenes/UI, persistence boundary tests.

## Stage 2 — Progression and economy

### OD-005 progression

- Separate power, capability, efficiency, and access rewards.
- Keep capability rewards meaningful without inventing stat curves.
- Implement approved EXP/level budgets and save tests.

### OD-006 gear/economy

- Hybrid gear model: upgrade within tier, replace across tiers.
- Keep gear specialization distinct from character capability.
- Implement only approved refinement, rarity, crafting, and failure rules.

### OD-007 inventory/currency

- Preserve secured versus at-risk ownership.
- Add only approved capacity, stack, banking, and expedition rules.
- Keep economy non-monetized and outside Ninja Saga-style token systems.

### OD-008 defeat policy

- Preserve permanent progression and secured data.
- Apply only the owner-approved defeat loss policy.
- Verify retry and exactly-once extraction/defeat behavior.

## Stage 3 — Narrative and dungeon expansion

### OD-010 quests/narrative

- Branch locally and reconverge at approved chapter beats.
- Persist choices and quest state safely.
- Add only approved factions, reputation, NPCs, dialogue, and rewards.

### OD-011 dungeons

- Keep seeded generation and reachable extraction.
- Add approved modules, hazards, floors, and difficulty grammar.
- Add persistent dungeon mastery as knowledge/access, not unbounded power.

## Per-stage execution contract

1. Owner ratifies the selected OD values and scope.
2. MiMo implements only that ratified stage.
3. MiMo adds positive/negative tests and report evidence.
4. OpenCode independently verifies the results.
5. Work remains `REVIEW_PENDING_CODEX`.
6. Codex CLI review occurs later when available.

## Current next action

Before Stage 1 execution, ratify the specific OD-002/003/004 values. The
recommendations define structure and behavior, but they do not yet define the
initiative formula, elemental matrix, damage/resource formulas, durations, or
boss resistances.
