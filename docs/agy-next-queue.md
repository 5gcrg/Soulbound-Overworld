# agy Next Work Queue — Batch 4 (review fixes, staged)

Plan owner: Codex. Implementation owner: agy. **agy never reviews.** Codex CLI review has now run, so these are approved review fixes, not speculative work.

## Position

- **Batch 3 complete** (`9040561`, `4720ade`, `5e81a04`): SBL-BLD-002 build-time tier injection and SBL-MCP-003 committed MCP proof harness.
- **Independent verification** 29/29 headless suites PASS; tier markers read from all three zips; `verify_exported_tier.gd` gates the MVP `.pck` and opens the full-release `.pck`; working tree clean.
- **Codex CLI review of `e25491d..5e81a04`** (session `01a1be9a-5583-7252-b082-ebd436372c80`, `gpt-6.1-sol`): **CHANGES_REQUESTED**, three P2 findings. No P0/P1, no save-invariant or tier-gating faults.
- Everything in the range is `CHANGES_REQUESTED` until these fixes land and are re-reviewed. Do not mark anything `REVIEWED`.

## Batch 4 tasks (implement in order)

### 1. SBL-FIX-013 — Keyboard focus must scroll into view (review finding 1)

Codex probe: at 150% text scale the focused Respec button sat at y=570 while the scroll viewport ended at y=465 and scroll stayed at zero.

- Set `follow_focus = true` on every `ScrollContainer` that holds focusable controls: `scenes/ui/character_sheet.tscn`, the settings sheet, and any other scrollable sheet or modal with buttons inside.
- Keep the existing minimum-size/scroll guards intact; do not shrink text below the authored base.
- Extend `tests/headless/layout_audit_test.gd`: for each scroll container, assert `follow_focus` is true and that a focused control below the fold produces a non-zero scroll offset at 1.5x text scale.
- Godot primitives only, no art assets.

### 2. SBL-VER-004 — Validate the PCK inside each archive (review finding 2)

Today `validate_release.ps1` mounts `builds\web-academic_mvp\index.pck` and `builds\web\index.pck`, so a mislabeled archive can pass against an unrelated correct local build, and the Windows `.pck` is never exercised.

- For every archive being validated, extract its own `index.pck` / `Soulbound.pck` to a temp directory and run the live tier gate against that extracted file.
- Cover all three archives: `Soulbound-AcademicMVP-Web.zip` (`academic_mvp`), `Soulbound-Web.zip` (`full_release`), `Soulbound-Windows-Portable.zip` (`full_release`, Windows `.pck`).
- Derive the expected tier from the archive's own `build_tier.txt` marker and cross-check the project setting inside the mounted pack.
- Prove it with a negative control: swap the markers between the MVP and full Web archives in a temp copy and confirm validation exits 1.
- Keep the existing entry-point, renderer, thread-support, and size assertions.

### 3. SBL-MCP-004 — MCP proof must reject error results and stale scenes (review finding 3)

`run_adapter_proof.js` resolves any JSON-RPC success, including `result.isError: true`, and callers print PASS. A reused disposable project with an old valid scene can fake a pass.

- Reject `result.isError === true` (and any `result.content` error text) in the JSON-RPC handler; fail the proof with the server's message.
- Delete any pre-existing `mcp_generated_scene.tscn` in the disposable project before `create_scene`, so a stale file cannot satisfy verification.
- Assert the saved scene's node tree is exactly the one created in this run (root `Node2D`, `Player` `CharacterBody2D`, `Collider` `CollisionShape2D`), not merely that the file exists.
- Do not rewrite the tracked reference `tools/mcp-proof/mcp_generated_scene.tscn`; write only into the disposable project and compare/report against the reference.
- Re-run the harness and paste the observed output into `docs/godot-mcp-evaluation.md`; if the adapter is unreachable, say so and keep `PENDING`.

### 4. SBL-BLD-003 — Prove the export failure path restores the tree

- Force an export failure (for example by validating a temp dist copy with a deliberately wrong marker) and assert `project.godot` is restored byte-identically and no `build_tier.txt` remains at the project root.
- Add `/build_tier.txt` to `.gitignore` so an interrupted run cannot silently flip the dev tier or be committed.
- Keep `release_tier="full_release"` as the checked-in default; `OD-017` still decides shipping.

## Verification and reporting

- Finish with `scripts/build/run_headless_tests.ps1 -Export`; paste the real suite count, exit codes, marker values, and artifact sizes.
- One queue entry per task in `docs/agent-review-queue.md` with requirements, files, asset provenance, verification table, `REVIEW: REVIEW_PENDING_CODEX`, open questions.
- Commit suffix `[REVIEW_PENDING_CODEX]`; emit the AGENTS.md report block.
- Do not claim the review is satisfied; Codex CLI re-reviews after you finish.

## Human-gated — do not attempt

- Shipping default tier (`OD-017`), browser smoke execution, image assets (Codex-only), binary audio (Gemini), educator sign-off (`OD-012`), combat ODs 002/003/004.

## Rules unchanged

Godot 4.7.2 Stable, Compatibility renderer, GDScript, Windows portable + single-threaded Web; no invented numbers or story; save invariants preserved; `[REVIEW_PENDING_CODEX]`; no `REVIEWED` without a Codex session ID.

Use `scripts/agy/run_next_queue.ps1` (it reads `docs/agy-dispatch-prompt.md`).
