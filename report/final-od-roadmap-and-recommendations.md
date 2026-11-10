# Final OD Roadmap and RPG Mechanics Recommendations

**Tag:** `FINAL_PLAN_PENDING_OWNER_RATIFICATION`  
**Date:** 10 November 2026  
**Execution:** MiMo after ratification; Codex CLI review deferred until available.

## Current completed/active work

- `OD-009`: MVP save-boundary scope ratified and implemented; review pending.
- `OD-013`: performance-evidence scope ratified; MiMo implementation active.
- `SBL-BLD-005`: provenance manifests implemented; review pending.
- Images: Codex-exclusive; provider credential failure recorded; no image generated.

## Recommended final implementation roadmap

### Plan 1 — Combat foundation: OD-002/003/004

**Recommendation:** keep the current deterministic MVP combat foundation and add
clarity before complexity.

Proposed mechanics:

1. Visible initiative order, without ATB or extra turns unless explicitly approved.
2. Elemental weaknesses produce tactical effects in addition to any approved
   damage effect, but the six-element matrix remains `TBD`.
3. Every status declares one policy: replace, refresh, stack, or convert.
4. Action metadata explains speed, potency, resource cost, duration, and setup.

Required owner decisions:

- Initiative/tie/extra-turn behavior: OD-002.
- Six-element interactions, formulas, SP, cooldowns, resistances: OD-003.
- Status durations, stacking, cleansing, boss resistance: OD-004.

MiMo scope after ratification: combat rules, Kurei metadata, status engine,
normal/boss combat, UI explanations, and regression tests.

### Plan 2 — Progression/economy: OD-005/006/007/008

**Recommendation:** use a two-track progression model:

- Character progression owns identity, capability, and access.
- Gear owns specialization and magnitude.

Proposed mechanics:

1. Capability-first rewards: new tactical verbs and utility before raw numbers.
2. Hybrid gear progression: upgrade within a tier, replace across tiers.
3. Meaningful inventory/currency choices without monetization or PvP systems.
4. Push/extract decisions using existing satchel risk; no invented drop rates.
5. Defeat preserves permanent data and applies only ratified unbanked loss.

Required owner decisions:

- EXP curve, stats, level budgets: OD-005.
- Refinement, rarity, crafting and failure: OD-006.
- Capacity, stacks, currency and expedition earnings: OD-007.
- Defeat EXP/currency retention: OD-008.

MiMo scope after ratification: progression, inventory/economy, reward paths,
defeat/extraction tests, save migration if approved, and UI feedback.

### Plan 3 — Narrative/dungeon expansion: OD-010/011

**Recommendation:** branch locally and reconverge at approved chapter beats;
retain replayable seeded dungeons with permanent mastery markers.

Proposed mechanics:

1. Quest choices alter local objectives/rewards without multiplying the full story graph.
2. Dungeon mastery unlocks knowledge, safer routes, or optional challenges.
3. Existing guaranteed extraction remains mandatory.

Required owner decisions:

- Factions, quests, reputation, NPCs, branches and content: OD-010.
- Dungeon modules, grammar, floors, hazards and difficulty budgets: OD-011.

MiMo scope after ratification: quest/dialogue state, narrative persistence,
dungeon generation/content modules, mastery markers, and tests.

## Human-gated roadmap

- `OD-012`: educator/question-bank approval before assessed deployment.
- `OD-013`: owner-machine performance evidence; browser execution remains human.
- `OD-015/016`: binary audio, visual assets, quantities and licensing.
- `OD-017`: public shipping tier.
- GDD-111: Web publishing.
- GDD-123/TC-WEB-001/002: Chromium/Firefox/additional browser smoke.
- GDD-132: final release acceptance.

## Final recommendation

The best design direction is:

1. **Readable tactical combat** rather than more combat complexity.
2. **Capability-first progression** rather than pure stat inflation.
3. **Meaningful push/extract choices** using the existing risk loop.
4. **Branch-and-reconverge narrative** to control scope.
5. **Dungeon mastery** as persistent knowledge rather than raw power inflation.

These are recommendations only. No OD value is resolved by this report, and no
MiMo implementation begins until the owner ratifies the selected stage and its
SoulBound-specific values.
