extends RefCounted
class_name CityVehicleRadioController

var _backend: RefCounted = null
var _driving := false
var _vehicle_state: Dictionary = {}
var _power_on := false
var _selected_station_snapshot: Dictionary = {}
var _resolved_stream: Dictionary = {}

func configure(backend: RefCounted) -> void:
	_backend = backend
	_sync_backend_playback()

func set_driving_context(is_driving: bool, vehicle_state: Dictionary = {}) -> void:
	_driving = is_driving
	_vehicle_state = vehicle_state.duplicate(true) if is_driving else {}
	_sync_backend_playback()

func set_power_state(power_on: bool) -> void:
	_power_on = power_on
	_sync_backend_playback()

func select_station(station_snapshot: Dictionary, resolved_stream: Dictionary) -> void:
	_selected_station_snapshot = station_snapshot.duplicate(true)
	_resolved_stream = resolved_stream.duplicate(true)
	_sync_backend_playback()

func stop(reason: String = "stopped") -> void:
	if _backend != null and _backend.has_method("stop_playback"):
		_backend.stop_playback(reason)

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
		"error_code": str(backend_state.get("error_code", "")),
		"error_message": str(backend_state.get("error_message", "")),
		"backend_id": str(backend_state.get("backend_id", "")),
	}

func _sync_backend_playback() -> void:
	if _backend == null:
		return
	if _driving and _power_on and not _selected_station_snapshot.is_empty() and not str(_resolved_stream.get("final_url", "")).is_empty():
		if _backend.has_method("play_resolved_stream"):
			_backend.play_resolved_stream(_selected_station_snapshot, _resolved_stream)
		return
	if _backend.has_method("stop_playback"):
		_backend.stop_playback("stopped")
