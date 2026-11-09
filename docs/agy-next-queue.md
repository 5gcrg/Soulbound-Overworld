# Next Work Queue — SBL-BLD-005

Plan owner: Codex. Implementation executor: `opencode-go/mimo-v2.6-flash`. Reviewer: Codex CLI. agy is paused.

## Approved scope

Owner approval received for the Codex plan on archive-contained JSON provenance manifests.

### Requirements

- GDD-110, GDD-124, GDD-131
- FR-REL-001, TC-REL-001
- GDD-093, GDD-095, GDD-107, GDD-108, GDD-109, GDD-129
- NFR-BUILD-001, NFR-SEC-001, NFR-MAINT-001

### Files

Create:

- `scripts/build/release_manifest.ps1`
- `scripts/build/test_release_manifest.ps1`

Modify:

- `scripts/build/export_release.ps1`
- `scripts/build/validate_release.ps1`
- `scripts/build/run_headless_tests.ps1`
- `scripts/build/test_export_failure_restoration.ps1`
- `docs/agent-review-queue.md`
- `docs/traceability-matrix.md`
- `docs/testing.md`
- `report/implementation-review-ledger.md`

### Required behavior

- Every requested ZIP contains exactly one root `release-manifest.json`.
- Write an external `<archive>.manifest.sha256` receipt for the exact manifest bytes.
- Record full source commit, dirty state/status digest, actual Godot version and executable hash, platform, tier, preset, renderer/thread configuration, snapshots, and raw payload sizes/SHA-256 hashes.
- Validate archive bytes, not local `builds/` substitutes.
- Reject missing/altered/swapped manifests or receipts, malformed/future JSON, duplicate/case-colliding paths, traversal/absolute/backslash/unsafe Windows paths, unsupported entry types, missing/extra payloads, size/hash mismatches, stale output, and semantic tier/platform/configuration mismatches.
- Preserve archive-contained PCK validation, existing forbidden-file/entry-point gates, `-SkipZip` semantics, and byte-identical restoration of `project.godot`, markers, and presets on failures.
- Use fresh isolated staging directories and verify cleanup paths stay inside their staging root.
- Chain `test_release_manifest.ps1` into the canonical `-Export` path and propagate failures.

### Acceptance matrix

Use the same verifier functions for production and disposable synthetic tests:

- Valid synthetic fixture passes.
- Academic MVP Web, Full Web, and Full Windows packages pass their own manifest and PCK validation.
- Missing receipt/manifest, malformed/future manifest, changed source metadata, changed payload bytes/length, deleted/added files, duplicate/colliding/traversal paths, swapped manifests, altered configuration, stale output, Git/engine failures, packaging failure, and verification-disabled controls fail nonzero.
- Clean/dirty Git fixtures capture correct provenance before exporter mutation.
- `-SkipZip` creates no new archive/receipt and does not validate stale archives.
- Existing restoration positive control exits 0; disabled-restoration control exits 1 with expected evidence.
- Prove every Godot test/PCK gate uses disposable user data before execution.

### Boundaries

No images, browser smoke, publishing, tagging, signing, release authorization, shipping-tier choice (`OD-017`), educator work (`OD-012`), binary audio, combat ODs, or new performance budgets.

### Reporting

Record actual commands, suite count, artifact hashes/sizes, negative-control exits, base/implementation commits, and all findings in `/report` and `docs/agent-review-queue.md`. Commit with `[REVIEW_PENDING_CODEX]`. Do not mark reviewed.

Use Godot 4.7.2 Stable, Compatibility renderer, Windows portable and single-threaded Web constraints.
