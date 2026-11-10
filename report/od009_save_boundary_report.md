# OD-009 MVP Save Boundary — Implementation & Verification Report

**Task ID:** SBL-OD-009
**Date:** 10 November 2026
**Milestone:** Release Hardening & Scope Boundary Management
**Requirements:** GDD-098, GDD-099, GDD-100, FR-SAV-001, FR-CMB-001, TC-SAV-001, TC-SAV-002, TC-DNG-002, TC-DNG-003, TC-DNG-004, plus the `AGENTS.md` save invariants (suspend ≠ extraction; exactly-once reward transfer; permanent data survives defeat).
**Owner:** `opencode-go/mimo-v2.6-flash` (MiMo execution; Codex CLI review deferred)
**Plan owner:** Codex (plan of record: `docs/agy-next-queue.md`, owner-ratified OD-009 MVP scope)
**Implementation commit:** `e285514` on `feature/w4-5-vertical-slice`
**Review status:** `REVIEW_PENDING_CODEX` — nothing in this slice is `REVIEWED`.

---

## 1. Ratified scope implemented

The project owner approved the OD-009 MVP fallback:

- Persist only at room/exploration boundaries.
- Do not serialize mid-battle or partial-turn state.
- Preserve every future mid-battle field and behavior as `TBD`.

Nothing else was touched: no combat values, no initiative rules, no SP/cooldown values, no
rewards, no loss ratios, no story, no assets, no browser work, no profile schema bump, and no
other open decision was resolved. `OD-009` remains open for its full-release decision
(mid-battle serialization format, mid-battle browser resume, combat-action replay logs stay
blocked in `docs/open-decisions-ledger.md`).

## 2. What changed

### `scenes/main/game_root.gd` — explicit save-boundary guard + request entry point

New OD-009 section (after `_mutate_profile`):

| Symbol | Behavior |
|---|---|
| `OD009_SAVE_BLOCKED_HINT` | Constant actionable hint appended to every rejection diagnostic. |
| `get_save_blocker() -> String` | Returns the first blocking condition, or `""` at an allowed room/exploration boundary. Blockers: pending combat encounter open, live `BattleFixture` (diagnostic includes the live phase, so a partial turn reports `phase=ENEMY`), live `BossEncounter`, pending/live expedition, a held suspended-expedition snapshot, and non-empty at-risk satchel loot. |
| `check_save_boundary() -> Error` | `OK` when the request may proceed, `ERR_BUSY` when it must be rejected/deferred. Evaluated **before any profile mutation**. |
| `request_save(reason) -> Error` | The save-request entry point. On a blocker it returns `ERR_BUSY` **before** `ProfileStore` is touched and emits `push_warning("[OD-009] Save request '<reason>' deferred before any profile mutation: <blocker>. <hint>"`. With no store configured it returns `ERR_UNCONFIGURED`, again before mutation. |
| `_persist_exploration_boundary() -> Error` | The allowed path: one atomic `_mutate_profile` load-modify-save revision carrying character stats, the Kurei tree (`character["kurei_tree"]` is refreshed from the live controller so the rewrite can never drop stored skills/talents) and inventory. Education, chapter, slice, ending and expedition records keep their existing event-based writers and are never rewritten by this path, so completion gating and first-attempt immutability are untouched. |

Expedition state keeps its **separate handling** (GDD-099): it is written only by the atomic
Suspend / Extraction / Defeat commits. The generic boundary save is refused while a run is
active, parked, or its at-risk satchel is still live, which also prevents unbanked expedition
loot from ever becoming permanent through a generic save (protecting the `OD-008` defeat-loss
invariant).

### `scenes/dungeon/dungeon_expedition.gd`

- Header, `serialize_expedition()` and `suspend_expedition()` now document the OD-009 boundary:
  snapshots capture room/exploration-boundary state only (seed, path, step, at-risk satchel);
  no combat or turn state exists in the snapshot and no future mid-battle field may be added
  without Persistence Architecture Review; suspend is never an extraction.
- Guard: `serialize_expedition()` returns `{}` while an extraction commit is in flight
  (`_is_extracting`), so a snapshot can never interleave with the atomic terminal write.
  `suspend_expedition()` already refused that state, so no reachable behavior changed.

### `scripts/persistence/profile_store.gd`

- Documentation only on `save_profile()`: ProfileStore performs no combat-state
  serialization; mid-battle/partial-turn requests are rejected by the game layer *before*
  the writer is reached, so a rejected request commits no revision. Legacy/future schema
  validation code is unchanged.

### `tests/headless/dungeon_scene_test.gd`

New `_test_od009_save_boundary()` (59 assertions) plus `_profile_revision_count()` /
`_profile_revision_files()` helpers and an assertion counter for evidence. Coverage:

1. Seeded permanent profile (level/xp, banked gear, chapter progress, education record) →
   session boot commits nothing and leaves bytes unchanged; exploration boundary open.
2. Mid-battle: live `BattleFixture` → blocker reported, `check_save_boundary() == ERR_BUSY`,
   `request_save()` returns `ERR_BUSY`.
3. Partial turn: `BattleFixture.phase = ENEMY` (enemy resolution in flight) → rejected;
   temporary input/movement state unchanged.
4. Pending encounter open (`_battle_pending`) → rejected.
5. Live `BossEncounter` (full release tier) → rejected, then closed cleanly.
6. After all probes: profile export bytes identical, committed-revision count identical,
   and character, inventory, education, story, Kurei-tree, slice stage, current region and
   suspended-run snapshot all byte-identical (JSON-compare) to the pre-probe baseline.
