extends SceneTree

const T := preload("res://tests/_test_util.gd")

const VENUE_ID := "venue:v29:missile_command_battery:chunk_183_152"
const CHUNK_ID := "chunk_183_152"
const WORLD_POSITION := Vector3(11925.63, -4.74, 4126.84)
const INTERCEPTOR_MISSILE_MODEL_PATH := "res://city_game/assets/minigames/missile_command/projectiles/Missile.glb"
const INTERCEPTOR_MISSILE_VISUAL_SCENE_PATH := "res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisual.tscn"
const INTERCEPTOR_MISSILE_PREVIEW_WRAPPER_PATH := "res://city_game/assets/minigames/missile_command/projectiles/InterceptorMissileVisualPreview.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, FileAccess.file_exists(INTERCEPTOR_MISSILE_MODEL_PATH), "Missile Command battery contract must store the imported missile GLB in the formal minigame projectile asset directory"):
		return
	if not T.require_true(self, ResourceLoader.exists(INTERCEPTOR_MISSILE_VISUAL_SCENE_PATH, "PackedScene"), "Missile Command battery contract must expose an authored interceptor visual scene that wraps the missile GLB"):
		return
	if not T.require_true(self, ResourceLoader.exists(INTERCEPTOR_MISSILE_PREVIEW_WRAPPER_PATH, "PackedScene"), "Missile Command battery contract must expose a committed preview wrapper scene for F6 scene preview reuse"):
		return
	var interceptor_visual_scene := load(INTERCEPTOR_MISSILE_VISUAL_SCENE_PATH) as PackedScene
	if not T.require_true(self, interceptor_visual_scene != null, "Missile Command battery contract must load the interceptor visual scene as PackedScene"):
		return
	var preview_wrapper_scene := load(INTERCEPTOR_MISSILE_PREVIEW_WRAPPER_PATH) as PackedScene
	if not T.require_true(self, preview_wrapper_scene != null, "Missile Command battery contract must load the committed missile preview wrapper as PackedScene"):
		return
	var preview_wrapper := preview_wrapper_scene.instantiate() as Node3D
	if not T.require_true(self, preview_wrapper != null, "Missile Command battery contract must instantiate the committed missile preview wrapper scene"):
		return
	if not T.require_true(self, preview_wrapper.has_method("get_preview_runtime_state"), "Missile Command battery contract requires the preview wrapper to be rooted in the shared ScenePreviewHarness"):
		return
	root.add_child(preview_wrapper)
	await process_frame
	await process_frame
	var preview_runtime_state := preview_wrapper.get_preview_runtime_state() as Dictionary
	if not T.require_true(self, bool(preview_runtime_state.get("subject_loaded", false)), "Missile Command battery contract must mount the missile visual into the shared preview harness wrapper"):
		return
	if not T.require_true(self, str(preview_runtime_state.get("subject_scene_path", "")) == INTERCEPTOR_MISSILE_VISUAL_SCENE_PATH, "Missile Command battery contract must preserve the formal interceptor visual scene path inside the preview wrapper runtime state"):
		return
	if not T.require_true(self, bool(preview_runtime_state.get("preview_camera_current", false)), "Missile Command battery contract must activate the shared preview harness camera when running the committed wrapper scene"):
		return
	if not T.require_true(self, bool(preview_runtime_state.get("preview_mouse_captured", false)), "Missile Command battery contract must capture the mouse through the shared preview harness so free-look starts immediately"):
		return
	var preview_subject := preview_wrapper.get_node_or_null("PreviewSubjectRoot/InterceptorMissileVisual") as Node3D
	if not T.require_true(self, preview_subject != null, "Missile Command battery contract must mount InterceptorMissileVisual under PreviewSubjectRoot in the wrapper scene"):
		return
	var preview_subject_state := await _wait_for_preview_subject_state(preview_subject)
	if not T.require_true(self, bool(preview_subject_state.get("preview_active", false)), "Missile Command battery contract must activate the interceptor preview behavior through the shared preview harness contract"):
		return
	if not T.require_true(self, bool(preview_subject_state.get("trail_visible", false)), "Missile Command battery contract must keep the interceptor tail flame visible in the shared wrapper preview mode"):
		return
	preview_wrapper.queue_free()
	await process_frame

	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for Missile Command battery contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Missile Command battery contract requires Player teleport API"):
		return
	var interceptor_visual := interceptor_visual_scene.instantiate() as Node3D
	if not T.require_true(self, interceptor_visual != null, "Missile Command battery contract must instantiate the interceptor visual scene as Node3D"):
		return
	root.add_child(interceptor_visual)
	await process_frame
	if not T.require_true(self, interceptor_visual.has_method("sync_motion_state"), "Missile Command interceptor visual scene must expose sync_motion_state() for runtime trail updates"):
		return
	if not T.require_true(self, interceptor_visual.has_method("get_debug_state"), "Missile Command interceptor visual scene must expose get_debug_state() for standalone preview debugging"):
		return
	if not T.require_true(self, interceptor_visual.has_method("get_scene_preview_contract"), "Missile Command interceptor visual scene must expose get_scene_preview_contract() for the shared wrapper preview harness"):
		return
	if not T.require_true(self, interceptor_visual.has_method("set_scene_preview_active"), "Missile Command interceptor visual scene must expose set_scene_preview_active() for the shared wrapper preview harness"):
		return
	if not T.require_true(self, interceptor_visual.get_node_or_null("TrailVisual") != null, "Missile Command interceptor visual scene must include a concrete TrailVisual node for authored tail-flame tuning"):
		return
	if not T.require_true(self, interceptor_visual.get_node_or_null("TrailVisualCross") != null, "Missile Command interceptor visual scene must include a second crossed tail-flame plane so the flame does not collapse into a single flat sheet"):
		return
	var trail_visual := interceptor_visual.get_node_or_null("TrailVisual") as MeshInstance3D
	if not T.require_true(self, trail_visual != null and trail_visual.material_override is ShaderMaterial, "Missile Command interceptor visual scene must drive the tail flame with a ShaderMaterial instead of a glowing box material"):
		return
	if not T.require_true(self, interceptor_visual.get_node_or_null("PreviewCamera") == null, "Missile Command interceptor visual scene must migrate preview camera ownership into the shared harness instead of embedding PreviewCamera on the subject scene"):
		return
	if not T.require_true(self, interceptor_visual.get_node_or_null("PreviewLight") == null, "Missile Command interceptor visual scene must migrate preview light ownership into the shared harness instead of embedding PreviewLight on the subject scene"):
		return
	interceptor_visual.sync_motion_state(Vector3.ZERO, Vector3.FORWARD, 18.0, true)
	await process_frame
	var interceptor_debug_state := interceptor_visual.get_debug_state() as Dictionary
	if not T.require_true(self, bool(interceptor_debug_state.get("trail_visible", false)), "Missile Command interceptor visual scene must light the trail while sync_motion_state reports a fast active missile"):
		return
	interceptor_visual.queue_free()

	player.teleport_to_world_position(WORLD_POSITION + Vector3(0.0, 2.0, 12.0))
	var mounted_venue: Node3D = await _wait_for_mounted_venue(world)
	if not T.require_true(self, mounted_venue != null, "Missile Command battery contract must mount the v29 venue in chunk_183_152"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_missile_command_contract"), "Missile Command battery contract requires get_missile_command_contract() on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_match_start_contract"), "Missile Command battery contract requires get_match_start_contract() on the mounted venue"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_scoreboard_contract"), "Missile Command battery contract requires get_scoreboard_contract() on the mounted venue"):
		return

	var battery_contract: Dictionary = mounted_venue.get_missile_command_contract()
	if not T.require_true(self, str(battery_contract.get("venue_id", "")) == VENUE_ID, "Missile Command battery contract must preserve the formal venue_id"):
		return
	if not T.require_true(self, str(battery_contract.get("game_kind", "")) == "missile_command_battery", "Missile Command battery contract must preserve game_kind = missile_command_battery"):
		return
	if not T.require_true(self, battery_contract.get("gameplay_plane_origin", null) is Vector3, "Missile Command battery contract must expose gameplay_plane_origin as Vector3"):
		return
	if not T.require_true(self, float(battery_contract.get("gameplay_plane_half_width_m", 0.0)) >= 28.0, "Missile Command battery contract must expose a formally sized gameplay plane width"):
		return
	if not T.require_true(self, float(battery_contract.get("gameplay_plane_height_m", 0.0)) >= 42.0, "Missile Command battery contract must expose a formally sized gameplay plane height"):
		return
	if not T.require_true(self, battery_contract.get("camera_world_position", null) is Vector3, "Missile Command battery contract must expose camera_world_position as Vector3"):
		return
	if not T.require_true(self, battery_contract.get("camera_look_target", null) is Vector3, "Missile Command battery contract must expose camera_look_target as Vector3"):
		return
	var gameplay_plane_origin := battery_contract.get("gameplay_plane_origin", Vector3.ZERO) as Vector3
	var camera_look_target := battery_contract.get("camera_look_target", Vector3.ZERO) as Vector3
	var gameplay_plane_height_m := float(battery_contract.get("gameplay_plane_height_m", 0.0))
	if not T.require_true(self, camera_look_target.y >= gameplay_plane_origin.y + gameplay_plane_height_m * 0.12, "Missile Command battery contract must aim the tower cameras high enough to see the authored gameplay plane sky lane instead of the ground scenery"):
		return
	var silo_ids: Array = battery_contract.get("silo_ids", [])
	if not T.require_true(self, silo_ids.size() == 3, "Missile Command battery contract must freeze exactly three launch silos in v29"):
		return
	var city_ids: Array = battery_contract.get("city_ids", [])
	if not T.require_true(self, city_ids.size() == 3, "Missile Command battery contract must freeze exactly three defended city targets in v29"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_silo_camera"), "Missile Command battery contract requires authored silo camera lookup"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_silo_camera_pivot"), "Missile Command battery contract requires authored silo camera pivot lookup"):
		return
	if not T.require_true(self, mounted_venue.has_method("get_silo_camera_look_target"), "Missile Command battery contract requires authored silo camera look target lookup"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("GameplayPlaneAnchor") != null, "Missile Command battery contract requires an authored GameplayPlaneAnchor node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Left") != null, "Missile Command battery contract requires an authored left launch silo anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Left/ViewPivot") != null, "Missile Command battery contract requires an authored left silo ViewPivot node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Left/ViewPivot/ViewCamera") != null, "Missile Command battery contract requires an authored left silo ViewCamera node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Left/ViewLookTarget") != null, "Missile Command battery contract requires an authored left silo ViewLookTarget node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Left/LaunchAnchor") != null, "Missile Command battery contract requires an authored left silo LaunchAnchor node"):
		return
	if not T.require_true(self, mounted_venue.get_silo_camera("silo_left") != null, "Missile Command battery contract requires left silo camera resolution through the venue API"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Center") != null, "Missile Command battery contract requires an authored center launch silo anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Center/ViewPivot") != null, "Missile Command battery contract requires an authored center silo ViewPivot node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Center/ViewPivot/ViewCamera") != null, "Missile Command battery contract requires an authored center silo ViewCamera node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Center/ViewLookTarget") != null, "Missile Command battery contract requires an authored center silo ViewLookTarget node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Center/LaunchAnchor") != null, "Missile Command battery contract requires an authored center silo LaunchAnchor node"):
		return
	if not T.require_true(self, mounted_venue.get_silo_camera("silo_center") != null, "Missile Command battery contract requires center silo camera resolution through the venue API"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Right") != null, "Missile Command battery contract requires an authored right launch silo anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Right/ViewPivot") != null, "Missile Command battery contract requires an authored right silo ViewPivot node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Right/ViewPivot/ViewCamera") != null, "Missile Command battery contract requires an authored right silo ViewCamera node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Right/ViewLookTarget") != null, "Missile Command battery contract requires an authored right silo ViewLookTarget node"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("LaunchSilos/Right/LaunchAnchor") != null, "Missile Command battery contract requires an authored right silo LaunchAnchor node"):
		return
	if not T.require_true(self, mounted_venue.get_silo_camera("silo_right") != null, "Missile Command battery contract requires right silo camera resolution through the venue API"):
		return
	for silo_id_variant in silo_ids:
		var silo_id := str(silo_id_variant)
		var silo_contract: Dictionary = (battery_contract.get("silos", {}) as Dictionary).get(silo_id, {})
		var silo_world_position := silo_contract.get("world_position", Vector3.ZERO) as Vector3
		var launch_world_position := silo_contract.get("launch_world_position", Vector3.ZERO) as Vector3
		if not T.require_true(self, launch_world_position.y >= silo_world_position.y + 20.0, "Missile Command battery contract must place launch_world_position at the authored tower muzzle instead of near the ground"):
			return
	if not T.require_true(self, mounted_venue.get_node_or_null("CityTargets/Left") != null, "Missile Command battery contract requires an authored left city target anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("CityTargets/Center") != null, "Missile Command battery contract requires an authored center city target anchor"):
		return
	if not T.require_true(self, mounted_venue.get_node_or_null("CityTargets/Right") != null, "Missile Command battery contract requires an authored right city target anchor"):
		return
	var start_contract: Dictionary = mounted_venue.get_match_start_contract()
	if not T.require_true(self, bool(start_contract.get("visible", false)), "Missile Command battery contract must expose a visible start ring while idle"):
		return
	if not T.require_true(self, start_contract.get("world_position", null) is Vector3, "Missile Command battery contract must expose start ring world_position as Vector3"):
		return
	if not T.require_true(self, float(start_contract.get("trigger_radius_m", 0.0)) >= 3.0, "Missile Command battery contract must expose a practical trigger radius for entering battery mode"):
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

func _wait_for_preview_subject_state(preview_subject: Node3D) -> Dictionary:
	for _frame in range(90):
		await process_frame
		if not preview_subject.has_method("get_debug_state"):
			break
		var debug_state := preview_subject.get_debug_state() as Dictionary
		if bool(debug_state.get("preview_active", false)) and bool(debug_state.get("trail_visible", false)):
			return debug_state
	return preview_subject.get_debug_state() as Dictionary if preview_subject.has_method("get_debug_state") else {}
