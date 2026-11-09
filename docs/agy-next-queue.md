# agy Next Work Queue — Batch 2

Plan owner: Codex. Implementation owner: agy. **agy never reviews.** Codex CLI remains unavailable, so agy continues implementing under AGENTS.md Rule 5 and every commit stays `REVIEW_PENDING_CODEX`.

## Position after batch 1

- Implemented and independently verified: `SBL-VER-001`, `SBL-FIX-007`, `SBL-FIX-008`, `SBL-FIX-009`, `SBL-DOC-001`, `SBL-VER-002`, `SBL-MCP-001`, `SBL-DATA-001`, `SBL-DATA-002` (`e5f93e8..e2a68bd`).
- Independent check: `--import` exit 0, 24/24 headless suites pass, `export_release.ps1` exit 0 (Web 10,643,529 B / Windows 86,515,950 B).
- **Still unreviewed.** `SBL-FIX-006` and all batch-1 commits await Codex CLI.

## Batch 2 priorities

### 1. SBL-FIX-010 — Release-tier separation (highest priority, invariant gap)

AGENTS.md requires the 3-chapter academic MVP to stay separate from the 5-chapter 2-ending full release. Today `void_citadel` is registered unconditionally in `scripts/world/world_router.gd`, so an academic-MVP build can walk into Chapter V and trigger both endings.

- Add an explicit release-tier setting (for example `soulbound/release_tier` in `project.godot`) with tiers `academic_mvp` and `full_release`.
- Gate: Void Citadel region/portal, both ending altars, the ending modal path, and the capstone question behind `full_release`. Keep chapter 4 (`ACADEMIC_COMPLETE`) as the academic MVP endpoint.
- Default the checked-in value to the current behavior (`full_release`) so existing dev/evaluator flows keep working; **do not** silently choose the shipping default — record that as an open decision.
- Tests: academic tier cannot reach Chapter V/endings (portal absent or refused, `open_ending_modal` no-ops), full tier still can. Existing `ending_chapter5_test` must pass in full tier.
- No content deletion, no story rewrites.

### 2. SBL-BLD-001 — Canonical headless test runner

Every session hand-rolls the `Start-Process` loop, which is how the blank-exit-code trap keeps recurring.

- `scripts/build/run_headless_tests.ps1`: runs `--import`, then every `tests/headless/*.gd`, captures per-suite logs under `report/` (already gitignored), prints a PASS/FAIL table, exits non-zero on any failure.
- `-Export` switch chains `export_release.ps1`; `-Suite <name>` runs one suite.
- Prove it: green run exits 0, and a deliberately broken temporary suite makes it exit non-zero. Remove the broken suite afterwards.
- `docs/testing.md`: the exact command, why the console executable is used, and the expected suite count.

### 3. SBL-FIX-011 — 960×540 layout and overflow audit

Text scale up to 1.5× and high contrast are now applied live, but the logical resolution is 960×540 and the settings panel was already enlarged once.

- Audit Settings, Inventory, Character, chapter dialog, academic modal, and ending modal at 960×540 with `text_scale` 1.0 and 1.5.
- Add scroll containers / minimum-size guards where content can exceed the panel; never shrink text below the authored base.
- Headless assertions: each modal's rect stays inside the viewport at both scales, and no scroll container reports clipped content at 1.0×.
- Godot primitives only, no new art assets.

### 4. SBL-FIX-012 — Save compatibility and recovery UX

- Fixture tests: a profile written before `active_expedition` existed loads cleanly; unknown extension keys survive a save cycle; a corrupt slot is recovered without losing the previous revision.
- Surface recovery state: when `ProfileStore` reports `recovered`, the title screen must say so and offer backup export before any overwrite.
- Keep schema-version rules exact; do not add leniency that accepts values which only round to the current version.

### 5. SBL-VER-003 — Exported-artifact validator

