extends RefCounted
class_name CityRadioStreamBackend

var _state := {
	"backend_id": "base",
	"playback_state": "stopped",
	"buffer_state": "idle",
	"resolved_url": "",
	"metadata": {},
	"latency_ms": 0,
	"underflow_count": 0,
	"error_code": "",
	"error_message": "",
}

func play_resolved_stream(station_snapshot: Dictionary, resolved_stream: Dictionary) -> Dictionary:
	_state["playback_state"] = "playing"
	_state["buffer_state"] = "ready"
	_state["resolved_url"] = str(resolved_stream.get("final_url", ""))
	_state["metadata"] = {
		"station_id": str(station_snapshot.get("station_id", "")),
		"station_name": str(station_snapshot.get("station_name", "")),
		"classification": str(resolved_stream.get("classification", "")),
	}
	_state["error_code"] = ""
	_state["error_message"] = ""
	return get_state()

func stop_playback(_reason: String = "stopped") -> Dictionary:
	_state["playback_state"] = "stopped"
	_state["buffer_state"] = "idle"
	_state["error_code"] = ""
	_state["error_message"] = ""
	return get_state()

func get_state() -> Dictionary:
	return _state.duplicate(true)
