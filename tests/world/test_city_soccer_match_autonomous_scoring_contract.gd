extends SceneTree

const T := preload("res://tests/_test_util.gd")

# Internal fast smoke only:
# This script is not the official M4 gold-standard acceptance.
# Official M4 must validate a full 5:00 autonomous match plus 10-match score sampling.

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const SOCCER_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const MATCH_DEBUG_SEED := 424242
const AUTONOMOUS_GOAL_TIMEOUT_FRAMES := 1800

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match autonomous scoring contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match autonomous scoring contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_ball_state"), "Soccer match autonomous scoring contract requires deterministic center-ball setup"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_match_seed"), "Soccer match autonomous scoring contract requires deterministic match seed control"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_match_clock_remaining_sec"), "Soccer match autonomous scoring contract requires deterministic clock override"):
		return
	if not T.require_true(self, world.has_method("debug_advance_soccer_match_time"), "Soccer match autonomous scoring contract requires deterministic time advancement"):
		return
	var seed_result: Dictionary = world.debug_set_soccer_match_seed(MATCH_DEBUG_SEED)
	if not T.require_true(self, bool(seed_result.get("success", false)), "Soccer match autonomous scoring contract must allow locking a deterministic match seed before kickoff"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer match autonomous scoring contract requires the mounted venue start ring contract"):
		return

	await _start_match(world, mounted_venue, player)
	if not T.require_true(self, mounted_venue.has_method("get_play_surface_contract"), "Soccer match autonomous scoring contract requires play surface metadata for deterministic center-ball setup"):
		return
	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", SOCCER_WORLD_POSITION)
	var reset_ball_result: Dictionary = world.debug_set_soccer_ball_state(kickoff_anchor + Vector3(0.0, 0.6, 0.0), Vector3.ZERO)
	if not T.require_true(self, bool(reset_ball_result.get("success", false)), "Soccer match autonomous scoring contract must allow deterministic center-ball setup before autonomous play"):
		return

	var scoring_runtime_state: Dictionary = await _wait_for_autonomous_goal(world)
	var total_goals := int(scoring_runtime_state.get("home_score", 0)) + int(scoring_runtime_state.get("away_score", 0))
	if not T.require_true(self, total_goals >= 1, "Soccer match autonomous scoring smoke requires at least one real goal in a short live-play window so debugging does not regress back to midfield deadlock"):
		return

	var shorten_clock_result: Dictionary = world.debug_set_soccer_match_clock_remaining_sec(1.0)
	if not T.require_true(self, bool(shorten_clock_result.get("success", false)), "Soccer match autonomous scoring smoke must allow fast-forwarding the remaining clock after the first real goal"):
		return
	var advance_clock_result: Dictionary = world.debug_advance_soccer_match_time(2.0)
	if not T.require_true(self, bool(advance_clock_result.get("success", false)), "Soccer match autonomous scoring smoke must allow deterministic advance into full time after autonomous scoring has occurred"):
		return
	var final_runtime_state := await _wait_for_match_state(world, "final")
	var final_total_goals := int(final_runtime_state.get("home_score", 0)) + int(final_runtime_state.get("away_score", 0))
	if not T.require_true(self, final_total_goals >= 1, "Soccer match autonomous scoring smoke must not erase the first real goal while fast-forwarding to full time"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _start_match(world, mounted_venue: Node3D, player) -> void:
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	await _wait_for_match_state(world, "in_progress")

func _wait_for_autonomous_goal(world) -> Dictionary:
	for _frame in range(AUTONOMOUS_GOAL_TIMEOUT_FRAMES):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		var total_goals := int(runtime_state.get("home_score", 0)) + int(runtime_state.get("away_score", 0))
		if total_goals >= 1:
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
