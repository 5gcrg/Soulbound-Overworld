class_name AudioManager
extends Node

## AudioManager — Procedural SFX & Sound Feedback Controller
## Requirements: GDD-098/103, TC-ACC-001, AGENTS.md Invariants.
##
## Provides procedural audio feedback for game feedback events:
## - Combat strikes, defense guards, spells, and healing
## - Dimensional phase shifts and portal transitions
## - Educational question feedback (correct chime, wrong cue)
## - UI interaction clicks
##
## Uses Godot-native AudioStreamWAV synthesis with zero external binary dependencies.

signal cue_played(cue_name: String)

const SAMPLE_RATE: int = 22050
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _max_players: int = 8

## Idempotent bus-initialization helper callable before player creation and before settings application.
## Ensures Music and SFX buses exist and route to Master without duplicating or reordering buses.
static func ensure_audio_buses() -> void:
	_ensure_bus(BUS_MUSIC, BUS_MASTER)
	_ensure_bus(BUS_SFX, BUS_MASTER)

static func _ensure_bus(bus_name: StringName, send_to: StringName) -> int:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, String(bus_name))
	if AudioServer.get_bus_send(idx) != send_to:
		AudioServer.set_bus_send(idx, send_to)
	return idx

func _init() -> void:
	ensure_audio_buses()

func _ready() -> void:
	ensure_audio_buses()
	if _players.is_empty():
		_create_players()
	_pregenerate_cues()

func _create_players() -> void:
	var sfx_idx: int = AudioServer.get_bus_index(BUS_SFX)
	if sfx_idx < 0:
		push_error("AudioManager: SFX bus does not exist before creating players")
	assert(sfx_idx >= 0, "AudioManager: SFX bus must exist before creating players")

	for i in range(_max_players):
		var player := AudioStreamPlayer.new()
		player.bus = BUS_SFX
		if player.bus != BUS_SFX:
			push_error("AudioManager: player bus fell back to %s instead of %s" % [player.bus, BUS_SFX])
		assert(player.bus == BUS_SFX, "AudioManager: player bus must be SFX")
		add_child(player)
		_players.append(player)

func get_players() -> Array[AudioStreamPlayer]:
	return _players

func play_cue(cue_name: String) -> void:
	if not _cache.has(cue_name):
		return

	var stream: AudioStreamWAV = _cache[cue_name] as AudioStreamWAV
	if stream == null:
		return

	for player in _players:
		if not player.playing:
			player.stream = stream
			player.play()
			cue_played.emit(cue_name)
			return

	# Fallback: steal oldest player
	if not _players.is_empty():
		_players[0].stream = stream
		_players[0].play()
		cue_played.emit(cue_name)

func _pregenerate_cues() -> void:
	_cache["button"] = _generate_tone(880.0, 0.04, "square", 0.15)
	_cache["strike"] = _generate_noise_hit(0.12, 0.3)
	_cache["defend"] = _generate_tone(150.0, 0.18, "sine", 0.35)
	_cache["heal"] = _generate_arpeggio([523.25, 659.25, 783.99, 1046.50], 0.08, 0.25) # C5, E5, G5, C6
	_cache["spell_cast"] = _generate_arpeggio([440.0, 554.37, 659.25, 880.0], 0.09, 0.3) # A Major
	_cache["shift"] = _generate_sweep(300.0, 900.0, 0.22, 0.3)
	_cache["portal"] = _generate_sweep(600.0, 180.0, 0.35, 0.35)
	_cache["correct"] = _generate_arpeggio([523.25, 659.25, 1046.50], 0.10, 0.35)
	_cache["wrong"] = _generate_tone(180.0, 0.25, "saw", 0.25)

func _generate_tone(freq: float, duration: float, wave_type: String = "sine", volume: float = 0.3) -> AudioStreamWAV:
	var total_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t: float = float(i) / float(SAMPLE_RATE)
		var sample: float = 0.0

		if wave_type == "sine":
			sample = sin(TAU * freq * t)
		elif wave_type == "square":
			sample = 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0
		elif wave_type == "saw":
			sample = 2.0 * fmod(t * freq, 1.0) - 1.0

		# Apply linear fade-out envelope
		var envelope: float = 1.0 - (float(i) / float(total_samples))
		var int_sample: int = int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)

		# 16-bit signed PCM little-endian
		bytes.encode_s16(i * 2, int_sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _generate_noise_hit(duration: float, volume: float = 0.3) -> AudioStreamWAV:
	var total_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	for i in range(total_samples):
		var noise: float = rng.randf_range(-1.0, 1.0)
		var envelope: float = pow(1.0 - (float(i) / float(total_samples)), 2.0)
		var int_sample: int = int(clampf(noise * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _generate_arpeggio(freqs: Array, note_duration: float, volume: float = 0.3) -> AudioStreamWAV:
	var total_samples: int = int(SAMPLE_RATE * note_duration * freqs.size())
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var samples_per_note: int = int(SAMPLE_RATE * note_duration)

	for note_idx in range(freqs.size()):
		var freq: float = float(freqs[note_idx])
		for s in range(samples_per_note):
			var i: int = note_idx * samples_per_note + s
			var t: float = float(s) / float(SAMPLE_RATE)
			var sample: float = sin(TAU * freq * t)
			var envelope: float = 1.0 - (float(s) / float(samples_per_note))
			var int_sample: int = int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
			bytes.encode_s16(i * 2, int_sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _generate_sweep(freq_start: float, freq_end: float, duration: float, volume: float = 0.3) -> AudioStreamWAV:
	var total_samples: int = int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	var phase: float = 0.0
	for i in range(total_samples):
		var progress: float = float(i) / float(total_samples)
		var current_freq: float = lerpf(freq_start, freq_end, progress)
		phase += TAU * current_freq / float(SAMPLE_RATE)

		var sample: float = sin(phase)
		var envelope: float = sin(PI * progress) # Smooth bell envelope
		var int_sample: int = int(clampf(sample * envelope * volume, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, int_sample)

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
