# OD-010 / OD-011 Owner-Approved Narrative & Dungeon Structure Batch — Implementation Report

**Task ID:** SBL-OD-010/011
**Date:** 11 November 2026
**Milestone:** Release Hardening & Scope Boundary Management (owner-approved narrative & dungeon structure batch)
**Branch:** `feature/w4-5-vertical-slice` (worktree `soulbound-overworld`), WIP commit `835a19b` + completion commit `b8ecffb`
**Plan owner:** Codex/OpenCode — scope of record `docs/agy-next-queue.md`; approved values `report/complete-od002-011-proposal.md` Stage C and `report/od002-011-implementation-plan-draft.md` Stage C
**Executor:** agy, staged by `opencode-go/mimo-v2.6-flash` (`835a19b`) and completed by `opencode-go/gemini-4-argon` (`b8ecffb`)
**Codex CLI review:** **not called** (deferred by the task instruction). Review status for every item in this slice: `REVIEW_PENDING_CODEX`.
**Requirements:** GDD-036..048, GDD-061..066, FR-WLD-001, FR-QST-001, FR-DNG-001/003, TC-WLD-001, TC-DNG-001/004, TC-SAV-001

---

## 1. Approved behavior implemented

### OD-010 — Branch-and-reconverge quest structure (`scripts/story/quest_branch_model.gd`, `scripts/persistence/gameplay_profile_validator.gd`)

| Approved rule | Where it lives | How it is enforced |
|---|---|---|
| Academic MVP stays linear across Chapters I–III | `QuestBranchModel` (`MODE_ACADEMIC_MVP` default) + `ChapterManager` (unchanged) | `record_choice()` and `reconverge_at_gate()` return `ERR_UNAVAILABLE` in `MODE_ACADEMIC_MVP`; `configure(MODE_ACADEMIC_MVP)` refuses any model that already carries branch or gate records (`ERR_INVALID_DATA`); `ChapterManager` writes no `world["quest_branches"]` record |
| Full release supports at most one local choice cluster per chapter | `MAX_CLUSTERS_PER_CHAPTER = 1`, `FULL_RELEASE_CHAPTERS = 5` | `record_choice()` accepts one cluster per chapter `1..5`, returns `OK` idempotently on identical `(cluster_id, branch_id)`, and rejects a second cluster in the same chapter with `ERR_ALREADY_EXISTS` |
| Local branches reconverge at the next chapter gate | `reconverge_at_gate(chapter)` | Marks the chapter's cluster `"reconverged": true`, appends `chapter` to `reconverged_chapters`, and freezes that chapter (`record_choice` returns `ERR_UNAVAILABLE`; duplicate gate call returns `ERR_ALREADY_EXISTS`) |
| Reputation/faction systems remain deferred from the academic MVP | `ROOT_KEYS`, `CLUSTER_KEYS`, `GameplayProfileValidator._validate_world` | Strict key whitelist (`["schema", "mode", "clusters", "reconverged_chapters"]` and `["chapter", "cluster_id", "branch_id", "reconverged"]`); any extra field such as `"reputation"` or `"faction"` is rejected with `ERR_INVALID_DATA` in both `QuestBranchModel.validate_record()` and `GameplayProfileValidator.validate()` |
| JSON serialization/deserialization normalization | `QuestBranchModel.serialize()` and `_parse()` | `_parse()` normalizes `rec["chapter"]` from JSON `float` (`1.0`) to `int` (`1`) within safe integer bounds (`MIN_SAFE_INT..MAX_SAFE_INT`) and `serialize()` emits canonical typed records so `serialize -> ProfileStore -> load -> serialize` and backup round-trips are byte-identical |
| No invented lore, dialogue, villain, faction roster, or ending trigger | `QuestBranchModel` stores opaque structural IDs only | Zero narrative strings, NPC definitions, or educational questions were added; `GDD-061..066` question banks and `ChapterManager` flow are untouched |

### OD-011 — Dungeon grammar and mastery markers (`scripts/dungeon/multi_floor_layout.gd`, `scripts/dungeon/dungeon_mastery.gd`, `scripts/persistence/gameplay_profile_validator.gd`)

