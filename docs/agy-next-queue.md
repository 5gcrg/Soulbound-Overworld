# agy Next Work Queue — Batch 3 (active)

Plan owner: Codex. Implementation owner: agy. **agy never reviews.** Codex CLI is still quota-blocked, so agy continues implementing under AGENTS.md Rule 5 and every commit stays `REVIEW_PENDING_CODEX`.

## Completed (do not redo)

- **Batch 1** `e5f93e8..e2a68bd`: SBL-VER-001, SBL-FIX-007/008/009, SBL-DOC-001, SBL-VER-002, SBL-MCP-001, SBL-DATA-001/002.
- **Batch 2** `f263001..6f6efa5`: SBL-FIX-010 (release tiers), SBL-BLD-001 (canonical runner), SBL-FIX-011 (layout audit), SBL-FIX-012 (save compatibility/recovery), SBL-VER-003 (artifact validator), SBL-MCP-002 (MCP trial), SBL-DATA-003 (OD briefs).
- Independently verified after batch 2: 27/27 suites pass via `scripts/build/run_headless_tests.ps1`, negative control exits 1, `-Export` chain exits 0 with artifacts validated.
- **Review status: `REVIEW_PENDING_CODEX` for everything from `e25491d` onward.** Codex CLI probe on 9 Nov 12:13 returned a usage-limit error; no review ran.

## Batch 3 tasks (implement these, in order)

### 1. SBL-BLD-002 — Wire the release tier into the build (highest priority)

The code gate exists (`ReleaseTier`, `void_citadel` refusal, ending/boss/capstone gating), but the build does not set it: `project.godot` ships `release_tier="full_release"` and `export_presets.cfg` has no tier switch. An artifact labelled "academic MVP" would still contain an unlocked Chapter V.

- Add `-Tier academic_mvp|full_release` to `scripts/build/export_release.ps1`, defaulting to the current `full_release` behavior.
- Apply the tier to the **exported artifact only**; the working tree must be byte-identical afterwards (restore `project.godot` on exit, including on failure).
- Write a `build_tier.txt` (or equivalent small marker) into each artifact and have `scripts/build/validate_release.ps1` assert the marker matches the requested tier; a mismatch must fail the export.
- Produce `dist/Soulbound-AcademicMVP-Web.zip` (tier `academic_mvp`) alongside the existing full-release archives.
- Prove the gate end-to-end: load the MVP artifact (or run its pck headless) and confirm `void_citadel` is unavailable and `open_ending_modal` no-ops; full-release artifact still opens them.
- Tests: extend `release_tier_test.gd` or add `build_tier_test.gd` for the marker/config parsing. Do not weaken the existing tier assertions.
- Do **not** decide the shipping default; that is `OD-017`.

### 2. SBL-MCP-003 — Make the MCP proof reproducible

Batch 2 reported `@coding-solo/godot-mcp` passing on a disposable project, but `scratch/` was deleted, so only prose remains.

- Commit a minimal harness under `tools/mcp-proof/`: the adapter driver script, the generated `mcp_generated_scene.tscn`, the headless `verify_mcp_scene.gd`, and a `README.md` with the exact `npx` invocation and expected output.
- No `node_modules`, no vendored binaries, no credentials. The disposable project itself stays out of the repo; the README explains how to recreate it.
- Re-run the proof once from the committed harness so the README matches reality, and paste the observed result into `docs/godot-mcp-evaluation.md`.
- If the adapter is unreachable this time, keep the existing `PENDING`/evidence state and say so plainly; do not fabricate a pass.

### 3. Verification and reporting

- Run `scripts/build/run_headless_tests.ps1 -Export` at the end and paste the real suite count, exit codes, and artifact sizes.
- One queue entry per task in `docs/agent-review-queue.md` with requirements, files, asset provenance, verification table, `REVIEW: REVIEW_PENDING_CODEX`, open questions.
- Commit suffix `[REVIEW_PENDING_CODEX]` on every commit; emit the AGENTS.md report block.

## Human-gated — do not attempt

- Shipping default tier (`OD-017`).
- Browser smoke execution (needs Chromium/Firefox; keep `PENDING HUMAN EXECUTION`).
- Image assets (Codex-exclusive; never route to agy or Gemini Flash).
- Binary audio (Gemini Flash audio output pending; procedural SFX is the fallback).
- Educator sign-off on assessed questions (`OD-012`).
- Combat design ODs 002/003/004 (briefs exist; human decides).
- Codex CLI review (quota-blocked; never claim it happened).

## Rules unchanged

Godot 4.7.2 Stable, Compatibility renderer, GDScript, Windows portable + single-threaded Web; no invented numbers or story; save invariants preserved; per-task report block; `[REVIEW_PENDING_CODEX]`; no `REVIEWED` without a Codex session ID.

Use `scripts/agy/run_next_queue.ps1` (it reads `docs/agy-dispatch-prompt.md`).
