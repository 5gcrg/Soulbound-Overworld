IΓÇÖll split this into three batches, with Codex review between them. Rebinding changes input handling across the app; 
the journal builds on that behavior; packaging should capture their reviewed result.

One manifest detail needs an explicit check: an archive cannot authenticate changes to its own manifest. The plan will 
keep the manifest inside each ZIP and write its expected SHA-256 to a companion receipt outside the ZIP. The validator 
will check both the receipt and every payload hash.
codex
Use **three sequential agy batches**, one task per batch, with Codex CLI review between batches. UX changes input 
handling; EDU adds another modal and consumes that behavior; BLD packages the resulting reviewed code. Separate 
commits and reviews make failures attributable and avoid combining input, assessment, and packaging risks.

The following is paste-ready queue content. No files were modified.

---

**Execution contract**

- Plan owner: Codex. Implementation owner: agy. Reviewer: Codex CLI; agy does not review its own work.
- Target: **Godot 4.7.2 Stable, GDScript, Compatibility renderer, Windows portable and single-threaded Web**.
- No generated images, audio, question content, dialogue, or story content.
- Preserve existing save invariants and completion gates.
- Every task uses an isolated feature branch, records its base/commit hashes, updates traceability and review 
evidence, and ends as `REVIEW_PENDING_CODEX`.
- Do not rerun SBL-BLD-004 as unfinished work: it is REVIEWED.
- Before Batch 1, obtain Codex CLI review of **SBL-FIX-001..005**, accounting for subsequent reviewed fixes. Review 
findings requiring remediation become separate scoped fixes. Do not infer approval of their balance, story, or asset 
choices from passing tests.
- Use authoritative IDs from `Soulbound_GDD_SRS.md`; do not copy conflicting descriptions or nonexistent FR IDs from 
older queue entries.
- Browser smoke execution remains blocked. Test download preparation through an injectable delivery boundary; do not 
report that as browser execution.
- Each task updates:
  - `docs/agent-review-queue.md`
  - `docs/traceability-matrix.md`
  - `docs/testing.md`
- Record actual tests and results, not anticipated passes. Preserve human acceptance gates.

### Batch 1 ΓÇö SBL-UX-001: Persistent keyboard/mouse rebinding

**Requirements**

- GDD-092: configurable keyboard/mouse inputs and accessibility.
- FR-SET-001: persist and consistently apply remapped inputs and existing settings.
- TC-ACC-001: input rebinding and accessible settings.
- Supporting NFR-ACC-001.

**Dependencies**

- Review closure for the existing settings/modal integration in SBL-FIX-001..005.
- Existing reviewed focus-following, layout and modal-exclusivity behavior.
- No OD resolution required for the scoped binding mechanism.

**Files**

Create:

- `scripts/settings/input_bindings.gd`
- `tests/headless/input_rebinding_test.gd`

Change:

- `scripts/settings/settings_manager.gd`
- `scenes/ui/settings_sheet.gd`
- `scenes/ui/settings_sheet.tscn`
- `scenes/main/game_root.gd`
- `scenes/ui/evaluator_debug_bar.gd`
- `tests/headless/settings_accessibility_test.gd`
- `tests/headless/layout_audit_test.gd`

Do not change existing input defaults in `project.godot`.

**Settings data model**

Keep settings at `user://settings.json`, shared across profiles. Introduce settings schema version `1`, independent of 
profile-save schema `1`.

Example of the new fields, alongside existing audio/accessibility fields:

```json
{
  "settings_schema_version": 1,
  "input_overrides": {
    "move_left": [
      {
        "kind": "key",
        "physical_keycode": 65
      }
    ],
    "toggle_inventory": [
      {
        "kind": "mouse_button",
        "button_index": 3
      }
    ]
  }
}
```

Rules:

- An absent action means ΓÇ£use all authored defaults.ΓÇ¥
- An override replaces only that actionΓÇÖs keyboard/mouse events.
- Preserve its deadzone, other event types, and every unrelated action.
- Store primitive JSON values only; never serialize `InputEvent` objects.
- Scope configurable actions to:
  - `move_left`, `move_right`, `move_up`, `move_down`
  - `shift_dimension`
  - `toggle_character`, `toggle_inventory`, `toggle_settings`