| Approved rule | Where it lives | How it is enforced |
|---|---|---|
| Academic MVP retains seeded 4-room/default DAG and guaranteed extraction | `scripts/dungeon/dungeon_generator.gd` (unchanged) | Existing generator is untouched; regression-pinned in `od010_011_test.gd` for both 4-room (`generate(1337, 4)`) and 6-room (`generate(1337, 6)`) seeded DAGs |
| Full-release proposal: 3 floors, 6 generated room slots per floor, one entry, >= 1 valid route, one extraction endpoint | `MultiFloorLayout` (`FLOOR_COUNT = 3`, `ROOMS_PER_FLOOR = 6`, `ROOM_TOTAL = 18`) | Deterministic seeded spanning-DAG generation per floor with inter-floor links (`floor_exit -> next_floor_entry`), room ID `0` as `TYPE_SPAWN`, and furthest room on Floor 3 as `TYPE_EXTRACTION` |
| Connected graph & reachable extraction validation | `MultiFloorLayout.validate_layout()` and `find_route()` | Rejects wrong floor/slot counts, duplicate IDs/slots, unapproved room types, asymmetric/self-loop/dangling neighbor edges, disconnected rooms (`_bfs` size != 18), and unreachable extraction (`_route` length < 2) with `ERR_INVALID_DATA` |
| Optional risk rooms only on existing reward-path rooms; no invented drop probabilities | `MultiFloorLayout.validate_layout()` (`ROOM_KEYS`, `LAYOUT_KEYS`) | `"risk": true` is allowed only on `TYPE_NORMAL` or `TYPE_COMBAT` (rejected on `TYPE_SPAWN` and `TYPE_EXTRACTION`); generated layouts default `risk = false`; extra keys like `"drop_rate"` or `"loot_chance"` are rejected |
| Dungeon mastery grants knowledge/access markers only, never uncapped combat power | `DungeonMastery` (`world["dungeon_mastery"]`) | Stores only `{"schema": "sbl-dungeon-mastery/1", "markers": Array[String]}`; idempotent `grant_marker()`; no API touches `CharacterStats`, `KureiTree`, or `InventoryManager`; validator rejects any extra key (e.g. `"power"`, `"attack"`, `"level"`), non-string markers, or duplicates |

---

## 2. Files changed

| File | Change |
|---|---|
| `scripts/story/quest_branch_model.gd` (+ `.uid`) | **New** (`835a19b`) + normalized (`b8ecffb`): OD-010 branch-and-reconverge structural model, academic MVP linearity enforcement, strict validator, safe-int bounds, and `int` normalization across JSON round-trips. |
| `scripts/dungeon/multi_floor_layout.gd` (+ `.uid`) | **New** (`835a19b`) + safe-int bounds (`b8ecffb`): OD-011 3-floor / 6-slot seeded layout generator, BFS connectivity and extraction reachability validator, route finder, and strict schema enforcement. |
| `scripts/dungeon/dungeon_mastery.gd` (+ `.uid`) | **New** (`835a19b`): OD-011 knowledge/access-only mastery marker model and strict schema validator. |
| `scripts/persistence/gameplay_profile_validator.gd` | Validates optional `world["quest_branches"]` via `QuestBranchModel.validate_record` and optional `world["dungeon_mastery"]` via `DungeonMastery.validate_record`. |
| `tests/headless/od010_011_test.gd` (+ `.uid`) | **New** (`835a19b`) + hardened (`b8ecffb`): **244-check** headless suite covering OD-010 academic linearity, local branch/reconverge lifecycle, profile/backup isolation (same-slot, cross-slot mismatch rejection, retargeted slot, and tampered reputation/faction rejection), OD-011 4-room and 6-room MVP DAG preservation, 3-floor/6-slot seeded generation across 72 seeds, 18 invalid-graph rejection cases, and mastery marker isolation/power-field rejection. |
| `docs/*`, `report/*` | Review queue entry, traceability matrix section, testing guide table (35 suites), open-decisions ledger update for OD-010/OD-011, and this report. |

