---
title: "SOULBOUND — Game Design Document and Software Requirements Specification"
subtitle: "E-Learning-Based 2D Turn-Based Roguelite Role-Playing Game"
author: "Radzgie V. Custodio; Jeferson G. Galaraga"
date: "8 November 2026"
lang: en-US
---


<!-- AGENT EXECUTION QUICK RULES
- Read §11 and AGENTS.md before editing Godot code.
- Codex plans and owns all image generation.
- agy executes scoped implementation.
- Codex CLI reviews after agy; if unavailable, agy continues with REVIEW_PENDING_CODEX queue.
- Gemini Flash generates all non-image assets.
- Unity-MCP is Unity-specific and must NOT be assumed operational in Godot.
- Do not invent TBD balancing/story numbers.
-->

> **Document control** — Baseline `SBL-GDD-SRS-1.0` | Status: **Approved high-level requirements / implementation details pending** | Course: **BSCS 4 — 2D Game Development** | Primary output: Academic three-stage game; full target: five-stage game.
>
> **Interpretation rule:** *Approved* means ratified by the nine design interviews; *proposed* denotes an implementation recommendation; *TBD* denotes a deliberately unspecified value. This document is a specification and implementation plan, **not evidence that the game or its integrations have already been built.**

# Abstract

Soulbound is an educational, two-dimensional pixel-art role-playing game featuring Ren, a spirit warrior seeking to understand a forgotten past while confronting corruption across overlapping physical and spiritual dimensions. The game combines eight-direction exploration, Ninja Saga-inspired side-view turn-based combat, six categories of Kurei magic, repeatable modular roguelite dungeons, and meaningful narrative decisions. Senior high school learners encounter competency-based activities concerning critical thinking, decision-making, problem-solving, perseverance, and resource management. This combined Game Design Document (GDD) and Software Requirements Specification (SRS) consolidates 132 high-level approved requirements, identifies implementation-level behaviors and acceptance checks, separates the three-chapter academic MVP from the full five-chapter target, and establishes a 13-week, two-developer delivery model. A controlled AI-assisted development workflow assigns Codex planning, image generation and review; agy implementation; Gemini Flash non-image asset generation; and requires a proven Godot integration rather than assuming a Unity-specific MCP package can operate unchanged.

# Document Governance and Reading Guide

| Field | Value |
| --- | --- |
| Primary title | Soulbound |
| Document identifier | SBL-GDD-SRS-1.0 |
| Prepared for | BSCS 4 — 2D Game Development |
| Project team | Radzgie V. Custodio; Jeferson G. Galaraga |
| Baseline date | 8 November 2026 |
| Approved requirements | 132 (GDD-001 through GDD-132) |
| Project category | Educational 2D turn-based roguelite RPG |
| Target implementation | Godot 4.7.2 Stable, GDScript, Compatibility renderer |
| Primary audience | Senior high school students |
| Initial academic scope | Three complete chapters, one modular replayable dungeon, coherent completion point |
| Full scope | Five chapters and two narrative endings |
| Document status | Requirements baseline approved; numeric balancing and story specifics TBD |

Source precedence: (1) explicit nine-phase user approvals; (2) source project proposal for concepts and academic requirements not superseded; (3) this document's clearly labeled proposals. If an example conflicts with a user-approved requirement, the approved requirement prevails. Changes require a documented change request.

# 1. Introduction

## 1.1 Purpose

Define an auditable, implementation-ready baseline for gameplay, educational content, architecture, assets, data, delivery, and verification, with enough structure for a human student team and the Codex/agy agent workflow. The machine-readable Markdown edition is authoritative for agent task planning; the DOCX edition communicates the same baseline in academic form.

## 1.2 Scope

Soulbound targets Windows PC and desktop web browsers. Its minimum academic deliverable provides Chapters I–III, at least one completed learning activity per playable chapter, and a complete representative roguelite dungeon; the full game adds Chapters IV–V and two narrative endings. The two stages of completion must not be confused.

## 1.3 Terms and conventions

| Term | Definition |
| --- | --- |
| MVP | Three-chapter academic release, not the entire approved five-chapter design. |
| Full release | Five-chapter target including two endings. |
| Kurei | Ren’s system of spiritual techniques and related elemental affinities. |
| SP | Spirit Energy; a Kurei resource. |
| Expedition | Repeatable dungeon run with temporary power, unsecured loot, and extraction/defeat outcomes. |
| Secured item | Item ownership that remains after expedition defeat. |
| Unbanked item | Loot at risk during an active expedition. |
| GDD-### | Approved high-level design requirement identifier. |
| FR-### | Implementation-level functional requirement identifier. |
| NFR-### | Nonfunctional requirement identifier. |
| TC-### | Acceptance test case identifier. |
| TBD | Unspecified and requiring formal resolution. |
| agy | Execution agent designated by the project owner; precise product/runtime integration is TBD. |

# 2. Game Overview and Core Loop

## 2.1 Premise and audience

Ren, a fixed protagonist who awakens without memories, learns spiritual Kurei magic and journeys through settlements, corrupted wilderness, shrines, mountains and a final spiritual sanctum. The story concerns identity, responsibility, perseverance and corruption. The canonical origin of Ren’s lost memories is intentionally not determined by the approvals and must be authored as a separate narrative decision.

## 2.2 Core gameplay loop

1. Enter a discovered region, follow the active story or optional quest, and examine environmental clues.
2. Explore with eight-direction movement; speak to NPCs, interact with physical and spirit objects, or shift dimensions where permitted.
3. Resolve combat using speed-based initiative and one main action per Ren turn: Attack, Kurei, Defend, or Item.
4. Gain permanent progression and potential items; manage limited SP, cooldowns, healing and equipment.
5. Enter an optional expedition, select temporary modifiers, defeat encounters, and reach an extraction point to secure loot.
6. Complete required educational activities with explanations and permanent learning records, without score-based story gates.
7. Progress the chapter, unlock waypoints/areas, save, and revisit older regions.

## 2.3 Platform and release objectives

| Property | Specification |
| --- | --- |
| Engine | Godot 4.7.2 Stable (approved target; validate available binaries in implementation environment) |
| Language | GDScript |
| Rendering | Compatibility for Windows and web |
| Display | 960×540 logical 16:9 viewport; scalable UI |
| Performance | 60 FPS goal; documented 30 FPS fallback |
| Distribution | Windows portable ZIP; itch.io HTML5/Web build |
| Input | Keyboard/mouse with remapping; controller not required |
| Connectivity | Gameplay intended offline/local; web delivery requires loading website; no cloud account backend approved |

# 3. Narrative, Characters, Factions and Chapters

## 3.1 Story constraints

- Ren has a fixed name and story identity. No customizable protagonist or active party system is approved.
- Physical and spiritual dimensions overlap; some places can reveal spirit NPCs, objects, routes and puzzles.
- Choices can alter NPC reactions, follow-up quests, rewards, selected encounters and numeric faction reputation.
- Two endings are full-release outcomes; the academic third-chapter completion must not impersonate one of them.
- Ren’s backstory, named antagonist, decisive plot reveal, exact faction roster and ending triggers are open narrative work.

