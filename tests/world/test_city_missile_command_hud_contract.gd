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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for Missile Command HUD contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Missile Command HUD contract requires Player teleport API"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_crosshair_state"), "Missile Command HUD contract requires HUD crosshair introspection"):
		return
	if not T.require_true(self, world.has_method("get_missile_command_runtime_state"), "Missile Command HUD contract requires get_missile_command_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("get_missile_command_hud_state"), "Missile Command HUD contract requires get_missile_command_hud_state()"):
		return

	player.teleport_to_world_position(WORLD_POSITION + Vector3(0.0, 2.0, 12.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Missile Command HUD contract requires the mounted venue start ring contract"):
		return

	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(mounted_venue.get_match_start_contract().get("world_position", WORLD_POSITION) + Vector3.UP * standing_height)
	var runtime_state: Dictionary = await _wait_for_battery_mode(world, true)
	if not T.require_true(self, bool(runtime_state.get("battery_mode_active", false)), "Missile Command HUD contract requires an active battery-mode session"):
		return

	var hud_state: Dictionary = world.get_missile_command_hud_state()
	if not T.require_true(self, bool(hud_state.get("visible", false)), "Missile Command HUD contract must surface a visible missile HUD block during battery mode"):
		return
	if not T.require_true(self, hud_state.has("wave_index"), "Missile Command HUD contract must expose wave_index"):
		return
	if not T.require_true(self, hud_state.has("wave_state"), "Missile Command HUD contract must expose wave_state"):
		return
	if not T.require_true(self, hud_state.has("selected_silo_id"), "Missile Command HUD contract must expose selected_silo_id"):
		return
	if not T.require_true(self, not hud_state.has("selected_silo_missiles_remaining"), "Missile Command HUD contract must not expose a silo missile inventory once Missile Command uses unlimited interceptor launches"):
		return
	if not T.require_true(self, hud_state.has("cities_alive_count"), "Missile Command HUD contract must expose cities_alive_count"):
		return
	if not T.require_true(self, hud_state.has("enemy_remaining_count"), "Missile Command HUD contract must expose enemy_remaining_count"):
		return
	if not T.require_true(self, hud_state.has("zoom_active"), "Missile Command HUD contract must expose zoom_active"):
		return
	if not T.require_true(self, hud_state.has("feedback_event_token"), "Missile Command HUD contract must expose feedback_event_token"):
		return
	if not T.require_true(self, hud_state.has("feedback_event_text"), "Missile Command HUD contract must expose feedback_event_text"):
		return

	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, bool(crosshair_state.get("visible", false)), "Missile Command HUD contract must keep the crosshair visible during battery mode"):
		return
	if not T.require_true(self, crosshair_state.get("world_target", null) is Vector3, "Missile Command HUD contract must project the current missile reticle to a formal world_target"):
		return
	if not T.require_true(self, runtime_state.get("reticle_world_position", null) is Vector3, "Missile Command runtime snapshot must expose reticle_world_position as Vector3"):
		return
	if not T.require_true(self, (crosshair_state.get("world_target", Vector3.ZERO) as Vector3).distance_to(runtime_state.get("reticle_world_position", Vector3.ZERO)) <= 0.01, "Missile Command HUD contract must keep crosshair world_target aligned with runtime reticle_world_position"):
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
