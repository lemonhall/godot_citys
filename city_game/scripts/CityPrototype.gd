extends Node3D

const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkStreamer := preload("res://city_game/world/streaming/CityChunkStreamer.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const CityChunkNavRuntime := preload("res://city_game/world/navigation/CityChunkNavRuntime.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityChunkGroundSampler := preload("res://city_game/world/rendering/CityChunkGroundSampler.gd")
const CityMinimapProjector := preload("res://city_game/world/map/CityMinimapProjector.gd")

const CONTROL_MODE_PLAYER := "player"
const CONTROL_MODE_INSPECTION := "inspection"

@onready var generated_city: Node = $GeneratedCity
@onready var hud: CanvasLayer = $Hud
@onready var player: Node3D = $Player
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var chunk_renderer: Node3D = $ChunkRenderer

var _world_config
var _world_data: Dictionary = {}
var _chunk_streamer
var _navigation_runtime
var _control_mode := CONTROL_MODE_PLAYER
var _minimap_projector
var _minimap_route_overlay: Dictionary = {}

func _ready() -> void:
	_configure_environment()
	_world_config = CityWorldConfig.new()
	_world_data = CityWorldGenerator.new().generate_world(_world_config)
	_chunk_streamer = CityChunkStreamer.new(_world_config, _world_data)
	_navigation_runtime = CityChunkNavRuntime.new(_world_config, _world_data)
	_minimap_projector = CityMinimapProjector.new(_world_config, _world_data)
	if chunk_renderer != null and chunk_renderer.has_method("setup"):
		chunk_renderer.setup(_world_config, _world_data)
	if debug_overlay != null:
		debug_overlay.visible = false
	_align_player_to_streamed_ground()
	if player != null and player.has_method("suspend_ground_stabilization"):
		player.suspend_ground_stabilization(24)

	set_control_mode(CONTROL_MODE_PLAYER)
	update_streaming_for_position(_get_active_anchor_position())
	_refresh_hud_status()

func _process(_delta: float) -> void:
	if player == null:
		return
	update_streaming_for_position(player.global_position)

func _unhandled_input(event: InputEvent) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_C:
			set_control_mode(CONTROL_MODE_INSPECTION if _control_mode == CONTROL_MODE_PLAYER else CONTROL_MODE_PLAYER)

func _refresh_hud_status(snapshot_override: Dictionary = {}) -> void:
	if not generated_city.has_method("get_city_summary"):
		return
	if not hud.has_method("set_status"):
		return

	var snapshot: Dictionary = snapshot_override.duplicate(true) if not snapshot_override.is_empty() else get_streaming_snapshot()
	var world_summary := str(_world_data.get("summary", "World data unavailable"))
	var active_speed_text := ""
	if player != null and player.has_method("get_walk_speed_mps") and player.has_method("get_sprint_speed_mps"):
		active_speed_text = "move_speed=%.1f / %.1f m/s" % [float(player.get_walk_speed_mps()), float(player.get_sprint_speed_mps())]
	var lines := PackedStringArray([
		"City sandbox skeleton",
		"WASD / arrows move",
		"Shift sprint  Space jump",
		"Mouse rotates player camera  Esc releases cursor",
		"Press C to toggle normal / inspection speed",
		"control_mode=%s" % _control_mode,
		"tracked_position=%s" % str(_vector3_to_dict(player.global_position if player != null else Vector3.ZERO)),
		generated_city.get_city_summary(),
		world_summary,
		"current_chunk_id=%s | active_chunk_count=%d" % [
			str(snapshot.get("current_chunk_id", "")),
			int(snapshot.get("active_chunk_count", 0))
		],
		"multimesh_instance_total=%d" % int(snapshot.get("multimesh_instance_total", 0)),
		"visual_variant=%s" % str(snapshot.get("current_chunk_visual_variant_id", "")),
		active_speed_text,
	])
	hud.set_status("\n".join(lines))
	if hud.has_method("set_debug_text") and debug_overlay != null and debug_overlay.has_method("get_debug_text"):
		hud.set_debug_text(debug_overlay.get_debug_text())
	if hud.has_method("set_minimap_snapshot"):
		hud.set_minimap_snapshot(build_minimap_snapshot())

func get_world_config():
	return _world_config

func get_world_data() -> Dictionary:
	return _world_data

func get_chunk_streamer():
	return _chunk_streamer

func get_chunk_renderer():
	return chunk_renderer

func get_navigation_runtime():
	return _navigation_runtime

func get_control_mode() -> String:
	return _control_mode

func set_control_mode(mode: String) -> void:
	if mode != CONTROL_MODE_PLAYER and mode != CONTROL_MODE_INSPECTION:
		return
	_control_mode = mode
	if player != null and player.has_method("set_control_enabled"):
		player.set_control_enabled(true)
	if player != null and player.has_method("set_speed_profile"):
		player.set_speed_profile(mode)
	_set_camera_current(player.get_node_or_null("CameraRig/Camera3D"), true)
	_refresh_hud_status()

func get_streaming_snapshot() -> Dictionary:
	if _chunk_streamer == null:
		return {}
	var snapshot: Dictionary = _chunk_streamer.get_streaming_snapshot()
	if chunk_renderer != null and chunk_renderer.has_method("get_renderer_stats"):
		snapshot.merge(chunk_renderer.get_renderer_stats(), true)
	snapshot["control_mode"] = _control_mode
	snapshot["tracked_position"] = _vector3_to_dict(player.global_position if player != null else Vector3.ZERO)
	var current_chunk_id := str(snapshot.get("current_chunk_id", ""))
	if current_chunk_id != "" and chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene_stats"):
		var current_chunk_stats: Dictionary = chunk_renderer.get_chunk_scene_stats(current_chunk_id)
		snapshot["current_chunk_multimesh_instance_count"] = int(current_chunk_stats.get("multimesh_instance_count", 0))
		snapshot["current_chunk_lod_mode"] = str(current_chunk_stats.get("lod_mode", ""))
		snapshot["current_chunk_visual_variant_id"] = str(current_chunk_stats.get("visual_variant_id", ""))
	return snapshot

func update_streaming_for_position(world_position: Vector3) -> Array:
	if _chunk_streamer == null:
		return []
	var events: Array = _chunk_streamer.update_for_world_position(world_position)
	if chunk_renderer != null and chunk_renderer.has_method("sync_streaming"):
		chunk_renderer.sync_streaming(_chunk_streamer.get_active_chunk_entries(), world_position)
	var snapshot: Dictionary = get_streaming_snapshot()
	if debug_overlay != null and debug_overlay.has_method("set_snapshot"):
		debug_overlay.set_snapshot(snapshot)
		debug_overlay.visible = false
	_refresh_hud_status(snapshot)
	return events

func plan_macro_route(start_position: Vector3, goal_position: Vector3) -> Array:
	if _navigation_runtime == null:
		return []
	return _navigation_runtime.plan_route(start_position, goal_position)

func build_runtime_report(subject_position = null) -> Dictionary:
	var snapshot: Dictionary = get_streaming_snapshot()
	var resolved_position := _get_active_anchor_position()
	if subject_position is Vector3:
		resolved_position = subject_position
	var transition_count := 0
	if _chunk_streamer != null:
		transition_count = _chunk_streamer.get_transition_log().size()
	return {
		"control_mode": _control_mode,
		"current_chunk_id": str(snapshot.get("current_chunk_id", "")),
		"active_chunk_count": int(snapshot.get("active_chunk_count", 0)),
		"last_prepare_usec": int(snapshot.get("last_prepare_usec", 0)),
		"last_mount_usec": int(snapshot.get("last_mount_usec", 0)),
		"last_retire_usec": int(snapshot.get("last_retire_usec", 0)),
		"transition_count": transition_count,
		"final_position": _vector3_to_dict(resolved_position),
		"lod_mode_counts": snapshot.get("lod_mode_counts", {}),
		"multimesh_instance_total": int(snapshot.get("multimesh_instance_total", 0)),
	}

func build_minimap_snapshot() -> Dictionary:
	if _minimap_projector == null:
		return {}
	var snapshot: Dictionary = _minimap_projector.build_snapshot(
		_get_active_anchor_position(),
		player.global_position if player != null else Vector3.ZERO,
		player.rotation.y if player != null else 0.0,
		[],
		1600.0
	)
	snapshot["route_overlay"] = _minimap_route_overlay.duplicate(true)
	return snapshot

func build_minimap_route_overlay(start_position: Vector3, goal_position: Vector3) -> Dictionary:
	if _minimap_projector == null:
		return {}
	var route: Array = plan_macro_route(start_position, goal_position)
	_minimap_route_overlay = _minimap_projector.build_route_overlay(_get_active_anchor_position(), start_position, goal_position, route, 1600.0)
	if hud != null and hud.has_method("set_minimap_snapshot"):
		hud.set_minimap_snapshot(build_minimap_snapshot())
	return _minimap_route_overlay.duplicate(true)

func _align_player_to_streamed_ground() -> void:
	if player == null or _world_config == null:
		return
	var initial_anchor := player.global_position
	var chunk_payload := _build_chunk_payload_for_world_position(initial_anchor)
	var profile := CityChunkProfileBuilder.build_profile(chunk_payload)
	var chunk_center: Vector3 = chunk_payload.get("chunk_center", Vector3.ZERO)
	var local_point := _resolve_spawn_local_point(chunk_payload, profile)
	var standing_height := _estimate_player_standing_height()
	var target_position := Vector3(
		chunk_center.x + local_point.x,
		CityChunkGroundSampler.sample_height(local_point, chunk_payload, profile) + standing_height + 0.7,
		chunk_center.z + local_point.y
	)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(target_position)
	else:
		player.global_position = target_position

func _snap_player_to_active_surface() -> bool:
	if player == null or get_world_3d() == null:
		return false
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return false
	var from := player.global_position + Vector3.UP * 12.0
	var to := player.global_position + Vector3.DOWN * 24.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var standing_height := _estimate_player_standing_height()
	var hit_position: Vector3 = hit.get("position", player.global_position)
	var target_position := Vector3(player.global_position.x, hit_position.y + standing_height, player.global_position.z)
	if player.has_method("teleport_to_world_position"):
		player.teleport_to_world_position(target_position)
	else:
		player.global_position = target_position
	return true

func _get_active_anchor_position() -> Vector3:
	return player.global_position if player != null else Vector3.ZERO

func _build_chunk_payload_for_world_position(world_position: Vector3) -> Dictionary:
	var chunk_key := CityChunkKey.world_to_chunk_key(_world_config, world_position)
	var bounds: Rect2 = _world_config.get_world_bounds()
	var chunk_center := Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(_world_config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(_world_config.chunk_size_m)
	)
	return {
		"chunk_id": _world_config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(_world_config.chunk_size_m),
		"chunk_seed": _world_config.derive_seed("render_chunk", chunk_key),
		"world_seed": int(_world_config.base_seed),
		"road_graph": _world_data.get("road_graph"),
	}

func _resolve_spawn_local_point(chunk_payload: Dictionary, profile: Dictionary) -> Vector2:
	var chunk_size := float(chunk_payload.get("chunk_size_m", 256.0))
	var half_extent := chunk_size * 0.5 - 24.0
	var best_point := Vector2.ZERO
	var best_score := -INF
	for local_x in range(-96, 97, 24):
		for local_z in range(-96, 97, 24):
			var candidate := Vector2(
				clampf(float(local_x), -half_extent, half_extent),
				clampf(float(local_z), -half_extent, half_extent)
			)
			var road_clearance := _distance_to_profile_roads(candidate, profile)
			var building_clearance := _distance_to_profile_buildings(candidate, profile)
			var center_penalty := candidate.length() * 0.08
			var score := minf(road_clearance, 48.0) + minf(building_clearance, 48.0) - center_penalty
			if score > best_score:
				best_score = score
				best_point = candidate
	return best_point

func _distance_to_profile_roads(local_point: Vector2, profile: Dictionary) -> float:
	var min_distance := INF
	for road_segment in profile.get("road_segments", []):
		var segment_dict: Dictionary = road_segment
		var width := float(segment_dict.get("width", 0.0))
		var points: Array = segment_dict.get("points", [])
		for point_index in range(points.size() - 1):
			var a: Vector3 = points[point_index]
			var b: Vector3 = points[point_index + 1]
			var distance := Geometry2D.get_closest_point_to_segment(local_point, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(local_point) - width * 0.5
			min_distance = minf(min_distance, distance)
	return 9999.0 if min_distance == INF else min_distance

func _distance_to_profile_buildings(local_point: Vector2, profile: Dictionary) -> float:
	var min_distance := INF
	for building in profile.get("buildings", []):
		var building_dict: Dictionary = building
		var center: Vector3 = building_dict.get("center", Vector3.ZERO)
		var radius := float(building_dict.get("visual_footprint_radius_m", building_dict.get("footprint_radius_m", 0.0)))
		min_distance = minf(min_distance, local_point.distance_to(Vector2(center.x, center.z)) - radius)
	return 9999.0 if min_distance == INF else min_distance

func _estimate_player_standing_height() -> float:
	if player == null:
		return 1.0
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

func _set_camera_current(camera_node: Node, current: bool) -> void:
	var camera := camera_node as Camera3D
	if camera != null:
		camera.current = current

func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {
		"x": snappedf(value.x, 0.01),
		"y": snappedf(value.y, 0.01),
		"z": snappedf(value.z, 0.01),
	}

func _configure_environment() -> void:
	if world_environment == null:
		return
	var environment := world_environment.environment
	if environment == null:
		environment = Environment.new()
		world_environment.environment = environment

	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.168627, 0.270588, 0.431373, 1.0)
	sky_material.sky_horizon_color = Color(0.580392, 0.737255, 0.839216, 1.0)
	sky_material.ground_horizon_color = Color(0.627451, 0.654902, 0.615686, 1.0)
	sky_material.ground_bottom_color = Color(0.137255, 0.164706, 0.145098, 1.0)
	sky_material.sky_curve = 0.22
	sky_material.ground_curve = 0.08
	sky_material.sun_angle_max = 18.0

	var sky := Sky.new()
	sky.sky_material = sky_material

	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.75
	environment.ambient_light_sky_contribution = 0.8
	environment.fog_enabled = true
	environment.fog_density = 0.00065
	environment.fog_aerial_perspective = 0.55
	environment.fog_light_color = Color(0.643137, 0.741176, 0.803922, 1.0)
	environment.fog_light_energy = 0.8
	environment.fog_sky_affect = 1.0
	environment.fog_sun_scatter = 0.18