- Do not create a new interaction action or convert unrelated hardcoded controls in this slice.
- Capture creates one event per action override. Reset restores the actionΓÇÖs complete authored keyboard/mouse event 
list, including alternate movement keys.
- Accept physical keyboard keys without modifier chords and mouse buttons Left/Right/Middle. Exclude wheel, motion, 
double-click semantics, joypad and touch.
- Reserve Escape, Enter/keypad Enter, Tab, modifier-only keys, F1 and backtick for existing 
cancellation/navigation/evaluator behavior. Reject Ctrl/Alt/Meta/Shift chords.
- Reject a candidate event already used by another configurable actionΓÇÖs effective keyboard/mouse bindings. Display 
the conflicting action; do not silently swap or clear either action.
- Existing overlaps with Godot UI navigation defaults are preserved; do not rewrite `ui_*` actions.
- Validate the whole binding override set before applying it. Unknown action IDs, unsupported event kinds, empty event 
lists, invalid key/button values, duplicate events or conflicts reject the override set.
- Legacy settings without a version load existing settings and default bindings. Merely loading does not rewrite the 
file.
- Malformed or unsupported future-version settings must remain untouched on disk. Use session defaults, show an error, 
and reject persistence through the ordinary save path. An explicit ΓÇ£Reset settings fileΓÇ¥ action is out of scope.

**Implementation**

1. Implement `InputBindings` with:
   - A deep-copied snapshot of authored defaults from `ProjectSettings` input definitions, not from an already 
overridden global `InputMap`.
   - Override validation, effective-event calculation, binding display text, conflict detection, application and reset.
   - Public capture-active state usable by input consumers.
2. Integrate into `SettingsManager` serialization/deserialization and `apply_all_settings()`.
   - Load/apply before gameplay begins.
   - Avoid repeatedly recapturing current InputMap state as defaults.
3. Make binding persistence transactional:
   - Validate candidate settings.
   - Write and verify a temporary settings file.
   - Promote with recoverable previous-file handling.
   - Only publish the new binding state after successful persistence.
   - On failure, keep prior bindings and show an error.
   - Complete an interrupted settings-write recovery without silently replacing an unsupported-version file.
4. Add a Controls section inside the settings scroll container:
   - Action label, effective binding text, Rebind button, Reset button.
   - Reset All Controls button.
   - Capture instruction/status label and Cancel Capture button.
5. During capture:
   - Freeze gameplay as for the existing settings sheet.
   - Consume captured, rejected, repeated and cancellation events.
   - Escape cancels capture without closing Settings.
   - Mouse activation of Cancel Capture cancels rather than binding that click.
   - Do not capture the click/key that activated Rebind.
   - Wait for the candidateΓÇÖs release before applying the new binding.
   - Clear affected pressed action state; prevent held input leaking when Settings closes.
   - Restore focus to the initiating Rebind button.
6. Guard evaluator input while capture is active so rejected F1/backtick events cannot open evaluator tools.
   - Gate other active settings/title input paths before they react to capture events.
   - Do not rely solely on `_unhandled_input()` consumption: global input state and earlier `_input()` consumers also 
need protection.
7. Update the existing hardcoded dimension hint in `GameRoot` to display the effective binding instead of `[Q]`.
8. Preserve current close behavior outside capture and existing mutual exclusivity with character/inventory sheets.

**UI/focus**

- Entry: existing Settings entry points.
- Focus order includes every new button; scroll follows focus.
- Capture is a state within Settings, not a second freely stackable sheet.
- Escape once cancels capture; a subsequent Escape closes Settings.
- Reset failures retain previous effective bindings.
- No binding edits modify a profile or `project.godot`.

**Acceptance matrix**

