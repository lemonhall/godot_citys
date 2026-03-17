extends Node
class_name CityMusicRoadNotePlayer

const DEFAULT_VOICE_COUNT := 16
const FALLBACK_SAMPLE_RATE := 44100
const FALLBACK_MIN_DURATION_SEC := 0.12
const FALLBACK_MAX_DURATION_SEC := 0.68
const FALLBACK_ATTACK_SEC := 0.006
const FALLBACK_MIN_RELEASE_SEC := 0.05
const FALLBACK_MAX_RELEASE_SEC := 0.14
const FALLBACK_DURATION_BUCKETS_SEC := [0.14, 0.22, 0.34, 0.52, 0.82]

var _sample_bank_manifest_path := ""
var _sample_paths_by_id: Dictionary = {}
var _stream_cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player_index := 0
var _playback_enabled := true
var _triggered_note_count := 0
var _played_note_count := 0
var _suppressed_note_count := 0
var _last_sample_id := ""
var _bank_status := "unconfigured"
var _peak_active_voice_count := 0

func configure(sample_bank_manifest_path: String, voice_count: int = DEFAULT_VOICE_COUNT) -> void:
	_sample_bank_manifest_path = sample_bank_manifest_path
	_sample_paths_by_id.clear()
	_stream_cache.clear()
	_triggered_note_count = 0
	_played_note_count = 0
	_suppressed_note_count = 0
	_last_sample_id = ""
	_bank_status = "missing"
	_peak_active_voice_count = 0
	_ensure_players(voice_count)
	if _sample_bank_manifest_path == "":
		return
	var global_manifest_path := ProjectSettings.globalize_path(_sample_bank_manifest_path)
	if not FileAccess.file_exists(global_manifest_path):
		return
	var manifest_text := FileAccess.get_file_as_string(global_manifest_path)
	if manifest_text.strip_edges() == "":
		return
	var manifest_variant = JSON.parse_string(manifest_text)
	if not (manifest_variant is Dictionary):
		return
	var samples_variant = (manifest_variant as Dictionary).get("samples", [])
	if not (samples_variant is Array):
		return
	for sample_variant in samples_variant:
		if not (sample_variant is Dictionary):
			continue
		var sample: Dictionary = sample_variant
		var sample_id := str(sample.get("sample_id", "")).strip_edges()
		var sample_path := str(sample.get("sample_path", "")).strip_edges()
		if sample_id == "" or sample_path == "":
			continue
		_sample_paths_by_id[sample_id] = sample_path
	_bank_status = "ready" if not _sample_paths_by_id.is_empty() else "empty"

func play_note_event(note_event: Dictionary) -> bool:
	var sample_id := str(note_event.get("sample_id", "")).strip_edges()
	if sample_id == "":
		return false
	_triggered_note_count += 1
	var sample_path := str(_sample_paths_by_id.get(sample_id, "")).strip_edges()
	var stream = null
	if sample_path != "":
		stream = _load_stream(sample_id, sample_path)
	if stream == null:
		stream = _build_fallback_stream(
			int(note_event.get("midi_note", 0)),
			float(note_event.get("duration_sec", 0.25))
		)
		if stream == null:
			_bank_status = "missing_sample" if sample_path == "" else "load_failed"
			_last_sample_id = sample_id
			return false
	if _players.is_empty():
		_ensure_players(DEFAULT_VOICE_COUNT)
	if _players.is_empty():
		return false
	var player := _players[_next_player_index]
	_next_player_index = (_next_player_index + 1) % _players.size()
	player.stop()
	player.stream = stream
	player.volume_db = _velocity_to_volume_db(int(note_event.get("velocity", 100)))
	if not _playback_enabled:
		_suppressed_note_count += 1
		_last_sample_id = sample_id
		_bank_status = "ready" if sample_path != "" else "fallback_synth"
		return true
	player.play()
	_peak_active_voice_count = maxi(_peak_active_voice_count, _count_active_voices())
	_played_note_count += 1
	_last_sample_id = sample_id
	_bank_status = "ready" if sample_path != "" else "fallback_synth"
	return true

func set_playback_enabled(enabled: bool) -> void:
	_playback_enabled = enabled
	if enabled:
		return
	for player in _players:
		if player != null and is_instance_valid(player):
			player.stop()

func get_state() -> Dictionary:
	var active_voice_count := _count_active_voices()
	var peak_active_voice_count := maxi(_peak_active_voice_count, active_voice_count)
	return {
		"playback_enabled": _playback_enabled,
		"bank_status": _bank_status,
		"manifest_path": _sample_bank_manifest_path,
		"available_sample_count": _sample_paths_by_id.size(),
		"loaded_sample_count": _stream_cache.size(),
		"triggered_note_count": _triggered_note_count,
		"played_note_count": _played_note_count,
		"suppressed_note_count": _suppressed_note_count,
		"last_sample_id": _last_sample_id,
		"voice_count": _players.size(),
		"active_voice_count": active_voice_count,
		"peak_active_voice_count": peak_active_voice_count,
	}

