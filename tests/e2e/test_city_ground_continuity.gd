extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for ground continuity")
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

	var far_position := Vector3(1536.0, 2.0, 26.0)
	player.teleport_to_world_position(far_position)
	world.update_streaming_for_position(far_position)

	for _step in range(72):
		await physics_frame

	if not T.require_true(self, player.global_position.y > 0.5, "Player must remain above the streamed chunk ground outside the v1 center tile"):
		return
	if not T.require_true(self, player.is_on_floor(), "Player must settle on the streamed chunk ground"):
		return

	world.queue_free()
	T.pass_and_quit(self)
