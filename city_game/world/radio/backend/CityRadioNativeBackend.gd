extends "res://city_game/world/radio/backend/CityRadioStreamBackend.gd"
class_name CityRadioNativeBackend

const GDEXTENSION_PATH := "res://city_game/native/radio_backend/radio_backend.gdextension"
const BRIDGE_CLASS_NAME := "CityRadioNativeBridge"
const TARGET_MIX_RATE := 48000
const AUDIO_BUFFER_LENGTH_SEC := 1.5
const AUDIO_POP_BATCH_FRAMES := 2048
const AUDIO_FRAME_BUDGET_PER_TICK := 8192
const AUDIO_PLAYER_NAME := "CityRadioNativeAudioPlayer"

var _bridge: Object = null
var _available := false
var _unavailability_reason := ""
var _build_summary := ""
var _boot_attempted := false
var _audio_host: Node = null
var _audio_player: AudioStreamPlayer = null
var _audio_stream: AudioStreamGenerator = null
var _audio_playback: AudioStreamGeneratorPlayback = null

func _init() -> void:
	_state["backend_id"] = "native"

func is_available() -> bool:
	_ensure_boot()
	return _available

func get_unavailability_reason() -> String:
	_ensure_boot()
	return _unavailability_reason

func get_build_summary() -> String:
	_ensure_boot()
	return _build_summary

func attach_audio_host(host: Node) -> void:
	_audio_host = host
	_ensure_audio_output()
	_apply_audio_player_volume()

func update_audio_output() -> void:
	_ensure_boot()
	_sync_bridge_state()
	if not _available or _bridge == null or not is_instance_valid(_audio_host):
		return
	if str(_state.get("playback_state", "stopped")) != "playing":
		return
	var playback := _ensure_audio_playback()
	if playback == null:
		return
	var remaining_budget := AUDIO_FRAME_BUDGET_PER_TICK
	while remaining_budget > 0:
		var frames_available := playback.get_frames_available()
		if frames_available <= 0:
			break
		var requested_frames := mini(mini(frames_available, AUDIO_POP_BATCH_FRAMES), remaining_budget)
		if requested_frames <= 0:
			break
		var audio_frames: PackedVector2Array = _bridge.call("pop_audio_frames", requested_frames)
		if audio_frames.is_empty():
			break
		for frame in audio_frames:
			playback.push_frame(frame)
		remaining_budget -= audio_frames.size()
		if audio_frames.size() < requested_frames:
			break
	_sync_bridge_state()

func play_resolved_stream(station_snapshot: Dictionary, resolved_stream: Dictionary) -> Dictionary:
	_ensure_boot()
	if not _available:
		_state["playback_state"] = "error"
		_state["buffer_state"] = "error"
		_state["error_code"] = "backend_unavailable"
		_state["error_message"] = _unavailability_reason
		return get_state()
	_ensure_audio_output()
	_reset_audio_output()
	var opened := false
	if _bridge != null and _bridge.has_method("open_stream"):
		opened = bool(_bridge.call(
			"open_stream",
			str(station_snapshot.get("station_id", "")),
			str(station_snapshot.get("station_name", "")),
			str(resolved_stream.get("final_url", "")),
			str(resolved_stream.get("classification", "")),
		))
	if not opened:
		_state["playback_state"] = "error"
		_state["buffer_state"] = "error"
		_state["error_code"] = "open_stream_failed"
		_state["error_message"] = "native_bridge_open_failed"
		return get_state()
	_sync_bridge_state()
	return get_state()

func stop_playback(_reason: String = "stopped") -> Dictionary:
	_ensure_boot()
	if _bridge != null and _bridge.has_method("stop_stream"):
		_bridge.call("stop_stream", _reason)
	_reset_audio_output()
	_sync_bridge_state()
	if str(_state.get("playback_state", "")) == "playing":
		_state["playback_state"] = "stopped"
	if str(_state.get("buffer_state", "")) != "idle":
		_state["buffer_state"] = "idle"
	return get_state()

