extends Node
## Original procedural chiptune soundtrack and SFX. No external audio files required.

const RATE := 22050
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var music_tracks: Dictionary = {}
var sfx_tracks: Dictionary = {}
var cries: Dictionary = {}
var crowd_stream: AudioStreamWAV
var generated_music: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_index := 0
var _current_music := ""
var _active_music_player: AudioStreamPlayer
var _music_tween: Tween

func _ready() -> void:
	_rng.seed = 424242
	_ensure_buses()
	_create_players()
	_generate_sfx_library()
	_apply_volume_from_state()
	GameState.settings_applied.connect(_apply_volume_from_state)

func _ensure_buses() -> void:
	for bus_name in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")

func _create_players() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = MUSIC_BUS
	_music_a.volume_db = -4.0
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = MUSIC_BUS
	_music_b.volume_db = -80.0
	add_child(_music_b)
	_active_music_player = _music_a
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = SFX_BUS
	_ambience.volume_db = -18.0
	add_child(_ambience)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = SFX_BUS
		add_child(p)
		_sfx_players.append(p)

func _apply_volume_from_state() -> void:
	var music := clampf(float(GameState.get_setting("music", 0.62)), 0.0, 1.0)
	var sfx := clampf(float(GameState.get_setting("sfx", 0.8)), 0.0, 1.0)
	var music_idx := AudioServer.get_bus_index(MUSIC_BUS)
	var sfx_idx := AudioServer.get_bus_index(SFX_BUS)
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(0.001, music)) - 2.0)
		AudioServer.set_bus_mute(music_idx, music <= 0.001)
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(0.001, sfx)))
		AudioServer.set_bus_mute(sfx_idx, sfx <= 0.001)

# ------------------------------------------------------------------ public API

func prepare_track(track_name: String) -> void:
	if generated_music.has(track_name):
		return
	var stream := _generate_track(track_name)
	if stream != null:
		generated_music[track_name] = stream
		music_tracks[track_name] = stream

func prepare_all_music() -> void:
	for name in ["menu", "playground", "arena", "battle", "rocket", "victory", "defeat"]:
		prepare_track(name)

