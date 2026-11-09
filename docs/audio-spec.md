# Soulbound Audio Specifications & Generation Brief (SBL-DATA-002)

**Milestone**: Release Hardening & Audio Asset Specification  
**Authoring Agent**: Gemini Flash (Non-Image Asset Routing per AGENTS.md § Exclusive asset routing)  
**Binary Generation Status**: PENDING BINARY ACQUISITION (No active binary audio generation mode in environment)  
**Shipping Fallback**: Procedural SFX Engine (`scripts/audio/audio_manager.gd`) active and verified with zero binary dependencies.  

---

## 1. Architectural Audio Strategy & Fallback

Per `AGENTS.md`:
> "If no capable Gemini Flash audio-output mode exists, only prepare a spec/source and mark the binary asset pending; don't substitute another generator silently."

Soulbound employs a dual-tier audio architecture:
1. **Tier 1 (Shipping Fallback — Active)**: `scripts/audio/audio_manager.gd` implements dynamic in-engine PCM WAV synthesis (`AudioStreamWAV`) for button interactions, combat hits, guards, spells, heals, dimensional shifts, and educational feedback. This runs deterministically on all platforms (Windows desktop and single-threaded WebAssembly) without external asset loading.
2. **Tier 2 (Production Audio Brief — Pending)**: When a Gemini Flash audio-output modality becomes accessible, the detailed acoustic specifications below will serve as the generation brief for mastering production `.ogg` / `.wav` assets.

---

## 2. Production SFX Generation Specifications

### 2.1 User Interface & Educational Feedback

