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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match goal reset shape contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match goal reset shape contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer match goal reset shape contract requires deterministic ball placement"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer match goal reset shape contract requires the mounted venue start ring contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_goal_contracts"), "Soccer match goal reset shape contract requires goal contracts on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_roster_state"), "Soccer match goal reset shape contract requires roster introspection on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_player_contracts"), "Soccer match goal reset shape contract requires formal player anchor contracts on the mounted venue"):
		return

	await _start_match(world, mounted_venue, player)
	await _score_goal(world, mounted_venue, "home")
	var player_contracts: Array = mounted_venue.get_match_player_contracts()
	var roster_state: Dictionary = await _wait_for_anchor_reform(mounted_venue, player_contracts)
	if not T.require_true(self, _all_players_near_anchors(roster_state, player_contracts, 3.6), "After a goal reset, match players must reform near their kickoff anchors instead of staying piled in the center-circle scrum"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress")

func _score_goal(world, mounted_venue: Node3D, scoring_side: String) -> void:
	var goal_contracts: Dictionary = mounted_venue.get_goal_contracts()
	var goal_key := "goal_a" if scoring_side == "home" else "goal_b"
	var goal_contract: Dictionary = goal_contracts.get(goal_key, {})
	var goal_center: Vector3 = goal_contract.get("world_center", Vector3.ZERO)
	var approach_sign: float = float(goal_contract.get("approach_sign_z", 0.0))
	var score_result: Dictionary = world.debug_set_soccer_ball_state(goal_center, Vector3(0.0, 0.0, approach_sign * 1.3))
	if not bool(score_result.get("success", false)):
		return
	await _wait_for_score(world, scoring_side, 1)

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

func _wait_for_score(world, scoring_side: String, expected_score: int) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var score: int = int(runtime_state.get("home_score", 0)) if scoring_side == "home" else int(runtime_state.get("away_score", 0))
		if score >= expected_score:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _wait_for_anchor_reform(mounted_venue: Node3D, player_contracts: Array) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var roster_state: Dictionary = mounted_venue.get_match_roster_state()
		if _all_players_near_anchors(roster_state, player_contracts, 3.6):
			return roster_state
	return mounted_venue.get_match_roster_state()

func _all_players_near_anchors(roster_state: Dictionary, player_contracts: Array, max_distance_m: float) -> bool:
	var anchors_by_player_id := {}
	for player_contract_variant in player_contracts:
		var player_contract: Dictionary = player_contract_variant
		anchors_by_player_id[str(player_contract.get("player_id", ""))] = player_contract.get("local_anchor_position", Vector3.ZERO)
	for player_entry_variant in roster_state.get("players", []):
		var player_entry: Dictionary = player_entry_variant
		var state: Dictionary = player_entry.get("state", {})
		var local_position: Vector3 = state.get("local_position", Vector3.ZERO)
		var contract_anchor: Vector3 = anchors_by_player_id.get(str(player_entry.get("player_id", "")), local_position)
		if local_position.distance_to(contract_anchor) > max_distance_m:
			return false
	return true

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
