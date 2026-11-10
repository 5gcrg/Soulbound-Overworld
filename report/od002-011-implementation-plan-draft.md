# OD-002..OD-011 Implementation Plan Draft

**Tag:** `PLAN_DRAFT_NOT_CODEX`  
**Author:** GPT-5.6 Luna / OpenCode; Codex CLI unavailable  
**Executor after ratification:** MiMo  
**Status:** Planning only. No implementation is authorized by this document.

## Non-negotiable rule

Every formula, coefficient, threshold, probability, cost, duration, reward,
loss ratio, curve, narrative rule, and content quantity remains `TBD` until the
project owner/design authority explicitly ratifies it. MiMo may implement only
ratified values and scope.

## Execution order

1. **OD-002 → OD-003 → OD-004:** combat rules must be settled before balancing or
   status implementation.
2. **OD-005:** progression depends on the approved combat/reward loop.
3. **OD-006 → OD-007:** economy and inventory depend on progression and reward
   ownership.
4. **OD-008:** defeat rewards depend on inventory/economy decisions.
5. **OD-010 → OD-011:** quest/narrative and expanded dungeon content are last;
   both depend on approved progression and reward behavior.

`OD-009` is already separately ratified and implemented as the MVP save-boundary
scope. It must not be reopened by this plan.

---

## Stage A — Combat rules

### `OD-002` initiative and speed behavior

- **Requirements:** GDD-016, GDD-018, GDD-023, FR-CMB-001/003, TC-CMB-001.
- **Decision needed:** strict round ordering vs. dynamic/threshold-based speed
  behavior; all thresholds, tie rules, and extra-turn behavior are `TBD`.
- **Current fallback:** deterministic MVP round ordering.
- **Likely files after approval:** `scenes/combat/battle_fixture.gd`,
  `scenes/combat/boss_encounter.gd`, combat HUD scripts, combat tests.
- **Tests:** known-speed ordering, ties, invalid/duplicate actions, no extra
  action unless explicitly ratified, save/restore boundary unchanged.
- **Approver:** combat design authority/project owner.
- **Risk:** changing initiative can alter every combat test and balance assumption.

### `OD-003` elemental and Kurei formulas

- **Requirements:** GDD-017, GDD-019, GDD-021, FR-CMB-002/003/004,
  FR-MAG-001/002, TC-CMB-002.
- **Decision needed:** six-element interaction chart, damage/effect formulas,
  SP costs, cooldowns, resistance behavior; every value remains `TBD`.
- **Current fallback:** existing authored MVP skill effects and costs only.
- **Likely files after approval:** `scripts/magic/kurei_tree.gd`,
  `scripts/magic/kurei_system.gd`, `scripts/combat/status_engine.gd`,
  `scenes/combat/battle_fixture.gd`, `scenes/combat/boss_encounter.gd`, tests.
- **Tests:** each approved element interaction, cost/cooldown accounting,
  invalid action rollback, exact-once effect application, normal/boss scope.
- **Approver:** combat balancing authority/project owner.
- **Risk:** formula changes can invalidate existing authored fallback behavior.

### `OD-004` status and boss resistance rules

- **Requirements:** GDD-020, GDD-022, FR-CMB-003, TC-CMB-003.
- **Decision needed:** duration timing, stacking/intensity, cleansing, boss
  resistance hierarchy; all durations/limits/resistances remain `TBD`.
- **Current fallback:** existing basic per-turn status behavior.
- **Likely files after approval:** `scripts/combat/status_engine.gd`, combat
  scenes, status UI, combat tests.
- **Tests:** duration/expiry, stacking, cleanse, resistance, save-boundary
  behavior, no duplicate status application.
- **Approver:** combat balancing authority/project owner.
- **Risk:** status changes affect boss encounters and educational combat pacing.

**Stage A gate:** owner ratifies OD-002/003/004 together or explicitly approves
the subset. MiMo then implements one OD at a time with a Codex/OpenCode plan
update and independent tests.

---

## Stage B — Progression, economy, and defeat

### `OD-005` progression curve

- **Requirements:** GDD-024/025, FR-PRG-001/002, TC-PRG-001.
- **Decision:** EXP curve, starting values, level budgets, cap behavior; all
  numbers `TBD`.