| Suite | Required assertions |
|---|---|
| `input_rebinding_test.gd` | Default snapshot matches authored defaults; applying/resetting twice is idempotent. 
Unrelated and `ui_*` actions, deadzones and non-key/mouse events remain unchanged. |
| Same | Rebind a movement action using physical `InputEventKey`; after release/new press the new key moves Ren and 
replaced keys do not. Reset restores all original alternatives. |
| Same | Mouse-button binding triggers the intended menu action outside capture. |
| Same | Successful save followed by a fresh manager restores identical effective events. Settings are shared across 
profile switches. |
| Same | Conflict rejection leaves both actions, serialized settings and disk bytes unchanged. |
| Same | Invalid action, empty array, bad event kind/value and duplicate event reject atomically. |
| Same | Legacy settings load defaults without rewriting; future-version input leaves disk untouched and ordinary save 
fails. |
| Same | Inject settings write/promotion failure: no published binding change; a valid previous settings revision 
remains recoverable. |
| Same | Rebind activation event is ignored. Echoes do not commit. Escape/Cancel cancels without changing settings or 
closing the sheet. |
| Same | Capture movement/menu/dimension/evaluator keys: position, dimension, sheet count and evaluator visibility 
remain unchanged. Release is consumed and no stuck action remains. |
| `settings_accessibility_test.gd` | Existing audio/accessibility persistence still works; outside capture Escape 
closes Settings normally. |
| `layout_audit_test.gd` | Controls fit/scroll at 960├ù540 and 1.0/1.5 text scale; every binding/reset/cancel control 
is reachable and revealed by focus. |

Tests must restore global InputMap state in cleanup and use disposable settings paths.

**Top risk**

Input consumption can stop scene callbacks while leaving global pressed-action state active. Verify actual movement 
over physics frames and held-key release behavior, not only callback counts.

**Out of scope / blocked**

- Controller/touch bindings, modifier chords, user-defined actions, input presets.
- Combat action redesign: OD-002/003/004 blocked.
- Browser-reserved shortcut certification and browser smoke execution blocked.
- Changing authored defaults, shipping tier or profile schema.

**Review checkpoint**

Run targeted suites, then the full canonical headless runner. Perform a native visual check of capture, conflict 
feedback and keyboard focus. Codex CLI reviews persistence recovery, InputMap preservation and event leakage before 
Batch 2.

### Batch 2 ΓÇö SBL-EDU-005: Read-only learning journal and printable report

**Requirements**

- GDD-071: persistent activity/attempt records.
- GDD-072: learning journal, CSV and printable report.
- GDD-091: learning-journal screen.
- GDD-112: educational report export.
- FR-EDU-002/004.
- TC-EDU-002/004.
- Supporting NFR-SEC-001 and NFR-ACC-001.

**Dependencies**

- Batch 1 reviewed.
- Review closure for SBL-FIX-002 export integration.
- Existing assessment validation and immutable-first-response save behavior.
- OD-012 remains unresolved; this task does not authorize assessed deployment.

**Files**

Create:

- `scenes/ui/learning_journal.gd`
- `scenes/ui/learning_journal.tscn`
- `scripts/education/learning_report.gd`
- `tests/headless/learning_journal_test.gd`

Change:

- `scripts/education/assessment_controller.gd`
- `scenes/main/game_root.gd`
- `scenes/main/game_root.tscn`
- `scenes/ui/academic_completion_modal.gd`
- `scenes/ui/academic_completion_modal.tscn`
- `tests/headless/education_report_test.gd`
- `tests/headless/web_backup_test.gd`
- `tests/headless/settings_accessibility_test.gd`
- `tests/headless/layout_audit_test.gd`
- `docs/browser_verification_checklist.md` ΓÇö procedures only; execution stays pending.

**Data model**

- No profile schema bump or migration.
- Read only `AssessmentController.records`, loaded from existing `education.records`.
- Do not change `submit_answer()`, first-response merging, completion logic or save validation.
- Do not create records for unanswered questions or infer missing historical responses.
- Preserve existing CSV header and column order:

```text
question_id,competency,difficulty,first_attempt_correct,total_attempts,completed,timestamp
```

- Introduce a transient, deep-copied report row model containing those seven fields, sorted by question ID.
- Journal, CSV and HTML all consume that row model.
- `first_response` may be displayed in the journal only when already present; otherwise display ΓÇ£Not recorded.ΓÇ¥ Do 
not reconstruct answer text or correctness from current question definitions.
- Do not claim the record timestamp is completion time: current code updates it on attempts. Label it ΓÇ£Last recorded 
activity,ΓÇ¥ retaining the underlying numeric value in exports.
- No report history, learner identity fields, preferences or cached report data are saved.

