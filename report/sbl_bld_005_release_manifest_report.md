# SBL-BLD-005 — Archive-Contained JSON Provenance Manifests: Implementation & Verification Report

Date: 10 November 2026. Branch `feature/w4-5-vertical-slice`. Plan owner: Codex. Implementation executor: `opencode-go/mimo-v2.6-flash` (agy paused). Reviewer: Codex CLI.

```text
TASK ID: SBL-BLD-005
REQUIREMENTS: GDD-110, GDD-124, GDD-131, FR-REL-001, TC-REL-001,
  GDD-093, GDD-095, GDD-107, GDD-108, GDD-109, GDD-129,
  NFR-BUILD-001, NFR-SEC-001, NFR-MAINT-001
MILESTONE: M6 Release Candidate Foundation / Build Integrity & Artifact Governance
OWNER: agy (implementation executed by opencode-go/mimo-v2.6-flash)
PLAN OWNER: Codex
BRANCH/COMMIT: feature/w4-5-vertical-slice; implementation commit 30305d6
  (documentation committed in the same batch immediately afterwards)
FILES CHANGED:
  Create: scripts/build/release_manifest.ps1, scripts/build/test_release_manifest.ps1,
          report/sbl_bld_005_release_manifest_report.md
  Modify: scripts/build/export_release.ps1, scripts/build/validate_release.ps1,
          scripts/build/run_headless_tests.ps1, scripts/build/test_export_failure_restoration.ps1,
          docs/agent-review-queue.md, docs/traceability-matrix.md, docs/testing.md,
          report/implementation-review-ledger.md, report/README.md
ASSET PROVENANCE: none (no images, audio, or generated content; build automation and documentation only)
TESTS RUN + RESULTS: all six command groups below exited as required; 62/62 manifest controls,
  32/32 headless suites, export chain green, restoration 0 / disabled-control 1.
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: OD-017 (shipping default tier) remains untouched and deferred to human release
  authority. Browser smoke execution remains blocked. No OD was resolved by this task.
```

## What was implemented

