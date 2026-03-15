extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for autodrive interrupt contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("start_autodrive_to_active_destination"), "CityPrototype must expose start_autodrive_to_active_destination() for v12 M5"):
		return
	if not T.require_true(self, world.has_method("stop_autodrive"), "CityPrototype must expose stop_autodrive() for v12 M5"):
		return
	if not T.require_true(self, world.has_method("get_autodrive_state"), "CityPrototype must expose get_autodrive_state() for v12 M5"):
		return
	if not T.require_true(self, world.has_method("is_autodrive_active"), "CityPrototype must expose is_autodrive_active() for v12 M5"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Autodrive interrupt contract requires synthetic drive-mode setup support"):
		return
	if not T.require_true(self, player.has_method("set_vehicle_drive_input"), "Autodrive interrupt contract requires manual override input support"):
		return
	if not T.require_true(self, player.has_method("clear_vehicle_drive_input"), "Autodrive interrupt contract requires manual override cleanup support"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Autodrive interrupt contract requires a stable surface-aligned drive start"):
		return

	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	world.update_streaming_for_position(player.global_position, 0.0)
	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(512.0, 0.0, 40.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Autodrive interrupt contract requires a valid active route target"):
		return

	var start_result: Dictionary = world.start_autodrive_to_active_destination()
	if not T.require_true(self, bool(start_result.get("success", false)), "Autodrive must arm successfully from the active destination target"):
		return
	for _frame_index in range(24):
		await physics_frame
		await process_frame

	var active_state: Dictionary = world.get_autodrive_state()
	if not T.require_true(self, str(active_state.get("state", "")) == "following_route", "Autodrive must enter following_route after arming against the active route_result"):
		return
	if not T.require_true(self, world.is_autodrive_active(), "Autodrive must report active while following the formal route"):
		return

	player.set_vehicle_drive_input(0.0, 1.0, false)
	for _frame_index in range(8):
		await physics_frame
		await process_frame
	player.clear_vehicle_drive_input()

	var interrupted_state: Dictionary = world.get_autodrive_state()
	if not T.require_true(self, str(interrupted_state.get("state", "")) == "interrupted", "Manual vehicle input must interrupt autodrive and return control to the player"):
		return
	if not T.require_true(self, not world.is_autodrive_active(), "Interrupted autodrive must stop driving the player vehicle"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:autodrive_interrupt",
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