## 3.2 Chapter and region table

| Chapter | Region | Approved narrative and gameplay role | Release |
| --- | --- | --- | --- |
| I | Dawnreach Village | Controls, first Kurei abilities, introductory quests and battles, initial learning activity | Academic MVP |
| II | Whispering Grove | Corruption, enemy analysis and elemental weaknesses, forest boss, learning activity | Academic MVP |
| III | Forgotten Shrine | Shrine exploration, memories/lore, advanced spirits, Kurei unlock, learning activity, academic completion | Academic MVP |
| IV | Ashen Peaks | Stronger enemies, equipment development, resource management, mountain boss | Full release |
| V | The Soul Sanctum | Corruption source, Ren’s eventual truth, final boss and two endings | Full release |

## 3.3 Characters, enemies and factions

Initial enemy archetypes from the proposal are Lost Spirits, Corrupted Beasts, Fallen Warriors and Shadow Wraiths. They respectively introduce combat fundamentals, elemental strengths/weaknesses, offensive/defensive tactics, and debuffs/resource adaptation. Boss identities and stats are TBD. Factions shall use numeric reputation with small, meaningful effects on dialogue, optional follow-up quests and rewards. Faction identities and thresholds are not yet determined.

## 3.4 Narrative state

Use stable flags for chapter unlocks, dialogue choices, quest branches, reputation and ending-related decisions. Do not rewrite historic choices when a player replays bosses. Story state changes require validated save boundaries and traceable quest events.

# 4. Combat and Kurei Magic Specification

## 4.1 Encounter and battle flow

Story areas use visible enemies; repeatable dungeons can produce randomized encounters. Battle starts via a validated encounter trigger, loads appropriate participant definitions, initializes initiative, and proceeds until victory, defeat or an explicitly implemented alternative. Combat presentation is enhanced side-view with distinct sprites, casting motion, impact effects and readable status/intent cues.

## 4.2 Initiative and action economy

Speed controls initiative. Ren receives one main action per turn from Attack, Kurei, Defend or Item. Enemy inspection and telegraphed intents are approved, but whether inspection consumes an action and whether Speed causes extra turns remain TBD. Recommended initial behavior: one turn per combatant per round, ordered by Speed, with free non-consuming inspection. This recommendation must be ratified before balancing.

## 4.3 Kurei and damage

Ren may equip at most six learned Kurei spells. Spells consume SP and may be subject to cooldowns. Supported effect categories include direct damage, healing, buffs, debuffs and status application. Six affinities are Fire, Water, Wind, Earth, Light and Shadow. No exact elemental counter chart, damage formula, critical multiplier, SP regeneration amount, cooldown values or resistances are currently approved; all are balancing TBD.

## 4.4 Statuses, AI and bosses

The status engine supports Poison, Burn, Stun, Defense Down, Bleed, Silence, Shield, Regeneration and Slow. Status stacking rules, durations, turn timing, immunity/resistance, cleansing rules and boss adjustments require controlled tables. Enemy analysis must show relevant information as earned/available, and telegraphs must give enough information to make intentional defensive decisions. Major bosses may have phases, distinctive mechanics, weaknesses and observable warnings. Boss replay challenges must not replay permanent story flags.

## 4.5 Combat acceptance checks

- Reject a seventh equipped spell; keep menu and save representation consistent.
- Never spend SP or start cooldown for a rejected/invalid action.
- Apply exactly one main action per Ren turn.
- Surface intended enemy behavior and statuses without relying solely on colors.
- Treat optional educational combat questions as bonus-only; incorrect responses cause no direct penalty.
- Ensure combat state and expedition saving cannot duplicate turn results or rewards.

# 5. Character Progression, Items and Economy

## 5.1 Character model

Permanent character Level caps at 30. Attributes are Health, Spirit Energy, Physical Attack, Kurei Power, Defense, Spirit Resistance, Speed and Critical Rate. Growth combines automatic increases and manually allocated bonus points. Ability unlocks use story/level prerequisites; upgrades use skill points. The actual starting values, EXP thresholds, growth coefficients and point budgets are TBD.

## 5.2 Equipment and rarity

Equipment slots: Weapon, Head, Chest, Boots, Accessory 1 and Accessory 2. Rarity tiers: Common, Uncommon, Rare, Epic, Legendary. Item definitions have base stats; selected items may roll bonus stats, with roll seeds or captured values persisted. Refinement improves stats via materials/costs; caps, failures, material consumption and coin prices remain TBD. Owned equipped gear must not accidentally be treated as fresh unbanked loot.

## 5.3 Inventory, crafting and vendors

Inventory is slot-based and expandable. A single Spirit Coin currency serves specialized merchants. Basic gathering and crafting convert collected ingredients into agreed consumables/simple gear. Avoid introducing alternate currencies without change approval. Inventory stacking, capacity increments, recipes and merchant stock tables are TBD.

## 5.4 Roguelite persistence

Permanent character level, learned Kurei, allocated attributes, story and learning records, and already secured equipment must survive defeat. Temporary combat modifiers and unsecured expedition loot do not. Successful extraction commits eligible unbanked items to secured ownership. Suspended runs preserve the at-risk state and do not count as extraction. Whether EXP is committed immediately and how Spirit Coins are banked remains TBD; recommended: permanent earned EXP survives defeat, while newly obtained unbanked coins follow extraction rules.

# 6. World, Exploration and Quest Systems

## 6.1 Overworld design

Five authored regional-map groups are connected by roads, gates, caves, or portals. Travel points are available only after discovery/unlock. A minimap and full world map show player position and quest markers. Ren can move freely in eight directions even when tileset artwork follows a fixed 32×32 grid. World passage and fast travel must honor story gates and expedition restrictions.

## 6.2 Spirit-dimension rules

Dimension shifting is available only in eligible contexts after the appropriate Kurei unlock. It changes visible/interactable spirits, objects and paths. Collision layers must update safely: no shift may embed Ren in a solid obstacle or place the player outside the playable map. Proposed implementation uses shared map scenes with dimension-scoped nodes and collision layers instead of duplicate full maps where practical.

## 6.3 Quest and branch lifecycle

Quest classes: Main, Side, Faction, Bounty, Educational. Quest definitions contain stable ID, prerequisites, objectives, rewards and branch identifiers. Runtime state includes LOCKED/AVAILABLE/ACTIVE/COMPLETED/FAILED only if the particular quest supports those transitions; exact state-machine variants are a design detail. Quest journal and HUD show progress and objective markers. Dialogue choice and reputation effects are durable after save/load.

## 6.4 Puzzle and world secrets

Puzzles combine conventional interactions, Kurei effects, dimension shifting, sequencing and analysis. Hidden treasures, craft materials, Kurei secrets, and lore fragments reward exploration. Mandatory puzzles need reachable solutions and progressive learning hints. Do not lock story progress behind a minimum educational score.

# 7. Modular Roguelite Dungeon System

## 7.1 Room assembly

