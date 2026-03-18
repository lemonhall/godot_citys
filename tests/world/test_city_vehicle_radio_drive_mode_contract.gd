extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CONTROLLER_PATH := "res://city_game/world/radio/CityVehicleRadioController.gd"
const MOCK_BACKEND_PATH := "res://city_game/world/radio/backend/CityRadioMockBackend.gd"

class ProbeBackend:
	extends RefCounted

	var play_call_count := 0
	var stop_call_count := 0
	var _state := {
		"backend_id": "probe",
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
		play_call_count += 1
		_state["playback_state"] = "playing"
		_state["buffer_state"] = "ready"
		_state["resolved_url"] = str(resolved_stream.get("final_url", ""))
		_state["metadata"] = {
			"station_id": str(station_snapshot.get("station_id", "")),
			"station_name": str(station_snapshot.get("station_name", "")),
		}
		return get_state()

	func stop_playback(_reason: String = "stopped") -> Dictionary:
		stop_call_count += 1
		_state["playback_state"] = "stopped"
		_state["buffer_state"] = "idle"
		return get_state()

	func get_state() -> Dictionary:
		return _state.duplicate(true)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_drive_mode_contract")
	var controller_script := load(CONTROLLER_PATH)
	if not T.require_true(self, controller_script != null, "Vehicle radio drive mode contract requires CityVehicleRadioController.gd"):
		return
	var mock_backend_script := load(MOCK_BACKEND_PATH)
	if not T.require_true(self, mock_backend_script != null, "Vehicle radio drive mode contract requires CityRadioMockBackend.gd"):
		return

	var controller = controller_script.new()
	var backend = mock_backend_script.new()
	if not T.require_true(self, controller != null and controller.has_method("configure"), "Vehicle radio drive mode contract requires configure()"):
		return
	if not T.require_true(self, controller.has_method("set_driving_context"), "Vehicle radio drive mode contract requires set_driving_context()"):
		return
	if not T.require_true(self, controller.has_method("set_power_state"), "Vehicle radio drive mode contract requires set_power_state()"):
		return
	if not T.require_true(self, controller.has_method("select_station"), "Vehicle radio drive mode contract requires select_station()"):
		return
	if not T.require_true(self, controller.has_method("set_browser_preview_enabled"), "Vehicle radio drive mode contract requires set_browser_preview_enabled()"):
		return
	if not T.require_true(self, controller.has_method("set_volume_linear"), "Vehicle radio drive mode contract requires set_volume_linear()"):
		return
	if not T.require_true(self, controller.has_method("get_runtime_state"), "Vehicle radio drive mode contract requires get_runtime_state()"):
		return

	controller.configure(backend)
	controller.set_power_state(true)

	var station_snapshot := {
		"station_id": "station:test:drive_mode",
		"station_name": "Drive Mode FM",
		"country": "CN",
	}
	var resolved_stream := {
		"classification": "direct",
		"final_url": "https://radio.example/live.mp3",
		"candidates": ["https://radio.example/live.mp3"],
		"resolution_trace": [{"step": "direct"}],
		"resolved_at_unix_sec": 1700000000,
	}
	controller.select_station(station_snapshot, resolved_stream)
	station_snapshot["station_name"] = "Mutated Outside"

	var parked_state: Dictionary = controller.get_runtime_state()
	if not T.require_true(self, not bool(parked_state.get("driving", false)), "Vehicle radio controller must default to non-driving state"):
		return
	if not T.require_true(self, str(parked_state.get("playback_state", "")) != "playing", "Vehicle radio controller must not start playback outside driving mode"):
		return
	if not T.require_true(self, str(backend.get_state().get("playback_state", "")) != "playing", "Backend must not receive a play request before driving mode is active"):
		return
	var parked_snapshot: Dictionary = parked_state.get("selected_station_snapshot", {}) as Dictionary
	if not T.require_true(self, str(parked_snapshot.get("station_name", "")) == "Drive Mode FM", "Vehicle radio controller must preserve an internal station snapshot copy for session recovery"):
		return
	if not T.require_true(self, absf(float(parked_state.get("volume_linear", -1.0)) - 1.0) < 0.001, "Vehicle radio controller runtime state must surface default volume_linear=1.0"):
		return

	controller.set_browser_preview_enabled(true)
	var preview_state: Dictionary = controller.get_runtime_state()
	if not T.require_true(self, str(preview_state.get("playback_state", "")) == "playing", "Enabling browser preview with power=on and a selected station must start playback even outside driving mode"):
		return
	if not T.require_true(self, str(backend.get_state().get("playback_state", "")) == "playing", "Backend must start playback when browser preview becomes active"):
		return
	controller.set_volume_linear(0.25)
	preview_state = controller.get_runtime_state()
	if not T.require_true(self, absf(float(preview_state.get("volume_linear", -1.0)) - 0.25) < 0.001, "Vehicle radio controller set_volume_linear() must persist into runtime state"):
		return
	controller.set_browser_preview_enabled(false)
	var preview_stopped_state: Dictionary = controller.get_runtime_state()
	if not T.require_true(self, str(preview_stopped_state.get("playback_state", "")) == "stopped", "Disabling browser preview outside driving mode must stop playback again"):
		return

	controller.set_driving_context(true, {
		"vehicle_id": "veh:test:radio",
		"model_id": "sports_car_a",
	})
	var driving_state: Dictionary = controller.get_runtime_state()
	if not T.require_true(self, bool(driving_state.get("driving", false)), "Vehicle radio controller must surface driving=true after entering drive mode"):
		return
	if not T.require_true(self, str(driving_state.get("playback_state", "")) == "playing", "Entering drive mode with power=on and a selected station must start playback"):
		return
	if not T.require_true(self, str(backend.get_state().get("playback_state", "")) == "playing", "Backend must transition to playing when drive mode becomes active"):
		return
	if not T.require_true(self, absf(float(driving_state.get("volume_linear", -1.0)) - 0.25) < 0.001, "Driving runtime must preserve the last selected volume_linear"):
		return
	if not T.require_true(self, not driving_state.has("country_pages") and not driving_state.has("favorites"), "Vehicle radio controller runtime state must stay compact and avoid catalog payload leakage"):
		return

	controller.set_driving_context(false, {})
	var exited_state: Dictionary = controller.get_runtime_state()
	if not T.require_true(self, not bool(exited_state.get("driving", false)), "Vehicle radio controller must surface driving=false after exiting drive mode"):
		return
	if not T.require_true(self, str(exited_state.get("playback_state", "")) == "stopped", "Exiting drive mode must stop radio playback"):
		return
	if not T.require_true(self, str(backend.get_state().get("playback_state", "")) == "stopped", "Backend must stop playback when drive mode exits"):
		return

	var probe_backend := ProbeBackend.new()
	controller = controller_script.new()
	controller.configure(probe_backend)
	probe_backend.play_call_count = 0
	probe_backend.stop_call_count = 0
	controller.set_power_state(true)
	controller.select_station(station_snapshot, resolved_stream)
	controller.set_browser_preview_enabled(false)
	probe_backend.play_call_count = 0
	controller.set_driving_context(true, {
		"vehicle_id": "veh:test:radio:reuse",
		"model_id": "sports_car_a",
	})
	controller.set_driving_context(true, {
		"vehicle_id": "veh:test:radio:reuse",
		"model_id": "sports_car_a",
	})
	controller.set_driving_context(true, {
		"vehicle_id": "veh:test:radio:reuse",
		"model_id": "sports_car_a",
	})
	if not T.require_true(self, probe_backend.play_call_count == 1, "Vehicle radio controller must not reopen the same stream every frame while driving context stays unchanged"):
		return

	T.pass_and_quit(self)
