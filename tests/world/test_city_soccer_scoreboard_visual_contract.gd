extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer scoreboard visual contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer scoreboard visual contract requires Player teleport API"):
		return
	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 3.0, 6.0))

	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer scoreboard visual contract must mount the soccer venue before scene inspection"):
		return

	var scoreboard_root := mounted_venue.get_node_or_null("Scoreboard") as Node3D
	if not T.require_true(self, scoreboard_root != null, "Soccer scoreboard visual contract requires a dedicated Scoreboard root in the mounted venue scene"):
		return
	if not T.require_true(self, scoreboard_root.get_node_or_null("Panel") is MeshInstance3D, "Soccer scoreboard visual contract requires a readable panel mesh instead of invisible bookkeeping only"):
		return
	if not T.require_true(self, scoreboard_root.get_node_or_null("HomeScoreLabel") is Label3D, "Soccer scoreboard visual contract requires a HomeScoreLabel Label3D for world-space readability"):
		return
	if not T.require_true(self, scoreboard_root.get_node_or_null("AwayScoreLabel") is Label3D, "Soccer scoreboard visual contract requires an AwayScoreLabel Label3D for world-space readability"):
		return
	if not T.require_true(self, scoreboard_root.get_node_or_null("StateLabel") is Label3D, "Soccer scoreboard visual contract requires a StateLabel Label3D for world-space readability"):
		return

	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var surface_size: Vector3 = play_surface.get("surface_size", Vector3.ZERO)
	if not T.require_true(self, absf(scoreboard_root.position.x) >= surface_size.x * 0.5 + 4.0, "Soccer scoreboard visual contract must place the scoreboard clearly outside the main playable floor instead of on top of the kick path"):
		return
	if not T.require_true(self, scoreboard_root.global_position.y >= float(play_surface.get("surface_top_y", 0.0)) + 2.5, "Soccer scoreboard visual contract must lift the panel high enough to read from the pitch instead of burying it at floor level"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue = chunk_scene.find_scene_minigame_venue_node(SOCCER_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null