**Implementation**

1. Add a read-only report-row accessor to `AssessmentController`.
   - Return deep copies.
   - Keep report construction free of calls to answer submission or saving.
2. Implement `LearningReport`:
   - Deterministic CSV and HTML rendering from the same rows.
   - Move CSV formatting behind this renderer while retaining existing public controller methods for callers.
   - Keep `_escape_csv` behavior compatible and use CRLF record separators for RFC-4180 output.
   - Neutralize spreadsheet-formula interpretation in exported text cells beginning with dangerous formula prefixes, 
including leading whitespace/control characters. Keep this transport encoding separate from the logical row values.
3. Generate standalone UTF-8 printable HTML:
   - Inline print CSS and an ordinary table.
   - No scripts, external resources, remote requests, inline event handlers or auto-print behavior.
   - Escape `&`, `<`, `>`, `"`, and `'` in every dynamic HTML value.
   - Do not place untrusted values in markup, CSS or filenames.
   - Include the active profile slot, row count and recorded completion/first-attempt counts.
   - Display: **ΓÇ£Practice records. Educator review pending ΓÇö OD-012. These records do not establish learning 
improvement.ΓÇ¥**
4. Build the journal:
   - Profile slot label, the same educator-status notice, record summary and scrollable records.
   - Columns/row details: question ID, competency, difficulty, first-attempt correctness, attempts, completion and 
last recorded timestamp.
   - Optional first-response index detail only from existing records.
   - Empty state: ΓÇ£No recorded activities.ΓÇ¥
   - Export CSV, Export Printable HTML and Close buttons.
5. Add a visible **Learning Journal** button to the exploration HUD.
   - Use a button only; do not introduce another keyboard action/default in this slice.
   - Disable/guard it during battle, dialogue, expedition, title screen, transitions or another sheet/modal.
6. Implement one journal instance on `SheetLayer`.
   - Freeze movement; consume menu hotkeys and Escape.
   - Escape/Close closes the journal and restores the prior movement lock/focus.
   - No other sheet may stack above it.
7. At the end of `_init_slice_progress()`, after the new controller is loaded:
   - Rebind any existing journal to the new controller/profile slot and refresh.
   - Never retain a reference to the replaced controller.
   - Also refresh on every journal opening.
   - This covers both title profile switching and successful backup import, which already reload through that path.
8. Add Printable HTML export to the academic completion modal.
   - Keep its existing CSV entry point.
   - Use the same renderer; do not open the journal above the completion modal.
9. Add an injectable report-delivery callable:
   - Desktop: write fixed filenames under `user://reports/`; report success only after successful write.
   - Web: call `JavaScriptBridge.download_buffer` with UTF-8 bytes and appropriate MIME type, without requiring a 
`user://` write or clipboard access.
   - Feedback says download was requested, not that the user saved/printed successfully.
   - Use fixed filenames derived only from allowlisted profile IDs.

**UI/focus**

- Exploration HUD button is the journal entry point.
- Academic completion offers direct CSV/HTML export.
- Use plain `Label` text or disable BBCode interpretation.
- Focus starts on an export button, cycles through exports/Close and follows scrolling.
- Do not make every report cell focusable.
- Reuse existing high contrast and text-scale application.
- Keep buttons and educator notice accessible at 960├ù540/150% scale.

**Acceptance matrix**

