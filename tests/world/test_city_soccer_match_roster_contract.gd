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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match roster contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match roster contract requires Player teleport API"):
		return
	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 8.0))

	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer match roster contract must mount the soccer venue before roster checks"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_roster_state"), "Soccer match roster contract requires get_match_roster_state() on the mounted venue"):
		return

	var roster_state: Dictionary = mounted_venue.get_match_roster_state()
	if not T.require_true(self, int(roster_state.get("player_count", 0)) == 10, "Soccer match roster contract must spawn exactly 10 on-field players"):
		return
	if not T.require_true(self, int((roster_state.get("team_counts", {}) as Dictionary).get("home", 0)) == 5, "Soccer match roster contract must freeze home team size at 5"):
		return
	if not T.require_true(self, int((roster_state.get("team_counts", {}) as Dictionary).get("away", 0)) == 5, "Soccer match roster contract must freeze away team size at 5"):
		return
	if not T.require_true(self, int((roster_state.get("goalkeeper_counts", {}) as Dictionary).get("home", 0)) == 1, "Soccer match roster contract must freeze exactly one home goalkeeper"):
		return
	if not T.require_true(self, int((roster_state.get("goalkeeper_counts", {}) as Dictionary).get("away", 0)) == 1, "Soccer match roster contract must freeze exactly one away goalkeeper"):
		return
	var team_color_ids: Array = roster_state.get("team_color_ids", [])
	if not T.require_true(self, team_color_ids.has("red") and team_color_ids.has("blue"), "Soccer match roster contract must expose red and blue team color identities"):
		return
	if not T.require_true(self, int(roster_state.get("idle_player_count", 0)) == 10, "Soccer match roster contract must keep every player in idle before kickoff"):
		return

	var player_root := mounted_venue.get_node_or_null("MatchPlayers") as Node3D
	if not T.require_true(self, player_root != null and player_root.get_child_count() == 10, "Soccer match roster contract must instantiate 10 concrete player nodes under MatchPlayers"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(SOCCER_VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null
