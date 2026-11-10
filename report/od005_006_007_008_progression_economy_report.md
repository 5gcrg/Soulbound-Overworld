# OD-005 / OD-006 / OD-007 / OD-008 Owner-Approved Progression & Economy Batch — Implementation Report

**Task ID:** SBL-OD-005/006/007/008
**Date:** 11 November 2026
**Milestone:** Release Hardening & Scope Boundary Management (owner-approved progression/economy batch)
**Branch:** `feature/w4-5-vertical-slice` (worktree `soulbound-overworld`), implementation commit `0c16720`
**Plan owner:** Codex/OpenCode — scope of record `docs/agy-next-queue.md`; approved values `report/complete-od002-011-proposal.md` Stage B and `report/final-plan-specifications.md` Stage 2
**Executor:** agy, executed by `opencode-go/mimo-v2.6-flash` (MiMo)
**Codex CLI review:** **not called** (deferred by the task instruction). Review status for every item in this slice: `REVIEW_PENDING_CODEX`.
**Requirements:** GDD-024, GDD-025, GDD-026, GDD-027, GDD-028, GDD-029, GDD-030, GDD-034, GDD-035, FR-PRG-001/002, FR-INV-001/002, FR-DNG-002, FR-SAV-001, TC-PRG-001, TC-INV-001/002, TC-DNG-003/004, TC-SAV-001

---

## 1. Approved behavior implemented

### OD-005 — Progression (`scripts/progression/character_stats.gd`, `scenes/ui/character_sheet.gd`)

| Approved rule | Where it lives | How it is enforced |
|---|---|---|
| Level cap 30 | `CharacterStats.LEVEL_CAP = 30` | `add_xp()` stops awarding XP and level-ups at 30; the level-up loop is guarded by `level < LEVEL_CAP` |
| XP to next level = 100 x current level | `get_xp_for_next_level()` (`BASE_XP_PER_LEVEL = 100`) | unchanged formula, now asserted at levels 1/2/15/29/30 and pinned by the cap test (43500 XP = level 1 → 30 exactly) |
| Level-up reward = 2 attribute points | `POINTS_PER_LEVEL = 2` | each level-up adds exactly 2 `unspent_points`; 29 level-ups yield exactly 58 points |
| +1 per allocation to Vitality/Resonance/Agility/Focus | `allocate_point()` | +1 to the single selected attribute only; unknown attributes and zero-point allocations are rejected with no mutation |
| Kurei talent points = max(0, level − 1) | `KureiTree.sync_with_level()` (existing rule, now regression-pinned) | level 1 → 0, level 30 → 29, level 0 → 0 (never negative) |
| No negative XP / no level loss | `add_xp()` rejects `amount <= 0`; `deserialize()` clamps `level` into `[1, 30]` and `xp >= 0` | negative-XP probes and tampered-save probes (level 999 → 30, level 0 → 1, xp −50 → 0) |
| Capability/access preferred over raw inflation | leveling grants only the approved attribute points; no automatic stat growth was added anywhere | cap probes assert zero extra levels/points from further XP |
| Cap display | `CharacterSheet.refresh()` shows `XP: Max Level 30 (Cap)` instead of an unreachable threshold | — |

**Load/save roundtrip (TC-PRG-001):** a capped character saves and reloads with level 30, XP and all 58 points intact; `GameplayProfileValidator` rejects a backup with `level = 31` and accepts `level = 30`.

### OD-006 — Gear tiers and deterministic refinement (`scripts/inventory/inventory_manager.gd`)