- **Fallback:** existing MVP progression placeholder.
- **Likely files:** character/progression scripts, profile serialization,
  character UI, progression tests.
- **Tests:** level-up boundaries, save/load, respec/skill ownership, defeat
  preservation, no overflow or duplicate awards.
- **Approver:** progression design authority.

### `OD-006` refinement and crafting economy

- **Requirements:** GDD-026..028, FR-INV-001/002, TC-INV-002.
- **Decision:** refinement caps, rarity/affix rules, materials, costs, failure
  behavior; all values/weights `TBD`.
- **Fallback:** deterministic MVP item tiers and existing inventory behavior.
- **Likely files:** inventory/item definitions, inventory UI, profile validator,
  economy tests.
- **Tests:** valid/invalid refinement transactions, failed transaction rollback,
  persistence, secured/unbanked ownership.
- **Approver:** economy authority.

### `OD-007` inventory and currency rules

- **Requirements:** GDD-029/030, FR-INV-001, FR-DNG-002, TC-INV-001.
- **Decision:** slot growth, stack limits, currency banking, expedition earning
  multipliers; all caps/multipliers `TBD`.
- **Fallback:** current fixed MVP capacity/count behavior.
- **Likely files:** inventory manager/UI, profile store/validator, dungeon reward
  paths, inventory tests.
- **Tests:** capacity boundaries, stack operations, bank/satchel isolation,
  backup round-trip, exact-once extraction.
- **Approver:** inventory/roguelite authority.

### `OD-008` defeat EXP/currency policy

- **Requirements:** GDD-034/035, FR-DNG-002, FR-SAV-001, TC-DNG-003.
- **Decision:** retained/lost EXP and currency on defeat; all ratios/amounts
  `TBD`.
- **Fallback:** secured permanent data survives; approved unbanked satchel loss.
- **Likely files:** `scenes/dungeon/dungeon_expedition.gd`, `scenes/main/game_root.gd`,
  inventory/profile persistence, defeat tests.
- **Tests:** defeat preserves permanent data, applies only ratified loss,
  retry/exact-once behavior, no reward duplication.
- **Approver:** roguelite/economy authority.

**Stage B gate:** OD-005 must precede OD-006/007/008. No economy implementation
starts from this draft alone.

---

## Stage C — Narrative/quest and expanded dungeon

### `OD-010` quest and narrative rules

- **Requirements:** GDD-036..041, GDD-061..066, FR-WLD-001, FR-QST-001.
- **Decision:** quest scripts, factions, reputation thresholds, NPC roster,
  branching content; all narrative/content values remain `TBD`.
- **Fallback:** linear three-chapter academic MVP.
- **Likely files:** quest/dialogue scenes, chapter manager, profile story data,
  quest tests and content register.
- **Tests:** branch persistence, prerequisite gating, profile isolation,
  reload/backup, no unauthorized story reveal.
- **Approver:** narrative/content lead and project owner; educator review where
  educational content is affected.

### `OD-011` expanded dungeon grammar

- **Requirements:** GDD-042..048, FR-DNG-001/003, TC-DNG-001/004.
- **Decision:** module pool, connection grammar, floors, difficulty budgets,
  hazards, extraction guarantees; all inventories/budgets remain `TBD`.
- **Fallback:** seeded MVP dungeon DAG with reachable extraction.
- **Likely files:** dungeon generator/validator, room scenes/resources,
  expedition state, dungeon tests.
- **Tests:** seeded reproducibility, connectivity, reachable extraction,
  invalid-module rejection, profile/save invariants, no unreachable content.
- **Approver:** dungeon design authority/project owner.

**Stage C gate:** OD-010 content approval and OD-011 grammar approval are required
before expanding the full-release dungeon/story scope.

## MiMo execution contract after approval

For each ratified OD stage:

1. Record exact approved values and scope in the ledger.
2. MiMo changes only the approved files.
3. Add positive, negative, save-invariant, and migration tests.
4. Run independent verification and record evidence in `/report`.
5. Keep status `REVIEW_PENDING_CODEX`; Codex CLI review remains deferred until available.

**No OD-002..OD-011 implementation begins from this draft without the owner
ratifying the specific decision values and scope for the selected stage.**
