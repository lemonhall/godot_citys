extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for walk-arrival navigation clear contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Walk-arrival navigation clear contract requires player teleport support"):
		return
	if not T.require_true(self, world.has_method("select_map_destination_from_world_point"), "Walk-arrival navigation clear contract requires destination selection support"):
		return
	if not T.require_true(self, world.has_method("get_active_route_result"), "Walk-arrival navigation clear contract requires active route introspection"):
		return
	if not T.require_true(self, world.has_method("get_pin_registry_state"), "Walk-arrival navigation clear contract requires pin registry introspection"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "Walk-arrival navigation clear contract requires minimap route overlay introspection"):
		return
	if not T.require_true(self, world.has_method("fast_travel_to_target"), "Walk-arrival navigation clear contract requires stable fast-travel setup support"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Walk-arrival navigation clear contract requires a stable starting point"):
		return

	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(1400.0, 0.0, 26.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Walk-arrival navigation clear contract requires a valid destination selection"):
		return

	var route_result: Dictionary = world.get_active_route_result()
	if not T.require_true(self, not route_result.is_empty(), "Selecting a destination must arm an active route before walk-arrival clear can be validated"):
		return
	var snapped_destination: Vector3 = route_result.get("snapped_destination", Vector3.ZERO)

	player.teleport_to_world_position(snapped_destination + Vector3.UP * _estimate_standing_height(player))
	world.update_streaming_for_position(player.global_position, 0.0)
	for _frame_index in range(8):
		await physics_frame
		await process_frame

	var cleared_route: Dictionary = world.get_active_route_result()
	if not T.require_true(self, cleared_route.is_empty(), "Walking into the destination circle must clear the active route instead of leaving the yellow navigation line alive"):
		return

	var pin_state: Dictionary = world.get_pin_registry_state()
	if not T.require_true(self, not (pin_state.get("pin_types", []) as Array).has("destination"), "Walking into the destination circle must clear the destination pin together with the route"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var route_overlay: Dictionary = minimap_snapshot.get("route_overlay", {})
	if not T.require_true(self, route_overlay.is_empty() or (route_overlay.get("polyline", PackedVector2Array()) as PackedVector2Array).size() == 0, "Walking into the destination circle must remove the minimap route overlay together with the active route"):
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
