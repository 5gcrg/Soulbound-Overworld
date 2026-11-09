# Soulbound Asset Register

In accordance with `AGENTS.md` and `NFR-LIC-001`, this document registers all visual, audio, and narrative assets created or imported into the Soulbound repository, detailing provenance, authoring agent, and licensing.

## Asset Routing Policy

- **Images / Sprites / Visual Art**: **Codex exclusive**. Never route to agy or Gemini Flash.
- **Narrative / Audio Specs / Questions**: **Gemini Flash**. Non-image assets only; educator review required before assessed grading (`OD-012`).
- **Code / Scenes / Automated Tests**: **agy**. Implement per Codex plan; code creation is not classified as asset generation.

---

## Registered Assets

| Asset ID | Path / Reference | Type | Provenance / Generator | Reviewer / Status | License / Notes |
|---|---|---|---|---|---|
| *None* | *None* | *None* | *None* | *N/A* | Task SBL-M1-001 contains zero image, audio, or generated narrative assets. Foundation code, scenes, and test scripts only. |
| *None* | *None* | *None* | *None* | *N/A* | Task SBL-W2-001 contains zero image, audio, or generated narrative assets. Technical fixture visuals use engine ColorRect primitives exclusively. |
| *None* | *None* | *None* | *None* | *N/A* | Task SBL-W3-001 contains zero image, audio, or generated narrative assets. Combat fixture UI uses Godot primitives and native controls. |
| *None* | *None* | *None* | *None* | *N/A* | Task SBL-W3-002 contains zero image, audio, or generated narrative assets. Code and an automated headless test only. |
| *None* | *None* | *None* | *None* | *N/A* | Task SBL-W4-001 contains zero image or audio assets (ColorRect primitives and native Control UI only). Quest dialog scenario text authored per Gemini Flash non-image specification. |
| *None* | *None* | *None* | *None* | *N/A* | Task SBL-M3-001 contains zero image, audio, or generated narrative assets. Pure GDScript system classes and automated tests only. |
| `spec_audio_prod` | `docs/audio-spec.md` | Audio Specifications & Generation Brief (Non-image) | Gemini Flash | Specification Ready / Pending Binary | 10 SFX and 4 BGM production specifications authored per AGENTS.md. Zero external binaries; shipping procedural synthesizer active in `scripts/audio/audio_manager.gd`. |
| `copy_review_edu` | `docs/educational_copy_review.md` | Narrative & Educational Copy (Non-image) | Gemini Flash | Reviewed for MVP / Gated under `OD-012` | Quest dialogues and 8 assessed questions in `QuestionBank`. Completion-gated for MVP; formal educator certification gated under `OD-012`. |
| *Visual Art* | *Blocked* | Images, Sprites, Tilesets, Portraits, Visual Textures | **Codex Exclusive** | BLOCKED FOR CODEX | **Zero images generated**. Codex is the sole authorized image agent per AGENTS.md. |

### Summary
- **Total visual image assets**: 0 (Blocked for Codex; engine uses ColorRect primitives and programmatic shapes only).
- **Total audio binary assets**: 0 (Specifications finalized in `docs/audio-spec.md`; procedural in-engine synthesis active in `AudioManager`).
- **Total generated narrative / educational assets**: 8 questions in `QuestionBank` + quest text (Authored per Gemini Flash spec; completion-gated; educator review gated under `OD-012`).
