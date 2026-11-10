# RPG Mechanics Research and SoulBound Options

**Status:** Research/options only; no mechanics adopted.  
**Date:** 10 November 2026  
**Research basis:** RPG combat/progression/economy/dungeon design references and
historical Ninja Saga references. Sources are inspiration, not SoulBound authority.

## Recommended additions/revisions

### 1. Visible initiative timeline — `[OD-002]`

Show the next actor order and update it at round boundaries when approved speed
effects change. This improves planning without requiring an ATB system.

**Recommendation:** consider as a presentation layer over the current deterministic
MVP order. It should not create extra turns or new speed formulas without OD-002
approval.

### 2. Elemental weakness creates tactical states — `[OD-003/004]`

Instead of weakness being damage-only, an approved weakness could also create a
short tactical state: interruption, vulnerability, displacement, or another
ratified effect.

**Recommendation:** adopt the pattern, not the values. Define the six-element
mapping and effects before implementation. Do not copy another game's matrix.

### 3. Explicit status stack policies — `[OD-004]`

Give every status one policy: replace, refresh duration, stack intensity, or
convert into a stronger state. Display the policy in tests and tooltips.

**Recommendation:** use one consistent policy per status and keep boss resistance
separate. This is clearer than ad hoc stacking.

### 4. Action tradeoff tags — `[OD-002/003]`

Classify actions by speed, potency, cost, duration, and setup. A fast low-impact
action, expensive burst, defensive action, and setup action can all be useful
without requiring more buttons.

**Recommendation:** add metadata and UI explanation first; do not assign formulas
until combat decisions are ratified.

### 5. Capability-first progression — `[OD-005]`

Separate progression rewards into power, capability, efficiency, and access. Favor
new tactical verbs or utility over only larger numbers.

**Recommendation:** use this as the design rubric for Kurei and chapter rewards;
keep EXP curves and budgets `TBD`.

### 6. Two-track progression — `[OD-005/006]`

Keep character progression responsible for identity/capabilities and gear
responsible for specialization/magnitude. Avoid making random loot the only path
to new abilities.

**Recommendation:** compatible with SoulBound's secured gear and Kurei tree;
requires owner decisions on refinement and rarity.

### 7. Deliberate extraction choices — `[OD-007/008/011]`

Offer a meaningful push/extract decision: optional treasure, safer retreat, or a
deeper risk path. The existing expedition/satchel system already supports this.

**Recommendation:** add optional risk/reward encounter choices only after dungeon
module and defeat-reward ODs are ratified. Do not add drop probabilities yet.

### 8. Branch-and-reconverge quests — `[OD-010]`

Let choices alter local objectives/rewards while reconverging at approved chapter
beats. This provides agency without multiplying the whole story graph.

**Recommendation:** suitable for the five-chapter target, but not before narrative
owners approve characters, branches, and ending triggers.

### 9. Dungeon mastery loop — `[OD-011]`

After a dungeon is cleared, retain a permanent mastery marker that can unlock
knowledge, safer routes, or optional challenges without removing replayability.

**Recommendation:** consider for full release; do not select rewards, room budgets,
or difficulty values before OD-011 approval.

## Mechanics not recommended now

- PvP, pets, token monetization, social recruitment, or pay-to-win systems from
  historical Ninja Saga references.
- Random loot affix probabilities before OD-006 approval.
- ATB/extra-turn combat before OD-002 approval.
- Unspecified elemental formulas or boss effects before OD-003/004 approval.
- Spatial inventory puzzles before OD-007 scope approval; current slot inventory
  is sufficient for the academic MVP.

## Suggested adoption order

1. Ratify OD-002/003/004 and add initiative/weakness/status design metadata.
2. Ratify OD-005 and apply capability-first progression to rewards.
3. Ratify OD-006/007/008 and refine economy/extraction choices.
4. Ratify OD-010/011 for branch/reconverge narrative and dungeon mastery.

No implementation should begin from this research alone. The project owner must
approve the selected mechanic and its SoulBound-specific values first.
