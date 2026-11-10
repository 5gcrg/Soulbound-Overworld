# SBL-TEST-ISOLATION-001 — Five-Suite Profile Write Isolation

- **Date** 11 November 2026
- **Scope** Test fixtures only; no production save, gameplay, OD-010/011, image, audio, or browser implementation changes.
- **Review status** `REVIEW_PENDING_CODEX`. No Codex CLI review is claimed.
- **Queue** [`docs/agent-review-queue.md`](../docs/agent-review-queue.md) → `SBL-TEST-ISOLATION-001`.

## Implementation

`tests/support/profile_test_isolation.gd` supplies one unique disposable root per
suite/process and a `ProfileStore` rooted below it. The store contains a valid,
minimal `profile_01` baseline because the existing GameRoot save boundaries
require one. Each affected suite injects that store before adding GameRoot to the
scene tree, so `_ready()` cannot fall back to the production default
`user://profiles` store.

The helper recursively snapshots `user://profiles/profile_01` as relative path →
raw bytes before fixture setup. At suite exit it compares the current file set
and bytes, reports added/modified/removed paths on drift, and fails the suite on
any difference. Cleanup is restricted to the generated
`user://test_profile_isolation_*` root. `ProfileStore` and GameRoot production
code are untouched.

Affected suites:

- `tests/headless/ending_chapter5_test.gd`
- `tests/headless/evaluator_debug_bar_test.gd`
- `tests/headless/release_tier_test.gd`
- `tests/headless/title_screen_audio_test.gd`
- `tests/headless/verify_exported_tier.gd`

## Verification — Godot 4.7.2 Stable `ed1daf0bf`, Windows

### Targeted canonical runs

Each command below exited 0 and its suite passed. The canonical runner also
reported `realUserDataUnchanged=True` and removed its outer disposable root.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite ending_chapter5_test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite evaluator_debug_bar_test -SkipImport
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite release_tier_test -SkipImport
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite title_screen_audio_test -SkipImport
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1 -Suite verify_exported_tier -SkipImport
```

### Direct runs against the real user-data location

To exercise the new suite-local guards independently of the runner's outer
redirection, all five suites were also run sequentially with the Godot console
binary, with **no** `APPDATA`/`LOCALAPPDATA` override:

```text
Godot_v4.7.2-stable_win64_console.exe --headless --path <worktree> --fixed-fps 60 \
  --script res://tests/headless/<suite>.gd --quit-after 600
```

An external SHA-256 manifest compared the real
`%APPDATA%\Godot\app_userdata\Soulbound\profiles\profile_01` before and after
**each** direct run:

| Suite | Exit | Files before / after | Added | Removed | Modified | Byte-identical |
|---|---:|---:|---:|---:|---:|---|
| `ending_chapter5_test.gd` | 0 | 2 / 2 | 0 | 0 | 0 | Yes |
| `evaluator_debug_bar_test.gd` | 0 | 2 / 2 | 0 | 0 | 0 | Yes |
| `release_tier_test.gd` | 0 | 2 / 2 | 0 | 0 | 0 | Yes |
| `title_screen_audio_test.gd` | 0 | 2 / 2 | 0 | 0 | 0 | Yes |
| `verify_exported_tier.gd` | 0 | 2 / 2 | 0 | 0 | 0 | Yes |

The final external comparison over all of real `user://profiles`, against the
baseline captured before implementation/testing, likewise found **5 files before
and after, 0 added, 0 removed, 0 modified**. The two real `profile_01` revisions
retained their original lengths and hashes:

| Revision | Bytes | SHA-256 |
|---|---:|---|
| `profile.0000000000000434.10116.87022165.json` | 2922 | `925E05C9CC836F671F9B885BB1FCC1728E3463FFDE62A8508B80F40993D2922D` |
| `profile.0000000000000435.10116.87034589.json` | 2920 | `160BD37A3FEF2DEC7B479FE912957ECD6DDB82C7735CD8723CB0949A33EB43A7` |

No `test_profile_isolation_*` directories remained in the real Soulbound user
folder after the direct runs. A full recursive copy of the real Soulbound user
folder and the before/after manifests/direct logs were retained under
`%LOCALAPPDATA%\Temp\opencode\od013-profile-test-isolation-kimi` on the test
machine.

### Canonical regression

```text
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build\run_headless_tests.ps1
Exit 0; import clean; 35/35 suites passed;
realUserDataUnchanged=True; disposableFiles=655; rootRemoved=True.
```

The canonical run includes the OD-010/011 suite, but no OD-010/011 implementation
file was changed. Exported PCK packaging and browser execution were not run;
`verify_exported_tier.gd` passed as a headless suite, and no browser or release
acceptance is claimed.

## Required AGENTS.md report block

```text
TASK ID: SBL-TEST-ISOLATION-001
REQUIREMENTS: GDD-098/099/100/109/124, FR-SAV-001, TC-SAV-001, NFR-MAINT-001, TC-AGY-001
MILESTONE: M6 QA / save-data protection hardening
OWNER: agy
PLAN OWNER: Codex
BRANCH/COMMIT: isolated detached worktree od013-test-isolation-kimi, base 835a19b; this [REVIEW_PENDING_CODEX] commit (hash supplied in final handoff)
FILES CHANGED: tests/support/profile_test_isolation.gd (+ UID), tests/headless/ending_chapter5_test.gd, evaluator_debug_bar_test.gd, release_tier_test.gd, title_screen_audio_test.gd, verify_exported_tier.gd, docs/testing.md, docs/agent-review-queue.md, report/sbl_test_isolation_001_report.md
ASSET PROVENANCE: none
TESTS RUN + RESULTS: five targeted canonical suites exit 0; five direct suites exit 0 with per-suite external SHA-256 profile_01 diff 0; final real user://profiles diff 0 (5/5 files); canonical 35/35 exit 0 with realUserDataUnchanged=True; zero disposable-root leftovers
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS: none design-related; Codex CLI review pending; exported PCK packaging and browser gates not run and not claimed
```
