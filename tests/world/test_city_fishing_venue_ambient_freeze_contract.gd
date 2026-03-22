extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_CHUNK_ID := "chunk_147_181"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"
const VENUE_WORLD_POSITION := Vector3(2834.0, 0.0, 11546.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fishing venue ambient freeze contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Fishing venue ambient freeze contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_fishing_venue_runtime_state"), "Fishing venue ambient freeze contract requires fishing runtime introspection"):
		return
	if not T.require_true(self, world.has_method("get_fishing_hud_state"), "Fishing venue ambient freeze contract requires fishing HUD introspection"):
		return
	if not T.require_true(self, world.has_method("is_ambient_simulation_frozen"), "Fishing venue ambient freeze contract requires world-level ambient freeze introspection"):
		return

	player.teleport_to_world_position(VENUE_WORLD_POSITION + Vector3.UP * 1.2)
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_fishing_contract"), "Fishing venue ambient freeze contract must mount the fishing venue before runtime checks"):
		return

	var frozen_state: Dictionary = await _wait_for_freeze_state(world, true)
	if not T.require_true(self, bool(frozen_state.get("ambient_simulation_frozen", false)), "Entering the lake leisure playable area must activate fishing ambient_simulation_freeze"):
		return
	if not T.require_true(self, bool(world.is_ambient_simulation_frozen()), "Fishing venue ambient freeze contract must aggregate to the world-level freeze state"):
		return
	var hud_state: Dictionary = world.get_fishing_hud_state()
	if not T.require_true(self, hud_state is Dictionary, "Fishing venue ambient freeze contract must keep fishing HUD state accessible while frozen"):
		return

	var fishing_contract: Dictionary = mounted_venue.get_fishing_contract()
	var play_bounds: Dictionary = fishing_contract.get("play_bounds", {})
	var play_center: Vector3 = play_bounds.get("world_center", VENUE_WORLD_POSITION)
	var half_extents: Vector2 = play_bounds.get("half_extents_m", Vector2(70.0, 60.0))
	var release_buffer_m := float(fishing_contract.get("release_buffer_m", 32.0))
	player.teleport_to_world_position(play_center + Vector3(half_extents.x + release_buffer_m - 2.0, 1.2, 0.0))
	await _settle_frames(16)
	if not T.require_true(self, bool(world.is_ambient_simulation_frozen()), "Leaving the lake leisure play bounds but staying inside the 32m release buffer must keep ambient freeze active"):
		return

	player.teleport_to_world_position(play_center + Vector3(half_extents.x + release_buffer_m + 6.0, 1.2, 0.0))
	var released_state: Dictionary = await _wait_for_freeze_state(world, false)
	if not T.require_true(self, not bool(released_state.get("ambient_simulation_frozen", true)), "Only leaving beyond the release buffer may release fishing ambient freeze"):
		return
	if not T.require_true(self, not bool(world.is_ambient_simulation_frozen()), "Fishing ambient freeze release must propagate back to the world aggregate state"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(VENUE_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _wait_for_freeze_state(world, expected_state: bool) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_fishing_venue_runtime_state()
		if bool(runtime_state.get("ambient_simulation_frozen", false)) == expected_state and bool(world.is_ambient_simulation_frozen()) == expected_state:
			return runtime_state
	return world.get_fishing_venue_runtime_state()

func _settle_frames(frame_count: int = 8) -> void:
	for _frame in range(frame_count):
		await physics_frame
		await process_frame
