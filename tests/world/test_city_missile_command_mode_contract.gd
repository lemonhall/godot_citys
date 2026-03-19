extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_ID := "venue:v29:missile_command_battery:chunk_183_152"
const CHUNK_ID := "chunk_183_152"
const WORLD_POSITION := Vector3(11925.63, -4.74, 4126.84)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for Missile Command mode contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Missile Command mode contract requires Player teleport API"):
		return
	if not T.require_true(self, player.has_method("is_control_enabled"), "Missile Command mode contract requires player control introspection"):
		return
	if not T.require_true(self, player.has_method("is_movement_locked"), "Missile Command mode contract requires player movement-lock introspection"):
		return
	if not T.require_true(self, world.has_method("get_missile_command_runtime_state"), "Missile Command mode contract requires get_missile_command_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_missile_command_hud_state"), "Missile Command mode contract requires get_missile_command_hud_state()"):
		return
	if not T.require_true(self, world.has_method("request_missile_command_primary_fire"), "Missile Command mode contract requires request_missile_command_primary_fire()"):
		return
	if not T.require_true(self, world.has_method("cycle_missile_command_silo"), "Missile Command mode contract requires cycle_missile_command_silo()"):
		return
	if not T.require_true(self, world.has_method("set_missile_command_zoom_active"), "Missile Command mode contract requires set_missile_command_zoom_active()"):
		return
	if not T.require_true(self, world.has_method("exit_missile_command_mode"), "Missile Command mode contract requires exit_missile_command_mode()"):
		return
	if not T.require_true(self, world.has_method("is_ambient_simulation_frozen"), "Missile Command mode contract requires world-level ambient freeze introspection"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "Missile Command mode contract requires pedestrian runtime snapshot introspection"):
		return
	if not T.require_true(self, world.has_method("get_vehicle_runtime_snapshot"), "Missile Command mode contract requires vehicle runtime snapshot introspection"):
		return
	if not T.require_true(self, world.has_method("is_world_simulation_paused"), "Missile Command mode contract requires world simulation pause introspection"):
		return

	player.teleport_to_world_position(WORLD_POSITION + Vector3(0.0, 2.0, 16.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Missile Command mode contract requires the mounted venue start ring contract"):
		return

	var runtime_state: Dictionary = world.get_missile_command_runtime_state()
	if not T.require_true(self, not bool(runtime_state.get("battery_mode_active", true)), "Standing outside the Missile Command start ring must not begin battery mode"):
		return

	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(start_contract.get("world_position", WORLD_POSITION) + Vector3.UP * standing_height)

	runtime_state = await _wait_for_battery_mode(world, true)
	if not T.require_true(self, bool(runtime_state.get("battery_mode_active", false)), "Entering the Missile Command start ring must activate battery mode"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()), "Missile Command battery mode must preserve player look control for free-view aiming"):
		return
	if not T.require_true(self, bool(player.is_movement_locked()), "Missile Command battery mode must lock locomotion while the player keeps free-look control"):
		return
	if not T.require_true(self, bool(world.is_ambient_simulation_frozen()), "Missile Command battery mode must aggregate world-level ambient freeze"):
		return
	if not T.require_true(self, not bool(world.is_world_simulation_paused()), "Missile Command battery mode must not flip world_simulation_pause to true"):
		return
	var ped_runtime: Dictionary = world.get_pedestrian_runtime_snapshot()
	var veh_runtime: Dictionary = world.get_vehicle_runtime_snapshot()
	if not T.require_true(self, bool(ped_runtime.get("simulation_frozen", false)), "Missile Command battery mode must freeze pedestrian simulation while the battery session is active"):
		return
	if not T.require_true(self, bool(veh_runtime.get("simulation_frozen", false)), "Missile Command battery mode must freeze vehicle simulation while the battery session is active"):
		return
	var hud_state: Dictionary = world.get_missile_command_hud_state()
	if not T.require_true(self, bool(hud_state.get("visible", false)), "Missile Command battery mode must surface a visible HUD block"):
		return
	if not T.require_true(self, str(hud_state.get("selected_silo_id", "")) != "", "Missile Command HUD must expose a formal selected_silo_id during battery mode"):
		return

	var selected_silo_index_before := int(runtime_state.get("selected_silo_index", -1))
	var cycle_result: Dictionary = world.cycle_missile_command_silo()
	if not T.require_true(self, bool(cycle_result.get("success", false)), "Missile Command mode contract must allow cycling the selected launch silo"):
		return
	runtime_state = world.get_missile_command_runtime_state()
	if not T.require_true(self, int(runtime_state.get("selected_silo_index", -1)) != selected_silo_index_before, "Cycling silos in Missile Command battery mode must change selected_silo_index"):
		return

	var zoom_result: Dictionary = world.set_missile_command_zoom_active(true)
	if not T.require_true(self, bool(zoom_result.get("success", false)), "Missile Command mode contract must accept explicit zoom activation"):
		return
	await process_frame
	runtime_state = world.get_missile_command_runtime_state()
	if not T.require_true(self, bool(runtime_state.get("zoom_active", false)), "Missile Command runtime state must expose zoom_active after right-click equivalent activation"):
		return
	world.set_missile_command_zoom_active(false)
	await process_frame
	runtime_state = world.get_missile_command_runtime_state()
	if not T.require_true(self, not bool(runtime_state.get("zoom_active", true)), "Missile Command runtime state must clear zoom_active when zoom is released"):
		return

	var exit_result: Dictionary = world.exit_missile_command_mode()
	if not T.require_true(self, bool(exit_result.get("success", false)), "Missile Command mode contract must allow exiting battery mode through the formal exit entrypoint"):
		return
	runtime_state = await _wait_for_battery_mode(world, false)
	if not T.require_true(self, not bool(runtime_state.get("battery_mode_active", true)), "Exiting Missile Command battery mode must clear battery_mode_active"):
		return
	if not T.require_true(self, bool(player.is_control_enabled()), "Exiting Missile Command battery mode must restore player control"):
		return
	if not T.require_true(self, not bool(player.is_movement_locked()), "Exiting Missile Command battery mode must release the movement lock"):
		return
	if not T.require_true(self, not bool(world.is_ambient_simulation_frozen()), "Exiting Missile Command battery mode must release ambient freeze aggregation"):
		return
	ped_runtime = world.get_pedestrian_runtime_snapshot()
	veh_runtime = world.get_vehicle_runtime_snapshot()
	if not T.require_true(self, not bool(ped_runtime.get("simulation_frozen", true)), "Exiting Missile Command battery mode through Esc must release pedestrian ambient freeze"):
		return
	if not T.require_true(self, not bool(veh_runtime.get("simulation_frozen", true)), "Exiting Missile Command battery mode through Esc must release vehicle ambient freeze"):
		return
	hud_state = world.get_missile_command_hud_state()
	if not T.require_true(self, not bool(hud_state.get("visible", true)), "Exiting Missile Command battery mode must hide the missile HUD block"):
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

func _wait_for_battery_mode(world, expected_state: bool) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_missile_command_runtime_state()
		if bool(runtime_state.get("battery_mode_active", false)) == expected_state:
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
