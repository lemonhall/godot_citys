extends SceneTree

const T := preload("res://tests/_test_util.gd")
const UserStateStore := preload("res://city_game/world/radio/CityRadioUserStateStore.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	_seed_session_state()

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for vehicle radio session recovery contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_vehicle_radio_runtime_state"), "Vehicle radio session recovery contract requires get_vehicle_radio_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_radio_quick_overlay_state"), "Vehicle radio session recovery contract requires get_vehicle_radio_quick_overlay_state()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Vehicle radio session recovery contract requires synthetic drive-mode setup support"):
		return
	if not T.require_true(self, player.has_method("exit_vehicle_drive_mode"), "Vehicle radio session recovery contract requires exit_vehicle_drive_mode()"):
		return

	var parked_state: Dictionary = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, str(parked_state.get("selected_station_id", "")) == "station:session:recover", "Radio session recovery must preload selected_station_id from persisted session state even before driving resumes"):
		return
	if not T.require_true(self, str(parked_state.get("power_state", "")) == "on", "Radio session recovery must preload persisted power_state before driving resumes"):
		return
	if not T.require_true(self, str(parked_state.get("playback_state", "")) == "stopped", "Radio session recovery must remain stopped before driving mode becomes active"):
		return

	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	await process_frame
	var driving_state: Dictionary = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, bool(driving_state.get("driving", false)), "Radio session recovery must enter driving=true after synthetic drive-mode setup"):
		return
	if not T.require_true(self, str(driving_state.get("selected_station_id", "")) == "station:session:recover", "Entering driving mode must recover the persisted selected station identity"):
		return
	if not T.require_true(self, str(driving_state.get("playback_state", "")) == "playing", "Entering driving mode with persisted power=on must resume playback automatically"):
		return
	var recovered_snapshot: Dictionary = driving_state.get("selected_station_snapshot", {}) as Dictionary
	if not T.require_true(self, str(recovered_snapshot.get("station_name", "")) == "Session Recover FM", "Recovered runtime must keep the persisted station snapshot even without catalog data"):
		return

	if not T.require_true(self, bool(world.open_vehicle_radio_quick_overlay().get("success", false)), "Radio session recovery contract must still allow opening the quick overlay while driving"):
		return
	player.exit_vehicle_drive_mode()
	await process_frame
	var exited_state: Dictionary = world.get_vehicle_radio_runtime_state()
	if not T.require_true(self, not bool(exited_state.get("driving", false)), "Exiting drive mode must reset runtime driving=false"):
		return
	if not T.require_true(self, str(exited_state.get("playback_state", "")) == "stopped", "Exiting drive mode must stop playback immediately"):
		return
	var overlay_state: Dictionary = world.get_vehicle_radio_quick_overlay_state()
	if not T.require_true(self, not bool(overlay_state.get("visible", true)), "Exiting drive mode must close the quick overlay through shared runtime sync"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _seed_session_state() -> void:
	var store := UserStateStore.new()
	var station_snapshot := {
		"station_id": "station:session:recover",
		"station_name": "Session Recover FM",
		"country": "CN",
		"stream_url": "https://radio.example/session_recover.mp3",
	}
	if not bool(store.save_presets([
		{
			"slot_index": 0,
			"station_snapshot": station_snapshot.duplicate(true),
		}
	], 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio session recovery contract failed to seed presets")
		return
	if not bool(store.save_favorites([], 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio session recovery contract failed to reset favorites")
		return
	if not bool(store.save_recents([station_snapshot.duplicate(true)], 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio session recovery contract failed to seed recents")
		return
	if not bool(store.save_session_state({
		"power_state": "on",
		"selected_station_id": "station:session:recover",
		"selected_station_snapshot": station_snapshot.duplicate(true),
	}, 100).get("success", false)):
		T.fail_and_quit(self, "Vehicle radio session recovery contract failed to seed session_state.json")
		return

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:radio_session_recovery",
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
