extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for ground continuity")
		return
	var terrain_script := load("res://city_game/world/rendering/CityTerrainSampler.gd")
	if terrain_script == null:
		T.fail_and_quit(self, "Missing CityTerrainSampler.gd for ground continuity")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.get_node_or_null("Ground") == null, "Ground continuity must rely on chunk ground, not legacy Ground"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for ground continuity"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position()"):
		return

	var terrain_height := float(terrain_script.sample_height(1536.0, 26.0, world.get_world_config().base_seed))
	var far_position := Vector3(1536.0, terrain_height + 6.0, 26.0)
	player.teleport_to_world_position(far_position)
	world.update_streaming_for_position(far_position)

	for _step in range(72):
		await physics_frame

	var hit := _raycast_surface(world, player)
	if not T.require_true(self, not hit.is_empty(), "Ground continuity must find the streamed chunk ground under the player"):
		return
	var ground_height := float((hit.get("position", Vector3.ZERO) as Vector3).y)
	if not T.require_true(self, player.global_position.y > ground_height + 0.5, "Player must remain above the streamed chunk ground outside the v1 center tile"):
		return
	if not T.require_true(self, player.is_on_floor(), "Player must settle on the streamed chunk ground"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _raycast_surface(world: Node, player: Node3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 20.0,
		player.global_position + Vector3.DOWN * 60.0
	)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query)