- `scripts/build/validate_release.ps1`: assert both zips contain the expected entry points (`index.html`, `index.wasm`, `index.pck`, `Soulbound.exe`, `Soulbound.pck`), that the Web preset stays single-threaded and Compatibility, that no editor/debug leftovers ship, and that pck sizes are plausible against the previous build.
- Wire it into `export_release.ps1` so a bad build fails the export.
- Report sizes in the queue entry.

### 6. SBL-MCP-002 — Attempt a real Godot-compatible MCP adapter

- Batch 1 only recorded `PENDING`. Now attempt an actual Godot-capable community adapter on a **disposable** project: list scene tree, create/edit a node, save the scene, inspect errors, run headless validation, capture evidence.
- Name every adapter attempted with version and why it passed or failed. Never install the Unity package into Godot. If none works, keep `PENDING` with the evidence.
- Do not point a third-party tool at the real project until it passes on the disposable one.

### 7. SBL-DATA-003 — Decision-ready briefs for the combat ODs

- For `OD-002` (initiative), `OD-003` (element/affinity and SP curves), `OD-004` (status stacking/duration): one page each with the options, what each option changes, what it unblocks, and the risk of each.
- **No invented coefficients, percentages, or drop rates.** Options and consequences only; the human decides.

## Blocked — do not attempt

- Browser smoke execution: needs a human with Chromium/Firefox. Keep `PENDING HUMAN EXECUTION`.
- Image assets: Codex-exclusive. Never route to agy or Gemini Flash.
- Binary audio: Gemini Flash audio output pending; procedural SFX remains the shipping fallback.
- Educator sign-off on assessed questions: `OD-012`, human gate.
- Codex CLI review: unavailable. Never claim it happened.

## Rules unchanged

Godot 4.7.2 Stable, Compatibility, GDScript, Windows portable + single-threaded Web; no invented numbers or story; save invariants preserved; per-task report block; commit suffix `[REVIEW_PENDING_CODEX]`; queue entry per task; no `REVIEWED` without a Codex session ID.

Use `scripts/agy/run_next_queue.ps1` (it reads `docs/agy-dispatch-prompt.md`).

## Batch 3 (draft, found during verification of batch 2)

### A. SBL-BLD-002 — Wire the release tier into the build

Batch 2 gated Chapter V in code, but nothing sets the tier at build time: `project.godot` ships `release_tier="full_release"`, and `export_presets.cfg` has only Windows/Web presets with no tier switch. So a build labelled "academic MVP" would still contain an unlocked Void Citadel.

- Add a build parameter (for example `export_release.ps1 -Tier academic_mvp|full_release`) that writes the tier into the exported build only — do not leave the working tree modified afterwards.
- Emit a tier marker into each artifact (for example a `build_tier.txt` inside the zip) and have `validate_release.ps1` assert the marker matches the requested tier.
- Produce `dist/Soulbound-AcademicMVP-Web.zip` with tier `academic_mvp`; keep the full-release artifacts as they are.
- Test: launch the MVP artifact headless (or assert the marker plus a `ReleaseTier` unit check) and confirm `void_citadel` is unavailable in that build.
- Shipping default stays `OD-017`; do not decide it.

### B. SBL-MCP-003 — Keep the MCP proof reproducible

`SBL-MCP-002` passed with `@coding-solo/godot-mcp` on a disposable project, but `scratch/` was deleted, so only the prose report remains.

- Commit the tiny harness (`scratch/run_adapter_test.js` equivalent) plus the generated `mcp_generated_scene.tscn` and `verify_mcp_scene.gd` under a documented `tools/mcp-proof/` path with a README.
- No `node_modules`, no vendored binaries. If the adapter is needed again, the README states the exact `npx` invocation.
- This stays evidence only: production work remains Godot-native files + headless CLI.

### C. Still human-gated (not agy)

Browser smoke execution, image assets (Codex-only), binary audio (Gemini), educator sign-off (`OD-012`), shipping tier (`OD-017`), and Codex CLI review of `e25491d..6f6efa5`.