A repeatable dungeon constructs an approximately 6–10-room-or-encounter layout from authored room modules. Each template declares entrances/exits, door compatibility, traversable space, encounter sockets and optional puzzle/loot/rest points. Generator uses a seed, builds a valid route, and rejects disconnected or unsolvable results. Save both seed and mutable dungeon state, including sufficient generation/version information to reproduce the run.

## 7.2 Challenge tiers and reward flow

Base dungeon difficulty follows region tier, with optional challenge modes. Each expedition can award temporary stat increases and tactical modifiers. Loot remains unbanked until designated extraction. Successful exit validates transfer and closes the expedition; defeat discards unsecured assets and resets temporary upgrades while preserving permanent data. Boss challenge replays grant relevant repeatable rewards without modifying story completion flags.

## 7.3 Suspension and failure-safe persistence

Suspended snapshots must preserve current room, map seed/version, RNG state if needed, enemies defeated, current HP/SP, cooldown/status state when relevant, temporary upgrades, unbanked loot, and safe resume point. A suspend snapshot cannot secure loot. Saving/extraction must be transaction-like, prevent duplicate claims, and recover from interrupted writes. Saving during unresolved combat actions is a controlled TBD boundary.

# 8. Educational Game Design and Assessment

## 8.1 Audience and objectives

Primary learners are senior high school students. The five domains are Decision-Making, Critical Thinking, Problem-Solving, Perseverance (through reflection and strategy revision, not raw retry counts), and Resource Management. Narrative and combat situations should connect fictional choices to transferable real-life judgment while acknowledging context-dependent answers.

## 8.2 Activities and item bank

Educational content includes multiple choice, scenario decisions, sequencing and interactive logic puzzles. A minimum of one completed required educational activity appears in each playable chapter; the full game extends this across five chapters. Manually authored and reviewed banks supply randomized question selection by competency, chapter, difficulty and eligibility. No live AI-created, unvalidated questions are permitted in assessed gameplay.

## 8.3 Feedback and assistance

Questions provide immediate explanations and an activity summary. Practice permits retries; assessed activities retain first-attempt correctness and report subsequent practice separately. Progressive hints are available according to defined stage/difficulty criteria. Players must complete—not pass a score threshold on—required story learning activities. Optional battle questions grant positive bonuses for correct reasoning and impose no direct incorrect-answer penalty.

## 8.4 Records and reports

Store activity IDs, competency IDs, first response, outcome, attempts, optional hint-use counts if implemented, completion timestamps if feasible, and per-domain aggregated progress. Educational data survives expedition defeat. The journal shows learner progress; export sanitized local CSV and printable HTML or equivalent report. Avoid collecting real names or unnecessary personal identifiers. Any report must distinguish observed correctness from educational improvement claims.

## 8.5 Content validation

A qualified reviewer assesses content accuracy, alignment, difficulty and explanations. Learner evaluation examines comprehension, usability and engagement. Do not interpret attempts, scores or combat performance as proof of generalized learning outcomes without an appropriate evaluation design.

# 9. Art Direction, Audio and User Experience

## 9.1 Visual style and animation

The approved style is 32×32-inspired mystical fantasy pixel art, three-quarter top-down overworld, detailed side-view combat presentation, story-driven time-of-day effects and a distinctive spirit dimension. Art dimensions remain consistent but characters/buildings may exceed one tile. Use four-direction movement animation as initial coverage despite eight-direction motion; add diagonals where useful. Character animation types include idle, walk, attack, cast, hurt, defend, dodge, interaction and selected special abilities. The final art pipeline and frame counts are TBD.

## 9.2 Six-element visual language

Fire uses flame/ember shapes; Water uses splashes/flows; Wind uses swirls; Earth uses rock/dust; Light uses radiance; Shadow uses dark wisps/distortion. Shapes and icons complement color to maintain readability. Enhanced particle, trail and light effects must respect performance quality and reduced-motion options.

## 9.3 Audio

Hybrid retro-fantasy music changes by settlement, forest, boss, combat and spirit context. Nonverbal voice reactions and detailed attack, status, spell, and UI sounds are permitted; full voice acting is not in approved scope. Audio settings expose Master, Music and SFX. Avoid treating text-only or symbolic music scripts as playable soundtrack files until an authorized audio generator/rendering workflow has produced a valid sound file.

## 9.4 Interface inventory

| UI screen | Principal functions |
| --- | --- |
| Main menu | New/Continue, settings, exit where platform supports |
| Exploration HUD | HP/SP, objective tracker, minimap, interaction prompt |
| Battle HUD | Turn order, statuses, enemy intent, Attack/Kurei/Defend/Item |
| Kurei panel | Learned techniques, upgrades, six-slot equipped spell grid |
| Character & Equipment | Attributes, level/EXP, six equipment slots, refine |
| Inventory & Merchant | Categories, stack quantities, slot capacity, trade |
| Quest/Map | Quest journal, NPC objectives, fast travel, discovered markers |
| Dialogue | Expressive character portraits and choice options |
| Educational UI | Assessment activities, hints, feedback, learning journal |
| Settings/Pause | Audio bus sliders, remap controls, accessibility, scaling |
| Results | Victory/defeat/extraction rewards and chapter completion |

## 9.5 Accessibility and input

Support configurable keyboard/mouse controls, readable scalable UI, and reduced-motion settings. Suggested defaults: WASD/arrows move, E interact, Esc back/pause, I inventory, J journal, M map, C character, K Kurei, Q contextual dimension shift; all remain proposals. Avoid browser-reserved input conflicts and test focus handling. A 960×540 logical view must scale clearly to desktop resolutions and browser viewport changes.

# 10. Godot Architecture and Development Design

## 10.1 Architectural baseline

Use GDScript and the Compatibility renderer for both native/web targets. Architecture combines a small number of Autoload services for persistent cross-scene concerns, scene-owned controllers for local features, signal-based events, and explicit domain data models. No Unity assembly, C# gameplay dependency or direct Unity Editor API is part of the Godot build.

## 10.2 Proposed folders

```text
res://
  assets/{sprites,tilesets,portraits,effects,music,sfx,fonts}/
  scenes/{main,characters,overworld,combat,dungeons,ui,education}/
  scripts/{autoload,components,combat,progression,inventory,quests,world,dungeons,education,persistence}/
  resources/{items,equipment,kurei,enemies,quests}/
  data/{question_banks,balance,localization}/
  tests/
  docs/
user://
  profiles/profile_01/{profile.json,expedition.json,backups/}
  profiles/profile_02/{profile.json,expedition.json,backups/}
  profiles/profile_03/{profile.json,expedition.json,backups/}
  settings.json
```

## 10.3 Proposed scene tree and services

```text
GameRoot
  WorldContainer -> CurrentRegion -> Tile Layers / NPCs / Interactables / Spawns
  Player (CharacterBody2D) -> movement / animation / interactions
  BattleContainer -> BattleScene -> BattleController / UnitViews / BattleHUD
  UI (CanvasLayer) -> ExplorationHUD / Menus / Dialogue / Education
  TransitionLayer (CanvasLayer)
Autoloads (proposed, minimal): GameState, SceneRouter, SaveManager,
  ContentRegistry, SettingsManager, EventBus
Scene-owned systems: BattleController, QuestState, DungeonGenerator,
  ExpeditionController, AssessmentController
```