| Suite | Required assertions |
|---|---|
| `education_report_test.gd` | Wrong-first/correct-retry fixture produces `first_attempt_correct=false`, 
`total_attempts=2`, `completed=true` in canonical rows, parsed CSV and HTML table. |
| Same | First-response dictionary is byte-for-byte logically unchanged by rendering/export; legacy records lacking it 
stay unchanged. |
| Same | Sorted row IDs, completion counts, first-attempt counts and timestamps agree across all formats. |
| Same | CSV round-trips commas, quotes and embedded newlines; formula-leading text is neutralized according to the 
documented transport rule. |
| Same | Inject `<script>`, `<img onerror=ΓÇª>`, ampersands, quotes and apostrophes into transient record text: HTML 
contains escaped text and no executable injected markup/attributes. |
| Same | Empty records yield a valid header-only CSV and valid HTML empty state; neither adds records. |
| Same | HTML contains OD-012/pending status and the no-learning-improvement statement. |
| `learning_journal_test.gd` | Open/refresh/export/close leave controller serialization and all profile revision bytes 
unchanged. |
| Same | Profile A ΓåÆ B ΓåÆ A shows only the selected profileΓÇÖs records and label. |
| Same | Successful backup import reloads the controller; reopening/refreshing uses imported rows. Failed import 
leaves prior rows intact. |
| Same | Movement remains frozen; character/inventory/settings hotkeys and repeated journal entry cannot stack sheets. 
Close restores the previous lock and focus. |
| Same | Entry attempts during each blocking modal/transition are rejected. |
| `web_backup_test.gd` | Fake delivery callable receives exact UTF-8 CSV/HTML bytes, fixed filenames and MIME types. 
Simulated unavailable disk does not prevent Web delivery preparation. No real browser pass is claimed. |
| Same | Inject desktop write failure: error feedback, no success message and records unchanged. |
| `layout_audit_test.gd` | Journal and revised completion modal fit at 960├ù540 and 1.0/1.5 scale; export/close remain 
reachable. |
| `settings_accessibility_test.gd` | New controls receive live scale/high-contrast settings and visible keyboard 
focus. |

**Top risk**

A report renderer could accidentally reinterpret practice retries as first-attempt success or read stale records after 
profile replacement. Pin both behaviors with integration tests.

**Out of scope / blocked**

- New questions, explanations, competency rubrics, scoring, adaptive hints or educator approval: **OD-012 blocked**.
- Claims of mastery, educational improvement, accreditation or validity.
- Question-bank approval metadata redesign.
- Combining `education.vertical_slice` into assessed rows; it has a different existing record shape.
- LMS/network integration, personal names, analytics telemetry.
- Browser download/print execution remains blocked.

**Review checkpoint**

Run targeted suites and the full canonical headless runner. Perform native visual QA of journal layout, focus and an 
exported HTML report. Codex CLI reviews read-only behavior, first-attempt preservation, escaping, profile refresh and 
pending educator status before Batch 3.

### Batch 3 ΓÇö SBL-BLD-005: Archive-contained JSON provenance manifests

**Requirements**

- GDD-110: portable Windows/web distribution.
- GDD-124: verification evidence.
- GDD-131: source/build handoff.
- FR-REL-001, TC-REL-001.
- Supporting NFR-BUILD-001.
- This contributes packaging evidence; it does not satisfy blocked TC-WEB-001/002 or replace TC-WIN-001.

**Dependencies**

- Batches 1 and 2 reviewed.
- SBL-BLD-004 and SBL-VER-004 remain the baseline.
- Git metadata and an executable reporting Godot 4.7.2 Stable are available.
- No OD-017 shipping decision required: package the explicitly requested existing tiers.

**Files**

Create:

- `scripts/build/release_manifest.ps1`
- `scripts/build/test_release_manifest.ps1`

Change:

- `scripts/build/export_release.ps1`
- `scripts/build/validate_release.ps1`
- `scripts/build/run_headless_tests.ps1`
- `scripts/build/test_export_failure_restoration.ps1` ΓÇö only to cover any additional temporary-state restoration.

No gameplay scenes, save schema or settings changes.

**Manifest and receipt model**

Every ZIP contains exactly one root `release-manifest.json`, UTF-8 JSON, schema version `1`.

Required structure:

```json
{
  "manifest_schema_version": 1,
  "package": {
    "archive_name": "Soulbound-AcademicMVP-Web.zip",
    "platform": "web",
    "tier": "academic_mvp"
  },
  "source": {
    "commit": "<full Git commit ID>",
    "dirty": false,
    "status_porcelain_sha256": "<SHA-256>"
  },
  "godot": {
    "version": "<actual --version output>",
    "executable_sha256": "<SHA-256>"
  },
  "configuration": {
    "preset_name": "Web",
    "renderer": "gl_compatibility",
    "web_thread_support": false,
    "project_snapshot": "provenance/project.godot",
    "presets_snapshot": "provenance/export_presets.cfg"
  },
  "payload": [
    {
      "path": "index.pck",
      "size_bytes": 123,
      "sha256": "<lowercase SHA-256>"
    }
  ]
}
```

