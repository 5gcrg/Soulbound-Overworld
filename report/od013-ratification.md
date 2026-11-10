# OD-013 Ratification — Platform and Performance Evidence

**Status:** Ratified for scoped implementation by project owner  
**Date:** 10 November 2026  
**Plan status:** `PLAN_DRAFT_NOT_CODEX`; Codex CLI unavailable

## Ratified decisions

- Reference hardware: the owner's current Windows machine; capture exact hardware details during implementation.
- Browser coverage: Chromium, Firefox, and additional owner-selected browsers where available.
- Performance target: 60 FPS with documented 30 FPS fallback.
- Measured scenes: title, overworld, combat, dungeon, and learning journal.
- Measurement method: combined automated MiMo capture plus manual profiling evidence.
- Build-size budget: no maximum budget is imposed.
- Threshold behavior: warn and record when below target; do not automatically block release.
- Web target: Godot 4.7.2 Compatibility, single-threaded Web.
- Release integration: performance evidence becomes a canonical release test gate, with warning semantics and recorded results.

## Still human-controlled

Browser availability and manual profiling execution remain human-environment
checks. No claim of browser acceptance is made until those checks are run.
