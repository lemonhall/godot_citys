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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer match start contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer match start contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_soccer_venue_runtime_state"), "Soccer match start contract requires get_soccer_venue_runtime_state()"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 2.0, 12.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer match start contract must mount the soccer venue before kickoff checks"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_start_contract"), "Soccer match start contract requires get_match_start_contract() on the mounted venue"):
		return

	var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
	if not T.require_true(self, str(runtime_state.get("match_state", "")) == "idle", "Soccer match start contract must boot in match_state = idle before the player touches the start ring"):
		return

	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	if not T.require_true(self, str(start_contract.get("theme_id", "")) == "task_available_start", "Soccer match start contract must reuse the shared task_available_start ring theme"):
		return
	var start_anchor: Vector3 = start_contract.get("world_position", Vector3.ZERO)
	var standing_height := _estimate_standing_height(player)

	player.teleport_to_world_position(start_anchor + Vector3(float(start_contract.get("trigger_radius_m", 0.0)) + 3.0, standing_height, 0.0))
	await _settle_frames(8)
	runtime_state = world.get_soccer_venue_runtime_state()
	if not T.require_true(self, str(runtime_state.get("match_state", "")) == "idle", "Standing outside the soccer match start ring must not begin the match"):
		return

	player.teleport_to_world_position(start_anchor + Vector3.UP * standing_height)
	runtime_state = await _wait_for_match_state(world, "in_progress")
	if not T.require_true(self, str(runtime_state.get("match_state", "")) == "in_progress", "Entering the soccer match start ring must begin the match"):
		return
	if not T.require_true(self, is_equal_approx(float(runtime_state.get("match_clock_remaining_sec", -1.0)), 300.0), "Soccer match start contract must initialize the match clock to exactly 300 seconds"):
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
