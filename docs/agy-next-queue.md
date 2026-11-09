# agy Next Work Queue — Batch 5 (one review fix)

Plan owner: Codex. Implementation owner: agy. **agy never reviews.**

## Position

- **Batch 4 complete** (`0b7e85f..b2b45a4`): SBL-FIX-013, SBL-VER-004, SBL-MCP-004, SBL-BLD-003.
- **Codex CLI re-review** of `b2ddee1..b2b45a4` (session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`) cleared the three original findings and found **one new P2** in the failure-restoration test.
- Everything else in `e25491d..b2b45a4` is now `REVIEWED`. Only `SBL-BLD-003` is `CHANGES_REQUESTED`.

## Batch 5 task

### SBL-BLD-004 — Deterministic export-failure injection (review finding)

Codex found that `scripts/build/test_export_failure_restoration.ps1:34-37` does not reliably test the restoration boundary:

- A nonexistent `-GodotPath` makes `export_release.ps1` fall back to an installed Godot, so the test may run a real export.
- Without a fallback it throws before `project.godot` or `build_tier.txt` is modified, so the test passes even if the `finally` restore is broken.

Required:

- Inject the failure **after** the tier is applied and `build_tier.txt` is written. Either:
  - pass a controlled shim executable that exits 0 for version/import probes and non-zero for `--export-release`/`--export-pack`, or
  - add an explicit test-only failure switch to `export_release.ps1` that throws inside the `try` after both mutations.
- Assert the mutation was observed before the failure (shim log, sentinel file, or exporter log line), not just that the process exited non-zero.
- Keep the existing assertions: non-zero exit, `project.godot` byte-identical by bytes and SHA-256, no `build_tier.txt` at the project root.
- **Prove the test is non-vacuous:** run it against a copy of the exporter with the `finally` restore disabled and confirm the test fails. Record the observed failure in the queue entry.
- Do not change `release_tier="full_release"` or `OD-017`.

## Verification and reporting

- `scripts/build/test_export_failure_restoration.ps1` exits 0 with the controlled failure, and exits 1 with the restore disabled.
- `scripts/build/run_headless_tests.ps1 -Export` exits 0; paste the suite count and artifact sizes.
- One queue entry in `docs/agent-review-queue.md` with requirements, files, asset provenance, verification table, `REVIEW: REVIEW_PENDING_CODEX`, open questions.
- Commit suffix `[REVIEW_PENDING_CODEX]`; emit the AGENTS.md report block.

## Human-gated — do not attempt

- Shipping default tier (`OD-017`), browser smoke execution, image assets (Codex-only), binary audio (Gemini), educator sign-off (`OD-012`), combat ODs 002/003/004.

## Rules unchanged

Godot 4.7.2 Stable, Compatibility renderer, GDScript, Windows portable + single-threaded Web; no invented numbers or story; save invariants preserved; `[REVIEW_PENDING_CODEX]`; no `REVIEWED` without a Codex session ID.

Use `scripts/agy/run_next_queue.ps1` (it reads `docs/agy-dispatch-prompt.md`).
