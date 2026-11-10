# OD-002 / OD-003 / OD-004 Owner-Approved Combat Batch — Implementation Report

**Task ID:** SBL-OD-002/003/004
**Date:** 10 November 2026
**Milestone:** Release Hardening & Scope Boundary Management (owner-approved combat batch)
**Branch:** `feature/w4-5-vertical-slice` (worktree `soulbound-overworld`), implementation commit `494c412`
**Plan owner:** Codex/OpenCode — scope of record `docs/agy-next-queue.md`; approved values `report/complete-od002-011-proposal.md` Stage A
**Executor:** agy, executed by `opencode-go/mimo-v2.6-flash` (MiMo)
**Codex CLI review:** **not called** (deferred by the task instruction). Review status for every item in this slice: `REVIEW_PENDING_CODEX`.
**Requirements:** GDD-016, GDD-017, GDD-018, GDD-019, GDD-020, GDD-021, GDD-022, GDD-023, GDD-030, GDD-089, FR-CMB-001/002/003/004, FR-MAG-001/002, TC-CMB-001/002/003, TC-SAV-001

---

## 1. Approved behavior implemented

### OD-002 — Initiative

| Approved rule | Where it lives | How it is enforced |
|---|---|---|
| Initiative equals effective Agility | `scripts/combat/initiative_order.gd` | per-round snapshot `base Agility + haste/slow modifier` |
| Higher score acts first | `_sort_by_initiative()` | descending effective Agility |
| Ties → stable actor ID ascending | `_sort_by_initiative()` | stable ID assigned at registration (spawn order: Ren 0, opponent/boss 1), then registration order as a total-order fallback |
| One main action per actor per round | `record_action()` / `can_act()` + `request_action()` guards in both scenes | a second action in the same round is rejected with zero mutation |
| No ATB, extra turns, reaction attacks, initiative rolls | engine contains no time or random input | deterministic recompute control in `initiative_test.gd` (5 identical recomputes) |
| Haste/slow changes apply at the next round boundary | `begin_round()` snapshots; `set_modifier()` / `set_actor_agility()` never mutate the live round | round-boundary tests in `initiative_test.gd` |
| Battle HUD shows the next three actors | `TurnOrderLabel` in both combat scenes + `get_next_three_actors_text()` | exact HUD string assertions in `initiative_test.gd`, `boss_combat_test.gd` |

**Agility sources (no invented numbers).** Ren uses the authored `CharacterStats` default Agility (`CharacterStats.new().agility` → 10) so no new stat constant was introduced. MVP encounter and boss definitions author **no** opponent Agility value; that value is explicitly `TBD` content and is held at `0`, which preserves the existing "Ren acts first" flow until authored content exists. Test fixtures set opponent Agility explicitly (test data, not game balance data) to exercise higher-opponent-initiative rounds.

### OD-003 — Kurei categories, roles, costs

- `KureiSystem.CATEGORY_ROLES` records the six approved roles exactly: Flame `damage/Burn`, Torrent `heal/cleanse`, Gale `haste/evasion`, Earth `shield/mitigation`, Lumina `pierce/focus`, Umbra `drain/debuff`; `get_category_role()` / `get_skill_role()` expose them.
- **No rock-paper-scissors multiplier chart exists**: no `multiplier`, `weakness*`, `resistance*`, `affinity*`, `counter*` or `chart*` field was added to any skill record, and `cast_skill()` returns the authored `base_power` unchanged (negative control asserts the field absence across all 11 skills).
- Authored values are untouched: pip costs, cooldowns and base powers for all 11 catalog skills are asserted value-for-value (2/2/18, 2/3/12, 1/1/10, 2/3/0, 1/2/14, 2/3/12, 3/3/28, 2/3/20, 2/3/16, 1/2/10, 0/0/0).
- SP baselines unchanged: `BattleFixture.BASELINE_MAX_SP == 2`, `BossEncounter.BASELINE_MAX_SP == 3`, `KureiTree.AUTHORED_PHASE_MASTERY_MAX_SP == 4`.
- **No new regeneration, critical, resistance, damage or boss-effect formula** was added; existing authored scene damage (Flame Burst 2, Solar Flare 3, Lumina Lance 1/2, Defend mitigation, boss intents) is untouched.
- Unsupported advanced boss effects (`solar_flare`, `celestial_prism`, `glacial_aegis`, `void_shift`, `gale_flurry`, `earth_bastion`, `umbra_drain`, `phase_mastery`) stay disabled with the pending-design notice and are proven mutation-free.

