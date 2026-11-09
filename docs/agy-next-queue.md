# agy Next Work Queue — Remediation Batch B (SBL-REV-004)

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Position

- Remediation Batch A (`SBL-REV-001..003`) is **REVIEWED**.
- Batch A implementation and fix evidence are recorded in `report/implementation-review-ledger.md`.
- Codex review sessions: `01a1bfe5-fd15-7463-b4b1-c55215e0c3f0` and `01a1bff5-713f-73e2-bb28-9a9dd10f37f3`.
- Batch C (`SBL-REV-005/006`) follows only after this batch is independently verified and Codex-reviewed.
- Do not resume `SBL-UX-001` yet.

## SBL-REV-004 — Effective SFX bus routing and mute

**Finding:** 7, P2 from Codex review session `01a1bee0-6c04-72b0-b38d-6bce20925f2f`.

### Requirements

- GDD-087.
- FR-SET-001.
- TC-ACC-001 audio-controls portion.
- Supporting GDD-096.

### Dependencies

- Batch A reviewed.
- No asset-generation capability required.

### Files

Change only the necessary files among:

- `scripts/audio/audio_manager.gd`
- `scripts/settings/settings_manager.gd`
- `scenes/main/game_root.gd`
- `tests/headless/title_screen_audio_test.gd`
- `tests/headless/settings_accessibility_test.gd`
- `docs/agent-review-queue.md`
- `docs/traceability-matrix.md`
- `docs/testing.md`

### Data model

- No settings schema change.
- Reuse existing `master_volume`, `music_volume`, and `sfx_volume`.
- Bus creation is runtime configuration, not a generated audio asset.
- Do not change procedural cue synthesis, gain constants, stream cache behavior, or acquire binary audio.

### Implementation

1. Add an idempotent bus-initialization helper callable before player creation and before settings application.
2. Ensure `Music` and `SFX` buses exist and route to `Master`.
   - Reuse existing buses by name.
   - Do not duplicate, reorder, or overwrite unrelated buses.
3. Invoke initialization before `AudioManager` creates players.
4. Assign every cue player to `SFX` and verify that the bus exists; never silently fall back to `Master`.
5. Apply loaded settings after buses exist and before user-triggered playback.
6. For zero volume, use the bus mute flag as well as existing gain handling. Positive volume clears the settings-controlled mute flag.
7. Master affects all output; Music and SFX remain independent.

### Acceptance tests

- Remove test `Music`/`SFX` buses, initialize, and assert exactly one of each exists, both route to `Master`, and every cue player reports `SFX`.
- Reinitialize and assert no duplicate buses.
- Set SFX volume to zero and assert SFX is muted while Master/Music remain unchanged; restore a positive value and assert SFX unmutes.
- Set Master to zero and assert all output remains muted through Master.
- Reload settings and assert values apply to existing buses.
- Existing title audio and settings accessibility behavior remains green.
- Run `scripts/build/run_headless_tests.ps1`; record the actual suite count.
- Preserve Batch A profile/title tests and save invariants.

### Negative controls

Run only against disposable test state:

- Omit SFX initialization or route a player to Master; routing assertions must exit nonzero.
- Initialize buses after players; player-routing assertion must exit nonzero.
- Remove the SFX mute update; zero-volume assertion must exit nonzero.

Record expected and observed failure evidence in `report/`.

### Out of scope and blocked

- New cues, music, synthesis changes, mixing balance, or binary audio; `OD-015` remains pending.
- Browser audio-unlock certification.
- Combat integration (`SBL-REV-005/006`).
- Rebinding (`SBL-UX-001`).
- Image generation.

### Review and reporting

- Perform a native listening check using existing procedural cues; headless routing is not proof of audible output.
- Add a queue entry with requirements, files, tests, asset provenance `none`, review status, and open questions.
- Commit suffix `[REVIEW_PENDING_CODEX]`.
- Codex CLI reviews the diff, bus initialization order, mute behavior, and confirms no asset-generation changes.

Use `scripts/agy/run_next_queue.ps1`.
