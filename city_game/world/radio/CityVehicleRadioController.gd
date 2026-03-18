extends RefCounted
class_name CityVehicleRadioController

var _backend: RefCounted = null
var _driving := false
var _vehicle_state: Dictionary = {}
var _power_on := false
var _browser_preview_enabled := false
var _volume_linear := 1.0
var _selected_station_snapshot: Dictionary = {}
var _resolved_stream: Dictionary = {}
var _requested_playback_key := ""

func configure(backend: RefCounted) -> void:
	_backend = backend
	if _backend != null and _backend.has_method("set_volume_linear"):
		_backend.set_volume_linear(_volume_linear)
	_sync_backend_playback()

func set_driving_context(is_driving: bool, vehicle_state: Dictionary = {}) -> void:
	_driving = is_driving
	_vehicle_state = vehicle_state.duplicate(true) if is_driving else {}
	_sync_backend_playback()

func set_power_state(power_on: bool) -> void:
	_power_on = power_on
	_sync_backend_playback()

func set_browser_preview_enabled(enabled: bool) -> void:
	_browser_preview_enabled = enabled
	_sync_backend_playback()

func set_volume_linear(volume_linear: float) -> void:
	_volume_linear = clampf(volume_linear, 0.0, 1.0)
	if _backend != null and _backend.has_method("set_volume_linear"):
		_backend.set_volume_linear(_volume_linear)

func select_station(station_snapshot: Dictionary, resolved_stream: Dictionary) -> void:
	_selected_station_snapshot = station_snapshot.duplicate(true)
	_resolved_stream = resolved_stream.duplicate(true)
	_sync_backend_playback()

func stop(reason: String = "stopped") -> void:
	if _backend != null and _backend.has_method("stop_playback"):
		_backend.stop_playback(reason)
	_requested_playback_key = ""

func get_runtime_state() -> Dictionary:
	var backend_state: Dictionary = {}
	if _backend != null and _backend.has_method("get_state"):
		backend_state = _backend.get_state()
	return {
		"driving": _driving,
		"vehicle_id": str(_vehicle_state.get("vehicle_id", "")),
		"power_state": "on" if _power_on else "off",
		"selected_station_id": str(_selected_station_snapshot.get("station_id", "")),
		"selected_station_snapshot": _selected_station_snapshot.duplicate(true),
		"playback_state": str(backend_state.get("playback_state", "stopped")),
		"buffer_state": str(backend_state.get("buffer_state", "idle")),
		"resolved_url": str(backend_state.get("resolved_url", "")),
		"metadata": (backend_state.get("metadata", {}) as Dictionary).duplicate(true),
		"latency_ms": int(backend_state.get("latency_ms", 0)),
		"underflow_count": int(backend_state.get("underflow_count", 0)),
		"volume_linear": float(backend_state.get("volume_linear", _volume_linear)),
		"error_code": str(backend_state.get("error_code", "")),
		"error_message": str(backend_state.get("error_message", "")),
		"backend_id": str(backend_state.get("backend_id", "")),
	}

func _sync_backend_playback() -> void:
	if _backend == null:
		return
	var desired_playback_key := _build_desired_playback_key()
	if desired_playback_key != "":
		if desired_playback_key == _requested_playback_key:
			return
		if _backend.has_method("play_resolved_stream"):
			_backend.play_resolved_stream(_selected_station_snapshot, _resolved_stream)
		_requested_playback_key = desired_playback_key
		return
	if _requested_playback_key == "":
		return
	if _backend.has_method("stop_playback"):
		_backend.stop_playback("stopped")
	_requested_playback_key = ""

func _build_desired_playback_key() -> String:
	if not _power_on:
		return ""
	if not _driving and not _browser_preview_enabled:
		return ""
	if _selected_station_snapshot.is_empty():
		return ""
	var station_id := str(_selected_station_snapshot.get("station_id", ""))
	var resolved_url := str(_resolved_stream.get("final_url", ""))
	if station_id == "" or resolved_url == "":
		return ""
	return "%s|%s" % [station_id, resolved_url]