### OD-004 — Status policy (`scripts/combat/status_engine.gd`)

- Same-name reapplication refreshes to the **larger duration** and **larger potency**; `stacks` stays at 1 (**no intensity stacking**).
- Approved durations are owned by the engine (`OD004_DEFAULT_DURATIONS`) and act as both default and cap: Burn/Poison/Bleed/Regeneration **3**, Defense Up/Down **2**, Silence **1**, Stun **1**, Shield **3**.
- `cleanse_negative()` removes negative statuses only (poison, burn, bleed, silence, stun, defense_down) and keeps regeneration, shield and defense_up.
- `consume_stun()` implements "Stun skips 1 action": both combat scenes consume the Stun instead of resolving the actor's action, and the telegraph does not advance for an action that never happened.
- Shield expires when depleted (existing absorption path) **or** after the approved 3 turns.
- Bosses use the identical engine, defaults, refresh rule and caps — **no hidden boss resistance**.
- Skill applications were moved to the approved durations: Flame Burst Burn 2→3, Glacial Aegis Shield 2→3, Void Shift Defense Up 1→2, boss Defend Defense Up 1→2, boss Torrent Surge Regeneration 2→3 (authored potencies unchanged).
- Torrent Surge (Torrent role: heal/cleanse) now calls `cleanse_negative()` in both scenes.

---

## 2. Files changed

| File | Change |
|---|---|
| `scripts/combat/initiative_order.gd` | **New** OD-002 initiative engine (ordering, ties, round/action budget, HUD preview, haste/slow snapshot). |
| `scripts/combat/status_engine.gd` | OD-004 policy: approved durations + caps, no-stack refresh, `get_duration`, `is_negative/is_positive`, `cleanse_negative()`, `consume_stun()`. |
| `scripts/magic/kurei_system.gd` | OD-003 `CATEGORY_ROLES` + role accessors + header; no numeric change. |
| `scenes/combat/battle_fixture.gd` | Initiative registration/round flow, one-action guard, opponent-first handling, Stun skip, approved durations, Torrent cleanse, HUD text. |
| `scenes/combat/battle_fixture.tscn` | `TurnOrderLabel` inside the fighter row (no added row height). |
| `scenes/combat/boss_encounter.gd` | Same initiative/round/Stun/status wiring for the boss; terminal guard on deferred boss turns. |
| `scenes/combat/boss_encounter.tscn` | `TurnOrderLabel` inside the fighter row (keeps SBL-FIX-011 960x540 fit at 1.5x). |
| `tests/headless/initiative_test.gd` | **New** OD-002 suite (115 checks). |
| `tests/headless/status_engine_test.gd` | OD-004 policy section (64 checks total; Silence expectation updated to the approved 1 turn). |
| `tests/headless/kurei_combat_test.gd` | OD-003 role/value/no-chart controls and OD-004 fixture controls (103 checks total). |
| `tests/headless/boss_combat_test.gd` | OD-002/004 boss controls plus 8-action unsupported-skill zero-mutation suite (108 checks total). |
| `docs/agy-next-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`, `docs/open-decisions-ledger.md`, `report/README.md` | Evidence, traceability and decision-record updates. |

