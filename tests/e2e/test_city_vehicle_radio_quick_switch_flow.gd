extends SceneTree

const T := preload("res://tests/_test_util.gd")
const UserStateStore := preload("res://city_game/world/radio/CityRadioUserStateStore.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("vehicle_radio_quick_switch_flow")
	_reset_radio_user_state()
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio quick switch flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_vehicle_radio_selection_sources"), "Vehicle radio quick switch flow requires set_vehicle_radio_selection_sources()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_runtime_state"), "Vehicle radio quick switch flow requires get_vehicle_radio_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("open_vehicle_radio_quick_overlay"), "Vehicle radio quick switch flow requires open_vehicle_radio_quick_overlay()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_quick_overlay_state"), "Vehicle radio quick switch flow requires get_vehicle_radio_quick_overlay_state()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Vehicle radio quick switch flow requires synthetic drive-mode setup support"):
		return

	world.set_vehicle_radio_selection_sources(_build_station_entries(), [], [])
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	var open_result: Dictionary = world.open_vehicle_radio_quick_overlay()
	if not T.require_true(self, bool(open_result.get("success", false)), "Vehicle radio quick switch flow must open the quick overlay in driving mode"):
		return

	_press_action(world, "vehicle_radio_next")
	_press_action(world, "vehicle_radio_next")
	await process_frame
	var overlay_state: Dictionary = world.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, int(overlay_state.get("selected_slot_index", -1)) == 2, "Two vehicle_radio_next actions must advance the selected quick slot to index 2"):
		return

	_press_action(world, "vehicle_radio_power_toggle")
	await process_frame
	var runtime_state: Dictionary = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, str(runtime_state.get("power_state", "")) == "on", "vehicle_radio_power_toggle must switch radio power_state to on"):
		return

	_press_action(world, "vehicle_radio_confirm")
	await process_frame
	runtime_state = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, str(runtime_state.get("selected_station_id", "")) == "station:quick:2", "vehicle_radio_confirm must bind the currently selected quick slot into radio runtime state"):
		return
	if not T.require_true(self, str(runtime_state.get("playback_state", "")) == "playing", "Confirming a quick slot while driving with power on must start radio playback"):
		return

	overlay_state = world.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, not bool(overlay_state.get("visible", true)), "Confirming a quick slot must close the overlay"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Confirming a quick slot must restore world simulation pause state"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _reset_radio_user_state() -> void:
	var store := UserStateStore.new()
	if not bool(store.save_presets([], 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio quick switch flow failed to reset presets")
		return
	if not bool(store.save_favorites([], 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio quick switch flow failed to reset favorites")
		return
	if not bool(store.save_recents([], 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio quick switch flow failed to reset recents")
		return
	if not bool(store.save_session_state({"power_state": "off"}, 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio quick switch flow failed to reset session state")
		return

func _press_action(world: Node, action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	world._unhandled_input(event)

func _build_station_entries() -> Array:
	var stations: Array = []
	for index in range(5):
		stations.append({
			"station_id": "station:quick:%d" % index,
			"station_name": "Quick %d" % index,
			"country": "CN",
			"stream_url": "https://radio.example/quick_%d.mp3" % index,
		})
	return stations

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_quick_switch_flow",
		"model_id": "car_b",
		"heading": Vector3(1.0, 0.0, 0.0),
		"world_position": player.global_position - Vector3.UP * standing_height,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.6,
		"speed_mps": 0.0,
	}

func _estimate_standing_height(player) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0
