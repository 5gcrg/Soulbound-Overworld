# Next Work Queue — OD-009 MVP Save Boundary

Plan owner: Codex/OpenCode. Implementation executor: `opencode-go/mimo-v2.6-flash`. Reviewer: Codex CLI deferred.

## Ratified scope

The project owner approved the MVP fallback for `OD-009`:

- Persist only at room/exploration boundaries.
- Do not serialize mid-battle or partial-turn state.
- Preserve all future mid-battle fields and behavior as `TBD`.

## Requirements

- GDD-098, GDD-099, GDD-100.
- FR-SAV-001, FR-CMB-001.
- TC-SAV-001, TC-SAV-002, TC-DNG-002, TC-DNG-003, TC-DNG-004.
- AGENTS.md save invariants: suspension is not extraction; exactly-once reward transfer; permanent data survives defeat.

## Allowed implementation

- Add explicit save-boundary guards and documentation for the approved MVP behavior.
- Reject/defer mid-battle or partial-turn save requests before mutation, with actionable diagnostics.
- Preserve existing room/exploration saves, suspended expedition persistence, backup validation, extraction, defeat, and retry behavior.
- Add regression tests proving rejected mid-battle saves do not change profile bytes, inventory, education, story, or temporary state.
- Update `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`, and `/report`.

## Forbidden scope

- No mid-battle serialization format.
- No partial-turn replay/state schema.
- No new combat numbers, initiative rules, SP/cooldown values, rewards, loss ratios, story, assets, browser work, or other OD resolution.
- No profile schema bump unless an existing guard requires documentation only; preserve schema compatibility.

## Likely files

- `scenes/dungeon/dungeon_expedition.gd`
- `scenes/main/game_root.gd`
- `scripts/persistence/profile_store.gd`
- `tests/headless/dungeon_scene_test.gd`
- `tests/headless/save_model_test.gd`
- `tests/headless/save_compatibility_recovery_test.gd`
- `tests/headless/web_backup_test.gd`
- required docs and report files only

## Acceptance

- Allowed room/exploration save succeeds and round-trips.
- Mid-battle/partial-turn save request rejects or defers before any profile mutation.
- Rejected save leaves profile bytes and all permanent/temporary state unchanged.
- Suspend/resume remains distinct from extraction.
- Extraction and defeat remain atomic and exactly-once.
- Legacy/future profile validation remains unchanged and safe.
- Targeted tests and canonical headless suite pass.
- Record actual evidence and leave implementation `REVIEW_PENDING_CODEX`.

Use MiMo execution only; Codex CLI review is deferred.