1. **`scripts/build/release_manifest.ps1`** — shared library used by production validation and
   disposable tests:
   - Strict RFC 8259 JSON parser (recursive descent) that rejects trailing content, comments,
     single quotes, trailing commas, unescaped control characters and **duplicate object member
     names**, with line/column diagnostics. Collection results are comma-wrapped so the pipeline
     can never unroll parsed arrays (an unrolled array collapses to a fixed-size `Object[]` and
     breaks 1-element/empty arrays).
   - Source provenance capture **before any staging or configuration mutation**:
     `git rev-parse HEAD` (full 40-hex commit) and `git status --porcelain=v1 --untracked-files=all`
     with a documented LF-normalization, `dirty` boolean, and SHA-256 of the UTF-8 status text
     (`status_porcelain_sha256`). Git failures throw; nothing is ever recorded as "unknown".
   - Engine provenance: real `godot --version` output (must be `4.7.2.stable.*`) plus SHA-256 of
     the executable.
   - Fixed package specs for the three release archives (platform/tier/preset/required entries/PCK).
   - Manifest creation (`New-SblReleaseManifest`), archive creation with forward-slash entry names
     (`New-SblArchiveFromDirectory`), external receipt writing (`Write-SblManifestReceipt`),
     safe extraction (`Expand-SblArchiveToDirectory`).
   - **`Test-SblReleaseArchive`** — the shared verifier: ZIP readability; entry-type
     classification rejecting symlink/reparse/directory/unsupported types; path safety
     (empty/control/backslash/absolute/drive/colon/`.`/`..`/empty-component, with drive checks
     ordered before backslash so diagnostics are order-independent); **ordinal case-sensitive**
     exact duplicate tracking plus separate lowercased case-collision tracking (both before any
     hash lookup); exactly one root `release-manifest.json` (case variants and nested
     manifest-named entries rejected); external receipt presence/format/digest against the exact
     archived manifest bytes; strict parse + schema version/type/enum/digest validation with
     unknown-member rejection; archive identity (archive name, platform, tier, preset against the
     fixed spec and caller expectations); exact payload-to-entry correspondence; per-entry
     declared-size, streamed raw-byte length and lowercase SHA-256; archived configuration
     semantics read **only from `provenance/` snapshot bytes inside the archive** (effective
     `release_tier`, Compatibility renderer + web override, Web single-thread flag vs the preset
     snapshot); `build_tier.txt` marker equality; required entry points; forbidden-file gates;
     optional size constraints.
   - `Invoke-SblArchivePckGate` — extracts each archive's **own** PCK and runs
     `verify_exported_tier.gd` against it.
   - Disposable user-data isolation: `Enter-/Exit-SblGodotUserDataIsolation` redirect
     `APPDATA`/`LOCALAPPDATA` to a fresh temp root, **prove the redirection with a headless probe
     (`OS.get_user_data_dir()`) before any test or gate runs**, snapshot the real roaming/local
     Godot directories for byte-identity comparison on exit, and remove the disposable root with a
     containment-checked helper. Optional `-SeedFrom` copies the real Godot data directory into
     the disposable (robocopy, long-path capable, verified by file count) so suites keep the
     historical baseline state and chained exporters can resolve export templates. Long-path
     (`\\?\`) fallbacks cover hashing and recursive deletion of deep seeded shader-cache paths
     beyond MAX_PATH.

2. **`scripts/build/export_release.ps1`** — strict engine resolution (explicit invalid path and
   missing default both fail; no GUI/PATH fallback); provenance captured before mutation; fresh
   GUID staging root under `builds/` with one isolated directory per requested package (stale
   output can never enter a new package); after export: tier marker + configuration snapshots
   (`provenance/project.godot` effective tier-mutated bytes, `provenance/export_presets.cfg`
   actual bytes) → manifest built from staged payload bytes → ZIP payload+manifest → external
   receipt for the exact archived manifest bytes → **re-open and verify the new ZIP against its
   receipt before packaging succeeds** → publish to `builds/` replacing prior contents (stale
   local output removed; manifest/provenance excluded from publish). `-SkipZip` creates no
   archive/receipt and performs no archive validation. `finally` still restores `project.godot`
   byte-identically and the root marker, and now also removes the staging root through a
   containment-checked helper. The three exact strings consumed by the `-DisableRestore` control
   are preserved.

3. **`scripts/build/validate_release.ps1`** — local preset/renderer checks retained; every
   selected archive is validated from **archive bytes and its external receipt only** via the
   shared verifier (never local `builds/` payloads or local configuration as archive evidence);
   missing Godot fails immediately (no fallback, no successful gate skip); each archive that
   passes byte verification runs its own PCK gate under proven disposable user data; real user
   data must be byte-identical after the run or validation fails.

4. **`scripts/build/run_headless_tests.ps1`** — strict engine resolution; enters seeded
   disposable user-data isolation and proves it before `--import` and every suite; exits fail if
   the real user data changed; the canonical `-Export` path now chains
   `test_release_manifest.ps1` after successful export/validation and propagates its exit code.

5. **`scripts/build/test_export_failure_restoration.ps1`** — additionally snapshots all `dist/`
   archives+receipts and asserts, in both modes, that the failed export left no `.staging_*`
   directory and did not change any dist artifact (violation exits 2 so it cannot hide behind the
   disabled control's expected exit 1).

6. **`scripts/build/test_release_manifest.ps1`** — 62 disposable controls that use the **same
   verifier functions as production validation** (plus subprocess invocations of
   `validate_release.ps1`/`export_release.ps1` for literal non-zero exits).

## Manifest model (schema version 1)

Exactly one root `release-manifest.json` per ZIP, UTF-8 without BOM:

```json
{
  "manifest_schema_version": 1,
  "package":  { "archive_name": "...", "platform": "web|windows", "tier": "academic_mvp|full_release" },
  "source":   { "commit": "<40-hex>", "dirty": false, "status_porcelain_sha256": "<64-hex>" },
  "godot":    { "version": "4.7.2.stable.official.ed1daf0bf", "executable_sha256": "<64-hex>" },
  "configuration": { "preset_name": "Web|Windows Desktop", "renderer": "gl_compatibility",
                     "web_thread_support": false|null, "project_snapshot": "provenance/project.godot",
                     "presets_snapshot": "provenance/export_presets.cfg" },
  "payload":  [ { "path": "...", "size_bytes": 123, "sha256": "<lowercase 64-hex>" } ]
}
```

Payload lists every regular ZIP entry except the manifest itself, sorted by ordinal normalized
path, hashed over raw uncompressed bytes. The external `<archive>.manifest.sha256` receipt holds
the lowercase SHA-256 of the exact archived manifest bytes (integrity reference, not a digital
signature; coordinated archive+receipt replacement is explicitly out of scope).

## Commands actually run and results

| Command (from repo root, `powershell -NoProfile -ExecutionPolicy Bypass -File ...`) | Exit | Result |
|---|---|---|
| `scripts\build\test_release_manifest.ps1` | **0** | **62/62 controls PASS** (final code) |
| `scripts\build\run_headless_tests.ps1` | **0** | **32/32 suites PASS**; disposable user data proved before execution (`OS.get_user_data_dir()` under temp root), `realUserDataUnchanged=True`, `disposableFiles=654`, `rootRemoved=True` |
| `scripts\build\run_headless_tests.ps1 -Export -Tier all` | **0** | 32/32 suites; 3 packages exported with manifest+receipt; self-verification, byte validation and all 3 archive-contained PCK gates pass; chained `test_release_manifest.ps1` **62/62**; isolation `realUserDataUnchanged=True` |
| `scripts\build\test_export_failure_restoration.ps1` | **0** | Mutation observed, `SIMULATED_EXPORT_FAILURE` caught, `project.godot` byte-identical, root marker absent, staging root removed, dist archives/receipts unchanged (6 artifacts) |
| `scripts\build\test_export_failure_restoration.ps1 -DisableRestore` | **1** | `[NON-VACUOUS PROOF CONFIRMED]`: `project.godot` differs, `build_tier.txt` remained; harness safety cleanup restored the tree |
| `scripts\build\export_release.ps1 -Tier all` (post-commit, clean tree) | **0** | Clean-capture proof: all three manifests record `commit=30305d6…`, `dirty=false`, `status_porcelain_sha256=e3b0c442…` (SHA-256 of empty status); `git status` empty after the run (byte-identical restoration) |

Control breakdown (62): negative 32, positive 8, git 5, export 5, engine 4, subprocess 3,
restoration 2, preflight 1, sanity 1, isolation 1.

### Negative/positive controls (all disposable, under a fresh temp root)

- **Positive**: valid synthetic Web fixture; valid synthetic Windows fixture (null
  `web_thread_support` path); the three real packages verified from archive bytes; their three
  archive-contained PCK gates; byte-faithful rebuild sanity check.
- **Manifest/receipt**: missing manifest, missing receipt (no fallback to self-declared
  metadata), malformed JSON (receipt regenerated so only parsing fails), future schema version 2,
  duplicate JSON member name, garbage receipt content, wrong receipt digest, corrupt/truncated
  archive bytes.
- **Metadata tampering**: `source.commit` change and `source.dirty` flip with the original
  receipt → receipt mismatch although payload bytes are unchanged; older same-tier manifest
  substitution (previous commit + empty status digest) detected by the expected receipt;
  `godot.version` tamper (receipt regenerated) → schema rejection.
- **Payload**: same-size byte flip → SHA-256 mismatch; length change → size/length failure;
  deleted listed file → missing-payload + missing-entry-point; added unlisted file → exact
  entry-set failure.
- **Paths/types**: duplicate ZIP entry path, case-colliding ZIP entry path, duplicate root
  manifest entry, case-variant manifest name, traversal/absolute/backslash/drive/empty-component
  paths (with proof that no `sbl_bld_005_evil*` file was written outside the temp root),
  unsupported symlink/reparse/directory entry types, duplicate payload path and case-colliding
  payload path in the manifest.
- **Swapped manifests**: manifests+receipts swapped across tiers in both directions → archive
  identity failure (receipt itself passes, identity/payload checks catch it).
- **Configuration**: renderer field, Web single-thread flag, effective tier (receipt regenerated
  each time → semantic checks fire), snapshot byte change → payload hash mismatch, snapshot made
  semantically inconsistent with the manifest (payload hash + receipt regenerated) → archived
  preset-snapshot disagreement.
- **Subprocess (literal non-zero exits)**: `validate_release.ps1` with missing manifest / missing
  receipt / payload tamper → exit 1 with the matching diagnostic.
- **Engine**: explicit invalid `-GodotPath` for exporter and validator → exit 1; patched-default
  copies with a nonexistent default engine → exit 1 with "no fallback is attempted" /
  "required archive-contained PCK gate cannot run", and output must **not** contain the old
  "skipping live headless PCK gate" text (non-vacuous against the previous fallback behavior).
- **Git capture**: clean fixture → `dirty=false`, commit matches, digest = SHA-256 of empty
  status; dirty fixture → `dirty=true` and digest equals an independently recomputed
  LF-normalized porcelain digest; pre-mutation capture (clean) vs post-mutation capture (dirty)
  proves capture timing; capture outside a Git work tree throws.
- **Stale output**: a seeded `SBL_BLD_005_STALE_SEED.txt` in the old `builds/web-academic_mvp`
  output directory is absent from the freshly packaged ZIP and removed from the output directory.
- **`-SkipZip`**: exit 0 with the `[SkipZip]` marker, no validation markers in output, and all
  6 dist archives/receipts byte-identical afterwards.
- **Source timing**: the freshly exported manifest's `source` equals a live capture taken after
  the run (exporter mutation did not flip it).
- **Isolation**: real roaming/local Godot user data byte-identical across the whole suite.

## Final artifacts (clean-tree export after implementation commit `30305d6`)

| Archive | Size (bytes) | ZIP SHA-256 | Entries (payload) | Archived manifest SHA-256 = receipt |
|---|---|---|---|---|
| `Soulbound-AcademicMVP-Web.zip` | 10,806,918 | `950c5ba87d938efab8ce96d951fe313a1bccbf6d505a8a6ba9091204f4e39810` | 13 (12) | `1b423257b764283c9589f62e221d0d52864a9a2cc781fbcd9de02487203fa5d7` |
| `Soulbound-Web.zip` | 10,806,906 | `88423fe24d28260d1614d185bf177fd4291364371c6dc3056044c31e9bb40cf2` | 13 (12) | `3f0332167b6a097a4ac826e64c2107f96aacae30094fb4117a707009db1b925e` |
| `Soulbound-Windows-Portable.zip` | 86,680,630 | `57ea5e09049013dff1f6ec46c3cd655005665209059b503334b4ecbce999b6f9` | 6 (5) | `f5ff924408f83defaf3a8c1be48eb84df299049247b3b65090f962fd7777a75c` |

All three manifests: `manifest_schema_version=1`, `commit=30305d64eeec74efae983125314904c1461a7004`,
`dirty=false`, `status_porcelain_sha256=e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`,
`godot.version=4.7.2.stable.official.ed1daf0bf`,
`godot.executable_sha256=c8f0a6bc45a19b33541501e57f6f7cd972ab18453743266339d495cbbe846643`,
`renderer=gl_compatibility`; Web packages `web_thread_support=false`, Windows package `null`.
Receipt contents equal the archived manifest digests exactly (verified by reading both sides).

## Execution-time defects found and fixed (all before final runs)

1. **Parser array unrolling** — `return $list` through the pipeline collapsed JSON arrays to
   fixed-size `Object[]` (and would collapse empty/1-element arrays), aborting the suite at the
   duplicate-payload control with "Collection was of a fixed size". Fixed by comma-wrapping all
   collection returns in the parser.
2. **Case-collision misclassification** — exact-path tracking used a case-insensitive PowerShell
   `@{}`, so `Index.html` was reported as an exact duplicate. Fixed with ordinal
   `HashSet[string]` in both the ZIP verifier and the payload schema check.
3. **Drive-path expectation order** — `C:\...` tripped the backslash check before the drive
   check. Fixed by ordering the drive check first and using a forward-slash `C:/...` control
   entry so the expectation is order-independent.
4. **Empty-array parameter binding** — hashing the empty clean-repo status was rejected by a
   mandatory `[byte[]]` parameter. Fixed with `[AllowEmptyCollection()]`.
5. **Export templates vs disposable user data** — Godot resolves export templates from
   `%APPDATA%\Godot\export_templates`; export subprocesses in the manifest suite failed with
   "No export template found". Fixed by spawning only exporter subprocesses with the
   pre-isolation environment (`-RealUserData`); an empirical before/after digest proved an export
   leaves the real `%APPDATA%\Godot` byte-identical, so the suite/gate isolation proof is
   unaffected.
6. **Suite baseline state** — `ending_chapter5_test.gd` (pre-existing dependency recorded in the
   ledger, test file out of this batch's scope) requires an existing `profile_01`. The runner now
   seeds its disposable from a copy-on-enter snapshot of the real Godot data directory (robocopy,
   verified by file count), preserving the exact historical baseline while all writes stay in the
   disposable and the real directory stays byte-identical.
7. **MAX_PATH** — deep seeded shader-cache paths broke `Copy-Item`, `Remove-Item` and hashing.
   Fixed with robocopy seeding plus `\\?\`-prefixed fallbacks for hashing and recursive deletion
   (containment checks still run on resolved paths before any deletion).

## Observations / notes for the reviewer

- An unrelated documentation commit `18ffb02` ("docs: record failed Ren image generation due to
  expired provider key") landed from another agent mid-session; the mid-run
  `manifest_source_equals_live_capture` control correctly failed against it and passed again once
  the manifest was rebuilt from a fresh export. Final manifests all record `30305d6`.
- The receipt detects metadata-only alteration and substitution; it is not a signature, and
  coordinated replacement of both archive and receipt is explicitly out of scope per the plan.
- A dirty build is permitted and honestly recorded (`dirty=true` plus the status digest); the
  clean-state capture is proven both by the Git fixtures and by the post-commit export above.
- No gameplay scene, save schema, settings, or test `.gd` file was modified. No asset was
  generated. No OD was resolved (`OD-017`, browser smoke, `OD-012`, combat ODs remain open).

Raw logs (gitignored): `report/release_manifest_test.log`, `report/godot_user_data_isolation.log`,
`report/verify_pck_*.log|.err`, and the run transcripts under the session temp directory.