| Approved rule | Where it lives | How it is enforced |
|---|---|---|
| Five tiers: Common, Uncommon, Rare, Epic, Legendary | `TIER_NAMES`, `TIER_COMMON..TIER_LEGENDARY` (indices 0..4) | exact name/order assertions; `get_item_tier()` defaults unlisted items to Common |
| No random affix rolls in the academic MVP | the inventory scripts contain no RNG entry points | negative control scans `inventory_manager.gd` and `inventory_sheet.gd` for `randi`/`randf`/`randfn`/`randomize`/`RandomNumberGenerator`/`pick_random`/`rand_weighted` — zero hits |
| Refinement is deterministic | `refine_item()` | two separate instances with identical inputs produce byte-identical results and state; no RNG exists to diverge |
| Refinement cannot destroy the item | `refine_item()` is all-or-nothing | after every failed refinement the serialized inventory is byte-identical and the item count is unchanged |
| Refinement cost = base_item_cost x next_tier_index | `static refinement_cost(base, tier)` returns `base x (tier + 1)` | asserted for every tier step (100/200/300/400) plus `-1` refusals at Legendary, non-positive base, and negative tier |
| Use the existing authored item cost table; invent nothing | `base_item_cost_table` (the designated content table) **ships empty** | `refine_item()` on an item without an authored cost returns `ERR_DOES_NOT_EXIST / "cost_not_authored"` and mutates nothing — FR-ITM-002's "once costs are authored" gate |
| Character owns capabilities, gear owns specialization/magnitude | refining changes only `item_tiers[item_id]`; it never touches `CharacterStats` | success assertions check tier/coins/item only |

Refund of a failed transaction: insufficient banked Spirit Coins (`ERR_UNAVAILABLE / "insufficient_coins"`), unbanked item (`ERR_INVALID_PARAMETER`), tier cap (`ERR_PARAMETER_RANGE_ERROR / "tier_cap"`) — each proven zero-mutation by before/after `serialize()` snapshots. Tiers, `banked_coins` and `satchel_coins` roundtrip through `serialize()`/`deserialize()`; legacy profiles without the new keys load with Common/0 defaults; malformed tier indices and negative coins are rejected atomically (prior state untouched).

### OD-007 — Inventory capacity, stacks and currency (`scripts/inventory/inventory_manager.gd`, `scenes/ui/inventory_sheet.gd`)

| Approved rule | Where it lives | How it is enforced |
|---|---|---|
| 20 inventory slots, no expansion in the MVP | `MAX_INVENTORY_SLOTS = 20` — one shared budget of distinct item stacks across bank + satchel | 20 distinct stacks accepted, the 21st refused in **both** containers with zero mutation; `inventory_slot_count()` reported in the inventory sheet |
| Max stack 99 for stackable consumables/materials | `MAX_STACK_SIZE = 99` — counted per item type across bank + satchel | 99 accepted / 100th refused; split stacks (60 bank + 40 satchel) refused, 60 + 39 accepted |
| Equipped/banked gear secured; satchel at risk until extraction | `banked_items` / `equipment` vs. `satchel_items` (existing split, now asserted with currency) | defeat wipes only the satchel; bank and equipment survive |
| Banked Spirit Coins secured; satchel currency follows the satchel-loss policy | `banked_coins` / `satchel_coins` | defeat zeroes `satchel_coins` and keeps `banked_coins`; extraction moves satchel coins into the bank exactly once; suspend snapshots carry `satchel_coins` so suspension never secures or drops it |
| No tokens/PvP/monetization/trading | none exists; nothing added | scope statement only — no new economy surface was introduced |

**Why the shared model:** bank and satchel are two ownership states of one inventory, so an extraction *move* can never add a slot or overflow a stack. `extract_satchel_to_bank()` therefore transfers unconditionally (move semantics, never destroys loot), while every *acquisition* (`add_banked_item` / `add_satchel_item`) is all-or-nothing at both boundaries. `equip_item()` was made transactional: the previously equipped item is returned only if it fits, and the swap rolls back by direct restore, so no equip/unequip path can destroy an item.

**UI:** the inventory sheet now shows `[Slots N/20 | Coins X secured]`, `[At risk until extraction | Coins Y]`, and each item's `[Tier]`.

### OD-008 — Defeat, extraction and retry (`scenes/dungeon/dungeon_expedition.gd`, `scenes/main/game_root.gd`)

