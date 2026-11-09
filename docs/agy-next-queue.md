# agy Next Work Queue — Batch A Review Fix

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Position

- Batch A implementation (`SBL-REV-001..003`) is complete and independently verified: 30/30 suites PASS.
- Codex CLI review session `01a1bfe5-fd15-7463-b4b1-c55215e0c3f0` found one P2 in `SBL-REV-003`.
- Batch B (`SBL-REV-004`) and Batch C (`SBL-REV-005/006`) are paused until this fix is reviewed.
- Do not resume `SBL-UX-001` yet.

## SBL-REV-003-FIX — Defense Demo must activate the selected profile

### Finding

After the title selects another slot while the title remains open, Defense Demo still applies persistent progression, inventory, and stat changes through the previously active `GameRoot._profile_slot`. Selecting `profile_02` can therefore mutate `profile_01`.

Codex source: review session `01a1bfe5-fd15-7463-b4b1-c55215e0c3f0`, range `2596420..HEAD`, `report/codex_review_batchA.log`.

### Requirements

- GDD-015, GDD-098.
- FR-SAV-001, FR-WLD-001/002.
- TC-SAV-001/002, TC-WLD-001, TC-DIM-001.
- Preserve profile ownership and save invariants from AGENTS.md.

### Allowed scope

- Route Defense Demo through the existing validated profile-activation path for the title-selected slot before any persistent demo mutation.
- If activation fails, leave the title open, do not mutate either profile, and show actionable failure feedback.
- Preserve the existing demo behavior and authored values after activation.
- Add regression coverage proving the selected slot receives the changes and the previously active slot remains byte-identical.
- No new story, balance, combat values, profile schema, overwrite behavior, or image/audio assets.

### Files

Change only the necessary files among:

- `scenes/ui/title_screen.gd`
- `scenes/main/game_root.gd`
- `tests/headless/profile_activation_test.gd`
- `tests/headless/title_screen_audio_test.gd`
- `docs/agent-review-queue.md`
- `docs/traceability-matrix.md`
- `docs/testing.md`

### Acceptance tests

- Select profile B from the title while gameplay A is loaded, activate Defense Demo, and assert:
  - B is the active/modified profile;
  - A's profile bytes, inventory, progression, and education records are unchanged;
  - the demo does not run against stale `_profile_slot` state.
- Run the failure-path test: activation failure leaves the title visible and both profile files unchanged.
- Existing title Settings/Backup and profile activation tests remain green.
- Run `scripts/build/run_headless_tests.ps1`; record the actual suite count.
- Run negative control in a disposable copy: bypass selected-slot activation and assert the regression test exits nonzero.

### Out of scope

- Batch B SFX routing.
- Batch C Phase Mastery or purchased skills.
- Rebinding (`SBL-UX-001`).
- Human-gated ODs, browser smoke, image generation, binary audio, or release acceptance.

### Reporting

Commit suffix `[REVIEW_PENDING_CODEX]`. Add a queue entry with the Codex finding, files, tests, asset provenance `none`, open questions, and `REVIEW: REVIEW_PENDING_CODEX`. Do not mark any task `REVIEWED`.

Use `scripts/agy/run_next_queue.ps1`.
