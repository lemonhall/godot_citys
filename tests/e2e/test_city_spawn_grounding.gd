extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for spawn grounding")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for spawn grounding"):
		return

	var chunk_ready := false
	for _step in range(24):
		await physics_frame
		var snapshot: Dictionary = world.get_streaming_snapshot()
		var current_chunk_id := str(snapshot.get("current_chunk_id", ""))
		if current_chunk_id == "":
			continue
		var current_chunk = world.get_node("ChunkRenderer").get_chunk_scene(current_chunk_id)
		if current_chunk == null:
			continue
		if current_chunk.get_node_or_null("GroundBody") == null:
			continue
		chunk_ready = true
		break

	if not T.require_true(self, chunk_ready, "Spawn grounding test must wait for the active chunk ground body"):
		return

	var hit := _raycast_surface(world, player)
	if not T.require_true(self, not hit.is_empty(), "Spawn grounding must find the streamed active surface under the player"):
		return

	var expected_y := float((hit.get("position", Vector3.ZERO) as Vector3).y) + _estimate_standing_height(player)
	if not T.require_true(self, player.global_position.y >= expected_y - 0.05, "Player spawn height must not end up below the streamed active surface"):
		return

	for _step in range(24):
		await physics_frame
		if player.is_on_floor():
			break

	if not T.require_true(self, player.is_on_floor(), "Player must settle onto the streamed active surface shortly after spawn"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _raycast_surface(world: Node, player: CharacterBody3D) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 20.0,
		player.global_position + Vector3.DOWN * 40.0
	)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _estimate_standing_height(player: CharacterBody3D) -> float:
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