Avoid Autoloads for every feature. Autoload scope is reserved for cross-scene state and shared services, whereas combat and dungeon state should be instance-owned with serializable state snapshots. Use stable content IDs rather than relying on display strings or node paths in saves.

## 10.4 Resource definitions and structured JSON

Use typed Godot Resource definitions for asset-linked items, enemies, Kurei and quests; use reviewed structured JSON for question banks and selected bulk data. Runtime saved state references immutable content IDs plus mutable properties. The loader validates unknown IDs, duplicate IDs, schema versions, and missing prerequisites. Static content definitions should not be copied into each save.

## 10.5 Save schema outline

```json
{
  "schema_version": 1,
  "profile_id": "profile_01",
  "character": {"level": 1, "exp": 0, "attributes": {}, "learned_kurei": [], "loadout": []},
  "inventory": {"capacity": null, "owned_items": [], "equipment": {}, "secured_spirit_coins": null},
  "world": {"region": "dawnreach", "unlocked_regions": [], "waypoints": [], "quest_flags": {}, "reputation": {}},
  "education": {"completed_activities": [], "competency_results": {}},
  "expedition": {"active": false, "snapshot_id": null}
}
```

All values in this schema are illustrative placeholders, not balanced game constants. Save routines must be atomic or failure-tolerant through temporary write, validation and backup; import must validate schema and ignore unsafe paths. A suspend snapshot keeps loot at risk. Three profiles are independent. Web import/export is user-controlled backup, not cloud synchronization.

## 10.6 Web constraints

Web export is single-threaded, uses Godot 4 Compatibility/WebGL 2.0, and must be tested on Chromium and Firefox desktop browsers. Browser storage may be unavailable or cleared; export/import backups are required. Audio may require a user gesture to begin playback; UI focus and fullscreen behavior differ from native builds. No server-driven save synchronization is in the baseline.

## 10.7 Build and release

Provide Windows portable ZIP and the Godot web export ZIP uploaded to itch.io. Validate asset packaging, web startup, mouse and keyboard input, saves, browser downloads, educational report output, and reasonable initial load size. Include build version, source commit, docs and license/attribution register in a release manifest. GitHub tagged releases are the handoff source for evaluators.

# 11. AI-Assisted Development and Asset Production Policy

## 11.1 Binding project-owner directives

> **Exact user directive:** "all image generation involved wil be done with codex".
>
> **Normalized mandatory meaning:** All image generation involved in Soulbound will be done with Codex. All other asset generation will be done with Gemini Flash. Codex plans the implementation, calls agy to execute it, and Codex CLI reviews the completed work. If Codex CLI is unavailable or out of credentials/credits, agy continues implementing and Codex CLI reviews the queued changes when it becomes available again.

## 11.2 Roles and division of authority

| Actor | Authorized responsibilities | Not authorized to assume |
| --- | --- | --- |
| Codex (planner/orchestrator) | Read approved requirements, decompose work, create tickets, own all image generation, select image-capable workflow, delegate execution to agy, track risks | Silently change approved requirements or outsource image generation to Gemini Flash |
| agy (implementation agent) | Implement assigned Godot code/scenes/integrations, run tests, log changes, continue during Codex CLI outage | Treat missing review as permanent approval, bypass release gates, overwrite unapproved story/balancing |
| Codex CLI (reviewer) | Review agy diffs, validate tests and Godot compatibility, flag defects, approve or request fixes | Claim to have reviewed work while unavailable or out of credits |
| Gemini Flash (non-image asset generation) | Generate approved non-image asset content: dialogue, quest drafts, educational item data, metadata, localization, structured prompts, and compatible non-image outputs | Generate any image, pixel sprite, portrait, tileset, icon, texture or visual effect image |
| Human developers / project owner | Approve design changes, asset rights, quality gates, story reveals, release candidates | Assume agent completion means QA is complete |

## 11.3 Enforced agent execution cycle

1. **Codex plans** an implementation slice, citing requirements IDs and acceptance tests; isolate ambiguities before writing.
2. **Codex generates or directs image creation** through an image-generation-capable interface under Codex control. If such capability is unavailable, open a blocker; do not silently substitute Gemini Flash.
3. **Gemini Flash generates all non-image assets**, subject to the available modality. If Flash cannot output a playable music/audio file, it may provide structured source or a production specification and the binary remains pending; no alternative generative provider is silently permitted.
4. **Codex calls agy** with scoped file ownership, inputs, checks, and definition of done. agy implements in an isolated branch/worktree with commits and evidence.
5. **Codex CLI reviews** after agy completes: diff review, requirements coverage, editor/headless validation, tests, content provenance and cross-platform risks.
6. **If Codex CLI is absent, rate-limited or out of credentials/credits**, agy continues on independent, documented tasks. Each change is labeled `REVIEW_PENDING_CODEX`, logged in `docs/agent-review-queue.md`, and does not bypass protected-branch/release review. Queued work is reviewed when Codex CLI resumes.
7. **Fix and merge:** agy fixes review findings; Codex CLI rechecks as available; a human approver applies final gated release decision. Never assert that unreviewed code was reviewed.
8. **Audit trail:** record task ID, requirements, changed files, asset source/generator, test results, review status, decision, and commit hashes.

## 11.4 Image/non-image asset classification

| Asset class | Exclusive generator owner | Notes |
| --- | --- | --- |
| Character sprites, portraits, icons, tilesets, UI textures, backgrounds, VFX sprite sheets | Codex | Codex directs image generation; pixel-size, transparency, palette, license and format must be verified. |
| Story dialogue, quest content, question banks, localization, item descriptions | Gemini Flash | Always human/educator review before assessed use. |
| Non-image audio/music content and data | Gemini Flash | Only deliver actual audio files if supported by selected Gemini Flash workflow; otherwise flag as pending with source spec. |
| Code, scene assembly, tests, pipelines | agy under Codex plan | Programming is implementation, not treated as asset generation; Codex CLI performs review. |
| Final acceptance and release authorization | Human team | Automated agent checks are evidence, not a substitute for release approval. |

## 11.5 AI Game Developer / Unity MCP compatibility boundary

The specified reference is https://github.com/ivanmurzak/unity-mcp (AI Game Developer / Unity MCP), a Unity Editor/Runtime integration. Its README describes Unity-specific packages, APIs, scene/GameObject tooling and Unity C# execution. This repository is **not a verified drop-in Godot integration**. The project may borrow its agent tool orchestration pattern, but must use a proven Godot-compatible bridge, a separately implemented Godot MCP adapter, Godot editor scripts/headless CLI, or an explicitly approved compatible interface. No Unity package, Unity-specific APIs, GameObject/prefab assumptions or C# runtime dependencies may be treated as Godot capabilities.

## 11.6 Required Godot adapter validation

