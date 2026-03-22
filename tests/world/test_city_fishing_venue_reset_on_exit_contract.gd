extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_CHUNK_ID := "chunk_147_181"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fishing venue reset-on-exit contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Fishing venue reset-on-exit contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_fishing_venue_runtime_state"), "Fishing venue reset-on-exit contract requires fishing runtime introspection"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Fishing venue reset-on-exit contract requires the shared primary interaction entrypoint"):
		return

	player.teleport_to_world_position(Vector3(2834.0, 1.2, 11546.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_seat_anchor"), "Fishing venue reset-on-exit contract must mount the fishing venue before interaction checks"):
		return
	var seat_anchor: Dictionary = mounted_venue.get_seat_anchor("seat_main")
	player.teleport_to_world_position(seat_anchor.get("world_position", Vector3.ZERO) + Vector3.UP * 1.2)

	if not T.require_true(self, bool(world.handle_primary_interaction().get("success", false)), "Fishing venue reset-on-exit contract must seat the player before reset checks"):
		return
	if not T.require_true(self, bool(world.handle_primary_interaction().get("success", false)), "Fishing venue reset-on-exit contract must let the player cast before reset checks"):
		return
	var runtime_state: Dictionary = world.get_fishing_venue_runtime_state()
	if not T.require_true(self, bool(runtime_state.get("fishing_mode_active", false)), "Fishing venue reset-on-exit contract must enter an active fishing session before leaving bounds"):
		return

	var fishing_contract: Dictionary = mounted_venue.get_fishing_contract()
	var play_bounds: Dictionary = fishing_contract.get("play_bounds", {})
	var play_center: Vector3 = play_bounds.get("world_center", Vector3(2834.0, 0.0, 11510.0))
	var half_extents: Vector2 = play_bounds.get("half_extents_m", Vector2(70.0, 60.0))
	var release_buffer_m := float(fishing_contract.get("release_buffer_m", 32.0))
	player.teleport_to_world_position(play_center + Vector3(half_extents.x + release_buffer_m + 6.0, 1.2, 0.0))

	runtime_state = await _wait_for_cast_state(world, "idle")
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "idle", "Leaving beyond the release buffer must reset the fishing runtime to idle"):
		return
	if not T.require_true(self, not bool(runtime_state.get("fishing_mode_active", true)), "Leaving beyond the release buffer must release fishing_mode_active"):
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

func _wait_for_cast_state(world, expected_state: String) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_fishing_venue_runtime_state()
		if str(runtime_state.get("cast_state", "")) == expected_state:
			return runtime_state
	return world.get_fishing_venue_runtime_state()
