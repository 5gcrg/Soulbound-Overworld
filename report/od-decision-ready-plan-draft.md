# OD Decision-Ready Plan Draft — `PLAN_DRAFT_NOT_CODEX`

**Date:** 10 November 2026  
**Author:** GPT-5.6 Luna / OpenCode, because Codex CLI is unavailable due to usage limits.  
**Execution:** No MiMo execution is authorized by this draft.  
**Rule:** Every unresolved value remains `TBD`; this document resolves nothing.

## Recommended first decision

### `OD-009` — Explicit MVP save boundary

**Proposed decision for owner ratification:** retain the existing MVP fallback:
save at room/exploration boundaries; do not serialize mid-battle or partial-turn
state. The exact serialization boundary and any future full-release behavior remain
`TBD` unless the owner explicitly approves them.

**Why first:** smallest safe scope, directly protects save invariants, avoids
inventing combat-turn serialization, and can be implemented as explicit guards,
documentation, and tests without choosing combat numbers or story content.

- Affected: GDD-098..100, FR-SAV-001, FR-CMB-001, TC-SAV-001/002.
- Current fallback: mid-combat state is volatile; room/exploration boundaries persist.
- Human approver: project owner / persistence architecture authority.
- Later MiMo files: only after approval, likely `scenes/dungeon/dungeon_expedition.gd`,
  `scenes/main/game_root.gd`, `scripts/persistence/profile_store.gd`, tests, and docs.
- Acceptance: save during allowed boundary succeeds; attempted mid-battle save is
  rejected or deferred without partial mutation; restart preserves profile data and
  does not create a false resumable combat; suspend is not extraction; exact-once
  extraction remains green.
- Risk: accidentally weakening permanent-data preservation or changing combat flow.
- Out of scope: any new mid-battle format, replay log, combat resource values, or
  browser resume behavior.

## Staged OD roadmap

| Rank | Tag / OD | Decision required | Current fallback / blocked result | Human gate |
|---:|---|---|---|---|
| 1 | `[OD-BLOCKED] OD-009` | Ratify MVP save boundary vs. a future mid-battle format; all format/turn fields remain TBD. | Room/exploration boundary saves; mid-battle persistence blocked. | Project owner / persistence authority |
| 2 | `[OD-BLOCKED] OD-013` | Ratify reference hardware, browser versions, size budgets, and FPS evidence method; all targets remain TBD. | 960×540, Compatibility, single-thread Web; no certification/budgets. | QA/platform owner |
| 3 | `[HUMAN-GATE] OD-017` | Choose public default tier: `academic_mvp` or `full_release`. | Checked-in developer default remains `full_release`; no public selection. | Release authority |
| 4 | `[HUMAN-GATE] OD-012` | Approve question banks, rubrics, hints, and educator validity. | Completion-gated MVP; no assessment-validity claim. | Educator/assessment authority |
| 5 | `[OD-BLOCKED] OD-002` | Ratify initiative/speed behavior; thresholds and formulas remain TBD. | Deterministic MVP round ordering. | Combat design authority |
| 6 | `[OD-BLOCKED] OD-003` | Ratify element chart, damage/SP/cooldown formulas; every coefficient remains TBD. | Existing authored MVP fallback only; advanced boss mappings blocked. | Combat balancing authority |
| 7 | `[OD-BLOCKED] OD-004` | Ratify status timing, stacking, and boss resistance rules; values remain TBD. | Basic MVP status behavior. | Combat balancing authority |
| 8 | `[OD-BLOCKED] OD-005` | Ratify EXP curve, starting stats, and level budgets; curve values remain TBD. | Existing placeholder progression. | Progression authority |
| 9 | `[OD-BLOCKED] OD-008` | Ratify EXP/currency treatment on defeat; retention ratios remain TBD. | Secured data survives; approved unbanked satchel loss only. | Roguelite authority |
| 10 | `[OD-BLOCKED] OD-007` | Ratify inventory/stack/currency rules; caps and multipliers remain TBD. | Existing fixed MVP fallback. | Economy/roguelite authority |
| 11 | `[OD-BLOCKED] OD-006` | Ratify refinement, rarity, crafting and failure rules; all rolls/values remain TBD. | Deterministic MVP item tiers. | Economy authority |
| 12 | `[OD-BLOCKED] OD-011` | Ratify dungeon modules, grammar, floors and difficulty budgets; all budgets remain TBD. | Seeded MVP dungeon DAG. | Dungeon design authority |
| 13 | `[OD-BLOCKED] OD-010` | Ratify quests, factions, reputation, NPC roster and thresholds; all content remains TBD. | Linear MVP progression. | Narrative/content authority |
| 14 | `[OD-BLOCKED] OD-001` | Ratify Ren’s origin, villain, branches and ending triggers; all reveals remain TBD. | Placeholder/limited MVP narrative. | Narrative lead / owner |
| 15 | `[OD-BLOCKED] OD-014` | Approve a Godot 4.7.2-compatible MCP adapter proof and production boundary. | Native files/headless CLI; Unity/C# adapter rejected. | Engineering/tooling authority |
| 16 | `[ASSET-BLOCKED] OD-015` | Approve binary audio generation/modality and delivery. | Procedural audio fallback; binary audio pending. | Asset pipeline / Gemini tooling authority |
| 17 | `[ASSET-BLOCKED] OD-016` | Approve asset quantities, frame targets, licensing and attribution. | Primitive/procedural MVP visuals; full asset register pending. | Production/legal authority |

## Separate mandatory human work

- `[HUMAN-GATE]` Chromium/Firefox smoke: GDD-123, TC-WEB-001/002.
- `[HUMAN-GATE]` educator sign-off: GDD-127 / OD-012.
- `[HUMAN-GATE]` final release checklist: GDD-132.
- `[HUMAN-GATE]` Web publishing: GDD-111.
- `[HUMAN-GATE]` image generation credentials/assets: Codex-exclusive.

## MiMo execution contract after ratification

Only after the owner approves a specific OD and scope:

1. Create an implementation queue naming the ratified OD and exact approved values.
2. MiMo changes only the approved files and records the approval reference.
3. MiMo adds positive/negative tests and preserves save, education, and release invariants.
4. Independent verification runs before any review request.
5. Work remains `REVIEW_PENDING_CODEX`; Codex CLI review is deferred until available.

## Current disposition

**No OD is resolved by this draft. No MiMo execution should start until the
project owner ratifies the recommended `OD-009` scope or selects another OD.**