| Approved rule | Where it lives | How it is enforced |
|---|---|---|
| Defeat loses all unbanked satchel | `InventoryManager.handle_expedition_defeat()` | items **and** currency cleared; returned loss payload asserted |
| Defeat preserves banked/equipped/level/skills/story/education | `GameRoot._commit_defeat()` writes only the inventory section | post-defeat profile compared byte-for-byte against the pre-run profile for `character` (level 7, XP 350, attributes, Kurei tree incl. `solar_flare`), `world` (chapter progress) and `education` (record) |
| No consolation EXP or currency | defeat never touches `character` or `banked_coins` | XP/level/coin assertions after defeat; `handle_expedition_defeat()` only removes |
| Extraction transfers exactly once and clears the persisted snapshot | `GameRoot._commit_extraction()` banks + clears `world.active_expedition` in one atomic profile write | banked total and coins asserted after commit; a stale callback returns `ERR_UNAUTHORIZED` and leaves the profile byte-identical |
| Failed persistence leaves the run open for retry | `DungeonExpedition.extract_now()` / `fail_now()` reset the in-flight flag and mutate nothing on error | injected `ERR_FILE_CANT_WRITE` → run still active, satchel + 40 coins preserved, disk unchanged; the retry then commits the full transfer exactly once |
| Suspend ≠ extraction (OD-009, preserved) | suspend writes only the snapshot; bank untouched | suspension at 290 banked coins leaves them at 290 and stores 15 at-risk coins in the snapshot; resume restores them; the resumed defeat then loses only those 15 |

**Snapshot hardening:** `serialize_expedition()`/`restore_expedition()` now carry `satchel_coins`, and both the scene and `GameplayProfileValidator._validate_active_expedition()` enforce the OD-007 boundaries on untrusted snapshots (stacks 1..99, at most 20 distinct stacks, non-negative currency). Legacy snapshots without the key still resume with currency 0.

---

## 2. Files changed

| File | Change |
|---|---|
| `scripts/progression/character_stats.gd` | OD-005: `LEVEL_CAP`, cap-guarded `add_xp()`, `is_at_level_cap()`, load clamp `[1, 30]`, requirement/decision docs. |
| `scripts/inventory/inventory_manager.gd` | OD-006/007/008: 20-slot shared capacity, 99-unit stacks (all-or-nothing), `banked_coins`/`satchel_coins`, tier map + `refinement_cost()` + `refine_item()`, transactional `equip_item()`, move-semantics extraction, defeat currency loss, extended serialize/deserialize. |
| `scenes/dungeon/dungeon_expedition.gd` | snapshot carries `satchel_coins`; restore validates OD-007 stack/slot/currency boundaries before applying; docs. |
| `scenes/main/game_root.gd` | `get_save_blocker()` also defers to the expedition-state path when at-risk satchel currency is present (OD-009 boundary preserved). |
| `scripts/persistence/gameplay_profile_validator.gd` | level bound 1..30 (TC-PRG-001); optional `banked_coins`/`satchel_coins`/`tiers` validation; active-expedition snapshot stack/slot/currency bounds. |
| `scenes/ui/character_sheet.gd` | cap-aware XP readout. |
| `scenes/ui/inventory_sheet.gd` | slot usage, Spirit Coins and per-item tier display. |
| `tests/headless/progression_economy_test.gd` (+ `.uid`) | **New** 201-check suite covering OD-005..008 acceptance (TC-PRG-001, TC-INV-001/002, TC-DNG-003/004, TC-SAV-001). |
| `docs/*`, `report/*` | evidence, traceability, testing guide, ledger rows (docs commit). |

**Unchanged on purpose:** `scripts/combat/*`, both combat scenes, `scripts/magic/*` (OD-002/003/004 behavior and all authored pip costs/cooldowns/base powers), `scripts/persistence/profile_store.gd` (OD-009 writer contract, no schema bump), dungeon generator, story/education code, `project.godot`, export configuration.

---

## 3. Test evidence (Godot 4.7.2 Stable `ed1daf0bf`, Windows headless, disposable user data)