func set_volume_linear(volume_linear: float) -> Dictionary:
	_state["volume_linear"] = clampf(volume_linear, 0.0, 1.0)
	_apply_audio_player_volume()
	return get_state()

func get_state() -> Dictionary:
	_ensure_boot()
	_sync_bridge_state()
	return _state.duplicate(true)

func _ensure_boot() -> void:
	if _boot_attempted:
		return
	_boot_attempted = true
	_boot_bridge()

func _boot_bridge() -> void:
	_available = false
	_unavailability_reason = ""
	_build_summary = ""

	var extension_resource: Resource = load(GDEXTENSION_PATH)
	if extension_resource == null:
		_unavailability_reason = "gdextension_load_failed"
		return
	if not ClassDB.class_exists(BRIDGE_CLASS_NAME):
		_unavailability_reason = "bridge_class_missing"
		return
	var bridge_instance: Object = ClassDB.instantiate(BRIDGE_CLASS_NAME) as Object
	if bridge_instance == null:
		_unavailability_reason = "bridge_instantiate_failed"
		return
	if not bridge_instance.has_method("ping"):
		_unavailability_reason = "bridge_ping_missing"
		return
	if str(bridge_instance.call("ping")) != "pong":
		_unavailability_reason = "bridge_ping_failed"
		return
	_bridge = bridge_instance
	_available = bool(_bridge.call("is_backend_available")) if _bridge.has_method("is_backend_available") else true
	_unavailability_reason = "" if _available else "bridge_reported_unavailable"
	_build_summary = str(_bridge.call("get_build_summary")) if _bridge.has_method("get_build_summary") else ""

func _sync_bridge_state() -> void:
	if _bridge == null or not _bridge.has_method("poll_state"):
		return
	var polled_state: Dictionary = _bridge.call("poll_state")
	if polled_state.is_empty():
		return
	for field_name in [
		"backend_id",
		"playback_state",
		"buffer_state",
		"resolved_url",
		"latency_ms",
		"underflow_count",
		"error_code",
		"error_message",
	]:
		if polled_state.has(field_name):
			_state[field_name] = polled_state.get(field_name)
	var metadata_variant: Variant = polled_state.get("metadata", {})
	var metadata: Dictionary = (metadata_variant as Dictionary).duplicate(true) if metadata_variant is Dictionary else {}
	_state["metadata"] = metadata

func _ensure_audio_output() -> void:
	if not is_instance_valid(_audio_host):
		return
	if _audio_player == null or not is_instance_valid(_audio_player):
		_audio_player = AudioStreamPlayer.new()
		_audio_player.name = AUDIO_PLAYER_NAME
		_audio_player.bus = "Master"
	if _audio_player.get_parent() != _audio_host:
		var current_parent: Node = _audio_player.get_parent()
		if current_parent != null:
			current_parent.remove_child(_audio_player)
		_audio_host.add_child(_audio_player)
	if _audio_stream == null:
		_audio_stream = AudioStreamGenerator.new()
		_audio_stream.mix_rate = TARGET_MIX_RATE
		_audio_stream.buffer_length = AUDIO_BUFFER_LENGTH_SEC
	if _audio_player.stream != _audio_stream:
		_audio_player.stream = _audio_stream
	_apply_audio_player_volume()

func _ensure_audio_playback() -> AudioStreamGeneratorPlayback:
	_ensure_audio_output()
	if _audio_player == null or not is_instance_valid(_audio_player):
		return null
	if _audio_player.stream == null:
		return null
	if not _audio_player.playing:
		_audio_player.play()
	var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		_audio_playback = playback
	return _audio_playback

func _reset_audio_output() -> void:
	_audio_playback = null
	_audio_stream = null
	if _audio_player != null and is_instance_valid(_audio_player):
		_audio_player.stop()
		_audio_player.stream = null

func _apply_audio_player_volume() -> void:
	if _audio_player == null or not is_instance_valid(_audio_player):
		return
	var volume_linear := clampf(float(_state.get("volume_linear", 1.0)), 0.0, 1.0)
	_audio_player.volume_db = linear_to_db(volume_linear) if volume_linear > 0.0 else -80.0