- Document the chosen Godot bridge/MCP implementation, version, authority, permissions and install procedure.
- Prove, on a disposable test project, that the agent can inspect scene trees, open/edit/create nodes/scenes, save scenes, read errors, run a Godot headless import/test, and capture screenshot evidence where supported.
- Use Godot-native terminology: Nodes, Scenes, Resources, Signals and GDScript; do not translate Unity GameObject tools by name alone.
- If editor tool integration fails, use agy to modify versioned Godot text assets and scripts with headless validation; track the MCP adapter as blocked rather than claiming it works.
- Never let an agent delete or overwrite source assets without version control and peer-review controls.

## 11.7 Delegation template

```text
TASK: [short title]
REQUIREMENTS: [GDD/FR IDs]
MILESTONE: [M1..M6]
OWNER: agy (execution) | Codex (plan + images) | Codex CLI (review)
BRANCH: feature/[scope]
INPUTS: [files/resources and decisions]
DELIVERABLES: [Godot scenes, scripts, data, tests, images/non-image assets]
ASSET ROUTING: images -> Codex; all other generated assets -> Gemini Flash
ACCEPTANCE: [specific TC IDs, Godot headless check, browser/native validation]
OPEN DECISIONS: [TBD, do not invent]
REVIEW STATUS: REVIEW_PENDING_CODEX | CHANGES_REQUESTED | REVIEWED
```

# 12. Functional Requirements Specification

The following catalog is the entire approved high-level baseline. Each GDD statement will be refined into implementable FR records with scope, priority, preconditions, behavior, error handling and tests. Requirements listed in a later full-release phase may be implemented as framework-only in the academic MVP; this does not remove their full-release obligation.

## Phase 1 — Game Vision

| Requirement ID | Approved statement |
| --- | --- |
| GDD-001 | Hybrid world with connected story regions and repeatable randomized dungeons |
| GDD-002 | Free eight-direction overworld movement |
| GDD-003 | Ninja Saga-inspired side-view turn-based combat |
| GDD-004 | Roguelite defeat: temporary expedition progress resets while permanent progress persists |
| GDD-005 | Education through integrated gameplay and explicit educational activities |
| GDD-006 | Target platforms: Windows PC and web browser |
| GDD-007 | Game engine: Godot |

## Phase 2 — Narrative and World

| Requirement ID | Approved statement |
| --- | --- |
| GDD-008 | Fixed protagonist Ren with established identity and background |
| GDD-009 | Physical and spirit worlds overlap as dimensions |
| GDD-010 | Ren’s forgotten-past mystery remains intentionally unresolved for narrative design |
| GDD-011 | Solo playable combatant; no active battle companions |
| GDD-012 | Moderate branching narrative consequences |
| GDD-013 | Simple factions and NPC relationship/reputation systems |
| GDD-014 | Two distinct endings in the complete game |
| GDD-015 | Progressively unlocked regions with revisitation permitted |

## Phase 3 — Combat and Kurei Magic

| Requirement ID | Approved statement |
| --- | --- |
| GDD-016 | Hybrid encounters: visible story-area enemies and randomized dungeon encounters |
| GDD-017 | Speed-based combat initiative |
| GDD-018 | One main action per turn for Ren |
| GDD-019 | Spirit Energy costs and cooldowns for Kurei abilities |
| GDD-020 | Maximum six equipped Kurei spells in combat |
| GDD-021 | Six affinities: Fire, Water, Wind, Earth, Light, and Shadow |
| GDD-022 | Expanded status effects: Poison, Burn, Stun, Defense Down, Bleed, Silence, Shield, Regeneration, Slow |
| GDD-023 | Enemy inspection and telegraphed intentions |
| GDD-024 | Bosses with phases, mechanics, weaknesses, and telegraphed attacks |
| GDD-025 | Exploration learning activities and optional positive-incentive combat questions |

## Phase 4 — Progression, Inventory and Equipment

| Requirement ID | Approved statement |
| --- | --- |
| GDD-026 | Dual progression: permanent character leveling and temporary expedition upgrades |
| GDD-027 | Eight combat attributes: HP, SP, Physical Attack, Kurei Power, Defense, Spirit Resistance, Speed, Critical Rate |
| GDD-028 | Hybrid attribute progression: automatic level gains plus discretionary point allocation |
| GDD-029 | Permanent character level cap of 30 |
| GDD-030 | Kurei unlocked by story/level prerequisites and enhanced with skill points |
| GDD-031 | Six equipment slots: Weapon, Head, Chest, Boots, Accessory 1, Accessory 2 |
| GDD-032 | Five rarities: Common, Uncommon, Rare, Epic, Legendary |
| GDD-033 | Fixed base equipment attributes with selected randomized bonus attributes |
| GDD-034 | Equipment refinement levels |
| GDD-035 | Expandable slot-based inventory |
| GDD-036 | One currency (Spirit Coins) with specialized merchants |
| GDD-037 | Safe-storage model: banked items persist; unbanked expedition loot is lost on defeat |
| GDD-038 | Temporary expedition stat buffs and combat modifiers |
| GDD-039 | Basic gathering/material-based crafting |
| GDD-040 | Hybrid HP/SP recovery with limited regeneration, consumables, inns/checkpoints |

## Phase 5 — World, Quests and Dungeons

| Requirement ID | Approved statement |
| --- | --- |
| GDD-041 | Five story regions built as connected regional maps |
| GDD-042 | Contextual spirit-dimension switching in eligible areas following ability unlock |
| GDD-043 | Dimension shifts reveal objects, spirits, alternate routes, and puzzles |
| GDD-044 | Unlockable waypoint/shrine fast travel |
| GDD-045 | Minimap and full-screen world map with quest/navigation markers |
| GDD-046 | Repeatable dungeons assembled from randomized handcrafted room modules |
| GDD-047 | Region-tier dungeon difficulty with optional harder challenge modes |
| GDD-048 | Medium repeatable dungeons approximately 6–10 rooms or encounters |
| GDD-049 | Designated extraction points to secure expedition loot |
| GDD-050 | Replayable challenge versions of defeated story bosses without story reset |
| GDD-051 | Quest categories: main, side, faction, bounty, educational |
| GDD-052 | Quest journal, objective tracking, and map markers |
| GDD-053 | Quest branching affects NPC relations, follow-up quests, rewards, and selected encounters |
| GDD-054 | Simple numeric faction reputation |
| GDD-055 | Environmental, Kurei, dimension-shifting, and analytical reasoning puzzles |
| GDD-056 | Mixed educational activities: quizzes, scenarios, and interactive problems with feedback |
| GDD-057 | Exploration secrets: treasure, crafting materials, Kurei discoveries, and lore fragments |

## Phase 6 — Educational Gameplay and Assessment