| Command | Observed result |
|---|---|
| `run_headless_tests.ps1 -Suite progression_economy_test` | **Exit 0, PASS (2.03 s)** — new suite, **201 checks / 0 failures**. |
| `... -Suite m3_systems_test` / `dungeon_scene_test` / `ui_sheets_test` / `save_model_test` | **Exit 0, PASS** — progression, inventory, dungeon and save baselines green with the new rules. |
| `... -Suite web_backup_test` / `save_compatibility_recovery_test` / `profile_activation_test` / `overworld_gateway_test` | **Exit 0, PASS** — legacy profiles, snapshots, activation and gateway bank/defeat flows unchanged. |
| `run_headless_tests.ps1` (canonical) | **Exit 0, 34/34 suites PASS** (import clean, `realUserDataUnchanged=True`, `disposableFiles=654`, `rootRemoved=True`). |
| Negative control 1: level-cap guard removed in `add_xp()` | **Exit 1, 4 failed checks** (`No level gained once at the cap`, `Cap absorbs further XP…`, `Negative XP at the cap…`, `TC-PRG-001 roundtrip…`) → guard restored, suite green. |
| Negative control 2: refinement cost flattened to `base x 1` | **Exit 1, 4 failed checks** (`Uncommon -> Rare costs base x 2`, `Rare -> Epic…`, `Epic -> Legendary…`, `Second refinement costs base x 2…`) → formula restored, suite green. |
| Negative control 3: `MAX_INVENTORY_SLOTS` 20 → 21 | **Exit 1, 5 failed checks** (capacity constant, 20-slot fill, 21st-stack refusal, shared-budget refusal) → constant restored, suite green. |
| Negative control 4: defeat no longer clears the satchel | **Exit 1, 2 failed checks** (`Defeat loses ALL unbanked satchel items and currency`, `…lost on defeat (OD-008)`) → policy restored, suite green. |
| `run_headless_tests.ps1 -Export -Tier all` (canonical release gate) | **Exit 0** — 34/34 suites, Web + Windows + Academic MVP exports, `ALL RELEASE ARTIFACTS AND PRESETS VALIDATED SUCCESSFULLY`, **62/62 manifest controls**, OD-013 performance evidence **5/5 PASS** (headless, 128–145 avg FPS), isolation proof `realUserDataUnchanged=True`. |
| `test_export_failure_restoration.ps1` | **Exit 0** — injected post-mutation export failure restored `project.godot` byte-identically (SHA-256 `5C65BBCD…`), removed the staging root and left all 6 dist artifacts unchanged. |

Raw transcripts: `report/progression_economy_test.log`, `report/dungeon_scene_test.log`, `report/m3_systems_test.log`, `report/ui_sheets_test.log`, `report/save_model_test.log`, `report/web_backup_test.log`, plus the gitignored negative-control runs recorded in this report's control table.

The OD-013 evidence files regenerated during the `-Export` gate were restored to their committed content so this batch's diff contains only batch-relevant evidence; the gate's PASS result is recorded above.

---

## 4. Preserved invariants

- **OD-009 save boundary:** no change to `ProfileStore`, the OD-009 writer contract, or the boundary gate shape; the only `get_save_blocker()` addition is the parallel at-risk-currency condition. `dungeon_scene_test` (59 OD-009 checks), `save_model_test`, `save_compatibility_recovery_test`, `web_backup_test` pass unmodified.
- **OD-002/003/004 combat:** combat scripts/scenes untouched; `initiative_test`, `kurei_combat_test`, `boss_combat_test`, `status_engine_test` green.
- **Extraction/defeat:** no schema bump, no change to the atomic commit structure; existing exact-once, retry and suspend ≠ extraction suites pass unmodified.
- **Authored content:** no numerical gameplay value was invented. The only numbers authored are the owner-approved OD-005..008 constants (cap 30, 100 XP/level, 2 points, 20 slots, 99 stack, five tier names) and the `base_item_cost x next_tier_index` formula; `base_item_cost_table` ships empty and all coin/XP figures in tests are explicitly test-fixture data.
- **Scope:** only OD-005..008 ledger rows are updated; OD-001, OD-009..OD-017 keep their existing status. No story, image, audio, browser, PvP, monetization, trading or new OD decision was added.

