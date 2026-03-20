extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_ID := "venue:v29:missile_command_battery:chunk_183_152"
const CHUNK_ID := "chunk_183_152"
const WORLD_POSITION := Vector3(11925.63, -4.74, 4126.84)
const TEST_WAVE_SEED := 424242

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for Missile Command wave contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Missile Command wave contract requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_missile_command_runtime_state"), "Missile Command wave contract requires get_missile_command_runtime_state()"):
		return
	if not T.require_true(self, world.has_method("request_missile_command_fire_at_world_position"), "Missile Command wave contract requires request_missile_command_fire_at_world_position()"):
		return
	if not T.require_true(self, world.has_method("debug_set_missile_command_wave_seed"), "Missile Command wave contract requires deterministic wave-seed override API"):
		return

	var seed_result: Dictionary = world.debug_set_missile_command_wave_seed(TEST_WAVE_SEED)
	if not T.require_true(self, bool(seed_result.get("success", false)), "Missile Command wave contract must accept a deterministic wave seed before the session starts"):
		return

	player.teleport_to_world_position(WORLD_POSITION + Vector3(0.0, 2.0, 14.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null and mounted_venue.has_method("get_match_start_contract"), "Missile Command wave contract requires the mounted venue start ring contract"):
		return

	var standing_height := _estimate_standing_height(player)
	player.teleport_to_world_position(mounted_venue.get_match_start_contract().get("world_position", WORLD_POSITION) + Vector3.UP * standing_height)
	var runtime_state: Dictionary = await _wait_for_live_enemy_tracks(world, 2)
	if not T.require_true(self, bool(runtime_state.get("battery_mode_active", false)), "Missile Command wave contract requires an active battery-mode session before combat checks"):
		return
	if not T.require_true(self, int(runtime_state.get("enemy_remaining_count", -1)) == 2, "Missile Command wave contract must cap the first-wave incoming missile count at 2 after the difficulty reduction pass"):
		return
	var enemy_tracks: Array = runtime_state.get("enemy_tracks", [])
	if not T.require_true(self, enemy_tracks.size() > 0, "Missile Command wave contract requires at least one live enemy track in the current wave"):
		return
	for enemy_track_variant in enemy_tracks:
		var enemy_track: Dictionary = enemy_track_variant
		if not T.require_true(self, str(enemy_track.get("target_kind", "city")) == "city", "Missile Command wave contract must only spawn enemy tracks that target cities"):
			return
		if not T.require_true(self, float(enemy_track.get("speed_mps", 999.0)) <= 6.5, "Missile Command wave contract must keep first-wave enemy missile speed at or below 6.5m/s after the latest slow-down pass"):
			return

	var first_track: Dictionary = enemy_tracks[0]
	var intercept_world_position_variant: Variant = first_track.get("recommended_intercept_world_position", null)
	if not T.require_true(self, intercept_world_position_variant is Vector3, "Missile Command wave contract requires each live enemy track to expose recommended_intercept_world_position"):
		return
	var destroyed_enemy_count_before := int(runtime_state.get("destroyed_enemy_count", 0))
	var interceptor_count_before := (runtime_state.get("interceptor_tracks", []) as Array).size()
	for shot_index in range(26):
		var fire_result: Dictionary = world.request_missile_command_fire_at_world_position(intercept_world_position_variant as Vector3)
		if not T.require_true(self, bool(fire_result.get("success", false)), "Missile Command wave contract must allow repeated interceptor launches without a silo ammo limit"):
			return
	await process_frame
	runtime_state = world.get_missile_command_runtime_state()
	if not T.require_true(self, (runtime_state.get("interceptor_tracks", []) as Array).size() >= interceptor_count_before + 26, "Missile Command wave contract must materialize repeated live interceptor tracks without exhausting a silo inventory"):
		return
	if not T.require_true(self, _has_authored_interceptor_visual(mounted_venue), "Missile Command wave contract must instance the authored missile visual scene instead of rendering interceptor tracks as placeholder spheres"):
		return
	if not T.require_true(self, _has_visible_interceptor_trail(mounted_venue), "Missile Command wave contract must drive a visible TrailVisual behind the live interceptor instead of a bare missile mesh"):
		return
	if not T.require_true(self, _authored_interceptor_preview_helpers_are_runtime_safe(mounted_venue), "Missile Command wave contract must keep PreviewCamera/PreviewLight disabled in runtime so the authored debug helpers never hijack the live game scene"):
		return
	runtime_state = await _wait_for_destroyed_enemy_count(world, destroyed_enemy_count_before + 1)
	if not T.require_true(self, int(runtime_state.get("destroyed_enemy_count", 0)) >= destroyed_enemy_count_before + 1, "Missile Command wave contract must increase destroyed_enemy_count after a successful intercept"):
		return
	runtime_state = await _wait_for_live_explosion_track(world)
	if not T.require_true(self, (runtime_state.get("explosion_tracks", []) as Array).size() > 0, "Missile Command wave contract must surface a live explosion track after interceptor detonation"):
		return
	var explosion_track: Dictionary = (runtime_state.get("explosion_tracks", []) as Array)[0]
	if not T.require_true(self, float(explosion_track.get("radius_m", 0.0)) >= 14.0, "Missile Command wave contract must enlarge the interceptor explosion radius to at least 14m"):
		return
	if not T.require_true(self, (runtime_state.get("explosion_tracks", []) as Array).size() > 0 or int(runtime_state.get("explosion_spawn_count", 0)) > 0, "Missile Command wave contract must materialize a formal explosion track when an interceptor reaches its target point"):
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

func _wait_for_live_enemy_tracks(world, expected_count: int) -> Dictionary:
	for _frame in range(480):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_missile_command_runtime_state()
		if bool(runtime_state.get("battery_mode_active", false)) and (runtime_state.get("enemy_tracks", []) as Array).size() >= expected_count:
			return runtime_state
	return world.get_missile_command_runtime_state()

func _wait_for_destroyed_enemy_count(world, expected_count: int) -> Dictionary:
	for _frame in range(300):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_missile_command_runtime_state()
		if int(runtime_state.get("destroyed_enemy_count", 0)) >= expected_count:
			return runtime_state
	return world.get_missile_command_runtime_state()

func _wait_for_live_explosion_track(world) -> Dictionary:
	for _frame in range(240):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = world.get_missile_command_runtime_state()
		if (runtime_state.get("explosion_tracks", []) as Array).size() > 0:
			return runtime_state
	return world.get_missile_command_runtime_state()

func _has_authored_interceptor_visual(mounted_venue: Node3D) -> bool:
	var interceptor_root := mounted_venue.get_node_or_null("RuntimeVisuals/InterceptorTracks") as Node3D
	if interceptor_root == null:
		return false
	for child in interceptor_root.get_children():
		var node := child as Node
		if node != null and node.get_node_or_null("ModelRoot") != null:
			return true
	return false

func _has_visible_interceptor_trail(mounted_venue: Node3D) -> bool:
	var interceptor_root := mounted_venue.get_node_or_null("RuntimeVisuals/InterceptorTracks") as Node3D
	if interceptor_root == null:
		return false
	for child in interceptor_root.get_children():
		var trail_visual := child.get_node_or_null("TrailVisual") as VisualInstance3D
		if trail_visual != null and trail_visual.visible:
			return true
	return false

func _authored_interceptor_preview_helpers_are_runtime_safe(mounted_venue: Node3D) -> bool:
	var interceptor_root := mounted_venue.get_node_or_null("RuntimeVisuals/InterceptorTracks") as Node3D
	if interceptor_root == null:
		return false
	for child in interceptor_root.get_children():
		if child.has_method("get_debug_state"):
			var debug_state := child.get_debug_state() as Dictionary
			if bool(debug_state.get("preview_active", false)):
				return false
		var preview_camera := child.get_node_or_null("PreviewCamera") as Camera3D
		if preview_camera != null:
			return false
		var preview_light := child.get_node_or_null("PreviewLight") as Node3D
		if preview_light != null:
			return false
		if child.get_node_or_null("PreviewEnvironment") != null:
			return false
	return true

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
