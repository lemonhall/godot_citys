extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for destination world marker contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Destination world marker contract requires player teleport support"):
		return
	if not T.require_true(self, world.has_method("select_map_destination_from_world_point"), "Destination world marker contract requires destination selection support"):
		return
	if not T.require_true(self, world.has_method("get_active_route_result"), "Destination world marker contract requires active route introspection"):
		return
	if not T.require_true(self, world.has_method("get_destination_world_marker_state"), "Destination world marker contract requires destination marker state introspection"):
		return
	if not T.require_true(self, world.has_method("fast_travel_to_target"), "Destination world marker contract requires stable fast-travel setup support"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Destination world marker contract requires a stable starting point"):
		return

	var initial_state: Dictionary = world.get_destination_world_marker_state()
	if not T.require_true(self, not bool(initial_state.get("visible", true)), "Destination marker must stay hidden before any destination is selected"):
		return

	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Destination world marker contract requires a valid destination selection"):
		return

	var route_result: Dictionary = world.get_active_route_result()
	if not T.require_true(self, not route_result.is_empty(), "Selecting a destination must produce an active route before the marker appears"):
		return

	var visible_state: Dictionary = world.get_destination_world_marker_state()
	if not T.require_true(self, bool(visible_state.get("visible", false)), "Selecting a destination must show a world-space destination marker"):
		return
	var marker_position: Vector3 = visible_state.get("world_position", Vector3.ZERO)
	var snapped_destination: Vector3 = route_result.get("snapped_destination", Vector3.ZERO)
	var planar_error := Vector2(marker_position.x - snapped_destination.x, marker_position.z - snapped_destination.z).length()
	if not T.require_true(self, planar_error <= 2.5, "Destination world marker must sit on the active route snapped_destination instead of drifting elsewhere"):
		return
	if not T.require_true(self, float(visible_state.get("radius_m", 0.0)) >= 6.0, "Destination world marker must expose a readable arrival circle radius"):
		return

	player.teleport_to_world_position(snapped_destination + Vector3.UP * _estimate_standing_height(player))
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(8):
		await physics_frame
		await process_frame

	var cleared_state: Dictionary = world.get_destination_world_marker_state()
	if not T.require_true(self, not bool(cleared_state.get("visible", true)), "Walking into the destination circle must hide the world-space destination marker"):
		return

	world.queue_free()
	T.pass_and_quit(self)

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
