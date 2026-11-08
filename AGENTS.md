# AGENTS.md — Soulbound AI Development Operating Contract

**Read `Soulbound_GDD_SRS.md` first.** The 132 approved high-level requirements `GDD-001..GDD-132` are the baseline; unresolved choices are `OD-001..OD-016`. This file governs how AI agents implement the Godot project.

## Binding source-owner directive

> all image generation involved wil be done with codex

Normalized meaning: **All image generation is assigned exclusively to Codex. All other generated assets belong to Gemini Flash.**

## Required planning → execution → review sequence

1. **Codex plans** each feature: identify GDD/FR IDs, dependencies, targeted Godot scene/scripts, acceptance tests, implementation risks, and asset needs.
2. **Codex calls agy** to implement the approved slice using GDScript and Godot 4.7.2 Stable, Compatibility renderer and reusable scenes.
3. **agy executes** in an isolated feature branch, updates requirements/tests/asset register, and provides a concise change report with commit hash and runnable tests.
4. **Codex CLI reviews** the work immediately after agy is done, examining diffs and test evidence, validating save-state invariants and Godot compatibility, and requesting fixes.
5. **If Codex CLI is unavailable or out of credits/credentials**, agy **continues implementation** on independently scoped tasks. Mark commits/PRs `REVIEW_PENDING_CODEX`, record them in `docs/agent-review-queue.md`, and preserve full implementation/test logs. Codex CLI reviews **all pending changes once back**. No one may represent queued work as Codex-reviewed or bypass human release sign-off.
6. Human developers retain approval authority for scope changes and final release.

## Exclusive asset routing

| Content | Agent | Rule |
|---|---|---|
| Images, sprites, icons, tilesets, portraits, visual textures, image-based animation frames | **Codex** | Codex uses an image-capable tool/workflow. If unavailable, block and record; **never** route image generation to Gemini Flash. |
| Quest dialogue, item and enemy descriptions, structured educational questions, localization, other non-image assets | **Gemini Flash** | Generated content must be reviewed; educational questions must be educator-reviewed before assessed use. |
| Music/SFX and other non-image assets | **Gemini Flash** | If no capable Gemini Flash audio-output mode exists, only prepare a spec/source and mark the binary asset pending; don't substitute another generator silently. |
| Godot code, scenes, tests, deployment automation | **agy** | Implement per Codex plan; code creation is not classified as image/non-image asset generation. |

## AI Game Developer MCP caution

Reference: https://github.com/ivanmurzak/unity-mcp. Its documented plugin is for **Unity** (Unity Editor, Unity packages, GameObjects, C#), **not automatically for Godot**. Before using AI Game Dev to manipulate Godot, demonstrate a **Godot-compatible MCP/adapter** on a disposable project: list scene tree, create/edit node, save scene, inspect errors, run headless validation, and collect evidence. If unsupported, use Godot-native files/headless CLI and record the integration as pending. Never install a Unity package into Godot or invent equivalent Godot tools.

## Engineering invariants

- Platform: Windows portable and single-threaded Godot 4.7.2 web build; Compatibility renderer; GDScript.
- Keep the 3-chapter academic MVP separate from the 5-chapter 2-ending full release.
- Preserve secured gear, level/skills, story and educational records after expedition defeat; lose only approved unbanked items and temporary upgrades.
- Suspend/resume an expedition **does not count as extraction**; validate exactly-once reward transfer.
- Use stable content IDs and versioned JSON save profiles; provide local web backup export/import.
- Use seeded/validated modular dungeons; no unreachable extraction points.
- Required learning activities are completion-gated, not pass-score-gated; first-attempt correctness is immutable.
- Do not invent numerical stats, formula coefficients, drop probabilities, story revelations, or unsupported integrations. Mark such items `TBD` and seek change approval.

## Every task must provide

```text
TASK ID:
REQUIREMENTS:
MILESTONE:
OWNER: agy
PLAN OWNER: Codex
BRANCH/COMMIT:
FILES CHANGED:
ASSET PROVENANCE: Codex (image) / Gemini Flash (non-image) / none
TESTS RUN + RESULTS:
REVIEW: REVIEW_PENDING_CODEX | CHANGES_REQUESTED | REVIEWED
OPEN QUESTIONS:
```

## Definition of done

An implementation is complete for review only if it compiles or passes relevant headless checks, has its acceptance criteria verified, documents data changes, keeps main branch protected, and has accurate review status. A release is complete only after human acceptance; lack of Codex CLI credits is never grounds to claim review happened.