func play_music(track_name: String, fade: float = 0.8, force: bool = false) -> void:
	if _current_music == track_name and not force and _active_music_player.playing:
		return
	if not generated_music.has(track_name):
		prepare_track(track_name)
	var stream = generated_music.get(track_name)
	if stream == null:
		return
	var old := _active_music_player
	var next: AudioStreamPlayer = _music_b if old == _music_a else _music_a
	next.stream = stream
	next.volume_db = -40.0
	next.play()
	_active_music_player = next
	_current_music = track_name
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(next, "volume_db", -4.0, maxf(0.05, fade)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_music_tween.tween_property(old, "volume_db", -40.0, maxf(0.05, fade)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_music_tween.chain().tween_callback(func():
		if old != _active_music_player:
			old.stop()
	)

func stop_music(fade: float = 0.5) -> void:
	_current_music = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_parallel(true)
	_music_tween.tween_property(_music_a, "volume_db", -40.0, fade)
	_music_tween.tween_property(_music_b, "volume_db", -40.0, fade)
	_music_tween.chain().tween_callback(func():
		_music_a.stop()
		_music_b.stop()
	)

func play_ambience(kind: String, fade: float = 1.0) -> void:
	if kind == "crowd":
		if crowd_stream == null:
			crowd_stream = _generate_crowd()
		if _ambience.stream == crowd_stream and _ambience.playing:
			return
		_ambience.stream = crowd_stream
		_ambience.volume_db = -40.0
		_ambience.play()
		create_tween().tween_property(_ambience, "volume_db", -18.0, fade)
	elif kind == "stop":
		var tw := create_tween()
		tw.tween_property(_ambience, "volume_db", -40.0, fade)
		tw.tween_callback(_ambience.stop)

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sfx_tracks.has(sfx_name):
		return
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = sfx_tracks[sfx_name]
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.4, 2.5)
	player.play()

func play_cry(pokemon_id: String, pitch: float = 1.0) -> void:
	if not cries.has(pokemon_id):
		return
	play_sfx("cry_" + pokemon_id, -3.0, pitch)

func play_hit(effectiveness: float = 1.0) -> void:
	if effectiveness > 1.0:
		play_sfx("super_hit", 1.0, _rng.randf_range(0.95, 1.06))
	elif effectiveness < 1.0:
		play_sfx("weak_hit", -2.0, _rng.randf_range(0.9, 1.02))
	else:
		play_sfx("hit", -1.0, _rng.randf_range(0.92, 1.08))

func music_is_playing() -> bool:
	return _current_music != "" and _active_music_player != null and _active_music_player.playing

# ------------------------------------------------------------------ generation

func _generate_track(track_name: String) -> AudioStreamWAV:
	var spec := _track_spec(track_name)
	if spec.is_empty():
		return null
	var bpm := float(spec.get("bpm", 120.0))
	var beats := int(spec.get("beats", 16))
	var spb := 60.0 / bpm
	var total := int(beats * spb * RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(total)
	buf.fill(0.0)
	var chords: Array = spec.get("chords", [])
	var roots: Array = spec.get("roots", [])
	var beats_per_chord := maxf(1.0, float(beats) / maxf(1.0, float(chords.size())))
	for i in chords.size():
		var start := i * beats_per_chord
		_add_chord(buf, chords[i], start, beats_per_chord * 0.96, spb, spec.get("chord_wave", 1), float(spec.get("chord_gain", 0.06)))
		_add_arpeggio(buf, chords[i], start, beats_per_chord, spb, spec.get("arp_wave", 1), float(spec.get("arp_gain", 0.075)), float(spec.get("arp_rate", 0.5)))
		if i < roots.size():
			_add_bass(buf, int(roots[i]), start, beats_per_chord * 0.96, spb, spec.get("bass_wave", 2), float(spec.get("bass_gain", 0.15)))
	var melody: Array = spec.get("melody", [])
	for note in melody:
		var start_beat := float(note[0])
		var duration := float(note[1])
		var midi := int(note[2])
		var gain := float(note[3]) if note.size() > 3 else 1.0
		_add_note(buf, start_beat, duration, midi, int(spec.get("lead_wave", 0)), float(spec.get("lead_gain", 0.20)) * gain, spb, float(spec.get("vibrato", 0.0)))
	var drums: Array = spec.get("drums", [])
	for hit in drums:
		var beat := float(hit[0])
		var kind := str(hit[1])
		var gain := float(hit[2]) if hit.size() > 2 else 1.0
		match kind:
			"kick": _add_kick(buf, beat, spb, 0.25 * gain)
			"snare": _add_snare(buf, beat, spb, 0.15 * gain)
			"hat": _add_hat(buf, beat, spb, 0.06 * gain)
			"tom": _add_tom(buf, beat, spb, 0.18 * gain)
	_add_echo(buf, int(0.18 * RATE), 0.17)
	_normalize(buf, 0.92)
	var is_loop := bool(spec.get("loop", true))
	if is_loop:
		_crossfade_loop(buf, int(0.025 * RATE))
	return _encode(buf, is_loop)

func _track_spec(track_name: String) -> Dictionary:
	match track_name:
		"menu":
			return {
				"bpm": 112.0, "beats": 16, "loop": true,
				"chords": [[60, 64, 67, 71], [57, 60, 64, 67], [53, 57, 60, 64], [55, 59, 62, 65]],
				"roots": [36, 45, 41, 43],
				"melody": [
					[0, 1, 72], [1, 1, 76], [2, 1, 79], [3, 0.5, 76], [3.5, 0.5, 74],
					[4, 1, 72], [5, 1, 69], [6, 1, 72], [7, 1, 76],
					[8, 1, 77], [9, 1, 81], [10, 1, 79], [11, 0.5, 76], [11.5, 0.5, 74],
					[12, 1, 72], [13, 1, 67], [14, 1, 69], [15, 1, 71],
				],
				"drums": [[0, "kick"], [1, "snare"], [2, "hat"], [2.5, "hat"], [4, "kick"], [5, "snare"], [6, "hat"], [6.5, "hat"], [8, "kick"], [9, "snare"], [10, "hat"], [10.5, "hat"], [12, "kick"], [13, "snare"], [14, "hat"], [15, "hat"]],
				"lead_wave": 0, "chord_wave": 1, "bass_wave": 2, "arp_wave": 1,
				"lead_gain": 0.17, "chord_gain": 0.055, "bass_gain": 0.14, "arp_gain": 0.055, "vibrato": 0.008,
			}
		"playground":
			return {
				"bpm": 124.0, "beats": 16, "loop": true,
				"chords": [[55, 59, 62, 67], [52, 55, 59, 64], [48, 52, 55, 60], [50, 54, 57, 62]],
				"roots": [43, 40, 36, 38],
				"melody": [
					[0, 0.5, 67], [0.5, 0.5, 71], [1, 1, 74], [2, 0.5, 79], [2.5, 0.5, 78], [3, 1, 74],
					[4, 0.5, 71], [4.5, 0.5, 74], [5, 1, 76], [6, 1, 79], [7, 0.5, 76], [7.5, 0.5, 74],
					[8, 0.5, 72], [8.5, 0.5, 76], [9, 1, 79], [10, 0.5, 81], [10.5, 0.5, 79], [11, 1, 76],
					[12, 0.5, 74], [12.5, 0.5, 77], [13, 1, 81], [14, 1, 79], [15, 1, 74],
				],
				"drums": [[0, "kick"], [1, "snare"], [2, "hat"], [2.5, "hat"], [3, "kick"], [4, "kick"], [5, "snare"], [6, "hat"], [6.5, "hat"], [7, "kick"], [8, "kick"], [9, "snare"], [10, "hat"], [10.5, "hat"], [11, "kick"], [12, "kick"], [13, "snare"], [14, "hat"], [14.5, "hat"], [15, "kick"]],
				"lead_wave": 0, "chord_wave": 1, "bass_wave": 2, "arp_wave": 1,
				"lead_gain": 0.16, "chord_gain": 0.05, "bass_gain": 0.15, "arp_gain": 0.06, "vibrato": 0.004,
			}
		"arena":
			return {
				"bpm": 96.0, "beats": 16, "loop": true,
				"chords": [[50, 53, 57, 62], [46, 50, 53, 58], [53, 57, 60, 65], [57, 61, 64, 69]],
				"roots": [38, 34, 41, 45],
				"melody": [
					[0, 2, 74], [2, 1, 77], [3, 1, 81], [4, 2, 79], [6, 1, 77], [7, 1, 74],
					[8, 2, 72], [10, 1, 74], [11, 1, 77], [12, 2, 81], [14, 1, 84], [15, 1, 81],
				],
				"drums": [[0, "kick", 1.2], [2, "tom"], [4, "kick", 1.2], [6, "tom"], [8, "kick", 1.2], [10, "tom"], [12, "kick", 1.2], [14, "snare"], [15, "snare"]],
				"lead_wave": 3, "chord_wave": 3, "bass_wave": 2, "arp_wave": 3,
				"lead_gain": 0.14, "chord_gain": 0.045, "bass_gain": 0.18, "arp_gain": 0.045, "vibrato": 0.005,
			}
		"battle":
			return {
				"bpm": 144.0, "beats": 16, "loop": true,
				"chords": [[52, 55, 59, 64], [48, 52, 55, 60], [55, 59, 62, 67], [50, 54, 57, 62]],
				"roots": [40, 36, 43, 38],
				"melody": [
					[0, 0.5, 76], [0.5, 0.5, 79], [1, 0.5, 83], [1.5, 0.5, 79], [2, 0.5, 76], [2.5, 0.5, 79], [3, 0.5, 83], [3.5, 0.5, 86],
					[4, 0.5, 84], [4.5, 0.5, 79], [5, 0.5, 76], [5.5, 0.5, 72], [6, 0.5, 76], [6.5, 0.5, 79], [7, 1, 84],
					[8, 0.5, 83], [8.5, 0.5, 79], [9, 0.5, 76], [9.5, 0.5, 74], [10, 0.5, 71], [10.5, 0.5, 74], [11, 1, 79],
					[12, 0.5, 81], [12.5, 0.5, 78], [13, 0.5, 74], [13.5, 0.5, 78], [14, 0.5, 81], [14.5, 0.5, 86], [15, 0.5, 84],
				],
				"drums": [[0, "kick"], [0.5, "hat"], [1, "snare"], [1.5, "hat"], [2, "kick"], [2.5, "hat"], [3, "snare"], [3.5, "hat"], [4, "kick"], [4.5, "hat"], [5, "snare"], [5.5, "hat"], [6, "kick"], [6.5, "hat"], [7, "snare"], [7.5, "hat"], [8, "kick"], [8.5, "hat"], [9, "snare"], [9.5, "hat"], [10, "kick"], [10.5, "hat"], [11, "snare"], [11.5, "hat"], [12, "kick"], [12.5, "hat"], [13, "snare"], [13.5, "hat"], [14, "kick"], [14.5, "hat"], [15, "snare"], [15.5, "hat"]],
				"lead_wave": 0, "chord_wave": 2, "bass_wave": 2, "arp_wave": 0,
				"lead_gain": 0.15, "chord_gain": 0.045, "bass_gain": 0.16, "arp_gain": 0.06, "vibrato": 0.004,
			}
		"rocket":
			return {
				"bpm": 128.0, "beats": 16, "loop": true,
				"chords": [[48, 51, 55, 60], [44, 48, 51, 56], [41, 44, 48, 53], [43, 47, 50, 55]],
				"roots": [36, 32, 29, 31],
				"melody": [
					[0, 0.75, 72], [0.75, 0.75, 75], [1.5, 0.5, 72], [2, 1, 68], [3, 1, 67],
					[4, 0.75, 68], [4.75, 0.75, 72], [5.5, 0.5, 75], [6, 1, 80], [7, 1, 79],
					[8, 0.75, 77], [8.75, 0.75, 80], [9.5, 0.5, 77], [10, 1, 72], [11, 1, 71],
					[12, 0.75, 79], [12.75, 0.75, 75], [13.5, 0.5, 71], [14, 1, 68], [15, 1, 67],
				],
				"drums": [[0, "kick", 1.3], [1, "snare"], [2, "tom"], [3, "snare"], [4, "kick", 1.3], [5, "snare"], [6, "tom"], [7, "snare"], [8, "kick", 1.3], [9, "snare"], [10, "tom"], [11, "snare"], [12, "kick", 1.3], [13, "snare"], [14, "tom"], [15, "snare"]],
				"lead_wave": 1, "chord_wave": 2, "bass_wave": 2, "arp_wave": 1,
				"lead_gain": 0.15, "chord_gain": 0.05, "bass_gain": 0.19, "arp_gain": 0.05, "vibrato": 0.015,
			}
		"victory":
			return {
				"bpm": 120.0, "beats": 8, "loop": false,
				"chords": [[60, 64, 67], [65, 69, 72], [67, 71, 74], [60, 64, 67]],
				"roots": [36, 41, 43, 36],
				"melody": [[0, 0.5, 72], [0.5, 0.5, 76], [1, 0.5, 79], [1.5, 0.5, 84], [2, 1, 79], [3, 1, 84], [4, 1, 81], [5, 0.5, 79], [5.5, 0.5, 77], [6, 1, 76], [7, 1, 72]],
				"drums": [[0, "kick"], [1, "snare"], [2, "kick"], [3, "snare"], [4, "kick"], [5, "snare"], [6, "kick"], [7, "snare"]],
				"lead_wave": 0, "chord_wave": 1, "bass_wave": 2, "arp_wave": 1,
				"lead_gain": 0.2, "chord_gain": 0.07, "bass_gain": 0.16, "arp_gain": 0.07,
			}
		"defeat":
			return {
				"bpm": 80.0, "beats": 8, "loop": false,
				"chords": [[57, 60, 64], [53, 57, 60], [50, 53, 57], [45, 48, 52]],
				"roots": [45, 41, 38, 33],
				"melody": [[0, 1, 72], [1, 1, 69], [2, 1, 67], [3, 1, 64], [4, 1, 65], [5, 1, 62], [6, 2, 57]],
				"drums": [[0, "kick"], [2, "tom"], [4, "kick"], [6, "tom"]],
				"lead_wave": 1, "chord_wave": 1, "bass_wave": 2, "arp_wave": 1,
				"lead_gain": 0.15, "chord_gain": 0.06, "bass_gain": 0.14, "arp_gain": 0.04,
			}
	return {}

func _add_note(buf: PackedFloat32Array, start_beat: float, duration_beat: float, midi: int, wave: int, gain: float, spb: float, vibrato: float = 0.0) -> void:
	var start := int(start_beat * spb * RATE)
	var length := int(duration_beat * spb * RATE)
	if start < 0 or length <= 1 or start >= buf.size():
		return
	length = mini(length, buf.size() - start)
	var freq := _midi_to_freq(midi)
	var dur_s := float(length) / RATE
	var attack := 0.008
	var release := minf(0.10, dur_s * 0.4)
	for i in length:
		var t := float(i) / RATE
		var env := minf(1.0, t / attack)
		env *= 0.68 + 0.32 * exp(-t * 3.5)
		if t > dur_s - release:
			env *= maxf(0.0, (dur_s - t) / release)
		var phase := TAU * freq * t
		if vibrato > 0.0:
			phase += sin(t * 28.0) * vibrato * 12.0
		buf[start + i] += _wave(wave, phase) * gain * env

func _add_chord(buf: PackedFloat32Array, chord: Array, start_beat: float, duration_beat: float, spb: float, wave: int, gain: float) -> void:
	for midi in chord:
		_add_note(buf, start_beat, duration_beat, int(midi), wave, gain, spb, 0.002)
		_add_note(buf, start_beat, duration_beat, int(midi) - 12, wave, gain * 0.35, spb, 0.002)

func _add_arpeggio(buf: PackedFloat32Array, chord: Array, start_beat: float, duration_beat: float, spb: float, wave: int, gain: float, step: float) -> void:
	if chord.is_empty():
		return
	var index := 0
	var t := 0.0
	while t < duration_beat:
		var midi := int(chord[index % chord.size()]) + 12
		_add_note(buf, start_beat + t, minf(step * 0.9, duration_beat - t), midi, wave, gain, spb, 0.0)
		index += 1
		t += step

func _add_bass(buf: PackedFloat32Array, root: int, start_beat: float, duration_beat: float, spb: float, wave: int, gain: float) -> void:
	var steps := 4
	var step_len := duration_beat / float(steps)
	for i in steps:
		var midi := root + (12 if i % 2 == 1 else 0)
		_add_note(buf, start_beat + i * step_len, step_len * 0.8, midi, wave, gain, spb, 0.0)

func _wave(kind: int, phase: float) -> float:
	match kind:
		0: # square
			return 1.0 if sin(phase) >= 0.0 else -1.0
		1: # triangle
			return 2.0 / PI * asin(sin(phase))
		2: # saw
			var p := phase / TAU
			return 2.0 * (p - floor(p + 0.5))
		3: # soft brass-ish square
			return tanh(2.0 * (1.0 if sin(phase) >= 0.0 else -1.0) + 0.4 * sin(phase * 2.0))
		_:
			return sin(phase)

func _add_kick(buf: PackedFloat32Array, beat: float, spb: float, gain: float) -> void:
	var start := int(beat * spb * RATE)
	var length := int(0.18 * RATE)
	for i in length:
		if start + i >= buf.size():
			return
		var t := float(i) / RATE
		var env := exp(-t * 18.0)
		var freq := 48.0 + 95.0 * exp(-t * 28.0)
		buf[start + i] += sin(TAU * freq * t) * env * gain

func _add_snare(buf: PackedFloat32Array, beat: float, spb: float, gain: float) -> void:
	var start := int(beat * spb * RATE)
	var length := int(0.14 * RATE)
	for i in length:
		if start + i >= buf.size():
			return
		var t := float(i) / RATE
		var env := exp(-t * 24.0)
		var noise := _rng.randf_range(-1.0, 1.0)
		var body := sin(TAU * 180.0 * t) * 0.3
		buf[start + i] += (noise * 0.7 + body) * env * gain

func _add_hat(buf: PackedFloat32Array, beat: float, spb: float, gain: float) -> void:
	var start := int(beat * spb * RATE)
	var length := int(0.05 * RATE)
	var prev := 0.0
	for i in length:
		if start + i >= buf.size():
			return
		var t := float(i) / RATE
		var env := exp(-t * 70.0)
		var noise := _rng.randf_range(-1.0, 1.0)
		var high := noise - prev * 0.75
		prev = noise
		buf[start + i] += high * env * gain

func _add_tom(buf: PackedFloat32Array, beat: float, spb: float, gain: float) -> void:
	var start := int(beat * spb * RATE)
	var length := int(0.22 * RATE)
	for i in length:
		if start + i >= buf.size():
			return
		var t := float(i) / RATE
		var env := exp(-t * 12.0)
		var freq := 90.0 + 50.0 * exp(-t * 16.0)
		buf[start + i] += sin(TAU * freq * t) * env * gain

func _add_echo(buf: PackedFloat32Array, delay: int, amount: float) -> void:
	if delay <= 0 or delay >= buf.size():
		return
	for i in range(delay, buf.size()):
		buf[i] += buf[i - delay] * amount

func _normalize(buf: PackedFloat32Array, target: float) -> void:
	var peak := 0.0001
	for s in buf:
		peak = maxf(peak, absf(s))
	var scale := target / peak
	if scale < 1.0:
		for i in buf.size():
			buf[i] = clampf(buf[i] * scale, -1.0, 1.0)
	else:
		for i in buf.size():
			buf[i] = clampf(buf[i] * scale, -1.0, 1.0)

func _crossfade_loop(buf: PackedFloat32Array, fade: int) -> void:
	if fade <= 1 or fade * 2 >= buf.size():
		return
	var n := buf.size()
	for i in fade:
		var t := float(i) / float(fade)
		buf[n - fade + i] = lerpf(buf[n - fade + i], buf[i], t)

func _encode(buf: PackedFloat32Array, looped: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		var v := int(clampf(buf[i], -1.0, 1.0) * 32767.0)
		if v < 0:
			v += 65536
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = buf.size()
	return stream

func _midi_to_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (float(midi) - 69.0) / 12.0)

# ------------------------------------------------------------------ SFX / cries

func _generate_sfx_library() -> void:
	sfx_tracks["click"] = _make_sfx("click")
	sfx_tracks["hover"] = _make_sfx("hover")
	sfx_tracks["confirm"] = _make_sfx("confirm")
	sfx_tracks["back"] = _make_sfx("back")
	sfx_tracks["hit"] = _make_sfx("hit")
	sfx_tracks["super_hit"] = _make_sfx("super_hit")
	sfx_tracks["weak_hit"] = _make_sfx("weak_hit")
	sfx_tracks["faint"] = _make_sfx("faint")
	sfx_tracks["heal"] = _make_sfx("heal")
	sfx_tracks["unlock"] = _make_sfx("unlock")
	sfx_tracks["whoosh"] = _make_sfx("whoosh")
	sfx_tracks["rocket_alarm"] = _make_sfx("rocket_alarm")
	sfx_tracks["crowd_cheer"] = _make_sfx("crowd_cheer")
	sfx_tracks["pokeball_open"] = _make_sfx("pokeball_open")
	sfx_tracks["level_up"] = _make_sfx("level_up")
	sfx_tracks["cancel"] = _make_sfx("cancel")
	for id in ["charizard", "bulbasaur", "gengar", "pikachu", "squirtle"]:
		var cry := _make_cry(id)
		cries[id] = cry
		sfx_tracks["cry_" + id] = cry

func _make_sfx(kind: String) -> AudioStreamWAV:
	var duration := 0.3
	match kind:
		"click": duration = 0.08
		"hover": duration = 0.06
		"confirm": duration = 0.34
		"back": duration = 0.22
		"hit": duration = 0.30
		"super_hit": duration = 0.48
		"weak_hit": duration = 0.24
		"faint": duration = 1.1
		"heal": duration = 0.7
		"unlock": duration = 1.3
		"whoosh": duration = 0.38
		"rocket_alarm": duration = 1.0
		"crowd_cheer": duration = 1.4
		"pokeball_open": duration = 0.5
		"level_up": duration = 0.9
		"cancel": duration = 0.14
	var count := int(duration * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	buf.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + 77
	for i in count:
		var t := float(i) / RATE
		var p := t / duration
		var s := 0.0
		match kind:
			"click":
				s = sin(TAU * (900.0 - 300.0 * p) * t) * exp(-t * 40.0)
			"hover":
				s = sin(TAU * 1200.0 * t) * exp(-t * 55.0) * 0.35
			"confirm":
				var f := 520.0 + 380.0 * p
				s = (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t)) * exp(-t * 6.0) * minf(1.0, t * 60.0)
			"back":
				s = sin(TAU * (520.0 - 250.0 * p) * t) * exp(-t * 10.0)
			"cancel":
				s = sin(TAU * 220.0 * t) * exp(-t * 18.0)
			"hit":
				var env := exp(-t * 11.0)
				s = (rng.randf_range(-1.0, 1.0) * 0.55 + sin(TAU * (160.0 - 60.0 * p) * t) * 0.8) * env
			"super_hit":
				var env := exp(-t * 7.0)
				s = (rng.randf_range(-1.0, 1.0) * 0.35 + sin(TAU * (90.0 + 220.0 * exp(-t * 12.0)) * t) * 0.7) * env
				s += sin(TAU * (740.0 + 600.0 * p) * t) * exp(-t * 5.0) * 0.18
			"weak_hit":
				s = (rng.randf_range(-1.0, 1.0) * 0.3 + sin(TAU * 110.0 * t) * 0.45) * exp(-t * 15.0)
			"faint":
				var f := 360.0 * pow(0.12, p)
				s = sin(TAU * f * t) * (1.0 - p) * 0.7
				s += sin(TAU * f * 0.5 * t) * (1.0 - p) * 0.25
			"heal":
				var f := 440.0 + 660.0 * p
				s = (sin(TAU * f * t) + 0.5 * sin(TAU * f * 1.5 * t)) * sin(PI * p) * 0.6
			"unlock":
				var notes := [523.25, 659.25, 783.99, 1046.5]
				var idx := mini(3, int(p * 4.0))
				var f: float = notes[idx]
				s = (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.0 * t)) * sin(PI * p) * 0.55
			"whoosh":
				s = rng.randf_range(-1.0, 1.0) * sin(PI * p) * (0.5 - p * 0.3)
			"rocket_alarm":
				var pulse := fmod(t, 0.25)
				var f := 880.0 if int(t / 0.25) % 2 == 0 else 660.0
				s = sin(TAU * f * t) * exp(-pulse * 9.0) * 0.5
			"crowd_cheer":
				s = rng.randf_range(-1.0, 1.0) * sin(PI * p) * 0.5
				s += sin(TAU * (500.0 + 300.0 * p) * t) * sin(PI * p) * 0.08
			"pokeball_open":
				var f := 700.0 + 900.0 * p
				s = sin(TAU * f * t) * exp(-t * 6.0) * 0.5
				s += rng.randf_range(-1.0, 1.0) * exp(-t * 30.0) * 0.25
			"level_up":
				var f := 600.0 + 900.0 * p
				s = (sin(TAU * f * t) + 0.4 * sin(TAU * f * 2.0 * t)) * sin(PI * p) * 0.5
		buf[i] = s
	_normalize(buf, 0.8)
	return _encode(buf, false)

func _make_cry(id: String) -> AudioStreamWAV:
	var duration := 0.6
	var count := int(duration * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	buf.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id) + 123
	var base := 300.0
	var end := 180.0
	var grit := 0.15
	match id:
		"charizard":
			base = 160.0; end = 90.0; grit = 0.25; duration = 0.9
		"bulbasaur":
			base = 420.0; end = 620.0; grit = 0.05; duration = 0.55
		"gengar":
			base = 240.0; end = 120.0; grit = 0.35; duration = 0.8
		"pikachu":
			base = 880.0; end = 1380.0; grit = 0.08; duration = 0.45
		"squirtle":
			base = 520.0; end = 330.0; grit = 0.06; duration = 0.5
	var count2 := int(duration * RATE)
	buf.resize(count2)
	for i in count2:
		var t := float(i) / RATE
		var p := t / duration
		var freq := lerpf(base, end, p) * (1.0 + sin(t * 38.0) * 0.02)
		var env := minf(1.0, t * 50.0) * (1.0 - p) * (0.8 + 0.2 * sin(t * 20.0))
		var s := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.0 * t) * 0.2
		s += rng.randf_range(-1.0, 1.0) * grit
		buf[i] = s * env
	_normalize(buf, 0.75)
	return _encode(buf, false)

func _generate_crowd() -> AudioStreamWAV:
	var duration := 6.0
	var count := int(duration * RATE)
	var buf := PackedFloat32Array()
	buf.resize(count)
	buf.fill(0.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99173
	var filtered := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		filtered = filtered * 0.82 + noise * 0.18
		var swell := 0.35 + 0.15 * sin(t * 0.7) + 0.1 * sin(t * 1.9 + 1.2)
		var cheer := 0.0
		if fmod(t, 2.7) < 0.5:
			cheer = sin(PI * fmod(t, 2.7) / 0.5) * 0.18
		buf[i] = (filtered * 0.65 + noise * 0.12 + cheer) * swell * 0.4
	_crossfade_loop(buf, int(0.08 * RATE))
	_normalize(buf, 0.6)
	return _encode(buf, true)
