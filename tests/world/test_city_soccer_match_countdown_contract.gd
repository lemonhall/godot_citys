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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match countdown contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match countdown contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_soccer_match_hud_state"), "Soccer match countdown contract requires get_soccer_match_hud_state()"):
		return
	if not T.require_true(self, world.has_method("debug_set_soccer_match_clock_remaining_sec"), "Soccer match countdown contract requires debug_set_soccer_match_clock_remaining_sec()"):
		return
	if not T.require_true(self, world.has_method("debug_advance_soccer_match_time"), "Soccer match countdown contract requires debug_advance_soccer_match_time()"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 10.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Soccer match countdown contract requires the mounted venue start ring contract"):
		return
	await _start_match(world, mounted_venue, player)

	var hud_state: Dictionary = world.get_soccer_match_hud_state()
	if not T.require_true(self, bool(hud_state.get("visible", false)), "Soccer match countdown contract must expose a visible HUD block while the match is running"):
		return
	if not T.require_true(self, str(hud_state.get("clock_text", "")) == "05:00", "Soccer match countdown contract must boot with 05:00 in the HUD"):
		return

	var set_result: Dictionary = world.debug_set_soccer_match_clock_remaining_sec(12.0)
	if not T.require_true(self, bool(set_result.get("success", false)), "Soccer match countdown contract must allow deterministic clock override for test coverage"):
		return
	await _settle_frames(2)
	hud_state = world.get_soccer_match_hud_state()
	if not T.require_true(self, str(hud_state.get("clock_text", "")) == "00:12", "Soccer match countdown contract must format the HUD clock as mm:ss after a clock override"):
		return

	var advance_result: Dictionary = world.debug_advance_soccer_match_time(13.0)
	if not T.require_true(self, bool(advance_result.get("success", false)), "Soccer match countdown contract must allow deterministic time advancement for end-of-match validation"):
		return
	var runtime_state: Dictionary = await _wait_for_match_state(world, "final")
	if not T.require_true(self, str(runtime_state.get("match_state", "")) == "final", "Advancing the soccer match past zero must enter the final state"):
		return
	hud_state = world.get_soccer_match_hud_state()
	if not T.require_true(self, str(hud_state.get("clock_text", "")) == "00:00", "Soccer match countdown contract must clamp the HUD clock at 00:00 after the match ends"):
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

func _settle_frames(frame_count: int = 8) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

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
