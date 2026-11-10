# Next Work Queue — Approved OD-002/003/004 Combat Batch

Plan owner: OpenCode/Codex plan. Executor: `opencode-go/mimo-v2.6-flash`. Codex CLI review deferred.

## Approved specifications

### OD-002 initiative

- Initiative equals effective Agility.
- Higher score acts first.
- Ties resolve by stable actor ID ascending.
- One main action per actor per round.
- No ATB, extra turns, reaction attacks, or initiative rolls.
- Haste/slow changes apply at the next round boundary.
- Battle HUD displays the next three actors.

### OD-003 Kurei/elements

- Keep Flame, Torrent, Gale, Earth, Lumina, Umbra.
- No rock-paper-scissors multiplier chart in the academic MVP.
- Roles: Flame damage/Burn; Torrent heal/cleanse; Gale haste/evasion; Earth shield/mitigation; Lumina pierce/focus; Umbra drain/debuff.
- Skill magnitude uses existing authored `base_power`; no hidden elemental multiplier.
- Retain current authored pip costs/cooldowns in `KureiSystem`.
- Normal SP baseline 2; Phase Mastery raises it to 4. Boss baseline 3; Phase Mastery raises it to 4.
- No new regeneration, critical, resistance, damage, or boss-effect formulas.
- Unsupported advanced boss effects remain disabled.

### OD-004 status policy

- Same-name status reapplication refreshes to the larger duration and larger potency; no intensity stacking.
- Burn, Poison, Bleed, Regeneration: 3 turns by default.
- Defense Up/Down: 2 turns.
- Silence: 1 turn.
- Stun: 1 skipped action.
- Shield expires when depleted or after 3 turns.
- Cleanse removes negative statuses only.
- Bosses use the same status rules; no hidden resistance.

## Requirements

- GDD-016..023, GDD-030, GDD-089.
- FR-CMB-001/002/003/004, FR-MAG-001/002.
- TC-CMB-001/002/003, TC-SAV-001.

## Allowed files

- `scenes/combat/battle_fixture.gd`
- `scenes/combat/battle_fixture.tscn`
- `scenes/combat/boss_encounter.gd`
- `scenes/combat/boss_encounter.tscn`
- `scripts/magic/kurei_system.gd`
- `scripts/magic/kurei_tree.gd`
- `scripts/combat/status_engine.gd`
- related HUD/UI scripts and targeted combat tests
- docs and report evidence

## Acceptance

- Initiative ordering, stable ties, next-three HUD, round-boundary refresh, and no-extra-turn controls pass.
- Existing skill base powers/costs/cooldowns remain exact; six role descriptions are represented.
- Status refresh/no-stack, durations, cleanse, stun, shield expiry, and boss consistency pass.
- Unsupported advanced boss actions remain disabled and mutation-free.
- Save, extraction, defeat, and OD-009 boundaries remain green.
- Run targeted combat suites and canonical headless suite; record actual results in `/report`.
- Commit with `[REVIEW_PENDING_CODEX]`; do not mark reviewed.

## Boundaries

- No new content, story, images, audio, browser work, or further OD resolution.
- Codex CLI review remains deferred.
