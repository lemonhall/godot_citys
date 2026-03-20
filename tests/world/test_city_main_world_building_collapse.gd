extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Main-world building collapse contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Main-world building collapse contract requires Player node"):
		return
	var generated_city := world.get_node_or_null("GeneratedCity") as Node
	if not T.require_true(self, generated_city != null, "Main-world building collapse contract requires the legacy GeneratedCity node to remain mounted for compatibility"):
		return
	if not T.require_true(self, _count_visible_mesh_instances_in_tree(generated_city) == 0, "Streamed main world must hide legacy GeneratedCity visuals to avoid duplicate towers or road meshes when destructible buildings collapse"):
		return
	if not T.require_true(self, world.has_method("get_building_generation_contract"), "CityPrototype must expose building generation contract lookup for main-world collapse tracing"):
		return

	var target_runtime = await _await_target_runtime(player)
	if not T.require_true(self, target_runtime != null, "Main world must mount at least one near-field destructible building runtime"):
		return
	if not T.require_true(self, target_runtime.has_method("get_state"), "Main-world destructible building runtime must expose get_state()"):
		return
	if not T.require_true(self, target_runtime.has_method("apply_damage"), "Main-world destructible building runtime must expose apply_damage()"):
		return
	if not T.require_true(self, target_runtime.has_method("apply_explosion_damage"), "Main-world destructible building runtime must expose apply_explosion_damage() for the formal explosion chain"):
		return
	if not T.require_true(self, target_runtime.has_method("get_primary_target_world_position"), "Main-world destructible building runtime must expose a target world position"):
		return

	var initial_state: Dictionary = target_runtime.get_state()
	var building_id := str(initial_state.get("building_id", ""))
	if not T.require_true(self, building_id != "", "Main-world destructible building runtime must preserve a stable building_id"):
		return
	var generation_contract: Dictionary = world.get_building_generation_contract(building_id)
	if not T.require_true(self, not generation_contract.is_empty(), "Main-world destructible building must still round-trip to the formal building generation contract"):
		return

	var aim_world_position: Vector3 = target_runtime.get_primary_target_world_position() + Vector3.UP * 10.0
	var explosion_result: Dictionary = target_runtime.apply_explosion_damage(aim_world_position, 14.0, 18.0)
	if not T.require_true(self, bool(explosion_result.get("accepted", false)), "Main-world collapse contract requires streamed buildings to accept the formal explosion-damage API used by rocket blasts"):
		return

	var health_decreased := false
	for _frame in range(30):
		await process_frame
		var state: Dictionary = target_runtime.get_state()
		if float(state.get("current_health", 0.0)) < float(initial_state.get("current_health", 0.0)):
			health_decreased = true
			break
	if not T.require_true(self, health_decreased, "A formal explosion against a streamed main-world building must reduce health through the shared building damage chain"):
		return

	var hit_world_position: Vector3 = target_runtime.get_primary_target_world_position() + Vector3.UP * 14.0
	var prepare_result: Dictionary = target_runtime.apply_damage(4100.0, hit_world_position)
	if not T.require_true(self, bool(prepare_result.get("accepted", false)), "Main-world building collapse contract requires threshold-crossing damage acceptance"):
		return

	var fracture_ready := false
	for _frame in range(180):
		await process_frame
		var state: Dictionary = target_runtime.get_state()
		if str(state.get("damage_state", "")) == "collapse_ready":
			fracture_ready = true
			break
	if not T.require_true(self, fracture_ready, "Main-world buildings must finish fracture preparation before collapse just like the lab runtime"):
		return

	var collapse_result: Dictionary = target_runtime.apply_damage(5600.0, hit_world_position)
	if not T.require_true(self, bool(collapse_result.get("accepted", false)), "Main-world building collapse contract requires the collapse-threshold hit to be accepted"):
		return

	var collapsed := false
	for _frame in range(240):
		await physics_frame
		var state: Dictionary = target_runtime.get_state()
		if str(state.get("damage_state", "")) == "collapsed":
			collapsed = true
			break
	if not T.require_true(self, collapsed, "Main-world destructible building runtime must carry the streamed building through collapsing into collapsed"):
		return

	var collapsed_debug_state: Dictionary = target_runtime.get_debug_state()
	if not T.require_true(self, int(collapsed_debug_state.get("dynamic_chunk_count", 0)) >= 20, "Collapsed main-world buildings must still spawn a visible debris field, not silently disappear"):
		return
	if not T.require_true(self, bool(collapsed_debug_state.get("residual_base_visible", false)), "Collapsed main-world buildings must preserve a residual base in the streamed city"):
		return
	if not T.require_true(self, int(collapsed_debug_state.get("dynamic_chunk_airborne_count", 0)) > 0, "Main-world upper-half collapse hits must still leave some debris airborne when the collapse first finishes"):
		return
	if not T.require_true(self, int(collapsed_debug_state.get("dynamic_chunk_sleeping_airborne_count", -1)) == 0, "Main-world airborne debris must not be force-slept in midair when the collapse settles"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _await_target_runtime(player) -> Variant:
	if player == null:
		return null
	for _frame in range(240):
		await process_frame
		var best_runtime = _find_nearest_destructible_runtime(player)
		if best_runtime != null:
			return best_runtime
	return null

func _find_nearest_destructible_runtime(player) -> Variant:
	var nearest_runtime = null
	var nearest_distance := INF
	for runtime_variant in get_nodes_in_group("city_destructible_building"):
		var runtime_node := runtime_variant as Node3D
		if runtime_node == null or not is_instance_valid(runtime_node):
			continue
		if not runtime_node.has_method("get_primary_target_world_position"):
			continue
		var target_world_position: Vector3 = runtime_node.get_primary_target_world_position()
		var distance_m: float = player.global_position.distance_to(target_world_position)
		if distance_m < nearest_distance:
			nearest_distance = distance_m
			nearest_runtime = runtime_node
	return nearest_runtime

func _count_visible_mesh_instances_in_tree(root_node: Node) -> int:
	if root_node == null:
		return 0
	var visible_count := 0
	if root_node is MeshInstance3D:
		var mesh_instance := root_node as MeshInstance3D
		if mesh_instance.is_visible_in_tree():
			visible_count += 1
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		visible_count += _count_visible_mesh_instances_in_tree(child_node)
	return visible_count
