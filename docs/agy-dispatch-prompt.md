# agy Dispatch Prompt — implement the full next-work queue

Run this prompt with `scripts/agy/run_next_queue.ps1` (or paste it into `agy -p`). It is written for a non-interactive `agy` run inside this worktree.

```text
You are agy, the implementation agent for the SoulBound Godot project in this worktree.

FIRST read, in this order:
1. AGENTS.md (binding operating contract)
2. docs/agy-next-queue.md (the work queue you must implement)
3. docs/agent-review-queue.md (review status and open findings)
4. Soulbound_GDD_SRS.md sections for the requirement IDs named in the queue

Then implement ALL tasks in docs/agy-next-queue.md, in the order given. That file is the source of truth for the current batch; do not stop at the first task and do not skip a task because it looks blocked — record genuine blockers as PENDING with the attempted options named.

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

Run `--import` first, then the full tests/headless directory (29 suites at the time of writing), then scripts/build/export_release.ps1 when code changes affect the build.

Definition of done per task: relevant suites green with real assertion evidence, docs updated, commit marked [REVIEW_PENDING_CODEX], working tree clean. If a task is genuinely blocked (no browser automation, no Godot-compatible MCP adapter, no audio-output mode), record it as PENDING with the attempted options named — do not fake a pass.
```

## Dispatch status

- **Batch 1 complete** (`e5f93e8..e2a68bd`), **batch 2 complete** (`f263001..6f6efa5`), **batch 3 complete** (`9040561..5e81a04`), **batch 4 complete** (`0b7e85f..b2b45a4`), **batch 5 complete** (`e0ed0b5`): 23 tasks implemented, 29/29 suites green.
- **Codex CLI review of `e25491d..5e81a04`** (session `01a1be9a-5583-7252-b082-ebd436372c80`): CHANGES_REQUESTED, three P2 findings.
- **Codex CLI re-review of `b2ddee1..b2b45a4`** (session `01a1bebf-6857-7dd3-8fb0-fb78d93f13e0`): the three findings cleared; one new P2 in the failure-restoration test.
- **Codex CLI re-review of `81d613e..e0ed0b5`** (session `01a1becc-d949-7cc3-867d-a0a8ede9510b`): APPROVED for the patch, no actionable defects. The failure-injection P2 is fixed.
- **Every implementation entry from `e25491d..e0ed0b5` is `REVIEWED`.** Only `SBL-FIX-001..005`, which predate `e25491d`, remain `REVIEW_PENDING_CODEX`.
- **Next gate is human**: milestone/release acceptance, `OD-017` shipping tier, browser smoke, educator sign-off (`OD-012`), audio binaries, and Codex-only image assets.
- Runner pins `--model gemini-3.8-flash-high --effort high` because Gemini 4 Argon is quota-blocked until ~14 Nov 09:21.
