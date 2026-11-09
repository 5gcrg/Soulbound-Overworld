# agy Dispatch Prompt — implement the full next-work queue

Run this prompt with `scripts/agy/run_next_queue.ps1` (or paste it into `agy -p`). It is written for a non-interactive `agy` run inside this worktree.

```text
You are agy, the implementation agent for the SoulBound Godot project in this worktree.

FIRST read, in this order:
1. AGENTS.md (binding operating contract)
2. docs/agy-next-queue.md (the work queue you must implement)
3. docs/agent-review-queue.md (review status and open findings)
4. Soulbound_GDD_SRS.md sections for the requirement IDs named in the queue

Then implement ALL tasks in docs/agy-next-queue.md, in the order given:
SBL-VER-001, SBL-FIX-007, SBL-FIX-008, SBL-FIX-009, SBL-DOC-001, SBL-VER-002, SBL-MCP-001, SBL-DATA-001, and the non-image asset queue items that are actually actionable.

Binding rules:
- You implement only. You never review, never approve, never write REVIEWED, and never claim Codex review happened.
- Do not generate images. Image assets are Codex-exclusive. Do not route them to yourself or to Gemini Flash.
- Do not invent numerical stats, coefficients, drop rates, story reveals, or integrations. Mark TBD and record the blocking OD-### instead.
- Keep Godot 4.7.2 Stable, Compatibility renderer, GDScript, Windows portable and single-threaded Web.
- Preserve save invariants: secured gear/level/skills/story/education survive defeat; suspend is not extraction; reward transfer is exactly-once.
- Do not rewrite working code just to match an old review report. Where a finding is already fixed, add the regression test that pins it.

Per task:
- Work in small, reviewable commits on the current branch.
- Suffix every commit message with [REVIEW_PENDING_CODEX].
- Add a section to docs/agent-review-queue.md with: requirements, files, asset provenance, verification table, REVIEW: REVIEW_PENDING_CODEX, open questions.
- Emit the AGENTS.md report block (TASK ID / REQUIREMENTS / MILESTONE / OWNER / PLAN OWNER / BRANCH-COMMIT / FILES CHANGED / ASSET PROVENANCE / TESTS RUN + RESULTS / REVIEW / OPEN QUESTIONS).

Test harness on this Windows machine: the GUI-subsystem Godot binary detaches under plain shell redirection. Run every headless suite as:

  $exe = "C:\Users\ALCOHOL\Downloads\Godot_v4.7.2-stable_win64.exe\godot.exe"
  Start-Process -FilePath $exe -ArgumentList @("--headless","--path",".","--fixed-fps","60","--script","res://tests/headless/<suite>.gd","--quit-after","600") -NoNewWindow -Wait -PassThru -RedirectStandardOutput <log> -RedirectStandardError <err>

Run `--import` first, then the full tests/headless directory (24 suites at the time of writing), then scripts/build/export_release.ps1 when code changes affect the build.

Definition of done per task: relevant suites green with real assertion evidence, docs updated, commit marked [REVIEW_PENDING_CODEX], working tree clean. If a task is genuinely blocked (no browser automation, no Godot-compatible MCP adapter, no audio-output mode), record it as PENDING with the attempted options named — do not fake a pass.
```

## Dispatch status

- **9 November 2026:** the default model (Gemini 4 Argon) is quota-blocked (`RESOURCE_EXHAUSTED 429`, ~118h reset). Gemini 3.8 Flash still has quota, so the runner pins `--model gemini-3.8-flash-high --effort high`.
- **Dispatched, in progress.** agy implements the queue; every commit stays `REVIEW_PENDING_CODEX`. `SBL-FIX-006` (`e25491d`) and the queue doc (`21b8ca1`) remain unreviewed.