| Requirement ID | Approved statement |
| --- | --- |
| GDD-058 | Primary learner audience: senior high school students |
| GDD-059 | Fantasy decisions connected to transferable real-life reasoning and values |
| GDD-060 | Competency-based assessment across approved skills |
| GDD-061 | Random selection from manually authored, reviewed question banks |
| GDD-062 | Embedded main-story learning challenges plus optional educational activities |
| GDD-063 | At least one required educational activity per playable story chapter |
| GDD-064 | Varied assessment formats: multiple choice, scenarios, sequencing, interactive logic |
| GDD-065 | Optional combat questions reward correct answers; no direct wrong-answer penalty |
| GDD-066 | Progressively disclosed hints |
| GDD-067 | Context-sensitive wrong-answer handling; record initial assessed response and allow learning feedback/retry |
| GDD-068 | Immediate instructional explanations and end-of-activity summaries |
| GDD-069 | Completion rather than passing score gates required story activities |
| GDD-070 | Fixed chapter challenge progression with adaptive assistance/hints |
| GDD-071 | Track scores, first-attempt correctness, attempts, completed activities, competency progress |
| GDD-072 | Persistent learning journal plus local CSV and printable report export |

## Phase 7 — Art, Animation, Sound and UX

| Requirement ID | Approved statement |
| --- | --- |
| GDD-073 | 32×32-inspired pixel art |
| GDD-074 | Three-quarter top-down overworld perspective |
| GDD-075 | Mystical fantasy palette and atmosphere |
| GDD-076 | Distinct spirit-dimension lighting, particles, and environmental transformations |
| GDD-077 | Story-driven time-of-day changes, not a continuously simulated cycle |
| GDD-078 | Four-direction primary animation sets with optional diagonal enhancements for 8-direction motion |
| GDD-079 | Enhanced idle, walk, attack, cast, hurt, defend, dodge, interaction, and special techniques as applicable |
| GDD-080 | Enhanced side-view battles with movement and visual effects |
| GDD-081 | Distinct elemental particles, trails, lighting, impacts, and status visual feedback |
| GDD-082 | Dynamic camera with smooth follow, bounded zoom, subtle shake, scripted movements |
| GDD-083 | Hybrid retro/atmospheric fantasy soundtrack |
| GDD-084 | Contextual music for settlement, wilderness, combat, boss, and spirit scenes |
| GDD-085 | Distinct audio feedback for elements, damage, critical hits, statuses, warnings and UI |
| GDD-086 | Nonverbal character reactions and dialogue sounds instead of full voice acting |
| GDD-087 | Separate Master, Music, and SFX volume controls |
| GDD-088 | Hybrid retro RPG presentation with modern readable panels and tooltips |
| GDD-089 | Combat menu: Attack, Kurei (six-spell grid), Defend, Item |
| GDD-090 | Expressive portraits and choice-driven NPC dialogue |
| GDD-091 | Tabbed character, equipment, inventory, quest, Kurei, and learning journal screens |
| GDD-092 | Configurable keyboard/mouse inputs, scalable UI, readable fonts, reduced-motion options |

## Phase 8 — Godot Technology and Deployment

| Requirement ID | Approved statement |
| --- | --- |
| GDD-093 | Standardize on Godot 4.7.2 Stable |
| GDD-094 | Use GDScript |
| GDD-095 | Use Compatibility rendering for Windows and Web |
| GDD-096 | Modular hybrid design: reusable scenes, domain components, limited Autoload services, signals |
| GDD-097 | Hybrid data definitions using Godot Resources and external JSON where appropriate |
| GDD-098 | Three independent profiles with autosave |
| GDD-099 | Event-based autosave with separate expedition-state handling |
| GDD-100 | Versioned JSON for save data |
| GDD-101 | Suspend and resume active expeditions without counting as extraction |
| GDD-102 | Browser-local saves with export/import backups |
| GDD-103 | 960×540 logical resolution |
| GDD-104 | Target 60 FPS with documented 30 FPS fallback |
| GDD-105 | Deterministic seeded and validated dungeon generation |
| GDD-106 | Quality profiles and selective effects/resource optimization |
| GDD-107 | Single-threaded web export |
| GDD-108 | GitHub feature branches and peer review |
| GDD-109 | Manual playtesting and automated validation |
| GDD-110 | Portable Windows ZIP plus hosted web build |
| GDD-111 | Publish web version on itch.io |
| GDD-112 | Export educational CSV plus printable report |

## Phase 9 — Management and Acceptance

| Requirement ID | Approved statement |
| --- | --- |
| GDD-113 | Three fully playable story stages for academic MVP |
| GDD-114 | Implement approved core RPG systems with limited initial content quantities |
| GDD-115 | One complete repeatable dungeon for academic MVP |
| GDD-116 | Two final story endings deferred until full five-chapter release |
| GDD-117 | Milestone-based requirement prioritization |
| GDD-118 | 13-week academic development schedule |
| GDD-119 | Vertical-slice-first execution |
| GDD-120 | Feature ownership between two developers |
| GDD-121 | Twice-weekly integration/review rhythm |
| GDD-122 | Formal change-control policy |
| GDD-123 | Windows configurations plus Chromium and Firefox formal acceptance tests |
| GDD-124 | Documented feature acceptance criteria and test evidence |
| GDD-125 | Critical/High/Medium/Low defect classification |
| GDD-126 | Structured external gameplay playtesting |
| GDD-127 | Qualified educator review and learner evaluation |
| GDD-128 | Comprehensive GDD, SRS, architecture, data, test, user, asset, maintenance documentation |
| GDD-129 | Requirements-to-code-and-tests traceability matrix |
| GDD-130 | Guided demo plus evaluator free exploration |
| GDD-131 | GitHub repository/tagged release, source archive, builds, docs, asset attribution |
| GDD-132 | Formal multi-area release acceptance checklist |

## 12.1 Implementation-level functional requirements

| ID | Required behavior | Acceptance criterion |
| --- | --- | --- |
| FR-CMB-001 | Initialize a deterministic battle state from a valid encounter and participant definitions. | Combat start produces one valid instance; duplicate contact cannot spawn two parallel battles. |
| FR-CMB-002 | Determine initiative according to the ratified Speed/round rule. | Known Speed inputs yield documented turn ordering. |
| FR-CMB-003 | Validate one main action and its SP, cooldown, item and target prerequisites. | Invalid actions produce no resource spend or progression. |
| FR-CMB-004 | Apply effects, statuses and end-state resolution atomically. | Results are consistent after finalization; no duplicate combat rewards. |
| FR-CMB-005 | Support enemy inspection and telegraph feedback. | Accessible indicators reflect upcoming known intentions. |
| FR-PRG-001 | Award and save permanent character EXP and level-based unlocks under approved rules. | Level cap and persistence tests pass. |
| FR-ITM-001 | Maintain inventory, equipment slot rules, capacity and secured/unbanked ownership. | Defeat loses only approved unbanked assets. |
| FR-ITM-002 | Allow deterministic refinement and crafting once costs are authored. | Invalid upgrades never consume resources; successful upgrade persists. |
| FR-WLD-001 | Load connected regional scenes and keep a valid spawn position. | Transition preserves player/world state and collision. |
| FR-WLD-002 | Shift dimensions only when unlocked and position-safe. | Visible interactions change and player is not embedded in obstacles. |
| FR-QST-001 | Track quests, prerequisite states, branches, reputation changes and journal markers. | Save/reload retains the exact selected quest outcomes. |
| FR-DNG-001 | Generate a seeded, valid connected dungeon with extraction path. | Reproduced seed/version yields valid layout and reachable endpoint. |
| FR-DNG-002 | Suspend and resume active runs preserving at-risk loot and temporary effects. | Suspension does not secure loot or duplicate events. |
| FR-DNG-003 | Atomically process extraction or defeat. | Eligible rewards persist only once on extraction; unbanked loot lost on defeat. |
| FR-EDU-001 | Select validated questions mapped to competency and chapter. | No unreviewed/generated-on-the-fly assessed question is presented. |
| FR-EDU-002 | Record first attempts, feedback, retries and completion separately. | Test reports preserve initial response even after retries. |
| FR-EDU-003 | Unlock progress on activity completion without a passing score threshold. | Incorrect responses plus required feedback can still complete the chapter activity. |
| FR-EDU-004 | Export competency records to local CSV and printable report. | Reports match journal results and work on Windows and web. |
| FR-SAV-001 | Manage three isolated schema-versioned profiles and safe autosave. | Profile A operations never change Profile B or C. |
| FR-SAV-002 | Validate and import/export web profile backups. | Invalid files fail safely; good backup roundtrips. |
| FR-SET-001 | Persist master/music/SFX audio settings, remapped inputs, UI scale, reduced-motion. | Settings survive restart and apply consistently. |
| FR-REL-001 | Produce verified portable Windows and hosted web builds. | Both platform smoke suites pass on documented reference setups. |