**Unchanged on purpose:** `scripts/dungeon/dungeon_generator.gd`, `scenes/dungeon/dungeon_expedition.gd`, `scripts/story/chapter_manager.gd`, `scenes/vertical_slice/*`, `scripts/education/*`, `scripts/combat/*`, `scripts/progression/*`, `scripts/inventory/*`, `scripts/persistence/profile_store.gd`, `scenes/main/game_root.gd`, `project.godot`, export configuration.

---

## 3. Test evidence (Godot 4.7.2 Stable `ed1daf0bf`, Windows headless, disposable user data)

| Command | Observed result |
|---|---|
| `run_headless_tests.ps1 -Suite od010_011_test` | **Exit 0, PASS (1.02 s)** — new suite, **244 checks / 0 failures**, 0 lines in `report/od010_011_test.err`. |
| Targeted save/transition/dungeon/story suites (`save_model_test`, `web_backup_test`, `save_compatibility_recovery_test`, `profile_activation_test`, `transition_test`, `dungeon_scene_test`, `overworld_gateway_test`, `chapter_progression_test`, `vertical_slice_test`, `vertical_slice_loop_test`, `m3_systems_test`, `progression_economy_test`) | **Exit 0, PASS** — all 12 targeted suites green with zero regressions. |
| `run_headless_tests.ps1` (canonical) | **Exit 0, 35/35 suites PASS** (import clean, `realUserDataUnchanged=True`, `disposableFiles=655`, `rootRemoved=True`). |
| Negative control 1: allow `record_choice()` in `MODE_ACADEMIC_MVP` | **Exit 1, 7 failed checks** (`Academic MVP refuses a local choice cluster at chapter 1..5`, `No branch state was created in academic MVP mode`, `Academic mode is accepted on an empty model`) → guard restored, suite green. |
| Negative control 2: disable duplicate-chapter check in `record_choice()` | **Exit 1, 15 failed checks** (`Exactly one local choice cluster per chapter`, `No duplicate cluster record was appended`, plus downstream persistence/validator checks) → guard restored, suite green. |
| Negative control 3: disable BFS connectivity / extraction reachability check in `MultiFloorLayout.validate_layout()` | **Exit 1, 2 failed checks** (`Disconnected graph rejected`, `Unreachable extraction endpoint rejected (TC-DNG-001)`) → validator restored, suite green. |
| Negative control 4: disable `_exact_keys` check in `DungeonMastery._parse()` | **Exit 1, 1 failed check** (`Combat-power field inside the mastery record rejected`) → validator restored, suite green. |
| `run_headless_tests.ps1 -Export -Tier all` (canonical release gate) | **Exit 0** — 35/35 suites PASS, Web + Windows + Academic MVP exports, `ALL RELEASE ARTIFACTS AND PRESETS VALIDATED SUCCESSFULLY` (including all 3 archive-contained PCK gates), **62/62 manifest controls PASS**, OD-013 performance evidence **5/5 PASS** (headless, 129.0–144.9 avg FPS), isolation proof `realUserDataUnchanged=True`. |
| `test_export_failure_restoration.ps1` | **Exit 0** — injected post-mutation export failure exited 1, restored `project.godot` byte-identically (SHA-256 `5C65BBCD88161A7B0A32C2B018ECDE2018A2EDF807631C8803D002563BD1A14B`), removed `build_tier.txt` and staging root, and left all 6 `dist/` artifacts unchanged. |
| Clean-tree `export_release.ps1 -Tier all` after `b8ecffb` | **Exit 0** — all 3 release packages rebuilt and verified against their receipts on clean commit `b8ecffb`. |

---

## 4. Preserved invariants

