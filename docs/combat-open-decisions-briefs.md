# Combat Open Decisions — Decision-Ready Briefs (SBL-DATA-003)

**Document**: `docs/combat-open-decisions-briefs.md`  
**Milestone**: Combat Architecture & Systems Governance  
**Date**: November 9, 2026  
**Implementation Owner**: agy  
**Plan & Decision Authority**: Human Release Authority & Codex  
**Binding Constraint**: AGENTS.md § Engineering invariants & SBL-DATA-003 mandate:  
> *"For OD-002 (initiative), OD-003 (element/affinity and SP curves), OD-004 (status stacking/duration): one page each with the options, what each option changes, what it unblocks, and the risk of each. No invented coefficients, percentages, or drop rates. Options and consequences only; the human decides."*

---

## 1. OD-002: Speed Attribute, Turn Ordering & Initiative Resolution

### 1.1 Context & Current MVP Behavior
Under GDD-016, GDD-018, and GDD-023, combat involves turn-based tactical encounters. The current MVP (`scenes/combat/battle_fixture.gd`, `boss_encounter.gd`) enforces a strictly deterministic round structure:
- Ren acts first in every round.
- Enemies act subsequent to Ren in array order.
- Each combatant receives exactly one action per round.
- The `agility` / `speed` attribute exists in `character_stats.gd` and profiles, but currently has no mechanical effect on turn order or action frequency.

To graduate beyond the technical fixture, a canonical initiative paradigm must be selected by the combat designer.

### 1.2 Decision Options

#### Option A: Discrete Round Turn Ordering (Speed-Sorted Initiative)
- **Mechanism**:
  - At the start of each combat round, all alive combatants are gathered and sorted in descending order of their current Speed attribute.
  - Combatants act in that sorted sequence. Each participant gets exactly one action per round.
  - Ties are resolved deterministically (e.g., Player priority, followed by stable spawn ID).
- **What it Changes**:
  - Eliminates the static "Player always acts first" fixture rule. High-speed enemies can strike or prepare defenses before the player acts.
  - Makes Agility immediately tangible without disrupting the predictable "one turn per round" mental model.
- **What it Unblocks**:
  - Visual Turn Order Bar: A simple horizontal queue showing the exact order of actions for the current round.
  - In-round Speed buffs and debuffs that shift a combatant’s position in the upcoming round.
- **Risks**:
  - Speed provides diminishing tactical returns once higher than the fastest enemy in the encounter, as exceeding enemy speed by 1 point or 100 points yields the identical benefit (acting first).
  - Pure Agility builds may feel underpowered compared to Vitality or Resonance builds since Speed never grants additional actions.

#### Option B: Dynamic Action Accumulation / Tick Gauge (Speed as Action Rate)
- **Mechanism**:
  - Global rounds are removed. An abstract Action Time Gauge runs in continuous discrete ticks.
  - Each tick, every combatant accumulates gauge progress proportional to their Speed.
  - Upon reaching a fixed full threshold, time pauses, that combatant executes their action, and their gauge resets (or subtracts the threshold cost).
  - High-speed combatants naturally act more frequently than low-speed combatants over time.
- **What it Changes**:
  - Replaces discrete rounds with an asynchronous action timeline.
  - Actions themselves can have variable recovery costs (e.g., light attack has low gauge reset; ultimate spell has high gauge reset).
- **What it Unblocks**:
  - Turn-lapping: High-speed builds can earn additional turns against slower, heavily armored bosses.
  - Haste, Slow, Delay, and Turn-Advance mechanics that manipulate gauge accumulation directly.
- **Risks**:
  - Significantly higher implementation complexity and higher state surface for save/resume invariants (mid-turn suspension requires serializing gauge fractions).
  - Vulnerable to positive feedback loops where speed-stacking allows permanent turn denial, trivializing boss encounters.
  - Requires a dynamic, continuously updating timeline UI rather than a static round roster.

#### Option C: Tiered Action Pip Economy (Speed Gating Action Budgets)
- **Mechanism**:
  - Preserves synchronized global rounds.
  - Combatants receive an Action Pip budget per round determined by qualitative Speed brackets (e.g., Base Speed = 1 Action Pip; High Speed Bracket = 1 Action Pip + 1 Utility/Support Pip; Apex Speed Bracket = 2 Full Action Pips).
  - Combatants alternate executing single pips during the round until all budgets are exhausted.
- **What it Changes**:
  - Retains round synchronization while allowing speed investment to directly increase action volume.
- **What it Unblocks**:
  - Hybrid tactical turns (e.g., Cast a buff, then Strike).
  - Clear, discrete action pip indicators over player and enemy nameplates.
- **Risks**:
  - "Breakpoint optimization" behavior where stat points between bracket thresholds provide zero perceived return, driving min-maxing and penalizing hybrid stat allocation.
  - Enemy action economy balancing becomes sensitive when multiple enemies reach multi-pip tiers.

