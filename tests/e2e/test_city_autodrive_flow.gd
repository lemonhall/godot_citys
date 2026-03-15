extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for autodrive flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Autodrive flow requires drive-mode entry support"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Autodrive flow requires a stable fast-travel start point before entering drive mode"):
		return

	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	world.update_streaming_for_position(player.global_position, 0.0)
	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(512.0, 0.0, 40.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Autodrive flow requires a valid map-selected destination contract"):
		return

	var route_result: Dictionary = world.get_active_route_result()
	var start_result: Dictionary = world.start_autodrive_to_active_destination()
	if not T.require_true(self, bool(start_result.get("success", false)), "Autodrive flow must arm successfully before simulation frames advance"):
		return

	var max_speed_mps := 0.0
	for _frame_index in range(720):
		await physics_frame
		await process_frame
		var vehicle_state: Dictionary = world.get_player_vehicle_state()
		max_speed_mps = maxf(max_speed_mps, float(vehicle_state.get("speed_mps", 0.0)))
		var autodrive_state: Dictionary = world.get_autodrive_state()
		if str(autodrive_state.get("state", "")) == "arrived":
			break
		if str(autodrive_state.get("state", "")) == "failed":
			break

	var final_state: Dictionary = world.get_autodrive_state()
	if not T.require_true(self, str(final_state.get("state", "")) == "arrived", "Autodrive flow must reach the destination instead of stalling in armed/following_route"):
		return
	if not T.require_true(self, str(final_state.get("route_id", "")) == str(route_result.get("route_id", "")), "Autodrive flow must consume the active route_result instead of a hidden solver"):
		return
	if not T.require_true(self, int(final_state.get("polyline_point_count", 0)) == (route_result.get("polyline", []) as Array).size(), "Autodrive state must expose the consumed route polyline size for verification"):
		return
	if not T.require_true(self, max_speed_mps >= 8.0, "Autodrive flow must actually drive the player vehicle instead of only toggling state flags"):
		return

	var snapped_destination: Vector3 = route_result.get("snapped_destination", Vector3.ZERO)
	if not T.require_true(self, player.global_position.distance_to(snapped_destination) <= 32.0, "Autodrive flow must finish near the formal snapped_destination consumed from route_result"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:autodrive_flow",
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