- **Academic MVP linearity & separation:** `ChapterManager`, `SliceProgress`, `QuestDialog`, and `GameRoot` remain untouched; academic MVP profiles write no `quest_branches` record and stay strictly linear across Chapters I–III.
- **Academic MVP dungeon preservation:** `DungeonGenerator` and `DungeonExpedition` are untouched; the seeded 4-room and 6-room DAG layouts, suspend/resume (`OD-009`), and extraction/defeat (`OD-008`) invariants pass unmodified.
- **No invented lore, balancing, or probabilities:** no dialogue, NPCs, villain identity, Ren origin, ending triggers, faction rosters, reputation thresholds, educational questions, drop probabilities, or stat bonuses were invented.
- **Previous OD batches preserved:** `OD-009` save boundary (`dungeon_scene_test`), `OD-002/003/004` combat (`initiative_test`, `kurei_combat_test`, `boss_combat_test`, `status_engine_test`), and `OD-005/006/007/008` progression/economy (`progression_economy_test`) all pass unmodified.

---

## 5. Open questions for Codex review

1. **Full-release wiring deferral.** `QuestBranchModel`, `MultiFloorLayout`, and `DungeonMastery` are self-contained structural modules validated by `GameplayProfileValidator` and `od010_011_test.gd`, and are intentionally not wired into the academic MVP play loop in `GameRoot` / `DungeonExpedition`. Confirm that runtime wiring into Chapters IV–V and full-release multi-floor expeditions remains gated on narrative and dungeon content approval.
2. **Risk-room reward multiplier (`TBD`).** `MultiFloorLayout` validates that `"risk": true` can only appear on existing reward-path rooms (`normal` / `combat`) and rejects any invented probability key, while generated layouts default `risk = false`. Confirm that risk-room placement rules and reward-value modifiers remain deferred until approved content tables exist.
3. **Mastery marker unlock catalog (`TBD`).** `DungeonMastery` persists opaque string marker IDs and enforces that no stat/power field can exist in the record. Confirm that the specific marker IDs and the knowledge/access gates they unlock remain deferred to content review.

---

## 6. AGENTS report block

```text
TASK ID: SBL-OD-010/011
REQUIREMENTS: GDD-036..048, GDD-061..066, FR-WLD-001, FR-QST-001, FR-DNG-001/003, TC-WLD-001, TC-DNG-001/004, TC-SAV-001
MILESTONE: Release Hardening & Scope Boundary Management (owner-approved OD-010/011 narrative & dungeon structure batch)
OWNER: agy (staged by opencode-go/mimo-v2.6-flash in 835a19b, completed by opencode-go/gemini-4-argon in b8ecffb)
PLAN OWNER: Codex (docs/agy-next-queue.md; approved values report/complete-od002-011-proposal.md Stage C)
BRANCH/COMMIT: feature/w4-5-vertical-slice — implementation commits 835a19b and b8ecffb (docs committed immediately afterwards in the same batch)
FILES CHANGED: scripts/story/quest_branch_model.gd (new), scripts/story/quest_branch_model.gd.uid (new), scripts/dungeon/multi_floor_layout.gd (new), scripts/dungeon/multi_floor_layout.gd.uid (new), scripts/dungeon/dungeon_mastery.gd (new), scripts/dungeon/dungeon_mastery.gd.uid (new), scripts/persistence/gameplay_profile_validator.gd, tests/headless/od010_011_test.gd (new), tests/headless/od010_011_test.gd.uid (new), docs/agent-review-queue.md, docs/traceability-matrix.md, docs/testing.md, docs/open-decisions-ledger.md, report/od010_011_narrative_dungeon_report.md (new), report/README.md
ASSET PROVENANCE: none
TESTS RUN + RESULTS: targeted od010_011_test (244 checks / 0 failures) and 12 save/transition/dungeon/story suites all exit 0; four negative controls exit 1 (7 / 15 / 2 / 1 failed checks) and were restored; canonical suite 35/35 exit 0 with real user data unchanged; canonical -Export -Tier all gate exit 0 (35/35 suites, artifact validation + 3 PCK gates, 62/62 manifest controls, OD-013 evidence 5/5 PASS); test_export_failure_restoration.ps1 exit 0 (project.godot byte-identical)
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: see section 5 (full-release wiring deferral, risk-room reward multiplier TBD, mastery marker catalog TBD)
```