#### `sfx_button_click`
- **Category**: UI Interaction
- **Acoustic Profile**: Crisp tactile click with minimal resonance.
- **Waveform & Pitch**: 880 Hz (A5) square wave with rapid low-pass filtering.
- **Duration**: 40 ms.
- **Envelope**: Instant attack (<1 ms), exponential decay to silence.
- **Output Target**: `res://assets/audio/sfx/sfx_button.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_dialog_advance`
- **Category**: UI Navigation / Dialogue Paging
- **Acoustic Profile**: Soft sine chirp with delicate metallic chime overtone.
- **Waveform & Pitch**: 440 Hz sliding to 880 Hz over 60 ms.
- **Duration**: 180 ms.
- **Envelope**: 2 ms attack, smooth exponential decay (-48 dB).
- **Output Target**: `res://assets/audio/sfx/sfx_dialog_advance.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_educational_feedback_correct`
- **Category**: Educational Assessment Feedback
- **Acoustic Profile**: Harmonious major triad chime (C5 [523.25 Hz], E5 [659.25 Hz], G5 [783.99 Hz], C6 [1046.50 Hz]).
- **Timbre**: Resonant crystalline bell with gentle warmth, zero high-frequency dissonance.
- **Duration**: 450 ms.
- **Envelope**: 5 ms attack, linear sustain for 80 ms, smooth decay across 365 ms.
- **Output Target**: `res://assets/audio/sfx/sfx_correct.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_educational_feedback_retry`
- **Category**: Educational Assessment Feedback (Completion Gated)
- **Acoustic Profile**: Warm dual-tone reflection chime (A4 [440 Hz] to D5 [587 Hz]).
- **Timbre**: Mellow wooden resonator or bamboo bell. Conveys encouraging perseverance rather than punitive buzzer tones.
- **Duration**: 500 ms.
- **Envelope**: 8 ms attack, warm resonant ring with soft dampening.
- **Output Target**: `res://assets/audio/sfx/sfx_retry.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_quest_complete`
- **Category**: Milestone Fanfare
- **Acoustic Profile**: Ascending three-note spirit motif (E5 [659.25 Hz] -> G#5 [830.61 Hz] -> B5 [987.77 Hz]).
- **Duration**: 850 ms.
- **Envelope**: 10 ms attack, rich harmonic body, gradual exponential ring-out.
- **Output Target**: `res://assets/audio/sfx/sfx_quest_complete.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

---

### 2.2 Combat Action SFX

#### `sfx_combat_strike`
- **Category**: Physical Combat Action
- **Acoustic Profile**: Fast physical whoosh layered over punchy low-mid impact transient.
- **Frequency Profile**: Band-passed noise (600 Hz – 2.4 kHz) combined with 120 Hz transient thump.
- **Duration**: 140 ms.
- **Output Target**: `res://assets/audio/sfx/sfx_strike.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_combat_defend`
- **Category**: Turn-Based Combat Guard
- **Acoustic Profile**: Resonant spirit barrier deflection; ringing energy shield vibration.
- **Frequency Profile**: 150 Hz base fundamental with glass-like harmonics (1.7 kHz, 3.2 kHz).
- **Duration**: 280 ms.
- **Output Target**: `res://assets/audio/sfx/sfx_defend.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_combat_heal`
- **Category**: Restoration Spell
- **Acoustic Profile**: Ascending shimmering arpeggio (C5 -> E5 -> G5 -> C6).
- **Timbre**: Soft vocal bell / etheric warm glow.
- **Duration**: 320 ms.
- **Output Target**: `res://assets/audio/sfx/sfx_heal.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_combat_spell_cast`
- **Category**: Kurei Magic Incantation
- **Acoustic Profile**: Resonant occult surge (A major triad arpeggio: A4 -> C#5 -> E5 -> A5).
- **Duration**: 360 ms.
- **Output Target**: `res://assets/audio/sfx/sfx_spell.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

---

### 2.3 World & Exploration SFX

#### `sfx_dimension_shift`
- **Category**: Planar Shift Mechanic
- **Acoustic Profile**: Upward frequency sweep (300 Hz -> 900 Hz) with phasing whoosh.
- **Duration**: 220 ms.
- **Output Target**: `res://assets/audio/sfx/sfx_shift.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

#### `sfx_portal_transition`
- **Category**: Regional Portal Crossing
- **Acoustic Profile**: Downward vortex sweep (600 Hz -> 180 Hz) with deep resonant settling.
- **Duration**: 350 ms.
- **Output Target**: `res://assets/audio/sfx/sfx_portal.wav`
- **Status**: PENDING BINARY GENERATION (Procedural synthesis active in `AudioManager`).

---

## 3. Background Music (BGM) Production Briefs

### `bgm_alpha_ambient` (Overworld Region Alpha)
- **Tempo**: 64 BPM, non-intrusive 4/4 meter.
- **Instrumentation**: Pentatonic spirit wind chimes, subtle bowed strings, gentle field wind.
- **Key**: D Dorian / A minor modal spirit palette.
- **Looping**: Seamless 48-second loop with zero click at boundary.
- **Output Target**: `res://assets/audio/music/bgm_alpha.ogg`
- **Status**: PENDING BINARY ACQUISITION.

### `bgm_beta_peaks` (Region Beta: Ashen Peaks)
- **Tempo**: 76 BPM, solemn 3/4 meter.
- **Instrumentation**: Low taiko percussion, distant metallic ringing, muted brass drones.
- **Key**: E Phrygian mode.
- **Looping**: Seamless 60-second loop.
- **Output Target**: `res://assets/audio/music/bgm_beta.ogg`
- **Status**: PENDING BINARY ACQUISITION.

### `bgm_boss_theme` (Void Sovereign Encounter)
- **Tempo**: 128 BPM, intense 4/4 driving cadence.
- **Instrumentation**: Driving rhythmic strings, discordant synthesized pads, energetic pulse bass.
- **Key**: C minor harmonic.
- **Looping**: Seamless 75-second loop.
- **Output Target**: `res://assets/audio/music/bgm_boss.ogg`
- **Status**: PENDING BINARY ACQUISITION.

### `bgm_citadel_void` (Void Citadel / Ending Ambience)
- **Tempo**: 52 BPM, contemplative ethereal pulse.
- **Instrumentation**: Sub-bass drone, crystalline granular bells, solitary flute melody.
- **Key**: F# minor Aeolian.
- **Looping**: Seamless 64-second loop.
- **Output Target**: `res://assets/audio/music/bgm_void.ogg`
- **Status**: PENDING BINARY ACQUISITION.
