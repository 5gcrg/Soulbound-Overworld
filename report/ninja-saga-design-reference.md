# Ninja Saga Design Reference for SoulBound OD Planning

**Status:** Reference only; no SoulBound OD is resolved by this document.  
**Date:** 10 November 2026

## Sources consulted

- Ninja Saga Wiki: Attacks/Ninjutsu, Attributes, Status Effects, Talent.
- UrGameTips: Ninja Saga gameplay and battle overview (17 January 2011).
- Gamezebo: Ninja Saga review (15 April 2010).
- Ninja Saga official game-info mirror: element attributes.

These are historical/community references, not SoulBound requirements or
authoritative balance sources.

## Transferable design patterns

| Ninja Saga pattern | SoulBound OD it can inform | What remains TBD |
|---|---|---|
| Turn-based battle where agility/speed influences order | OD-002 | Exact initiative model, ties, extra turns, UI and thresholds |
| Element identities with different strategic roles | OD-003 | SoulBound's six-element matrix, formulas, costs, cooldowns and resistances |
| Resource-consuming skills with cooldowns | OD-003 | All SoulBound resource values and recovery rules |
| Active skills separated from passive talents | OD-003/004 and already implemented Kurei loadout | SoulBound effect semantics, costs and boss mappings |
| Buffs/debuffs with turn durations and cleansing | OD-004 | Duration, stacking, refresh, cleanse and boss resistance |
| Repeated application overriding same-name status in cited wiki | OD-004 | Must be explicitly ratified for SoulBound; not adopted automatically |
| XP/attributes/gear/currency progression loop | OD-005..008 | SoulBound curves, caps, costs, retention and defeat policy |
| Mission/arena/shop/menu progression structure | OD-006/007/010 | SoulBound scope, story, economy and non-PvP behavior |
| Skill loadout slots and talent trees | OD-003/005 | SoulBound six-slot rule is already approved; remaining effects/values TBD |

## Explicit non-transfer rules

- Do not copy Ninja Saga's five-element system into SoulBound's six affinities.
- Do not copy published damage, chakra, cooldown, percentage, level, cost,
  monetization, or attribute values.
- Do not import Ninja Saga PvP, pets, tokens, social recruitment, or pay-to-win
  systems; these are outside the approved SoulBound scope.
- Do not treat community wiki formulas as educator-approved or SoulBound-
  ratified design.
- Do not use the reference to resolve OD-001 narrative content or OD-012
  educational validity.

## Decision impact

The research can improve the owner questions for OD-002/003/004 and OD-005..008,
but it does not answer them. The project owner must still ratify SoulBound-
specific behavior and values before MiMo implementation.
