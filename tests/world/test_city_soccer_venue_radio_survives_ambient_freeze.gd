extends SceneTree

const T := preload("res://tests/_test_util.gd")
const UserStateStore := preload("res://city_game/world/radio/CityRadioUserStateStore.gd")

const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	T.install_vehicle_radio_test_scope("soccer_venue_radio_survives_ambient_freeze")
	_reset_radio_user_state()
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer venue radio survives ambient freeze")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Soccer venue radio survives ambient freeze requires synthetic drive-mode setup support"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Soccer venue radio survives ambient freeze requires Player teleport API"):
		return

	world.set_vehicle_radio_selection_sources(_build_station_entries(), [], [])
	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	var open_result: Dictionary = world.open_vehicle_radio_quick_overlay()
	if not T.require_true(self, bool(open_result.get("success", false)), "Soccer venue radio survives ambient freeze must be able to open the quick overlay before venue entry"):
		return
	_press_action(world, "vehicle_radio_power_toggle")
	await process_frame
	_press_action(world, "vehicle_radio_confirm")
	await process_frame
	var radio_state: Dictionary = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, str(radio_state.get("playback_state", "")) == "playing", "Radio survives ambient freeze contract requires live playback before entering the soccer venue"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 1.2, 0.0))
	await _wait_for_ambient_freeze(world, true)
	radio_state = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, str(radio_state.get("playback_state", "")) == "playing", "Ambient freeze must not stop radio playback when the radio was already playing"):
		return
	if not T.require_true(self, str(radio_state.get("power_state", "")) == "on", "Ambient freeze must not silently power the radio off"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Ambient freeze must keep world_simulation_pause false even while radio playback survives"):
		return

	world.queue_free()
	T.clear_vehicle_radio_test_scope()
	T.pass_and_quit(self)

func _wait_for_ambient_freeze(world, expected_state: bool) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if bool(runtime_state.get("ambient_simulation_frozen", false)) == expected_state and bool(world.is_ambient_simulation_frozen()) == expected_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _reset_radio_user_state() -> void:
	var store := UserStateStore.new()
	if not bool(store.save_presets([], 100).get("success", false)):
		T.fail_and_quit(self, "Soccer venue radio survives ambient freeze failed to reset presets")
		return
	if not bool(store.save_favorites([], 100).get("success", false)):
		T.fail_and_quit(self, "Soccer venue radio survives ambient freeze failed to reset favorites")
		return
	if not bool(store.save_recents([], 100).get("success", false)):
		T.fail_and_quit(self, "Soccer venue radio survives ambient freeze failed to reset recents")
		return
	if not bool(store.save_session_state({"power_state": "off"}, 100).get("success", false)):
		T.fail_and_quit(self, "Soccer venue radio survives ambient freeze failed to reset session state")
		return

func _press_action(world: Node, action_name: String) -> void:
	var event := InputEventAction.new()
	event.action = action_name
	event.pressed = true
	world._unhandled_input(event)

func _build_station_entries() -> Array:
	return [{
		"station_id": "station:soccer:0",
		"station_name": "Soccer Radio",
		"country": "CN",
		"stream_url": "https://radio.example/soccer_radio.mp3",
	}]

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:soccer_radio_freeze",
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