---

## 2. OD-003: Elemental Affinity System, SP Economy & Damage Resolution

### 2.1 Context & Current MVP Behavior
Under GDD-017, GDD-019, GDD-021, and FR-MAG-001/002, the game features Kurei magic, elemental spells (Ignite, Frostbite, Surge, Tremor, Radiance, Umbra), and resource costs:
- The current MVP uses a baseline direct subtraction formula: `max(1, attack - defense)`.
- Spirit Power (SP) costs are hardcoded test values (e.g., Ignite costs 5 SP).
- Kurei skill trees exist in `kurei_tree.gd` and unlock nodes, but there is no canonical elemental affinity counter matrix or mathematical damage curve.

### 2.2 Decision Options

#### Option A: Closed Circular Affinity Wheel with Opposing Poles
- **Mechanism**:
  - Physical elements are organized into a closed cyclic counter loop:
    - `Fire` overcomes `Wind`
    - `Wind` overcomes `Earth`
    - `Earth` overcomes `Water`
    - `Water` overcomes `Fire`
  - Spiritual elements form a mutually opposing dual axis:
    - `Light` and `Shadow` are mutually super-effective against each other.
  - Hitting an affinity counter triggers a categorical "Vulnerable" state; hitting the reverse triggers a "Resisted" state.
- **What it Changes**:
  - Converts combat into an intuitive, highly readable tactical puzzle.
  - Direct synergy with the game's educational foundations (classification, systems thinking, logic).
- **What it Unblocks**:
  - Distinct UI elemental affinity icons and visual indicator badges on enemy targets.
  - Predictable encounter planning across distinct regional biomes (e.g., Ashen Peaks as Fire, Whispering Grove as Wind).
- **Risks**:
  - If a player builds deeply into a single elemental tree (e.g., pure Fire in Kurei), they encounter severe hard-counter walls in water-themed zones unless multi-tree investment or elemental weapon swapping is facilitated.

#### Option B: Taxonomy-Driven Asymmetric Resistances
- **Mechanism**:
  - Elements do not adhere to a rigid geometric wheel. Instead, every creature family has an individualized affinity profile defined by lore and material composition (e.g., Golems resist Fire and Earth, but are vulnerable to Water; Phantoms are immune to physical elements and vulnerable only to Radiance).
  - Affinities are categorical: `Immune`, `Absorbs`, `Resistant`, `Neutral`, `Weak`.
- **What it Changes**:
  - Eliminates predictable "rock-paper-scissors" predictability in favor of monster knowledge and lore discovery.
- **What it Unblocks**:
  - Bestiary / Educational Knowledge Archive where defeated monsters reveal their physiological traits and elemental profiles.
  - Roguelite gear variety: Armors and relics granting specific elemental immunities or conversion shields.
- **Risks**:
  - Higher cognitive burden on players; requires in-combat inspect/scan actions or trial-and-error unless telegraphed clearly.
  - Encounter design requires manual balance per enemy rather than relying on systemic wheel symmetry.

### 2.3 Spirit Power (SP) Economy Paradigm
- **Paradigm 1: Attrition Pool (Fixed Cap, Consumable & Rest Recovery)**
  - Max SP is fixed or strictly capped; does not regenerate automatically between rounds.
  - SP is recovered via deliberate "Focus/Rest" combat actions or limited dungeon consumable items.
  - *Consequence*: Emphasizes survival-roguelite pacing where casting powerful spells carries an expedition-level opportunity cost.
- **Paradigm 2: Dynamic Flow (Resonance-Scaled, Action-Generated)**
  - Max SP scales with the Resonance attribute.
  - Basic actions (accurate strikes, well-timed guards, exploiting elemental weaknesses) actively generate SP, while Kurei spells consume it.
  - *Consequence*: Creates an active, momentum-based combat loop encouraging players to weave basic attacks and magic rotations.

---

## 3. OD-004: Status Effect Stacking, Duration Rules & Boss Tenacity

### 3.1 Context & Current MVP Behavior
Under GDD-020, GDD-022, and FR-CMB-003, combat features status effects including Burn, Freeze, Stun, Bleed, Poison, Vulnerable, and Fortify:
- The current MVP (`scripts/combat/status_engine.gd`) provides a baseline engine:
  - Duration is decremented once per round.
  - Stacks are tracked additively up to a temporary cap of 5.
  - When duration expires, the entire status is cleared.
- Unresolved: Stacking semantics upon reapplication, interaction between duration and intensity, and boss crowd-control resistance rules.

### 3.2 Decision Options

