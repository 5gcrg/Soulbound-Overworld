# Soulbound Audio Specifications — M2 Vertical Slice

In accordance with `AGENTS.md` and `Soulbound_GDD_SRS.md §15.1`, Gemini Flash authors non-image audio specifications. Because no capable Gemini Flash binary audio-output mode is configured, these assets are prepared as detailed acoustic and synthesis specifications, marked **PENDING BINARY ACQUISITION**, and tracked in `docs/asset-register.md`.

---

## 1. User Interface & Dialogue SFX

### `sfx_dialog_advance`
- **Category**: UI Navigation / Dialogue Paging
- **Acoustic Profile**: Soft sine chirp with delicate metallic chime overtone.
- **Fundamental Frequency**: 440 Hz sliding quickly to 880 Hz over 60 ms.
- **Duration**: 180 ms.
- **Envelope**: Instant attack (2 ms), exponential decay to silence (-48 dB).
- **Target Context**: Advancing quest text or acknowledging tutorial prompts in `QuestDialog`.
- **Status**: PENDING SPECIFICATION IMPLEMENTATION.

### `sfx_educational_feedback_correct`
- **Category**: Educational Assessment Feedback
- **Acoustic Profile**: Harmonious major triad chime (C5 [523 Hz], E5 [659 Hz], G5 [784 Hz]).
- **Timbre**: Resonant crystalline bell with gentle warmth, no harsh high-frequency dissonance.
- **Duration**: 450 ms.
- **Envelope**: 5 ms attack, linear sustain for 80 ms, smooth decay across 365 ms.
- **Target Context**: Player selects the optimal critical-thinking option (Option A: Harmonize).
- **Status**: PENDING SPECIFICATION IMPLEMENTATION.

### `sfx_educational_feedback_retry`
- **Category**: Educational Assessment Feedback (Completion Gated)
- **Acoustic Profile**: Warm dual-tone reflection chime (A4 [440 Hz] transitioning to D5 [587 Hz]).
- **Timbre**: Mellow wooden temple bell or soft bamboo resonator. Intended to convey encouragement, perseverance, and educational reflection rather than punitive buzzer sounds.
- **Duration**: 500 ms.
- **Envelope**: 8 ms attack, warm resonant ring with soft dampening.
- **Target Context**: Player selects Option B (Mismatch/Force) in `QuestDialog`, reinforcing perseverance.
- **Status**: PENDING SPECIFICATION IMPLEMENTATION.

---

## 2. Combat Action & Event SFX

### `sfx_combat_strike`
- **Category**: Turn-Based Combat Action
- **Acoustic Profile**: Fast physical whoosh layered over a punchy low-mid impact.
- **Frequency Content**: Band-passed white noise (600 Hz – 2.4 kHz) combined with 120 Hz transient thump.
- **Duration**: 140 ms.
- **Target Context**: Triggered on `BattleFixture.request_action(&"attack")`.
- **Status**: PENDING SPECIFICATION IMPLEMENTATION.

### `sfx_combat_defend`
- **Category**: Turn-Based Combat Guard
- **Acoustic Profile**: Resonant spirit barrier deflection; ringing energy shield vibration.
- **Frequency Content**: 580 Hz fundamental with glass-like high harmonics (1.7 kHz, 3.2 kHz).
- **Duration**: 280 ms.
- **Target Context**: Triggered on `BattleFixture.request_action(&"defend")`.
- **Status**: PENDING SPECIFICATION IMPLEMENTATION.

### `sfx_quest_complete`
- **Category**: Milestone Fanfare
- **Acoustic Profile**: Ascending three-note spirit motif (E5 [659 Hz] -> G#5 [830 Hz] -> B5 [988 Hz]).
- **Duration**: 850 ms.
- **Target Context**: Triggered upon `SliceProgress.turn_in()` via `QuestDialog`.
- **Status**: PENDING SPECIFICATION IMPLEMENTATION.

---

## 3. Background Ambient Audio

### `bgm_alpha_ambient`
- **Category**: Overworld Ambient Score
- **Tempo**: 64 BPM, non-intrusive 4/4 meter.
- **Instrumentation**: Pentatonic spirit wind chime, subtle bowed strings, and soft ambient field wind.
- **Key**: D Dorian / A minor modal spirit palette.
- **Looping**: Seamless 48-second loop with zero transient click at boundary.
- **Target Context**: Region Alpha background immersion.
- **Status**: PENDING SPECIFICATION IMPLEMENTATION.
