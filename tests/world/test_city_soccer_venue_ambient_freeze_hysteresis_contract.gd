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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer venue ambient freeze hysteresis contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer venue ambient freeze hysteresis contract requires Player teleport API"):
		return

	player.teleport_to_world_position(SOCCER_WORLD_POSITION + Vector3(0.0, 1.2, 0.0))
	await _wait_for_ambient_freeze(world, true)
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Soccer venue ambient freeze hysteresis contract must mount the venue before boundary checks"):
		return

	var play_surface: Dictionary = mounted_venue.get_play_surface_contract()
	var surface_size: Vector3 = play_surface.get("surface_size", Vector3.ZERO)
	var release_buffer_m: float = float(play_surface.get("release_buffer_m", 24.0))
	var kickoff_anchor: Vector3 = play_surface.get("kickoff_anchor", Vector3.ZERO)

	player.teleport_to_world_position(kickoff_anchor + Vector3(surface_size.x * 0.5 + 8.0, 1.2, 0.0))
	await _settle_frames(16)
	if not T.require_true(self, bool(world.is_ambient_simulation_frozen()), "Leaving the pitch but staying inside the 24m release buffer must keep ambient freeze active"):
		return

	player.teleport_to_world_position(kickoff_anchor + Vector3(surface_size.x * 0.5 + release_buffer_m + 8.0, 1.2, 0.0))
	await _wait_for_ambient_freeze(world, false)
	if not T.require_true(self, not bool(world.is_ambient_simulation_frozen()), "Only leaving beyond the release buffer may release ambient freeze"):
		return

	player.teleport_to_world_position(kickoff_anchor + Vector3(0.0, 1.2, 0.0))
	await _wait_for_ambient_freeze(world, true)
	if not T.require_true(self, bool(world.is_ambient_simulation_frozen()), "Re-entering the playable pitch must reactivate ambient freeze"):
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

func _wait_for_ambient_freeze(world, expected_state: bool) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_soccer_venue_runtime_state()
		if bool(runtime_state.get("ambient_simulation_frozen", false)) == expected_state and bool(world.is_ambient_simulation_frozen()) == expected_state:
			return runtime_state
	return world.get_soccer_venue_runtime_state()

func _settle_frames(frame_count: int = 8) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
