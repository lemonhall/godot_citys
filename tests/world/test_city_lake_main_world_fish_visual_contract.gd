extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_CHUNK_ID := "chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for lake main-world fish visual contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake main-world fish visual contract requires Player teleport API"):
		return
	player.teleport_to_world_position(Vector3(2834.0, 1.2, 11546.0))

	var chunk_scene := await _wait_for_chunk_scene(world, VENUE_CHUNK_ID)
	if not T.require_true(self, chunk_scene != null, "Lake main-world fish visual contract requires the lake owner chunk to mount before fish visual checks"):
		return
	var fish_schools_root := chunk_scene.get_node_or_null("NearGroup/LakeFishSchools") as Node3D
	if not T.require_true(self, fish_schools_root != null, "Lake main-world fish visual contract requires a dedicated NearGroup/LakeFishSchools runtime root in the owner chunk"):
		return
	if not T.require_true(self, fish_schools_root.get_child_count() >= 2, "Lake main-world fish visual contract requires the main world to materialize animated fish actors for the shared fish schools"):
		return
	var fish_school_actor := fish_schools_root.get_child(0) as Node3D
	if not T.require_true(self, fish_school_actor != null and fish_school_actor.has_method("get_debug_state"), "Lake main-world fish visual contract requires each fish actor to expose the formal debug API"):
		return
	var school_debug_state: Dictionary = fish_school_actor.get_debug_state()
	if not T.require_true(self, str(school_debug_state.get("current_animation", "")).to_lower().contains("swim"), "Lake main-world fish visual contract requires runtime fish actors to keep the Swim clip active inside the streamed lake"):
		return
	if not T.require_true(self, bool(school_debug_state.get("is_playing", false)), "Lake main-world fish visual contract requires runtime fish actors to actively play Swim instead of staying static"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_chunk_scene(world, chunk_id: String) -> Node:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene := chunk_renderer.get_chunk_scene(chunk_id) as Node
		if chunk_scene != null:
			return chunk_scene
	return null
