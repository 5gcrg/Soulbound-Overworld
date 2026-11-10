# Unimplemented / Deferred Work Inventory

**Date:** 10 November 2026  
**Status:** Inventory only; no implementation started by this report.

## Tags

- `[AGENT-NEXT]` — implementation may proceed after Codex plan and owner approval.
- `[HUMAN-GATE]` — requires human/product/QA/educator approval or execution.
- `[OD-BLOCKED]` — blocked by an unresolved `OD-###`; do not invent values/content.
- `[ASSET-BLOCKED]` — requires an approved asset-generation or licensing workflow.
- `[REVIEW-PENDING]` — implemented evidence exists, but Codex CLI review is deferred.
- `[OUT-OF-SCOPE]` — intentionally excluded from the current academic MVP or approved slice.

## Current implementation/review status

### `[REVIEW-PENDING]` SBL-BLD-005 review

Archive-contained JSON provenance manifests are implemented and verified:

- `62/62` manifest controls pass.
- `32/32` headless suites pass.
- All three release packages and archive-contained PCK gates pass.
- Restoration controls pass.

Codex CLI review is deferred at the owner’s direction. This is not unimplemented code; it is pending review.

### `[REVIEW-PENDING]` Historical queue status

The implementation slices from `e25491d` through `30305d6` have evidence and recorded reviews as described in
`docs/agent-review-queue.md`. Historical rows marked `REVIEW_PENDING_CODEX` or stale review text do not mean the
feature is absent; consult the later remediation/re-review entries and the session ledger before reopening work.

## Human-gated work

### `[HUMAN-GATE]` Browser acceptance

- **GDD-123, NFR-WEB-001, TC-WEB-001, TC-WEB-002:** Chromium and Firefox smoke execution using the documented checklist.
- Requires human QA/browser execution; headless Godot and export validation are not browser acceptance.

### `[HUMAN-GATE]` Educator and assessment approval

- **GDD-127, OD-012, FR-EDU-001..004, NFR-EDU-001:** educator review of question banks, rubrics, hint thresholds, validity, and classroom deployment.
- Current implementation deliberately remains completion-gated and makes no learning-improvement claim.

### `[HUMAN-GATE]` Shipping and release acceptance

- **OD-017:** choose `academic_mvp` versus `full_release` for public shipping.
- **GDD-111:** publish the Web build.
- **GDD-132:** formal multi-area release acceptance.
- **GDD-131:** final tagged/public release handoff and authorization.

### `[HUMAN-GATE]` Platform/performance acceptance

- **GDD-104, NFR-PERF-001, OD-013:** ratify reference hardware, browser targets, build-size budgets, and FPS telemetry method.
- No unsupported performance budget or hardware claim may be invented.

## OD-blocked design work

These are design/content decisions, not authorized implementation gaps:

- `[OD-BLOCKED] OD-001` — Ren’s forgotten origin, villain, narrative branches, and ending triggers; affects GDD-009..015, GDD-041.
- `[OD-BLOCKED] OD-002` — Speed initiative/extra-turn model; affects GDD-016/018/023 and combat tests.
- `[OD-BLOCKED] OD-003` — elemental counter chart, damage formulas, SP costs, cooldown curves; affects GDD-017/019/021.
- `[OD-BLOCKED] OD-004` — status timing/stacking and boss resistances; affects GDD-020/022.
- `[OD-BLOCKED] OD-005` — EXP curve, base stats, and level budgets; affects GDD-024/025.
- `[OD-BLOCKED] OD-006` — refinement caps, rarity rolls, crafting values, and failure penalties; affects GDD-026..028.
- `[OD-BLOCKED] OD-007` — inventory caps, stack sizes, currency banking, and expedition earnings; affects GDD-029/030.
- `[OD-BLOCKED] OD-008` — permanent EXP/currency loss policy on expedition defeat; affects GDD-034/035.
- `[OD-BLOCKED] OD-009` — mid-battle and partial-turn save boundary; affects GDD-098..100 and FR-SAV-001.
- `[OD-BLOCKED] OD-010` — quest scripts, factions, reputation, and full NPC roster; affects GDD-036..041 and FR-QST-001.
- `[OD-BLOCKED] OD-011` — dungeon module pool, connection grammar, and difficulty budgets; affects GDD-042..048 and FR-DNG-001/003.
- `[OD-BLOCKED] OD-014` — production Godot-compatible MCP adapter; current supported path remains native files/headless CLI.

## Asset and licensing work

- `[ASSET-BLOCKED] OD-015` — binary music/SFX workflow. Procedural runtime audio remains the fallback; no binary audio was generated.
- `[ASSET-BLOCKED] OD-016` — final asset quantities, sprite-frame targets, and licensing/attribution register.
- `[ASSET-BLOCKED] Image assets` — Codex-exclusive. The recent Ren image attempt failed because the provider API key expired; no image file was produced.

## Deferred full-release content

- `[OUT-OF-SCOPE] GDD-116` — the full five-chapter release and two-ending narrative are separate from the three-chapter academic MVP.
- `[OD-BLOCKED]` Full-release narrative details, ending triggers, faction content, and lore remain governed by OD-001/010.
- `[OD-BLOCKED]` Advanced boss effects for purchased skills remain partial under OD-003/004; unsupported actions are intentionally disabled rather than invented.

## Potential future agent work

These may be proposed as new Codex-planned slices only after owner approval:

- `[AGENT-NEXT]` Isolate the five pre-existing headless suites that still write `user://profiles/profile_01` during tests; this is separate from the completed SBL-EDU-005 fix and needs a new scope/plan.
- `[AGENT-NEXT]` Maintenance cleanup or traceability reconciliation for stale historical review rows, without changing implementation status claims.
- `[AGENT-NEXT]` Any new non-OD technical hardening exposed by human QA or later Codex review.

## Not counted as unimplemented

- Godot 4.7.2 Compatibility/GDScript foundation, MVP chapters, saves, dungeon persistence, accessibility, rebinding,
  learning journal/reporting, release export validation, and provenance manifests have implementation evidence.
- Their remaining review or human acceptance status does not mean their code is absent.
