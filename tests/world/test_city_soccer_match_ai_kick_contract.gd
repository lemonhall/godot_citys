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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match AI kick contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match AI kick contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer match AI kick contract requires debug_set_soccer_ball_state()"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer match AI kick contract requires the mounted venue start ring contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_roster_state"), "Soccer match AI kick contract requires roster introspection on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_play_surface_contract"), "Soccer match AI kick contract requires play surface metadata for goalkeeper defense checks"):
		return
	await _start_match(world, mounted_venue, player)
	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", SOCCER_WORLD_POSITION)

	var reset_ball_result: Dictionary = world.debug_set_soccer_ball_state(kickoff_anchor + Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
	if not T.require_true(self, bool(reset_ball_result.get("success", false)), "Soccer match AI kick contract must allow deterministic center-ball setup before the AI runs"):
		return

	var contest_roster_state: Dictionary = await _wait_for_team_contest_shape(mounted_venue)
	if not _require_team_intent(self, contest_roster_state, "home", "press_ball", "Soccer match AI contract must expose a live home ball-pressing runner when the ball is in open play"):
		return
	if not _require_team_intent(self, contest_roster_state, "away", "press_ball", "Soccer match AI contract must expose a live away ball-pressing runner when the ball is in open play"):
		return
	if not _require_team_intent(self, contest_roster_state, "home", "support_run", "Soccer match AI contract must keep at least one home teammate in a support run instead of sending the whole side to swarm the ball"):
		return
	if not _require_team_intent(self, contest_roster_state, "away", "support_run", "Soccer match AI contract must keep at least one away teammate in a support run instead of sending the whole side to swarm the ball"):
		return

	var runtime_state: Dictionary = await _wait_for_ai_kick(world)
	var ai_debug: Dictionary = (runtime_state.get("ai_debug_state", {}) as Dictionary).duplicate(true)
	if not T.require_true(self, int(ai_debug.get("kick_count", 0)) >= 1, "Soccer match AI kick contract must record at least one AI-triggered kick during a running match"):
		return
	if not T.require_true(self, str(ai_debug.get("last_touch_team_id", "")) != "", "Soccer match AI kick contract must identify which team last touched the ball through AI"):
		return
	if not T.require_true(self, str(ai_debug.get("last_touch_role_id", "")) != "", "Soccer match AI kick contract must identify whether the last AI touch came from a goalkeeper or field player"):
		return

	var home_goal_box_ball := kickoff_anchor + Vector3(0.0, 0.6, 42.0)
	var goal_box_result: Dictionary = world.debug_set_soccer_ball_state(home_goal_box_ball, Vector3.ZERO)
	if not T.require_true(self, bool(goal_box_result.get("success", false)), "Soccer match AI kick contract must allow deterministic goalkeeper-defense setup near the home goal"):
		return
	var goalkeeper_roster_state: Dictionary = await _wait_for_team_intent(mounted_venue, "home", "goalkeeper_intercept")
	if not _require_team_intent(self, goalkeeper_roster_state, "home", "goalkeeper_intercept", "Soccer match AI contract must switch the home goalkeeper into an intercept state when the ball enters the home box"):
		return
	if not _require_team_intent(self, goalkeeper_roster_state, "home", "collapse_defense", "Soccer match AI contract must send at least one home outfield player into collapse_defense while the goalkeeper steps out"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress")

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

func _wait_for_ai_kick(world) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var ai_debug: Dictionary = runtime_state.get("ai_debug_state", {})
		if int(ai_debug.get("kick_count", 0)) >= 1:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _wait_for_team_contest_shape(mounted_venue: Node3D) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var roster_state: Dictionary = mounted_venue.get_match_roster_state()
		if _team_has_intent(roster_state, "home", "press_ball") and _team_has_intent(roster_state, "away", "press_ball") \
			and _team_has_intent(roster_state, "home", "support_run") and _team_has_intent(roster_state, "away", "support_run"):
			return roster_state
	return mounted_venue.get_match_roster_state()

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