Untouched on purpose: `scenes/main/game_root.gd`, `scripts/persistence/*`, `scripts/magic/kurei_tree.gd`, dungeon/story/education code, `project.godot`, export configuration, and every other OD.

---

## 3. Test evidence (Godot 4.7.2 Stable `ed1daf0bf`, Windows headless, disposable user data)

### Targeted suites (post-change)

| Command | Result |
|---|---|
| `run_headless_tests.ps1 -Suite initiative_test` | **Exit 0, PASS (1.01 s)** — 115 OD-002 checks. |
| `run_headless_tests.ps1 -Suite combat_test` | **Exit 0, PASS** — `combat_test`, `kurei_combat_test`, `boss_combat_test` (baseline and post-change both green). |
| `run_headless_tests.ps1 -Suite status_engine_test` | **Exit 0, PASS (1.01 s)** — 64 checks incl. the OD-004 section. |
| `run_headless_tests.ps1 -Suite layout_audit_test` | **Exit 0, PASS (2.02 s)** — BossEncounter panel/menu rects inside 960x540 at 1.0x and 1.5x with the new HUD label. |

### Negative controls (guards deliberately broken, then restored)

| Control | Injection | Result |
|---|---|---|
| OD-002 one-action budget | `InitiativeOrder.can_act()` reduced to "registered" | `initiative_test` **exit 1 — 12 failed checks**, including `Second main action in the same round is rejected (no extra turns)`, `Rejected action deals no damage`, `Second main action in the same boss round is rejected` and `Rejected boss action does not advance the boss turn` (`report/neg_od002_one_action_budget.log`). |
| OD-004 no intensity stacking | restore `stacks + 1` on refresh | `status_engine_test` **exit 1 — 2 failed checks**: `Same-name refresh never stacks intensity (OD-004)`, `Repeated applications keep a single intensity` (`report/neg_od004_status_stacking.log`). |
| OD-003 authored values | `flame_burst.base_power` 18 → 17 | `kurei_combat_test` **exit 1 — 2 failed checks**: `flame_burst base_power stays at the authored 18`, `cast_skill returns the authored base_power unchanged (no hidden elemental multiplier)` (`report/neg_od003_authored_base_power.log`). |

All three injections were reverted; `git diff` afterwards shows only the intended implementation.

### Canonical suite

