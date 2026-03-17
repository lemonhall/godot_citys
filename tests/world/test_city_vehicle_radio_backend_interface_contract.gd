extends SceneTree

const T := preload("res://tests/_test_util.gd")
const BACKEND_PATH := "res://city_game/world/radio/backend/CityRadioStreamBackend.gd"
const MOCK_BACKEND_PATH := "res://city_game/world/radio/backend/CityRadioMockBackend.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var backend_script := load(BACKEND_PATH)
	if not T.require_true(self, backend_script != null, "Vehicle radio backend interface contract requires CityRadioStreamBackend.gd"):
		return
	var mock_backend_script := load(MOCK_BACKEND_PATH)
	if not T.require_true(self, mock_backend_script != null, "Vehicle radio backend interface contract requires CityRadioMockBackend.gd"):
		return

	var backend = mock_backend_script.new()
	if not T.require_true(self, backend != null and backend.has_method("play_resolved_stream"), "Vehicle radio backend interface contract requires play_resolved_stream()"):
		return
	if not T.require_true(self, backend.has_method("stop_playback"), "Vehicle radio backend interface contract requires stop_playback()"):
		return
	if not T.require_true(self, backend.has_method("get_state"), "Vehicle radio backend interface contract requires get_state()"):
		return

	var resolved_stream := {
		"classification": "direct",
		"final_url": "https://radio.example/live.mp3",
		"candidates": ["https://radio.example/live.mp3"],
		"resolution_trace": [{"step": "direct"}],
		"resolved_at_unix_sec": 1700000000,
	}
	var station_snapshot := {
		"station_id": "station:test:mock",
		"station_name": "Mock FM",
	}
	backend.play_resolved_stream(station_snapshot, resolved_stream)
	var playing_state: Dictionary = backend.get_state()
	if not _require_backend_state(playing_state):
		return
	if not T.require_true(self, str(playing_state.get("backend_id", "")) == "mock", "Mock backend must expose backend_id=mock"):
		return
	if not T.require_true(self, str(playing_state.get("playback_state", "")) == "playing", "Playing a resolved stream must update backend playback_state to playing"):
		return
	if not T.require_true(self, str(playing_state.get("resolved_url", "")) == "https://radio.example/live.mp3", "Backend runtime state must expose the active resolved_url"):
		return
	var metadata: Dictionary = playing_state.get("metadata", {}) as Dictionary
	if not T.require_true(self, str(metadata.get("station_id", "")) == "station:test:mock", "Backend metadata must preserve the selected station identity"):
		return

	backend.stop_playback("stopped")
	var stopped_state: Dictionary = backend.get_state()
	if not _require_backend_state(stopped_state):
		return
	if not T.require_true(self, str(stopped_state.get("playback_state", "")) == "stopped", "Stopping playback must update backend playback_state to stopped"):
		return
	if not T.require_true(self, str(stopped_state.get("error_code", "")) == "", "Mock backend stop path must not surface a spurious error_code"):
		return

	T.pass_and_quit(self)

func _require_backend_state(state: Dictionary) -> bool:
	for field_name in [
		"backend_id",
		"playback_state",
		"buffer_state",
		"resolved_url",
		"metadata",
		"latency_ms",
		"underflow_count",
		"error_code",
		"error_message",
	]:
		if not T.require_true(self, state.has(field_name), "Backend runtime state must expose %s" % field_name):
			return false
	return true
