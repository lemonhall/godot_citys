extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const MATCH_DEBUG_SEED := 424242

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer goalkeeper live-claim contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer goalkeeper live-claim contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer goalkeeper live-claim contract requires deterministic ball placement"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_match_seed"), "Soccer goalkeeper live-claim contract requires deterministic match seed control"):
		return
	var seed_result: Dictionary = world.debug_set_soccer_match_seed(MATCH_DEBUG_SEED)
	if not T.require_true(self, bool(seed_result.get("success", false)), "Soccer goalkeeper live-claim contract must allow locking a deterministic match seed before kickoff"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer goalkeeper live-claim contract requires the mounted venue start ring contract"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_play_surface_contract"), "Soccer goalkeeper live-claim contract requires play surface metadata"):
		return

	await _start_match(world, mounted_venue, player)
	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", SOCCER_WORLD_POSITION)
	var rolling_claim_ball := kickoff_anchor + Vector3(0.0, 0.6, 35.0)
	var ball_result: Dictionary = world.debug_set_soccer_ball_state(rolling_claim_ball, Vector3(0.0, 0.0, 8.8))
	if not T.require_true(self, bool(ball_result.get("success", false)), "Soccer goalkeeper live-claim contract must allow deterministic rolling-ball setup into the home box"):
		return

	var claim_runtime_state: Dictionary = await _wait_for_goalkeeper_live_claim(world)
	var ai_debug: Dictionary = claim_runtime_state.get("ai_debug_state", {})
	if not T.require_true(self, int(ai_debug.get("goalkeeper_distribution_count", 0)) >= 1, "A live rolling ball into the home box must produce a real goalkeeper claim and distribution event before the attack simply walks in"):
		return
	if not T.require_true(self, int(claim_runtime_state.get("home_score", 0)) == 0 and int(claim_runtime_state.get("away_score", 0)) == 0, "A saveable rolling attack into the home box must not immediately turn into a conceded goal"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress")

func _wait_for_goalkeeper_live_claim(world) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var ai_debug: Dictionary = runtime_state.get("ai_debug_state", {})
		if int(ai_debug.get("goalkeeper_distribution_count", 0)) >= 1:
			return runtime_state
		if int(runtime_state.get("away_score", 0)) >= 1:
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
