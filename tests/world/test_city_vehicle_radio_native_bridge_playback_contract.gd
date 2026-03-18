extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GDEXTENSION_PATH := "res://city_game/native/radio_backend/radio_backend.gdextension"
const BRIDGE_CLASS_NAME := "CityRadioNativeBridge"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_native_bridge_playback_contract")
	var extension_resource := load(GDEXTENSION_PATH)
	if not T.require_true(self, extension_resource != null, "Vehicle radio native bridge playback contract requires radio_backend.gdextension"):
		return
	if not T.require_true(self, ClassDB.class_exists(BRIDGE_CLASS_NAME), "Vehicle radio native bridge playback contract requires ClassDB.class_exists(\"%s\")" % BRIDGE_CLASS_NAME):
		return

	var bridge: Object = ClassDB.instantiate(BRIDGE_CLASS_NAME) as Object
	if not T.require_true(self, bridge != null, "Vehicle radio native bridge playback contract must instantiate CityRadioNativeBridge"):
		return
	for method_name in ["open_stream", "stop_stream", "poll_state", "pop_audio_frames"]:
		if not T.require_true(self, bridge.has_method(method_name), "Vehicle radio native bridge playback contract requires %s()" % method_name):
			return

	var open_result: Variant = bridge.call("open_stream", "station:test:native", "Bridge FM", "https://radio.example/live.mp3", "direct")
	if not T.require_true(self, open_result is bool, "Vehicle radio native bridge playback contract requires open_stream() to return bool"):
		return

	var state: Dictionary = bridge.call("poll_state")
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
		if not T.require_true(self, state.has(field_name), "Vehicle radio native bridge playback contract must expose %s" % field_name):
			return
	if not T.require_true(self, str(state.get("backend_id", "")) == "native", "Vehicle radio native bridge playback contract must expose backend_id=native"):
		return
	if not T.require_true(self, str(state.get("resolved_url", "")) == "https://radio.example/live.mp3", "Vehicle radio native bridge playback contract must preserve the requested resolved_url"):
		return

	var audio_frames: Variant = bridge.call("pop_audio_frames", 512)
	if not T.require_true(self, audio_frames is PackedVector2Array, "Vehicle radio native bridge playback contract requires pop_audio_frames() to return PackedVector2Array"):
		return

	bridge.call("stop_stream", "stopped")
	var stopped_state: Dictionary = bridge.call("poll_state")
	if not T.require_true(self, str(stopped_state.get("playback_state", "")) == "stopped", "Vehicle radio native bridge playback contract requires stop_stream() to surface playback_state=stopped"):
		return

	T.pass_and_quit(self)
