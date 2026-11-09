# Open Decisions Ledger — Soulbound (SBL-DATA-001)

**Milestone**: Release Hardening & Scope Boundary Management  
**Source Baseline**: `Soulbound_GDD_SRS.md` §16.1 (Requirements `GDD-001` through `GDD-132`)  
**Operating Contract**: `AGENTS.md` ("Do not invent numerical stats, formula coefficients, drop probabilities, story revelations, or unsupported integrations. Mark such items `TBD` and seek change approval.")  
**Status**: ACTIVE LEDGER (All decisions tracked with explicit placeholders; zero invented values)  

---

## 1. Operating Rules for Open Decisions

1. **No Invented Values**: Neither implementation agent (`agy`) nor planning agent (`Codex`) may unilaterally invent numeric balancing coefficients, formula multipliers, drop percentages, narrative reveals, or unverified tooling adapters.
2. **Traceable Placeholders**: Every deliberately unspecified parameter or deferred architectural decision in the codebase is marked as `TBD` and explicitly keyed to an `OD-###` identifier.
3. **Ratification Requirement**: Features touching an open decision remain locked to approved MVP fallback behaviors until the designated decision owner formally signs off on a change proposal.

---

## 2. Complete Open Decisions Register (`OD-001` .. `OD-016`)

| Open Decision ID | Decision Needed | Affected Requirement IDs | Current Placeholder in Code (`TBD`) | Resolution Owner / Gate | Current Impact / What Stays Blocked |
|---|---|---|---|---|---|
| **OD-001** | Ren's forgotten origin, villain identities, narrative branches, and dual-ending trigger choice flags. | GDD-009..015, GDD-041, FR-WLD-001 | `TBD` in `scenes/combat/boss_encounter.gd` and `scenes/ui/ending_modal.gd` (MVP uses generic chapter flags `chapter_5_cleared` and placeholder text). | Narrative Lead / Human Approval | Full 5-chapter release story script, permanent lore revelations, and branching narrative dialogue remain uncommitted. |
| **OD-002** | Speed initiative rule: strict turn ordering by Speed attribute vs. dynamic ATB ticks / extra turns from Speed thresholds. | GDD-016, GDD-018, GDD-023, FR-CMB-001/003, TC-CMB-001 | `TBD` in `scenes/combat/battle_fixture.gd` and `boss_encounter.gd` (MVP uses deterministic round-based ordering: Ren acts first, then enemies, 1 action per round). | Combat Design Review | Dynamic speed-ratio extra turns, initiative timeline UI, and speed-buff scaling formulas remain blocked. |
| **OD-003** | Full 6-element affinity counter chart (Fire, Water, Wind, Earth, Light, Shadow), damage formulas, SP costs, and cooldown curves. | GDD-017, GDD-019, GDD-021, FR-CMB-002/003/004, FR-MAG-001/002 | `TBD` in `scripts/magic/kurei_tree.gd` and `scenes/combat/battle_fixture.gd` (MVP uses discrete test costs [e.g. 5 SP for Ignite] and baseline direct subtraction). | Combat Balancing Review | Full elemental resistance matrix, critical hit multiplier scaling, and non-linear SP regeneration formulas remain blocked. |
| **OD-004** | Status effect duration timing, stacking rules (additive duration vs. intensity stacking), and boss resistance hierarchies. | GDD-020, GDD-022, FR-CMB-003 | `TBD` in `scripts/combat/status_engine.gd` (MVP uses per-turn round decrement and basic additive stacks up to cap 5). | Combat Balancing Review | Percentage-based boss debuff resistances, diminishing returns on crowd control, and cleansing tier hierarchies remain blocked. |
| **OD-005** | EXP progression curve to Level 30 cap, base attribute starting values, and stat point leveling budgets. | GDD-024, GDD-025, FR-PRG-001/002 | `TBD` in `scripts/persistence/profile_store.gd` and `scenes/ui/character_sheet.gd` (MVP uses baseline linear placeholder threshold `level * 100`). | Progression Design Review | Quadratic/polynomial EXP growth curves, late-game attribute diminishing returns, and endgame stat budgets remain blocked. |
| **OD-006** | Equipment refinement cap, item rarity affix roll distribution weights, crafting recipe material values, and failure penalties. | GDD-026, GDD-027, GDD-028, FR-INV-001 | `TBD` in `scenes/ui/inventory_sheet.gd` (MVP defines static tiers Common/Uncommon/Rare/Epic/Legendary with deterministic stats). | Economy Balancing Review | Blacksmith upgrade failure chances, randomized affix prefix/suffix rolls, and crafting ingredient price tables remain blocked. |
| **OD-007** | Inventory slot cap increments, item stack maximums, Spirit Coin banking rules, and unbanked expedition earning multipliers. | GDD-029, GDD-030, FR-INV-001, FR-DNG-002 | `TBD` in `scenes/ui/inventory_sheet.gd` and `scripts/persistence/profile_store.gd` (MVP enforces fixed 20-slot cap and scalar item count tracking). | Inventory / Roguelite Review | Expandable inventory pouch upgrades, bulk item stacking caps, and dynamic merchant buy/sell price scaling remain blocked. |
| **OD-008** | Persistent EXP and currency awarded or lost during a failed expedition (fraction retained vs. 100% defeat penalty). | GDD-034, GDD-035, FR-DNG-002, FR-SAV-001 | `TBD` in `scenes/dungeon/dungeon_expedition.gd` and `scenes/main/game_root.gd` (MVP retains 100% banked gear and permanent levels, but unbanked satchel loot is wiped). | Roguelite Review | Consolation EXP payouts on wipe, partial unbanked coin retention ratios, and soul-recovery mechanics remain blocked. |
| **OD-009** | Save boundary for in-progress battle and partial combat turns (save-on-turn vs. save-only-at-encounter/room-boundary). | GDD-098, GDD-099, GDD-100, FR-SAV-001, FR-CMB-001 | `TBD` in `scenes/dungeon/dungeon_expedition.gd` (MVP saves only at room/exploration boundaries; mid-combat actions are volatile and restart encounter). | Persistence Architecture Review | Mid-turn combat serialization, mid-battle browser resume, and combat-action replay logs remain blocked. |
| **OD-010** | Narrative quest scripts, faction alignment rules, reputation thresholds, and full chapter NPC roster. | GDD-036..041, GDD-061..066, FR-WLD-001, FR-QST-001 | `TBD` in `scenes/vertical_slice/quest_dialog.gd` and `scenes/main/game_root.gd` (MVP implements Chapters 1–3 linear progression). | Narrative / Content Review | Faction reputation influence, branching non-linear quest lines, and dialogue variation based on alignment remain blocked. |
| **OD-011** | Procedural dungeon module pool inventory, room generation connection grammar, and difficulty tier room budgets. | GDD-042..048, FR-DNG-001/003 | `TBD` in `scenes/dungeon/dungeon_expedition.gd` (MVP uses seeded 4-room exploration DAG with entry, encounter, puzzle/treasure, extraction). | Dungeon Design Review | Multi-floor labyrinth generation, dynamic room layout chunking, and biome-specific hazard budgets remain blocked. |
| **OD-012** | Assessed educational question banks, objective scoring rubrics, hint unlocking thresholds, and educator sign-off gate. | GDD-067..072, GDD-089..092, FR-EDU-001..004 | `TBD` in `scripts/education/assessment_controller.gd` (MVP uses completion-gated questions per AGENTS.md invariant). | Educator / Assessment Review (Mandatory gate) | Accredited classroom deployment and formal psychometric assessment validity remain blocked until external educator sign-off. |
| **OD-013** | Target reference hardware specifications, maximum build size budgets, browser minimum versions, and automated FPS telemetry capture. | GDD-093..097, GDD-104..107, NFR-PERF-001 | `TBD` in `project.godot` and `docs/browser_verification_checklist.md` (MVP targets 60 FPS fixed, 960x540 viewport, single-threaded Compatibility). | QA / Platform Review | Automated browser telemetry ingestion, low-end device certification, and hard asset package size enforcement remain blocked. |
| **OD-014** | Tooling runtime integration: specific agy agent runtime hooks, Codex CLI review bridge automation, and Godot-compatible MCP adapter. | GDD-108..112, GDD-129..132, AGENTS.md Operating Contract | `TBD` in `docs/godot-mcp-evaluation.md` (Unity-mcp rejected as incompatible; Godot-native files + headless CLI test harness retained). | Tooling Proof-of-Concept / Engineering Lead | Live real-time bidirectional scene tree editing via MCP remains blocked until a true Godot 4.7.2 adapter is developed. |
| **OD-015** | Image generation mechanism under Codex and Gemini Flash audio modality specification. | GDD-083..088, GDD-113..115, AGENTS.md § Exclusive asset routing | `TBD` in `docs/audio-spec.md` (Codex image generation exclusive; procedural audio fallback in `audio_manager.gd` used; Flash binary audio pending). | Asset Pipeline PoC / Codex & Gemini Tooling Leads | Production binary pixel art sprites, tilesets, portraits, and multi-track binary music stems remain blocked. |
| **OD-016** | Final asset inventory quantities, sprite animation frame targets, and third-party licensing attribution register. | GDD-083..088, GDD-125..128, docs/asset-register.md | `TBD` in `docs/asset-register.md` (MVP uses Godot geometric primitives and programmatically generated audio tones). | Production Planning / Legal Lead | Commercial asset licensing sign-off, full 8-direction sprite animation sets, and external attribution documents remain blocked. |

---

## 3. Mandatory Verification Checklist for PRs and Slices

Before submitting any code slice for Codex CLI review:
1. Verify that no numeric constants representing balance curves, formulas, or drop tables were invented.
2. Confirm that every placeholder or stubbed feature references its exact `OD-###` identifier.
3. Confirm that the slice adheres to all ratified MVP invariants:
   - Secured gear, level, skills, and educational records survive defeat (`OD-008`).
   - Suspend/resume does not count as extraction (`OD-009`).
   - Educational activities are completion-gated, never pass-score-gated (`OD-012`).
   - Single-threaded Compatibility renderer for Web and Windows (`OD-013`).
   - Image assets generated exclusively by Codex; non-image binary audio pending Gemini Flash (`OD-015`).