func prewarm_fallback_bank(note_event_like_items: Array) -> void:
	if not _sample_paths_by_id.is_empty():
		return
	var seen_keys: Dictionary = {}
	for item_variant in note_event_like_items:
		if not (item_variant is Dictionary):
			continue
		var item: Dictionary = item_variant
		var midi_note := int(item.get("midi_note", 0))
		var quantized_duration_sec := _quantize_note_duration_sec(float(item.get("duration_sec", 0.25)))
		var cache_key := "fallback_%03d_%04d" % [clampi(midi_note, 21, 108), int(round(quantized_duration_sec * 1000.0))]
		if seen_keys.has(cache_key):
			continue
		seen_keys[cache_key] = true
		_build_fallback_stream(midi_note, quantized_duration_sec)

func _ensure_players(voice_count: int) -> void:
	var resolved_voice_count := maxi(voice_count, 1)
	for player in _players:
		if player != null and is_instance_valid(player):
			player.queue_free()
	_players.clear()
	for voice_index in range(resolved_voice_count):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%02d" % voice_index
		add_child(player)
		_players.append(player)
	_next_player_index = 0

func _load_stream(sample_id: String, sample_path: String):
	if _stream_cache.has(sample_id):
		return _stream_cache.get(sample_id)
	var stream = load(sample_path)
	_stream_cache[sample_id] = stream
	return stream

func _build_fallback_stream(midi_note: int, note_duration_sec: float):
	var resolved_midi_note := clampi(midi_note, 21, 108)
	var resolved_duration_sec := _quantize_note_duration_sec(note_duration_sec)
	var release_sec := clampf(resolved_duration_sec * 0.22 + 0.03, FALLBACK_MIN_RELEASE_SEC, FALLBACK_MAX_RELEASE_SEC)
	var total_duration_sec := clampf(resolved_duration_sec * 0.52 + release_sec, FALLBACK_MIN_DURATION_SEC, FALLBACK_MAX_DURATION_SEC)
	var duration_bucket_ms := int(round(resolved_duration_sec * 1000.0))
	var cache_key := "fallback_%03d_%04d" % [resolved_midi_note, duration_bucket_ms]
	if _stream_cache.has(cache_key):
		return _stream_cache.get(cache_key)
	var frame_count := int(round(FALLBACK_SAMPLE_RATE * total_duration_sec))
	if frame_count <= 0:
		return null
	var frequency_hz := 440.0 * pow(2.0, float(resolved_midi_note - 69) / 12.0)
	var pcm_data := PackedByteArray()
	pcm_data.resize(frame_count * 2)
	for frame_index in range(frame_count):
		var time_sec := float(frame_index) / float(FALLBACK_SAMPLE_RATE)
		var attack_t := clampf(time_sec / maxf(FALLBACK_ATTACK_SEC, 0.0001), 0.0, 1.0)
		var release_t := clampf((total_duration_sec - time_sec) / maxf(release_sec, 0.0001), 0.0, 1.0)
		var envelope := minf(attack_t, release_t)
		envelope = pow(envelope, 0.88)
		var tone_decay := exp(-time_sec * 2.4)
		var waveform := sin(TAU * frequency_hz * time_sec)
		waveform += sin(TAU * frequency_hz * 2.0 * time_sec) * 0.12 * tone_decay
		waveform += sin(TAU * frequency_hz * 3.0 * time_sec) * 0.04 * tone_decay
		var sample_value := clampf(waveform * envelope * 0.22, -1.0, 1.0)
		var sample_int := int(round(sample_value * 32767.0))
		var byte_offset := frame_index * 2
		pcm_data[byte_offset] = sample_int & 0xFF
		pcm_data[byte_offset + 1] = (sample_int >> 8) & 0xFF
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = FALLBACK_SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = pcm_data
	_stream_cache[cache_key] = stream
	return stream

func _quantize_note_duration_sec(note_duration_sec: float) -> float:
	var resolved_duration_sec := clampf(note_duration_sec, 0.05, 1.4)
	var best_bucket := FALLBACK_DURATION_BUCKETS_SEC[0]
	var best_distance := absf(resolved_duration_sec - float(best_bucket))
	for bucket_variant in FALLBACK_DURATION_BUCKETS_SEC:
		var bucket := float(bucket_variant)
		var distance := absf(resolved_duration_sec - bucket)
		if distance < best_distance:
			best_distance = distance
			best_bucket = bucket
	return best_bucket

func _velocity_to_volume_db(velocity: int) -> float:
	var normalized := clampf(float(velocity) / 127.0, 0.0, 1.0)
	return lerpf(-14.0, -4.0, normalized)

func _count_active_voices() -> int:
	var active_voice_count := 0
	for player in _players:
		if player != null and is_instance_valid(player) and player.playing:
			active_voice_count += 1
	return active_voice_count