---

## 5. Open questions for Codex review

1. **Shared bank+satchel slot/stack budget.** The approved rules say "20 inventory slots" and "max stack 99" without naming a container; this slice treats bank and satchel as one inventory split by ownership (the only model where an extraction move can never overflow or lose loot). Confirm the interpretation.
2. **XP behavior at the cap.** Once level 30 is reached, incoming XP is ignored (no unbounded XP counter, no further levels). Leftover XP from the final level-up is retained. Confirm.
3. **Authored cost table location.** `InventoryManager.base_item_cost_table` is an instance dictionary that ships empty; refinement is therefore inert until content authors costs (FR-ITM-002). Confirm where the authored table should live (instance vs. shared content resource) when content lands.
4. **Boundary denial.** When the 20-slot budget is full, a new distinct item (e.g. a boss reward) is refused rather than queued; there is no discard/sell sink yet because merchant tables remain blocked. Confirm the refusal is acceptable until an economy sink is authored.
5. **Validator level cap.** `GameplayProfileValidator` now rejects backups with `level > 30` at the import/activation boundary (and `CharacterStats.deserialize` clamps on direct load). Confirm rejection-versus-clamp at the backup boundary.
6. **Stack ceiling applied uniformly.** Because no per-item stackability table exists, the 99-unit ceiling is enforced for every item type (gear included). Confirm until an authored stackability table exists.

---

## 6. AGENTS report block

```text
TASK ID: SBL-OD-005/006/007/008
REQUIREMENTS: GDD-024, GDD-025, GDD-026, GDD-027, GDD-028, GDD-029, GDD-030, GDD-034, GDD-035, FR-PRG-001/002, FR-INV-001/002, FR-DNG-002, FR-SAV-001, TC-PRG-001, TC-INV-001/002, TC-DNG-003/004, TC-SAV-001
MILESTONE: Release Hardening & Scope Boundary Management (owner-approved OD-005/006/007/008 progression & economy batch)
OWNER: agy (executed by opencode-go/mimo-v2.6-flash under the owner-approved plan)
PLAN OWNER: Codex (docs/agy-next-queue.md; approved values report/complete-od002-011-proposal.md Stage B, report/final-plan-specifications.md Stage 2)
BRANCH/COMMIT: feature/w4-5-vertical-slice — implementation commit 0c16720 (docs committed immediately afterwards in the same batch)
FILES CHANGED: scripts/progression/character_stats.gd, scripts/inventory/inventory_manager.gd, scenes/dungeon/dungeon_expedition.gd, scenes/main/game_root.gd, scripts/persistence/gameplay_profile_validator.gd, scenes/ui/character_sheet.gd, scenes/ui/inventory_sheet.gd, tests/headless/progression_economy_test.gd (new), tests/headless/progression_economy_test.gd.uid (new), docs/agent-review-queue.md, docs/traceability-matrix.md, docs/testing.md, docs/open-decisions-ledger.md, docs/agy-next-queue.md, report/od005_006_007_008_progression_economy_report.md, report/README.md
ASSET PROVENANCE: none
TESTS RUN + RESULTS: targeted progression_economy_test (201 checks), m3_systems_test, dungeon_scene_test, ui_sheets_test, save_model_test, web_backup_test, save_compatibility_recovery_test, profile_activation_test, overworld_gateway_test all exit 0; four negative controls exit 1 (4 / 4 / 5 / 2 failed checks) and were restored; canonical suite 34/34 exit 0 with real user data unchanged; canonical -Export gate exit 0 (34/34 suites, artifact validation, 62/62 manifest controls, OD-013 evidence 5/5); test_export_failure_restoration.ps1 exit 0 (project.godot byte-identical)
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: see section 5 (shared slot/stack budget, cap XP behavior, authored cost table location, boundary denial, validator clamp-vs-reject, uniform stack ceiling)
```
