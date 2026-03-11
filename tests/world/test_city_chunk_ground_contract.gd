extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd")
		return

	var chunk_scene = chunk_scene_script.new()
	root.add_child(chunk_scene)
	await process_frame

	chunk_scene.setup({
		"chunk_id": "chunk_13_13",
		"chunk_key": Vector2i(13, 13),
		"chunk_center": Vector3.ZERO,
		"chunk_size_m": 256.0,
	})

	if not T.require_true(self, chunk_scene.has_node("GroundBody"), "Chunk scene must provide GroundBody for continuous traversal"):
		return

	var ground_body: Node = chunk_scene.get_node("GroundBody")
	if not T.require_true(self, ground_body is StaticBody3D, "GroundBody must be a StaticBody3D"):
		return
	if not T.require_true(self, ground_body.get_node_or_null("CollisionShape3D") != null, "GroundBody must expose CollisionShape3D"):
		return
	if not T.require_true(self, ground_body.get_node_or_null("MeshInstance3D") != null, "GroundBody must expose MeshInstance3D"):
		return

	chunk_scene.queue_free()
	T.pass_and_quit(self)