7. Active expedition → rejected; Suspend then persists the room-boundary snapshot,
   banks nothing (suspend ≠ extraction), keeps secured bank intact; a parked run still
   defers to the expedition-state path.
8. Resume → reach the extraction shrine → extract: snapshot cleared atomically, loot banked
   exactly once.
9. Allowed boundary save returns `OK`, commits exactly one revision (new revision file added,
   only the superseded revision pruned — ProfileStore retains the two latest valid revisions),
   round-trips changed character xp and banked inventory, writes an empty satchel, preserves
   the Kurei tree, story progress, education records and expedition records.
10. A fresh GameRoot session loads the boundary-saved xp/bank and keeps first-attempt
    education correctness.

## 3. Test evidence (Godot 4.7.2 Stable `ed1daf0bf`, Windows headless)

All runs used the canonical runner with proven disposable user data.

| Command | Result |
|---|---|
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite dungeon_scene_test` | **Exit 0, PASS (2.02 s)**. `Project import clean (exit code 0)`. Log: `--- Running OD-009 MVP Save Boundary Test ---` → `OD-009 save boundary checks: 59 run, 0 failed` → `=== ALL DUNGEON SCENE TESTS PASSED SUCCESSFULLY ===` (`report/dungeon_scene_test.log`). |
| Same run, stderr diagnostics | **6 actionable OD-009 diagnostics**, one per rejected probe, each naming the blocker and stating *"no profile data was written"*: `battle in progress (phase=PLAYER…)`, `battle in progress (phase=ENEMY…)`, `a combat encounter is opening`, `boss encounter in progress`, `expedition in progress (persist only via Suspend, Extraction or Defeat)`, `a suspended expedition snapshot is held` (`report/dungeon_scene_test.err`). |
| `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1` (canonical) | **Exit 0, 32/32 suites PASS**, including `save_model_test`, `save_compatibility_recovery_test`, `web_backup_test`, `dungeon_scene_test`, `boss_combat_test`, `profile_activation_test`, `vertical_slice_loop_test`. `realUserDataUnchanged=True`, `disposableFiles=654`, `rootRemoved=True`. |
| Negative control: mid-battle branch disabled in `get_save_blocker()` (`if false and _battle != null …`), targeted suite re-run | **Exit 1, FAIL** with 7 assertions: `Live battle reports a save blocker`, `Boundary check rejects a mid-battle save`, `Mid-battle save request rejected`, `Partial-turn save request rejected`, **`Rejected saves leave profile bytes unchanged`**, **`Rejected saves commit no profile revision`**, `Expedition rejection leaves profile bytes unchanged`. Proves the guard is load-bearing and that without it a mid-battle save would mutate the profile. Guard restored afterwards. |
| `… -Suite dungeon_scene_test` after restore | **Exit 0, PASS (2.02 s)** — clean tree re-verified. |

## 4. Acceptance mapping

| Acceptance criterion | Evidence |
|---|---|
| Allowed boundary save round-trips | OD-009 checks 9–10: `request_save() == OK`, one new revision, xp/bank reload in a fresh session. |
| Mid-battle/partial-turn request rejects/defers before profile mutation | OD-009 checks 2–6 + 6 diagnostics; `check_save_boundary() == ERR_BUSY` is evaluated before `_persist_exploration_boundary()`. |
| Rejected save leaves profile bytes and all permanent/temporary state unchanged | Export text + revision count + JSON-compare of character/inventory/education/story/Kurei/slice/region/suspended snapshot; negative control shows these assertions fail when the guard is removed. |
| Suspend remains distinct from extraction | Existing SBL-P1-C / REV-001 assertions still green; new checks: suspend writes `world.active_expedition`, banks 0 fragments, keeps secured bank. |
| Extraction/defeat remain atomic exactly-once | Existing atomic-extraction, SBL-FIX-007 defeat-retry and REV-001 single-transfer assertions unchanged and green; new exactly-once check on the resumed run. |
| Legacy/future validation remains safe | `profile_store.gd` changed by documentation only; `save_model_test` and `save_compatibility_recovery_test` pass unmodified. |
| Targeted and canonical suites pass | Both runs above (exit 0). |
| Evidence recorded, work left `REVIEW_PENDING_CODEX` | This report, `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`; commit tagged `[REVIEW_PENDING_CODEX]`. |

## 5. Out of scope / explicitly not done

- No mid-battle serialization format, partial-turn schema, replay log, or combat resume.
- No new combat numbers, initiative rules, SP/cooldown values, rewards, loss ratios, story,
  assets, or browser work; no other OD resolved.
- No profile schema bump (`schema_version` stays `1`); no `ProfileStore` logic change.
- No UI button was added for `request_save()`; it is the guarded entry point that future
  event-based autosave (GDD-099) must call. Existing save paths are unchanged.
- `OD-009` itself stays open in the ledger for the full-release save-boundary decision.

## 6. Open questions for Codex review

1. Should `request_save()` be wired to an existing UI/event (e.g. region transition) in a
   follow-up slice, or is a programmatic entry point sufficient for the MVP?
2. The at-risk-satchel blocker defers generic saves while unbanked loot is live. Confirm this
   is the preferred reading of GDD-099 "separate expedition-state handling" (it prevents
   unbanked loot from becoming permanent without an expedition record).
3. `push_warning` diagnostics are the current "actionable diagnostic" channel; confirm no
   player-facing UI string is required for the MVP (no new copy was invented).
