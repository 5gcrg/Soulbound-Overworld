# Complete OD-002..OD-011 Proposal — For Owner Approval

**Tag:** `PROPOSED_VALUES_NOT_IMPLEMENTED`  
**Date:** 10 November 2026  
**Basis:** current SoulBound implementation, SoulBound GDD/SRS, Ninja Saga
reference research, and broader RPG design research.  
**Important:** These are proposed decisions for approval, not current game facts.

## Stage A — Combat

### OD-002: Initiative

**Proposed decision**

- Initiative score equals Ren/enemy `Agility`.
- Higher score acts first.
- Ties resolve by stable actor ID, ascending.
- One main action per actor per round.
- No ATB, extra turns, reaction attacks, or initiative rolls.
- Speed/haste effects apply at the next round boundary, not mid-resolution.
- Display the next three actors in the battle HUD.

**Why:** Ninja Saga uses agility-first turn order; deterministic order preserves
SoulBound's educational clarity and existing MVP action economy.

**Files after approval:** combat scenes, initiative/HUD code, combat tests.

**Acceptance:** ordering, ties, round refresh, status modifiers, save boundaries,
and no extra-action negative controls.

### OD-003: Elements, Kurei formulas, costs

**Proposed decision**

- Keep six SoulBound categories: Flame, Torrent, Gale, Earth, Lumina, Umbra.
- Do not add a rock-paper-scissors multiplier chart in the academic MVP.
- Element identity is role-based:
  - Flame: damage/Burn
  - Torrent: healing/cleanse
  - Gale: haste/evasion
  - Earth: shield/mitigation
  - Lumina: pierce/focus
  - Umbra: drain/debuff
- Skill damage/effect magnitude uses the existing authored `base_power`; no
  hidden elemental multiplier.
- Retain current authored pip costs/cooldowns in `KureiSystem`.
- Maximum normal SP remains baseline 2, or 4 with Phase Mastery; Boss baseline
  remains 3, or 4 with Phase Mastery.
- No new cost regeneration, critical, resistance, or damage formulas in MVP.
- Unsupported advanced boss effects remain disabled pending OD-003/004 approval.

**Why:** Ninja Saga differentiates elements by strategic identity and resource /
cooldown tradeoffs; this preserves SoulBound's six-category design without
inventing a counter chart.

**Acceptance:** role metadata, existing costs/cooldowns, exact resource spend,
normal/boss parity where supported, and zero-mutation unsupported-action tests.

### OD-004: Status effects

**Proposed decision**

- Reapplication policy: refresh duration to the larger remaining duration;
  potency becomes the larger potency; same-name effects do not increase stacks.
- Burn, Poison, Bleed, Regeneration: 3 turns by default.
- Defense Up/Down: 2 turns.
- Silence: 1 turn.
- Stun: 1 skipped action.
- Shield: absorbs its authored potency and expires when depleted or after 3 turns.
- Cleanse removes negative statuses; it does not remove positive statuses.
- Bosses use the same status rules; no hidden resistance until separately approved.

**Why:** the Ninja Saga reference uses duration-based effects and same-name
override behavior; a single policy is easier to teach and test.

**Acceptance:** refresh/expiry, no stacking, cleanse, shield depletion, stun,
silence, save-boundary, and boss consistency tests.

## Stage B — Progression and economy

### OD-005: Progression

- Level cap: 30.
- XP to next level: `100 × current level`.
- Level-up reward: 2 attribute points.
- Attribute allocation: 1 point per click to Vitality, Resonance, Agility, or Focus.
- Kurei talent points: existing `max(0, level - 1)` rule.
- Progression rewards prioritize capability/access before raw magnitude.
- No negative XP or level loss on defeat.

### OD-006: Gear/refinement

- Keep five tiers: Common, Uncommon, Rare, Epic, Legendary.
- No random affix rolls in the academic MVP.
- Refinement is deterministic and cannot destroy an item.
- Gear owns specialization/magnitude; character progression owns new abilities.
- Proposed refinement cost formula: `base_item_cost × next_tier_index`.
- Exact `base_item_cost` table remains a separate approved content table.

### OD-007: Inventory/currency

- Keep 20 inventory slots for the MVP.
- Maximum stack size: 99 for stackable consumables/materials.
- Equipped gear and banked items are secured.
- Expedition satchel items are at risk until extraction.
- No inventory expansion in the academic MVP.
- Spirit Coins in the bank are secured; coins found in an expedition satchel
  follow the approved satchel-loss rule.
- No tokens, PvP economy, monetization, or trading.

### OD-008: Defeat policy

- Defeat loses all unbanked satchel contents.
- Defeat preserves banked items, equipped gear, level, skills, story, and education.
- Defeat grants no consolation EXP or currency.
- Extraction transfers the satchel exactly once and clears its persisted snapshot.
- Failed persistence leaves the run open for retry.

## Stage C — Narrative and dungeon

### OD-010: Quest/narrative

- Use branch-and-reconverge structure.
- Academic MVP remains linear across Chapters I–III.
- Full release may add one local choice cluster per chapter, reconverging at the
  next chapter gate.
- Reputation/faction systems are deferred from the academic MVP.
- No permanent lore reveal, villain identity, or ending trigger is approved by
  this proposal; those require narrative-owner text approval.

### OD-011: Dungeon grammar

- Academic MVP retains the current seeded 4-room DAG and guaranteed extraction.
- Full-release proposal: 3 floors, each with 6 generated room slots, one entry,
  at least one valid route, and one extraction endpoint.
- A seed must produce a connected graph; unreachable extraction invalidates the run.
- Optional risk rooms may increase reward value but cannot alter approved defeat
  preservation rules.
- Dungeon mastery grants knowledge/access markers, not uncapped combat power.

## Implementation sequence after approval

1. MiMo implements OD-002 and tests.
2. MiMo implements OD-003 and tests.
3. MiMo implements OD-004 and tests.
4. MiMo implements OD-005 through OD-008 as one reviewed progression/economy batch.
5. MiMo implements OD-010 and OD-011 only after narrative/dungeon content approval.
6. OpenCode independently verifies each batch.
7. Work remains `REVIEW_PENDING_CODEX`; Codex review is deferred.

## Approval checklist

Owner should approve or amend each section independently:

- [ ] OD-002 initiative proposal
- [ ] OD-003 element/Kurei proposal
- [ ] OD-004 status proposal
- [ ] OD-005 progression proposal
- [ ] OD-006 gear proposal
- [ ] OD-007 inventory/currency proposal
- [ ] OD-008 defeat proposal
- [ ] OD-010 narrative proposal
- [ ] OD-011 dungeon proposal

No implementation begins until the owner approves the selected sections.
