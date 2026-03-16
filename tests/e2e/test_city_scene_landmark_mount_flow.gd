extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FOUNTAIN_LANDMARK_ID := "landmark:v21:fountain:chunk_129_142"
const FOUNTAIN_CHUNK_ID := "chunk_129_142"
const FOUNTAIN_WORLD_POSITION := Vector3(-1848.0, 14.545391, 1480.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for scene landmark mount flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Scene landmark mount flow requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Scene landmark mount flow requires chunk renderer introspection"):
		return

	var chunk_renderer = world.get_chunk_renderer()
	if not T.require_true(self, chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene"), "Scene landmark mount flow requires chunk scene lookup"):
		return

	player.teleport_to_world_position(FOUNTAIN_WORLD_POSITION + Vector3(0.0, 8.0, 12.0))
	var mounted_landmark: Node = null
	for _frame in range(180):
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(FOUNTAIN_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_landmark_node"):
			continue
		mounted_landmark = chunk_scene.find_scene_landmark_node(FOUNTAIN_LANDMARK_ID)
		if mounted_landmark != null:
			break
	if not T.require_true(self, mounted_landmark != null, "Scene landmark mount flow must instantiate the fountain when chunk_129_142 enters near range"):
		return
	if not T.require_true(self, bool(mounted_landmark.get_meta("city_scene_landmark", false)), "Mounted fountain node must expose city_scene_landmark metadata"):
		return

	player.teleport_to_world_position(Vector3(0.0, 8.0, 0.0))
	var retired := false
	for _frame in range(180):
		await process_frame
		if chunk_renderer.get_chunk_scene(FOUNTAIN_CHUNK_ID) == null:
			retired = true
			break
	if not T.require_true(self, retired, "Scene landmark mount flow must retire the fountain chunk after the player moves far away"):
		return

	world.queue_free()
	T.pass_and_quit(self)