The payload example is illustrative; calculate every value.

Rules:

- Payload lists **every regular ZIP entry except `release-manifest.json`**, including the tier marker and 
configuration snapshots.
- Sort entries by ordinal normalized path.
- Hash raw uncompressed bytes. Do not hash decoded text.
- Manifest does not hash itself.
- Include effective, tier-mutated `project.godot` and actual `export_presets.cfg` snapshots under `provenance/`.
- `platform` is `web` or `windows`; preset is `Web` or `Windows Desktop`.
- For Windows, `web_thread_support` is `null`.
- No absolute executable path, usernames or raw Git status filenames in the manifest.
- Config snapshots retain their actual bytes; existing absolute paths inside configuration are not silently rewritten.
- No invented tag/version: use the full commit and actual engine output.

For each ZIP, write an external companion:

```text
<archive-name>.manifest.sha256
```

Its contents are the lowercase SHA-256 of the exact archived manifest bytes.

This receipt is necessary to detect metadata-only manifest alteration and substitution with an older valid manifest. 
It is an integrity reference, **not a digital signature**; coordinated replacement of both archive and receipt is 
outside this task.

**Implementation**

1. In `release_manifest.ps1`, implement reusable manifest creation and archive verification functions. Keep these 
callable without triggering an export.
2. Before creating staging files or mutating source configuration:
   - Capture `git rev-parse HEAD`.
   - Capture `git status --porcelain=v1 --untracked-files=all`.
   - Derive dirty boolean and hash the captured UTF-8 status text using documented LF normalization.
   - Run the resolved Godot executable with `--version`; require 4.7.2 Stable.
   - Hash that executable.
   - Fail if Git/version commands fail; never substitute ΓÇ£unknown.ΓÇ¥
3. Use a fresh staging directory for each requested package.
   - Prevent stale output from prior exports entering new packages.
   - Verify resolved cleanup paths remain within the taskΓÇÖs temporary/staging directory before recursive deletion.
4. Preserve existing tier mutation and failure-injection behavior.
5. After a successful export:
   - Stage only that exportΓÇÖs current payload.
   - Add the tier marker and configuration snapshots.
   - Enumerate staged payload bytes and create the manifest.
   - ZIP payload plus manifest.
   - Write the manifest receipt outside the ZIP.
6. Reopen the newly created ZIP and verify it against its receipt before considering packaging successful.
7. Extend `validate_release.ps1`:
   - Require manifest and companion receipt for each selected archive.
   - Parse and validate schema, required fields, types and enumerations.
   - Reject unsupported versions.
   - Reject duplicate ZIP entry names, case-colliding names, absolute paths, backslashes, empty path components and 
`.`/`..` traversal segments.
   - Require a one-to-one match between payload records and ZIP regular entries excluding the manifest.
   - Reject duplicate payload paths, missing/extra files, size mismatches and SHA mismatches.
   - Recompute manifest digest from its own ZIP entry and compare to its external receipt.
   - Cross-check platform, archive name, preset and expected tier for the requested package.
   - Read configuration snapshots from ZIP bytes; verify their hashes, effective tier, Compatibility settings and Web 
single-thread flag.
   - Keep existing forbidden-file, entry-point and archive-contained PCK checks.
   - Do not use local `builds/` payloads or local configuration as substitutes for archived evidence.
   - Missing Godot during the required live PCK gate is a failure, not a successful skip.
8. Keep source provenance validation honest:
   - Receipt binds the recorded metadata to the exported manifest.
   - Source dirty status is captured before exporter mutations.
   - A dirty build is permitted and explicitly identified; do not claim it corresponds solely to committed source.
9. `-SkipZip` creates no archive/receipt and performs no archive-manifest verification. It must not validate an older 
ZIP accidentally.
10. Chain `test_release_manifest.ps1` from the canonical runnerΓÇÖs `-Export` path after successful export/validation.
11. Retain byte-identical restoration of `project.godot` and any pre-existing root marker on every failure path.

**Acceptance matrix**

`test_release_manifest.ps1` must use disposable archive copies and the same verifier functions used by production 
validation.

