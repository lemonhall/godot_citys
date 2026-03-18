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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer goalkeeper distribution contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer goalkeeper distribution contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer goalkeeper distribution contract requires deterministic ball placement"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer goalkeeper distribution contract requires the mounted venue start ring contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_play_surface_contract"), "Soccer goalkeeper distribution contract requires play surface metadata"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_roster_state"), "Soccer goalkeeper distribution contract requires roster introspection"):
		return

	await _start_match(world, mounted_venue, player)
	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", SOCCER_WORLD_POSITION)
	var home_keeper_ball := kickoff_anchor + Vector3(0.0, 0.6, 44.0)
	var ball_result: Dictionary = world.debug_set_soccer_ball_state(home_keeper_ball, Vector3.ZERO)
	if not T.require_true(self, bool(ball_result.get("success", false)), "Soccer goalkeeper distribution contract must allow deterministic keeper-box ball setup"):
		return

	var secure_roster_state: Dictionary = await _wait_for_team_intent(mounted_venue, "home", "goalkeeper_secure_ball")
	if not _require_team_intent(self, secure_roster_state, "home", "goalkeeper_secure_ball", "The home goalkeeper must be able to secure a slow ball inside the home box instead of only foot-poking it"):
		return
	var distribute_roster_state: Dictionary = await _wait_for_team_intent(mounted_venue, "home", "goalkeeper_distribute_ball")
	if not _require_team_intent(self, distribute_roster_state, "home", "goalkeeper_distribute_ball", "After securing the ball, the home goalkeeper must transition into an explicit distribution state before releasing it back into play"):
		return

	var release_runtime_state: Dictionary = await _wait_for_goalkeeper_distribution(world, mounted_venue)
	var ai_debug: Dictionary = release_runtime_state.get("ai_debug_state", {})
	if not T.require_true(self, str(ai_debug.get("last_distribution_role_id", "")) == "goalkeeper", "Goalkeeper distribution contract must record the keeper as the last distributor after securing the ball"):
		return
	var distributed_local_ball := mounted_venue.to_local(release_runtime_state.get("last_ball_world_position", Vector3.ZERO))
	if not T.require_true(self, distributed_local_ball.z <= 24.0, "After securing the ball, the goalkeeper must distribute it back toward midfield rather than keeping it trapped in the goalmouth"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress")

func _wait_for_goalkeeper_distribution(world, mounted_venue: Node3D) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var ai_debug: Dictionary = runtime_state.get("ai_debug_state", {})
		var ball_local_position := mounted_venue.to_local(runtime_state.get("last_ball_world_position", Vector3.ZERO))
		if str(ai_debug.get("last_distribution_role_id", "")) == "goalkeeper" and ball_local_position.z <= 24.0:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

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

func _wait_for_match_state(world, expected_state: String) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if str(runtime_state.get("match_state", "")) == expected_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _wait_for_team_intent(mounted_venue: Node3D, team_id: String, intent_kind: String) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var roster_state: Dictionary = mounted_venue.get_match_roster_state()
		if _team_has_intent(roster_state, team_id, intent_kind):
			return roster_state
	return mounted_venue.get_match_roster_state()

func _require_team_intent(test_tree: SceneTree, roster_state: Dictionary, team_id: String, intent_kind: String, message: String) -> bool:
	return T.require_true(test_tree, _team_has_intent(roster_state, team_id, intent_kind), message)

func _team_has_intent(roster_state: Dictionary, team_id: String, intent_kind: String) -> bool:
	for player_entry_variant in roster_state.get("players", []):
		var player_entry: Dictionary = player_entry_variant
		if str(player_entry.get("team_id", "")) != team_id:
			continue
		var state: Dictionary = player_entry.get("state", {})
		if str(state.get("intent_kind", "")) == intent_kind:
			return true
	return false

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