# 13. Nonfunctional Requirements and Quality Attributes

| ID | Category | Requirement |
| --- | --- | --- |
| NFR-PERF-001 | Performance | Target 60 FPS and document 30 FPS fallback for specified reference hardware and scenes; test cases must record test environment. |
| NFR-PORT-001 | Portability | Windows and Web versions share gameplay content and save semantics, subject to platform-specific file delivery. |
| NFR-REL-001 | Reliability | No loss of permanent progress after routine crashes, interrupted save handling, or failed imports in tested scenarios. |
| NFR-SEC-001 | Data validation | Treat imported profile backups, educational JSON, and external resources as untrusted; reject malformed paths/data. |
| NFR-ACC-001 | Accessibility | Readable UI, configurable keys, scalable interface, reduced motion, noncolor-only feedback for elements/statuses. |
| NFR-EDU-001 | Educational validity | Reviewed questions mapped to a competency, with explanation and reliable first-attempt measurement. |
| NFR-MAINT-001 | Maintainability | Stable resource IDs, typed GDScript, isolated modules, traceability, documented public interfaces and tests. |
| NFR-LIC-001 | Asset provenance | Generated/third-party assets have source, generator, usage rights and reviewer approval captured in register. |
| NFR-BUILD-001 | Reproducibility | Release tied to Git tag, Godot version, export configuration and asset manifest. |
| NFR-WEB-001 | Web compatibility | Single-threaded Compatibility HTML5 runs in Chromium/Firefox under documented host restrictions. |

# 14. Verification, Testing and Traceability

## 14.1 Testing layers

Use unit tests for formulas and invariants, integration tests for saves/quests/dungeons, Godot headless import and scene checks, manual playtests for visual/usability behavior, Windows/Web smoke tests, outside-player feedback and educator review. Each requirement must reference at least one test or explicit verification method before release.

## 14.2 Priority acceptance test catalog

| Test ID | Core verification |
| --- | --- |
| TC-CMB-001 | Initiative and exactly one Ren main action |
| TC-CMB-002 | SP/cooldown invalid action rollback |
| TC-CMB-003 | Status expiry and enemy telegraph visibility |
| TC-PRG-001 | Level cap at 30 and load/save roundtrip |
| TC-INV-001 | Six equipment slots and capacity boundary |
| TC-INV-002 | Refine/craft transaction integrity |
| TC-WLD-001 | Map transitions, unlocked waypoint gating |
| TC-DIM-001 | Shift eligibility and position safety |
| TC-QST-001 | Branch quest choices survive reload |
| TC-DNG-001 | Seeded room connectivity and extraction reachability |
| TC-DNG-002 | Suspend-resume preserves unbanked state |
| TC-DNG-003 | Defeat discards unsecured loot but preserves permanent data |
| TC-DNG-004 | Successful extraction commits rewards exactly once |
| TC-EDU-001 | Reviewed item selection and chapter learning activity |
| TC-EDU-002 | First-attempt score and retry records |
| TC-EDU-003 | Progress without passing score |
| TC-EDU-004 | CSV and printable report correctness |
| TC-SAV-001 | Profile isolation and backup recovery |
| TC-SAV-002 | Malformed imported save does not corrupt active profile |
| TC-WEB-001 | Chromium browser smoke test |
| TC-WEB-002 | Firefox browser smoke test |
| TC-WIN-001 | Windows portable build startup / save / shutdown |
| TC-ACC-001 | Reduced motion, input rebinding, scalable text |
| TC-REL-001 | Release gate and defect blocker check |
| TC-AGY-001 | Codex plan -> agy execution -> review queue -> Codex CLI review audit trail |
| TC-MCP-001 | Godot tool integration proof in disposable test project |

## 14.3 Traceability matrix schema

Required traceability columns: Requirement ID, description, milestone/scope, priority, planned scene/script/data owner, corresponding issue/PR, tests, evidence link, implementation status, review status, and last approval date. Never mark requirement accepted solely because an agent generated code.

| Requirement | Implementation target (proposed) | Tests | Status |
| --- | --- | --- | --- |
| GDD-018 / FR-CMB-003 | BattleController / action validator | TC-CMB-001, TC-CMB-002 | Planned |
| GDD-037 / FR-DNG-003 | ExpeditionController + SaveManager | TC-DNG-003, TC-DNG-004 | Planned |
| GDD-061 / FR-EDU-001 | QuestionBank + AssessmentController | TC-EDU-001 | Planned |
| GDD-099 / FR-SAV-001 | SaveManager | TC-SAV-001, TC-SAV-002 | Planned |
| GDD-120 / AI policy | docs/agent-review-queue.md / PR logs | TC-AGY-001 | Planned |

## 14.4 Severity and release decisions

| Severity | Example | Gate |
| --- | --- | --- |
| Critical | Crash, unrecoverable save damage, impossible chapter completion | Must resolve before release |
| High | Broken major feature, severe exploit, failed required assessment | Release blocking when applicable |
| Medium | Recoverable mechanic/UI defect | Document, prioritize and seek acceptance |
| Low | Cosmetic issue or minor presentation fault | May defer with recorded approval |

# 15. Academic Scope, Milestones and Schedule

## 15.1 MVP versus full release

| Topic | Academic MVP | Full release |
| --- | --- | --- |
| Story | Chapters I–III, coherent academic-build completion | All five chapters and two endings |
| Combat | Complete core framework, controlled enemies/spells | Broader enemy, skill and boss content |
| Dungeon | One complete modular repeatable dungeon with extraction | Additional region-specific dungeons and challenge modes |
| Education | One required activity per playable chapter | Five chapter activities and optional banks |
| Progression | Core leveling, Kurei, gear and inventory systems | Complete content variety and progression tuning |
| Platform | Windows and itch.io web builds | Same targets with wider optimization and polish |

