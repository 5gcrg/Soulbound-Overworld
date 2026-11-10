# Next Work Queue — OD-013 Performance Evidence

Plan owner: OpenCode/Codex plan draft. Implementation executor: `opencode-go/mimo-v2.6-flash`. Codex CLI review deferred.

## Ratified scope

- Reference hardware: owner's current Windows machine; capture exact specifications.
- Browsers: Chromium, Firefox, and additional available owner-selected browsers.
- Target: 60 FPS with documented 30 FPS fallback.
- Scenes: title, overworld, combat, dungeon, learning journal.
- Measurement: automated capture plus manual profiling evidence.
- No maximum build-size budget.
- Below-target result: warn and record; do not automatically fail release.
- Web: Godot 4.7.2 Compatibility, single-threaded.
- Performance evidence is included in the canonical release gate with warning semantics.

## Requirements

- GDD-093..097, GDD-104, GDD-107, GDD-123, GDD-124, GDD-129.
- FR-REL-001, TC-REL-001, TC-WEB-001/002, NFR-PERF-001, NFR-WEB-001, NFR-BUILD-001.
- OD-013 ratification: `report/od013-ratification.md`.

## Implementation

Create `scripts/build/performance_evidence.ps1`, `scripts/build/test_performance_evidence.ps1`, and `report/od013_performance_report.md`.

Modify only as needed: `scripts/build/run_headless_tests.ps1`, `scripts/build/export_release.ps1`, `scripts/build/validate_release.ps1`, `docs/browser_verification_checklist.md`, `docs/agent-review-queue.md`, `docs/traceability-matrix.md`, `docs/testing.md`, and report ledger files.

- Capture machine specs and actual Godot version/configuration.
- Measure title, overworld, combat, dungeon, and learning journal.
- Record average/minimum FPS, frame timing, scene, environment, and browser/device metadata where available.
- Automated evidence must distinguish headless/native evidence from human browser smoke; never claim browser acceptance automatically.
- 60 FPS is the target; 30 FPS is the documented fallback.
- Below-target results warn and remain exit 0; the report records the warning.
- No build-size limit may be introduced.
- Preserve existing export, PCK, save, and restoration gates.

## Acceptance

- Positive capture runs for all five scenes.
- Invalid/missing engine or incompatible renderer/thread configuration fails preflight.
- A disposable below-target fixture emits a warning but does not fail the release gate.
- Canonical `-Export` path includes performance evidence.
- Browser checklist remains human/manual and pending until executed by the owner.
- Run targeted tests, canonical headless tests, export validation, and restoration controls.
- Record actual results in `/report` and commit with `[REVIEW_PENDING_CODEX]`.

## Boundaries

- No browser acceptance claim.
- No maximum size budget.
- No image/audio generation, combat/story decisions, or other OD resolution.
- Codex CLI review is deferred.