#### Option A: Duration Refresh with Discrete Intensity Stacking (Soft Cap Model)
- **Mechanism**:
  - When an existing status effect is reapplied before expiration:
    1. The remaining duration resets to the full maximum duration of the new application.
    2. The intensity stack count increments by +1, up to a defined ceiling (e.g., Stack Cap).
  - Each intensity stack scales the periodic effect (e.g., Burn deals damage proportional to current stack count).
- **What it Changes**:
  - Rewards aggressive, continuous maintenance of debuffs on high-health targets.
  - Prevents "wasted" turns when applying a status shortly before it falls off.
- **What it Unblocks**:
  - Dedicated damage-over-time (DoT) and debuff-spreader archetypes.
  - Clear UI presentation: a single icon per effect with a stack counter and remaining turns badge.
- **Risks**:
  - If applied to debilitating crowd-control effects (Freeze, Stun), indefinite lockouts occur unless hard CC is strictly excluded from intensity stacking.

#### Option B: Independent Instance Tracking with Fixed Lifespans (Hard Duration Model)
- **Mechanism**:
  - Every application of a status creates an independent entry with its own immutable lifespan.
  - Reapplication does not refresh existing instances; multiple instances simply run in parallel.
  - When an individual instance's duration hits zero, only that single instance expires, reducing total intensity accordingly.
- **What it Changes**:
  - Prevents permanent status uptime via single maintenance pings. Achieving peak intensity requires concentrated, burst application within a narrow timeframe.
- **What it Unblocks**:
  - Precision combo windows (e.g., Applying three independent bleed procs in two turns to detonate a synergistic payoff skill).
- **Risks**:
  - Increased cognitive load and UI clutter (multiple timers on a single debuff icon).
  - Slightly higher memory and serialization complexity.

### 3.3 Boss Crowd-Control Tenacity & Resistance Hierarchy

#### Paradigm 1: Diminishing Returns / Tenacity Thresholds
- **Mechanism**:
  - Bosses are susceptible to all status effects (including Stun, Freeze, Silence).
  - However, each successful hard CC application increases the boss's Tenacity counter: subsequent hard CC effects have their duration halved, rapidly reaching complete temporary immunity.
  - After a refractory period with zero CC applied, Tenacity decays back to baseline.
- **What it Changes**:
  - Eliminates "cheesing" boss encounters while ensuring player CC builds remain viable and satisfying.
- **What it Unblocks**:
  - Strategic timing of interrupts (saving Stun for high-damage boss telegraphed attacks).
- **Risks**:
  - Requires clear UI communication so players know when a boss has entered high-tenacity states.

#### Paradigm 2: Categorical Phase Stagger Gating
- **Mechanism**:
  - Statuses are divided into two fundamental tiers:
    1. **Minor / Damage Debuffs** (Burn, Bleed, Poison, Vulnerable): Bosses are always vulnerable.
    2. **Hard Control / Interrupts** (Stun, Freeze, Sleep, Silence): Bosses are unconditionally immune during normal stance.
  - To apply Hard Control, the player must deplete a visible "Stagger / Break Gauge" by exploiting elemental weaknesses or landing critical strikes.
  - Once Staggered, the boss is temporarily vulnerable to Hard CC and critical multipliers for a fixed recovery window.
- **What it Changes**:
  - Aligns boss combat with modern action/turn-based RPG conventions (e.g., Break/Stagger meters).
- **What it Unblocks**:
  - Highly engaging multi-phase boss fight pacing with dedicated "burn / stagger" phases.
- **Risks**:
  - Adds a Stagger Gauge subsystem to combat state, requiring additional visual and audio feedback.

---

## 4. Summary Matrix for Stakeholder Review

| Decision ID | Core Dilemma | Primary Options | Primary Unblocked Capability | Critical Risk to Balance |
|---|---|---|---|---|
| **OD-002** | Turn order & initiative resolution | **A**: Discrete round sort<br>**B**: Continuous tick gauge<br>**C**: Action pip budgets | Initiative order UI, speed stat value, turn manipulation | Turn-locking enemies, excessive min-max breakpoints |
| **OD-003** | Elemental affinity & SP mechanics | **A**: Circular 4+2 counter wheel<br>**B**: Asymmetric taxonomy profiles<br>+ Attrition vs. Dynamic SP | Weakness exploitation, clear regional theming, Kurei synergy | Monotype build dead-ends, cognitive fatigue without scan UI |
| **OD-004** | Status stacking & boss resistance | **A**: Duration refresh + stack cap<br>**B**: Independent instances<br>+ Tenacity decay vs. Stagger meter | DoT builds, tactical interrupt timing, boss phase pacing | Infinite CC lockouts, visual clutter from multiple timers |

---

*Note: In accordance with project operating rules, zero numeric balance constants, damage multipliers, or drop percentages have been authored in this brief. Upon human architectural selection of the preferred options, concrete balance curves will be codified in companion specification documents.*