## 15.2 Thirteen-week plan

| Week | Development objective | Evidence/deliverable |
| --- | --- | --- |
| 1 | Project creation, baseline, Git workflow, art rules | M1: repository and minimal Godot project |
| 2–3 | Overworld controller, scene transitions, simple combat, save model | Integrated foundation |
| 4–5 | One-region vertical slice with quest, education, battle, save | M2: full loop demonstrated |
| 6–8 | Progression, inventory, Kurei, dimension, dungeon, extraction | M3: systems and tests |
| 9–10 | Finish three chapters, education, UX, audio, reporting | M4: academic content candidate |
| 11 | External player and learner tests, educator review, regression | M5: QA evidence |
| 12 | Compatibility, performance, fixes, documentation, release | M6: release candidate |
| 13 | Guided demo, free exploration, defense, submission | Academic handoff |

## 15.3 Team responsibilities

Two developers use task-level feature ownership and review each other's work. Hold two integration sessions weekly. Work on feature branches, require pull requests with test evidence, and keep main playable. Codex planning and agy execution augment rather than replace human academic accountability.

## 15.4 Scope and change control

Any change request records: requesting party, rationale, impacted GDD/FR IDs, scope/milestone, cost and educational impact, alternative, approval decision, and version bump. Prioritize P0 critical, P1 academic MVP, P2 full-release, P3 optional expansion. Freeze MVP requirements after vertical-slice approval unless a change is needed for acceptance or risk mitigation.

# 16. Risk Register and Open Decisions

| Risk | Impact | Mitigation / gate |
| --- | --- | --- |
| Unity-specific MCP invoked in Godot | Agent integration failure / corrupted Godot scene assumptions | Prove Godot-compatible adapter before depending on it; fallback to native tools and headless tests |
| Codex CLI credits exhausted | Unreviewed code backlog | agy continues isolated scoped tasks; queue REVIEW_PENDING_CODEX; no false review or ungated release |
| Image-generation functionality unavailable to Codex | Visual assets blocked | Codex owns image pipeline; log blocker rather than delegate to Gemini |
| Gemini Flash cannot produce required audio binary | Unfinished soundtrack/SFX | Produce non-image specifications only and track binary asset as blocked; request approval for feasible path |
| High art/animation workload | Academic schedule slips | Vertical slice and controlled initial sprite/animation counts |
| Web Compatibility effects performance | Low framerate or browser startup failure | Common Compatibility renderer, quality profiles, browser smoke tests |
| Save state duplication/loss | Loss of permanent XP and secured items | Versioned schema, atomic saves, staged extraction, recovery tests |
| Procedural dead ends | Unplayable dungeon seed | Connectivity/puzzle path validation and reproducible seeds |
| Educational content validity | Misleading assessment claims | Reviewed bank, first-attempt data, educator and learner evaluation |

## 16.1 Open decision register (no invented numbers)

| Open ID | TBD decision | Resolution owner / gate |
| --- | --- | --- |
| OD-001 | Ren’s forgotten origin, villain, two ending triggers and choice flags | Narrative lead / human approval |
| OD-002 | Speed initiative rule: ordering vs extra turns | Combat design review |
| OD-003 | Full elemental counter chart, damage formulas, SP costs and cooldown lengths | Combat balancing review |
| OD-004 | Status timing/stacking, boss resistances | Combat balancing review |
| OD-005 | EXP curve, base stats, leveling point budgets | Progression design review |
| OD-006 | Refinement cap, item rarity roll distributions, crafting values | Economy balancing review |
| OD-007 | Inventory slot cap, item stacks, coin banking and unbanked earnings | Inventory/roguelite review |
| OD-008 | Persistent EXP awarded during failed expedition | Roguelite review |
| OD-009 | Save boundary for in-progress battle and partial combat turns | Persistence architecture review |
| OD-010 | Quest scripts, factions, reputation thresholds and chapter NPC roster | Narrative/content review |
| OD-011 | Dungeon module inventory, generation rules, difficulty tier data | Dungeon design review |
| OD-012 | Educational question banks, objective scoring rubrics, hint thresholds | Educator/assessment review |
| OD-013 | Reference hardware, build sizes, browser targets and FPS capture method | QA/platform review |
| OD-014 | Specific agy runtime, Codex CLI bridge, and Godot-compatible MCP adapter | Tooling proof-of-concept |
| OD-015 | Image generation mechanism under Codex and Gemini Flash audio modality | Asset-pipeline proof-of-concept |
| OD-016 | Final asset quantities and licensing attribution register | Production planning |

# 17. Final Deliverables and Acceptance

- Playable Windows portable ZIP and a browser-playable itch.io build.
- Tagged GitHub source release plus an archive of the Godot project and export configuration.
- Full GDD/SRS, architecture diagrams, data dictionary, test plan, traceability matrix, user guide and maintenance notes.
- Educational content alignment, assessed learner outputs, educator review and learner evaluation evidence.
- Attribution and license register covering third-party and AI-generated assets.
- Guided gameplay demonstration and free exploration by evaluators.
- Release checklist documenting Windows/Chromium/Firefox smoke tests and all open Critical/High bugs.
- Agent delegation/review audit log; queued reviews explicitly labeled when Codex CLI is unavailable.

## 17.1 Formal acceptance gate

Accept the academic release only if three playable story stages and one complete repeatable dungeon reach their required completion states; all mandatory educational activities can be completed and persist; core combat/progression/loot/saving invariants pass; Windows and targeted browsers start and operate; reports export; accessibility options work as designed; there are no unresolved Critical or applicable High severity bugs; documentation and provenance are present; and the human team signs off. The complete five-chapter story/two endings are not prerequisites for the first academic release.

# 18. Agent Execution Instructions (Authoritative for AGENTS.md)

Codex acts as planner. agy acts as implementation executor. Codex CLI is the mandatory code reviewer when available, with documented deferred review during downtime. Gemini Flash owns every generated non-image asset. Codex exclusively owns generated images. The Unity-MCP project is architectural reference only until a Godot-compatible adapter passes proof of concept. Every implementation task must cite requirement and test IDs, keep main playable, and log pending review and asset provenance. No agent may invent narrative reveals, balance constants, or unsupported Godot tool capabilities as approved facts.

# References and Provenance

1. *BSCS 4 — 2D Game Development: Final Project Proposal, E-Learning-Based 2D Game*, original Soulbound proposal provided by the project team. Some original RPG Maker MZ choices are superseded by the nine approved Godot design phases.
2. Nine interactive Soulbound GDD/SRS requirements phases approved by the project owner, 8 November 2026.
3. Ivan Murzak, *AI Game Developer — Unity SKILLS, MCP* (Unity-MCP), https://github.com/ivanmurzak/unity-mcp — consulted to identify Unity-only integration scope; **not** evidence of Godot compatibility.
4. Godot Engine official documentation: https://docs.godotengine.org/ — version/export assumptions must be validated in the project environment before build sign-off.