| Test/control | Exact expected result |
|---|---|
| Valid synthetic fixture | Manifest schema, receipt, paths, sizes and hashes validate. |
| Real exported packages | Academic Web, Full Web and Full Windows each pass manifest verification and their existing 
archive-contained PCK gates. |
| Missing manifest | Nonzero exit with missing-manifest diagnostic. |
| Missing receipt | Nonzero exit; no fallback to accepting self-declared metadata. |
| Malformed/future manifest | Nonzero exit for invalid JSON/schema. |
| Change only `source.commit` or `source.dirty` | Receipt mismatch; nonzero exit even though payload bytes are 
unchanged. |
| Change payload byte without changing size | SHA mismatch; nonzero exit. |
| Change payload size | Size/hash failure; nonzero exit. |
| Delete listed file | Missing payload failure. |
| Add unlisted file | Exact entry-set failure. |
| Duplicate/case-colliding entry or payload path | Nonzero exit before ambiguous extraction/hash lookup. |
| Traversal/absolute path | Nonzero exit; nothing written outside temporary root. |
| Swap manifests across tiers/platforms | Receipt/package identity and/or payload checks fail. |
| Swap older same-tier manifest | Existing expected receipt detects the substitution. |
| Change configuration snapshot | Payload hash mismatch; with a freshly generated fixture receipt/hash, inconsistent 
renderer/tier/thread fields still fail semantic checks. |
| Dirty-source capture | Controlled dirty fixture records `dirty=true`; clean fixture records false. ExporterΓÇÖs own 
temporary mutation does not flip the captured clean result. |
| Stale build output | Seed an unrelated file in an old output directory; it is absent from the new staged package. |
| `-SkipZip` | No new receipt/ZIP and no validation of stale packages. |
| Existing restoration test | Exit 0 after observed post-mutation failure; source configuration and marker restored 
exactly. |
| Restoration disabled negative control | Exit 1 as before; harness cleanup restores the tree. |

**Top risk**

Hash validation can appear strong while checking unrelated local files or trusting the manifestΓÇÖs own claims. 
Require archive-byte hashing, exact entry-set matching and the external expected manifest digest.

**Out of scope / blocked**

- Shipping default selection: **OD-017 blocked**; retain checked-in default.
- Publishing, tagging, signing, remote attestation or release authorization.
- Reproducible byte-identical engine exports.
- Invented size/performance budgets or reference hardware: **OD-013 blocked**.
- New asset generation or licensing approval.
- Browser smoke execution.

**Review checkpoint**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build/run_headless_tests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build/run_headless_tests.ps1 -Export -Tier all
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build/test_export_failure_restoration.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/build/test_export_failure_restoration.ps1 -DisableRestore
```

The export chain must include `test_release_manifest.ps1`. The first three commands require exit 0; 
disabled-restoration control requires exit 1.

Codex CLI reviews the build diff, all negative controls, archive evidence, source-status capture timing and 
restoration behavior. Record artifact hashes/sizes and the actual suite count; do not retain the old count of 29 as a 
fixed expectation.

### Final batch gates and reporting

At each batch boundary:

1. Run targeted tests, then the canonical full headless suite.
2. Record native visual checks where applicable; keep browser checks pending.
3. Commit implementation and evidence with `[REVIEW_PENDING_CODEX]`.
4. Produce the required report:

```text
TASK ID:
REQUIREMENTS:
MILESTONE:
OWNER: agy
PLAN OWNER: Codex
BRANCH/COMMIT:
FILES CHANGED:
ASSET PROVENANCE: none
TESTS RUN + RESULTS:
REVIEW: REVIEW_PENDING_CODEX
OPEN QUESTIONS:
```

5. Codex CLI reviews immediately. Fix and re-review actionable findings before starting the dependent batch.
6. Only a recorded Codex review session can change status to `REVIEWED`. Human milestone/release acceptance remains 
pending.

No work in these three batches resolves OD-002/003/004, OD-012 or OD-017. If implementation exposes a need to choose 
balance values, educational validity rules, narrative content, shipping policy or another unresolved OD, record that 
portion as **blocked** and continue only with independent scoped work.
tokens used
120,202