| Command | Result |
|---|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1` | **Exit 0 — 33/33 suites PASS** (import clean; `initiative_test` 1.02 s, `combat_test` 1.01 s, `kurei_combat_test` 1.02 s, `boss_combat_test` 2.02 s, `status_engine_test` 1.01 s, `layout_audit_test` 1.01 s, `dungeon_scene_test` 2.02 s, `save_model_test` 2.03 s; per-suite transcripts `report/<suite>.log`, runner summary printed by `run_headless_tests.ps1`). Disposable user-data isolation proof: `realUserDataUnchanged=True`, `disposableFiles=654`, `rootRemoved=True` (`report/godot_user_data_isolation.log`). |

---

## 4. Preserved invariants

- **OD-009 save boundaries:** initiative/round state is runtime-only and is never serialized; `ProfileStore`, `game_root.request_save` and `dungeon_expedition` are untouched, and `dungeon_scene_test` (59 OD-009 checks), `save_model_test`, `save_compatibility_recovery_test` and `web_backup_test` pass unmodified.
- **Extraction/defeat:** no change to defeat preservation, extraction exactly-once, or suspend ≠ extraction; `vertical_slice_loop_test`, `overworld_gateway_test`, `dungeon_scene_test` and `e2e_academic_playthrough_test` are green.
- **Authored values:** no change to pip costs, cooldowns, base powers, SP baselines, HP/pip counts, damage numbers, XP curves, rewards, drop tables, or story/educational content.
- **No new formulas:** no regeneration, critical, resistance, damage, elemental, or boss-effect coefficient was authored; all unsupported advanced boss effects remain disabled.
- **Other ODs:** only OD-002/003/004 rows were updated in `docs/open-decisions-ledger.md`; OD-001, OD-005..OD-017 and their blocked items are untouched.

---

## 5. Open questions for Codex review

1. **Profile Agility is not yet wired into encounters.** `game_root.gd` is outside this slice's approved file list, so `BattleFixture`/`BossEncounter` read the authored `CharacterStats` default (10) instead of the live profile value. Wiring `instance.character_stats = character_stats` (or passing an agility int) is a one-line follow-up; ordering behavior is unaffected while opponents hold no authored Agility.
2. **Opponent/boss Agility is `TBD` content** (held at 0). Should encounter definitions author opponent Agility, and what values? No number was invented here.
3. **Haste/slow has an engine hook but no authored source.** `InitiativeOrder.set_modifier()` implements the approved boundary rule and is tested, but no unlockable skill applies haste/slow today (`gale_flurry` with `effect: "haste"` exists in the catalog but is not in the authored `KureiTree`). Same for GDD-022's Slow status. Content approval is required before either is granted.
4. **Cleanse is wired to Torrent Surge only** (the approved Torrent role). Confirm whether Glacial Aegis or a dedicated cleanse skill should also cleanse.
5. **Silence duration is enforced (1 turn) but nothing casts Silence and `can_use_skills()` is not yet consulted by `request_action`** — gating Kurei casts behind Silence is a behavior change that was not in the approved list, so it was left out.
6. **HUD placement:** the next-three-actor label sits between the two fighter panels (it adds no row height, which keeps BossEncounter inside 960x540 at 1.5x). Confirm the placement is acceptable UX-wise.

---

## 6. AGENTS.md task report block

```text
TASK ID: SBL-OD-002/003/004
REQUIREMENTS: GDD-016, GDD-017, GDD-018, GDD-019, GDD-020, GDD-021, GDD-022, GDD-023, GDD-030, GDD-089, FR-CMB-001, FR-CMB-002, FR-CMB-003, FR-CMB-004, FR-MAG-001, FR-MAG-002, TC-CMB-001, TC-CMB-002, TC-CMB-003, TC-SAV-001
MILESTONE: Release Hardening & Scope Boundary Management (owner-approved OD-002/003/004 combat batch)
OWNER: agy (executed by opencode-go/mimo-v2.6-flash)
PLAN OWNER: Codex (docs/agy-next-queue.md; approved values report/complete-od002-011-proposal.md)
BRANCH/COMMIT: feature/w4-5-vertical-slice (implementation commit 494c412, [REVIEW_PENDING_CODEX])
FILES CHANGED: scripts/combat/initiative_order.gd (new), scripts/combat/status_engine.gd, scripts/magic/kurei_system.gd, scenes/combat/battle_fixture.gd, scenes/combat/battle_fixture.tscn, scenes/combat/boss_encounter.gd, scenes/combat/boss_encounter.tscn, tests/headless/initiative_test.gd (new), tests/headless/status_engine_test.gd, tests/headless/kurei_combat_test.gd, tests/headless/boss_combat_test.gd, docs/agy-next-queue.md, docs/traceability-matrix.md, docs/testing.md, docs/open-decisions-ledger.md, report/od002_003_004_combat_report.md, report/README.md
ASSET PROVENANCE: none (no images, audio, or Gemini Flash content; all changes are Godot code, scenes, tests and documentation)
TESTS RUN + RESULTS: targeted initiative_test / combat_test / kurei_combat_test / boss_combat_test / status_engine_test / layout_audit_test all exit 0; 3 negative controls exit 1 (12 / 2 / 2 failed checks) then restored; canonical suite 33/33 exit 0 (real user data unchanged)
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: profile Agility wiring (game_root outside approved files), authored opponent/boss Agility values, haste/slow skill source, cleanse scope beyond Torrent Surge, Silence cast gating, HUD label placement
```
