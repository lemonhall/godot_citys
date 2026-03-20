extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_ID := "venue:v29:missile_command_battery:chunk_183_152"
const CHUNK_ID := "chunk_183_152"
const WORLD_POSITION := Vector3(11925.63, -4.74, 4126.84)
const TEST_WAVE_SEED := 991183

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for Missile Command damage contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Missile Command damage contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_missile_command_runtime_state"), "Missile Command damage contract requires get_missile_command_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("debug_set_missile_command_wave_seed"), "Missile Command damage contract requires deterministic wave-seed override API"):
		return

	var seed_result: Dictionary = world.debug_set_missile_command_wave_seed(TEST_WAVE_SEED)
	if not T.require_true(self, bool(seed_result.get("success", false)), "Missile Command damage contract must accept a deterministic wave seed before the session starts"):
		return

	player.teleport_to_world_position(WORLD_POSITION + Vector3(0.0, 2.0, 14.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Missile Command damage contract requires the mounted venue start ring contract"):
		return

	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(mounted_venue.get_match_start_contract().get("world_position", WORLD_POSITION) + Vector3.UP * standing_height)
	var runtime_state: Dictionary = await _wait_for_city_damage(world, 2)
	if not T.require_true(self, int(runtime_state.get("cities_alive_count", 3)) <= 2, "Missile Command damage contract must reduce cities_alive_count after an unintercepted enemy hit reaches a city target"):
		return
	var city_states_variant: Variant = runtime_state.get("city_states", {})
	if not T.require_true(self, city_states_variant is Dictionary, "Missile Command damage contract must expose city_states as a Dictionary runtime snapshot"):
		return
	var any_destroyed := false
	for city_state_variant in (city_states_variant as Dictionary).values():
		var city_state: Dictionary = city_state_variant
		if bool(city_state.get("destroyed", false)):
			any_destroyed = true
			break
	if not T.require_true(self, any_destroyed, "Missile Command damage contract must formally mark the hit city as destroyed instead of only decrementing a counter"):
		return
	var silo_states_variant: Variant = runtime_state.get("silo_states", {})
	if not T.require_true(self, silo_states_variant is Dictionary, "Missile Command damage contract must expose silo_states as a Dictionary runtime snapshot"):
		return
	for silo_state_variant in (silo_states_variant as Dictionary).values():
		var silo_state: Dictionary = silo_state_variant
		if not T.require_true(self, not bool(silo_state.get("destroyed", false)), "Missile Command damage contract must keep launch silos intact because enemy missiles may only target cities"):
			return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_mounted_venue(world) -> Variant:
	var chunk_renderer: Variant = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene: Variant = chunk_renderer.get_chunk_scene(CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_minigame_venue_node"):
			continue
		var mounted_venue: Variant = chunk_scene.find_scene_minigame_venue_node(VENUE_ID)
		if mounted_venue != null:
			return mounted_venue
	return null

func _wait_for_city_damage(world, expected_cities_alive_max: int) -> Dictionary:
	for _frame in range(1500):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_missile_command_runtime_state()
		if int(runtime_state.get("cities_alive_count", 3)) <= expected_cities_alive_max:
			return runtime_state
	return world.get_missile_command_runtime_state()

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
