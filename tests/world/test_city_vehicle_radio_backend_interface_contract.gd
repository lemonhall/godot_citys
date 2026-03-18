extends SceneTree

const T := preload("res://tests/_test_util.gd")
const BACKEND_PATH := "res://city_game/world/radio/backend/CityRadioStreamBackend.gd"
const MOCK_BACKEND_PATH := "res://city_game/world/radio/backend/CityRadioMockBackend.gd"
const NATIVE_BACKEND_PATH := "res://city_game/world/radio/backend/CityRadioNativeBackend.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_backend_interface_contract")
	var backend_script := load(BACKEND_PATH)
	if not T.require_true(self, backend_script != null, "Vehicle radio backend interface contract requires CityRadioStreamBackend.gd"):
		return
	var mock_backend_script := load(MOCK_BACKEND_PATH)
	if not T.require_true(self, mock_backend_script != null, "Vehicle radio backend interface contract requires CityRadioMockBackend.gd"):
		return
	var native_backend_script := load(NATIVE_BACKEND_PATH)
	if not T.require_true(self, native_backend_script != null, "Vehicle radio backend interface contract requires CityRadioNativeBackend.gd"):
		return

	var backend = mock_backend_script.new()
	if not T.require_true(self, backend != null and backend.has_method("play_resolved_stream"), "Vehicle radio backend interface contract requires play_resolved_stream()"):
		return
	if not T.require_true(self, backend.has_method("stop_playback"), "Vehicle radio backend interface contract requires stop_playback()"):
		return
	if not T.require_true(self, backend.has_method("get_state"), "Vehicle radio backend interface contract requires get_state()"):
		return
	if not T.require_true(self, backend.has_method("set_volume_linear"), "Vehicle radio backend interface contract requires set_volume_linear()"):
		return

	var native_backend = native_backend_script.new()
	if not T.require_true(self, native_backend != null and native_backend.has_method("play_resolved_stream"), "Vehicle radio native backend contract requires play_resolved_stream()"):
		return
	if not T.require_true(self, native_backend.has_method("stop_playback"), "Vehicle radio native backend contract requires stop_playback()"):
		return
	if not T.require_true(self, native_backend.has_method("get_state"), "Vehicle radio native backend contract requires get_state()"):
		return
	if not T.require_true(self, native_backend.has_method("set_volume_linear"), "Vehicle radio native backend contract requires set_volume_linear()"):
		return
	if not T.require_true(self, native_backend.has_method("is_available"), "Vehicle radio native backend contract requires is_available()"):
		return
	if not T.require_true(self, native_backend.has_method("get_unavailability_reason"), "Vehicle radio native backend contract requires get_unavailability_reason()"):
		return
	if not T.require_true(self, native_backend.has_method("attach_audio_host"), "Vehicle radio native backend contract requires attach_audio_host()"):
		return
	if not T.require_true(self, native_backend.has_method("update_audio_output"), "Vehicle radio native backend contract requires update_audio_output()"):
		return
	if not T.require_true(self, bool(native_backend.is_available()), "Vehicle radio native backend must report available=true once M6 native backend is implemented"):
		return
	if not T.require_true(self, str(native_backend.get_unavailability_reason()) == "", "Available native backend must not expose an unavailability reason"):
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
	var audio_host := Node.new()
	root.add_child(audio_host)
	native_backend.attach_audio_host(audio_host)
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
	backend.set_volume_linear(0.35)
	var adjusted_mock_state: Dictionary = backend.get_state()
	if not T.require_true(self, absf(float(adjusted_mock_state.get("volume_linear", -1.0)) - 0.35) < 0.001, "Mock backend set_volume_linear() must persist volume_linear into runtime state"):
		return

	native_backend.play_resolved_stream(station_snapshot, resolved_stream)
	native_backend.set_volume_linear(0.42)
	native_backend.update_audio_output()
	var native_playing_state: Dictionary = native_backend.get_state()
	if not _require_backend_state(native_playing_state):
		return
	if not T.require_true(self, str(native_playing_state.get("backend_id", "")) == "native", "Native backend must expose backend_id=native"):
		return
	if not T.require_true(self, str(native_playing_state.get("playback_state", "")) == "playing", "Native backend play_resolved_stream() must transition to playback_state=playing"):
		return
	if not T.require_true(self, str(native_playing_state.get("resolved_url", "")) == "https://radio.example/live.mp3", "Native backend runtime state must expose the active resolved_url"):
		return
	if not T.require_true(self, absf(float(native_playing_state.get("volume_linear", -1.0)) - 0.42) < 0.001, "Native backend set_volume_linear() must surface the active volume_linear"):
		return

	backend.stop_playback("stopped")
	var stopped_state: Dictionary = backend.get_state()
	if not _require_backend_state(stopped_state):
		return
	if not T.require_true(self, str(stopped_state.get("playback_state", "")) == "stopped", "Stopping playback must update backend playback_state to stopped"):
		return
	if not T.require_true(self, str(stopped_state.get("error_code", "")) == "", "Mock backend stop path must not surface a spurious error_code"):
		return

	native_backend.stop_playback("stopped")
	var native_stopped_state: Dictionary = native_backend.get_state()
	if not _require_backend_state(native_stopped_state):
		return
	if not T.require_true(self, str(native_stopped_state.get("playback_state", "")) == "stopped", "Stopping native playback must update backend playback_state to stopped"):
		return
	audio_host.queue_free()

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
		"volume_linear",
		"error_code",
		"error_message",
	]:
		if not T.require_true(self, state.has(field_name), "Backend runtime state must expose %s" % field_name):
			return false
	return true
