extends Node3D

const CityChunkMultimeshBuilder := preload("res://city_game/world/rendering/CityChunkMultimeshBuilder.gd")
const CityChunkHlodBuilder := preload("res://city_game/world/rendering/CityChunkHlodBuilder.gd")
const CityChunkOccluderBuilder := preload("res://city_game/world/rendering/CityChunkOccluderBuilder.gd")
const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")
const CityPedestrianCrowdRenderer := preload("res://city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd")
const CityVehicleTrafficRenderer := preload("res://city_game/world/vehicles/rendering/CityVehicleTrafficRenderer.gd")
const CityTerrainMeshBuilder := preload("res://city_game/world/rendering/CityTerrainMeshBuilder.gd")
const CityRoadMeshBuilder := preload("res://city_game/world/rendering/CityRoadMeshBuilder.gd")
const CityRoadMaskBuilder := preload("res://city_game/world/rendering/CityRoadMaskBuilder.gd")
const CityLakeBasinCarrierBuilder := preload("res://city_game/world/rendering/CityLakeBasinCarrierBuilder.gd")
const CityGroundRoadOverlayShader := preload("res://city_game/world/rendering/CityGroundRoadOverlay.gdshader")
const CityBuildingSceneBuilder := preload("res://city_game/world/serviceability/CityBuildingSceneBuilder.gd")
const CityDestructibleBuildingRuntime := preload("res://city_game/combat/buildings/CityDestructibleBuildingRuntime.gd")

const LOD_NEAR := "near"
const LOD_MID := "mid"
const LOD_FAR := "far"
const SURFACE_DETAIL_FULL := "full"
const SURFACE_DETAIL_COARSE := "coarse"

const NEAR_THRESHOLD_M := 880.0
const MID_THRESHOLD_M := 1600.0
const TERRAIN_GRID_STEPS := 12
const TERRAIN_GRID_STEPS_MID := 6
const TERRAIN_GRID_STEPS_FAR := 3
const FLAT_GROUND_GRID_STEPS := 1
const BUILDING_ORNAMENT_OVERLAP_M := 0.08

static var _shared_box_shape_cache: Dictionary = {}
static var _shared_box_mesh_cache: Dictionary = {}
static var _shared_box_material_cache: Dictionary = {}
static var _shared_building_override_scene_cache: Dictionary = {}
static var _shared_scene_landmark_scene_cache: Dictionary = {}
static var _shared_scene_interactive_prop_scene_cache: Dictionary = {}
static var _shared_scene_minigame_venue_scene_cache: Dictionary = {}
static var _shared_ground_overlay_material_template: ShaderMaterial = null
static var _shared_water_surface_material_template: StandardMaterial3D = null

var _chunk_data: Dictionary = {}
var _profile: Dictionary = {}
var _setup_profile: Dictionary = {}
var _current_lod_mode := LOD_NEAR
var _current_surface_detail_mode := SURFACE_DETAIL_FULL
var _current_terrain_collision_mode := ""
var _surface_page_contract: Dictionary = {}
var _terrain_page_contract: Dictionary = {}
var _terrain_mesh_results_by_lod: Dictionary = {}
var _building_collision_shapes: Array[CollisionShape3D] = []
var _building_collisions_enabled := true
var _terrain_mesh_apply_count := 0
var _terrain_collision_apply_count := 0
var _pedestrian_crowd: Node3D = null
var _vehicle_traffic: Node3D = null
var _bridge_proxy: Node3D = null
var _pedestrians_visible := true

func setup(chunk_data: Dictionary) -> void:
	var surface_page_provider = chunk_data.get("surface_page_provider")
	var surface_page_binding: Dictionary = chunk_data.get("surface_page_binding", {})
	var terrain_page_provider = chunk_data.get("terrain_page_provider")
	var terrain_page_binding: Dictionary = chunk_data.get("terrain_page_binding", {})
	_chunk_data = chunk_data.duplicate(false)
	if surface_page_provider != null:
		_chunk_data["surface_page_provider"] = surface_page_provider
	if not surface_page_binding.is_empty():
		_chunk_data["surface_page_binding"] = surface_page_binding
	if terrain_page_provider != null:
		_chunk_data["terrain_page_provider"] = terrain_page_provider
	if not terrain_page_binding.is_empty():
		_chunk_data["terrain_page_binding"] = terrain_page_binding
	_profile = (chunk_data.get("prepared_profile", {}) as Dictionary).duplicate(false)
	if _profile.is_empty():
		_profile = CityChunkProfileBuilder.build_profile(_chunk_data)
	_current_lod_mode = _normalize_lod_mode(str(_chunk_data.get("initial_lod_mode", LOD_NEAR)))
	_current_surface_detail_mode = _resolve_surface_detail_mode_for_lod(_current_lod_mode)
	name = str(_chunk_data.get("chunk_id", "ChunkScene"))
	position = _chunk_data.get("chunk_center", Vector3.ZERO)
	_rebuild()

static func prewarm_building_override_entries(entries: Dictionary) -> void:
	for entry_variant in entries.values():
		var entry: Dictionary = entry_variant
		var scene_path := str(entry.get("scene_path", ""))
		if scene_path == "":
			continue
		var packed_scene := _load_cached_building_override_scene(scene_path)
		if packed_scene == null:
			continue
		var preview_instance: Variant = packed_scene.instantiate()
		if preview_instance is Node:
			(preview_instance as Node).free()

static func prewarm_scene_landmark_entries(entries: Dictionary) -> void:
	for entry_variant in entries.values():
		var entry: Dictionary = entry_variant
		var scene_path := str(entry.get("scene_path", ""))
		if scene_path == "":
			continue
		var packed_scene := _load_cached_scene_landmark_scene(scene_path)
		if packed_scene == null:
			continue
		var preview_instance: Variant = packed_scene.instantiate()
		if preview_instance is Node:
			(preview_instance as Node).free()

static func prewarm_ground_overlay_material() -> void:
	if _shared_ground_overlay_material_template != null:
		return
	var material := ShaderMaterial.new()
	material.shader = CityGroundRoadOverlayShader
	material.set_shader_parameter("chunk_size_m", 256.0)
	material.set_shader_parameter("ground_color", Color(0.12549, 0.333333, 0.168627, 1.0))
	material.set_shader_parameter("road_color", Color(0.16, 0.17, 0.19, 1.0))
	material.set_shader_parameter("stripe_color", Color(0.9, 0.8, 0.5, 1.0))
	material.set_shader_parameter("stripe_enabled", true)
	material.set_shader_parameter("surface_uv_offset", Vector2.ZERO)
	material.set_shader_parameter("surface_uv_scale", Vector2.ONE)
	_shared_ground_overlay_material_template = material

static func _instantiate_ground_overlay_material() -> ShaderMaterial:
	prewarm_ground_overlay_material()
	if _shared_ground_overlay_material_template != null:
		var duplicated_material := _shared_ground_overlay_material_template.duplicate()
		if duplicated_material is ShaderMaterial:
			return duplicated_material as ShaderMaterial
	var material := ShaderMaterial.new()
	material.shader = CityGroundRoadOverlayShader
	return material

func set_lod_mode(mode: String) -> void:
	var normalized_mode := _normalize_lod_mode(mode)
	var target_surface_detail_mode := _resolve_surface_detail_mode_for_lod(normalized_mode)
	var near_group := get_node_or_null("NearGroup") as Node3D
	var mid_proxy := get_node_or_null("MidProxy") as Node3D
	var far_proxy := get_node_or_null("FarProxy") as Node3D
	var near_visibility_matches := near_group == null or near_group.visible == (normalized_mode == LOD_NEAR)
	var mid_visibility_matches := mid_proxy == null or mid_proxy.visible == (normalized_mode == LOD_MID)
	var far_visibility_matches := far_proxy == null or far_proxy.visible == (normalized_mode == LOD_FAR)
	if normalized_mode == _current_lod_mode \
		and target_surface_detail_mode == _current_surface_detail_mode \
		and near_visibility_matches \
		and mid_visibility_matches \
		and far_visibility_matches \
		and (normalized_mode != LOD_NEAR or near_group != null):
		return
	if normalized_mode == LOD_NEAR and near_group == null:
		_build_near_group()
		near_group = get_node_or_null("NearGroup") as Node3D
	if target_surface_detail_mode != _current_surface_detail_mode:
		_apply_ground_surface_detail_mode(target_surface_detail_mode)
	_current_lod_mode = normalized_mode
	_apply_terrain_lod_mode(normalized_mode)
	_apply_terrain_collision_mode(normalized_mode)
	mid_proxy = get_node_or_null("MidProxy") as Node3D
	far_proxy = get_node_or_null("FarProxy") as Node3D
	if near_group != null:
		near_group.visible = normalized_mode == LOD_NEAR
	if _bridge_proxy != null:
		_bridge_proxy.visible = normalized_mode != LOD_NEAR
	if mid_proxy != null:
		mid_proxy.visible = normalized_mode == LOD_MID
	if far_proxy != null:
		far_proxy.visible = normalized_mode == LOD_FAR
	_set_building_collisions_enabled(normalized_mode == LOD_NEAR)

func update_lod_for_distance(distance_m: float) -> void:
	if distance_m < NEAR_THRESHOLD_M:
		set_lod_mode(LOD_NEAR)
	elif distance_m < MID_THRESHOLD_M:
		set_lod_mode(LOD_MID)
	else:
		set_lod_mode(LOD_FAR)

func get_current_lod_mode() -> String:
	return _current_lod_mode

func get_profile_signature() -> String:
	return str(_profile.get("signature", ""))

func get_setup_profile() -> Dictionary:
	return _setup_profile.duplicate(true)

func get_surface_page_contract() -> Dictionary:
	return _surface_page_contract.duplicate(true)

func get_terrain_page_contract() -> Dictionary:
	return _terrain_page_contract.duplicate(true)

func get_terrain_lod_contract() -> Dictionary:
	_ensure_all_terrain_lod_mesh_results()
	var modes := {}
	for lod_mode in _terrain_mesh_results_by_lod.keys():
		var mesh_result: Dictionary = _terrain_mesh_results_by_lod[lod_mode]
		var sample_stats: Dictionary = mesh_result.get("sample_stats", {})
		modes[str(lod_mode)] = {
			"grid_steps": int(mesh_result.get("grid_steps", 0)),
			"vertex_count": int(sample_stats.get("current_vertex_sample_count", 0)),
		}
	var current_result: Dictionary = _terrain_mesh_results_by_lod.get(_current_lod_mode, {})
	var current_sample_stats: Dictionary = current_result.get("sample_stats", {})
	return {
		"current_mode": _current_lod_mode,
		"current_grid_steps": int(current_result.get("grid_steps", 0)),
		"current_vertex_count": int(current_sample_stats.get("current_vertex_sample_count", 0)),
		"modes": modes,
	}

func get_terrain_lod_debug_stats() -> Dictionary:
	var built_mesh_modes: Array[String] = []
	for lod_mode in _terrain_mesh_results_by_lod.keys():
		built_mesh_modes.append(str(lod_mode))
	built_mesh_modes.sort()
	return {
		"mesh_apply_count": _terrain_mesh_apply_count,
		"collision_apply_count": _terrain_collision_apply_count,
		"built_mesh_modes": built_mesh_modes,
	}

func get_visual_variant_id() -> String:
	return str(_profile.get("variant_id", ""))

func get_lod_signature(_mode: String) -> String:
	return get_profile_signature()

func get_lod_contract() -> Dictionary:
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
		"variant_id": get_visual_variant_id(),
		"profile_signature": get_profile_signature(),
		"modes": [LOD_NEAR, LOD_MID, LOD_FAR],
		"near_threshold_m": NEAR_THRESHOLD_M,
		"mid_threshold_m": MID_THRESHOLD_M,
	}

func get_prop_multimesh() -> MultiMeshInstance3D:
	return get_node_or_null("NearGroup/Props/StreetLamps") as MultiMeshInstance3D

func get_ground_body() -> StaticBody3D:
	return get_node_or_null("GroundBody") as StaticBody3D

func get_road_boundary_connectors() -> Dictionary:
	return (_profile.get("road_boundary_connectors", {}) as Dictionary).duplicate(true)

func get_building_collision_shape_count() -> int:
	return _building_collision_shapes.size()

func are_building_collisions_enabled() -> bool:
	return _building_collisions_enabled

func get_terrain_relief_m() -> float:
	return float(_profile.get("terrain_relief_m", 0.0))

func get_building_count() -> int:
	return int(_profile.get("building_count", 0))

func get_building_archetype_ids() -> Array:
	return (_profile.get("building_archetype_ids", []) as Array).duplicate()

func get_building_generation_contract(building_id: String) -> Dictionary:
	if building_id == "":
		return {}
	for building_variant in _profile.get("buildings", []):
		var building: Dictionary = building_variant
		if str(building.get("building_id", "")) == building_id:
			return building.duplicate(true)
	return {}

func find_building_override_node(building_id: String) -> Node:
	if building_id == "":
		return null
	var near_group := get_node_or_null("NearGroup") as Node
	if near_group == null:
		return null
	return _find_building_override_node_recursive(near_group, building_id)

func find_scene_landmark_node(landmark_id: String) -> Node:
	if landmark_id == "":
		return null
	var near_group := get_node_or_null("NearGroup") as Node
	if near_group == null:
		return null
	return _find_scene_landmark_node_recursive(near_group, landmark_id)

func find_scene_interactive_prop_node(prop_id: String) -> Node:
	if prop_id == "":
		return null
	var near_group := get_node_or_null("NearGroup") as Node
	if near_group == null:
		return null
	return _find_scene_interactive_prop_node_recursive(near_group, prop_id)

func find_scene_minigame_venue_node(venue_id: String) -> Node:
	if venue_id == "":
		return null
	var near_group := get_node_or_null("NearGroup") as Node
	if near_group == null:
		return null
	return _find_scene_minigame_venue_node_recursive(near_group, venue_id)

func get_road_collision_shape_count() -> int:
	var road_overlay := get_node_or_null("NearGroup/RoadOverlay") as Node
	if road_overlay != null and road_overlay.has_meta("road_collision_shape_count"):
		return int(road_overlay.get_meta("road_collision_shape_count"))
	return 0

func get_bridge_collision_shape_count() -> int:
	var road_overlay := get_node_or_null("NearGroup/RoadOverlay") as Node
	if road_overlay != null and road_overlay.has_meta("bridge_collision_shape_count"):
		return int(road_overlay.get_meta("bridge_collision_shape_count"))
	return 0

func get_bridge_min_clearance_m() -> float:
	return float(_profile.get("bridge_min_clearance_m", 0.0))

func get_bridge_deck_thickness_m() -> float:
	return float(_profile.get("bridge_deck_thickness_m", 0.0))

func get_min_building_road_clearance_m() -> float:
	return float(_profile.get("min_building_road_clearance_m", 0.0))

func get_min_prop_road_clearance_m() -> float:
	var prop_multimesh := get_prop_multimesh()
	if prop_multimesh != null and prop_multimesh.has_meta("min_road_clearance_m"):
		return float(prop_multimesh.get_meta("min_road_clearance_m"))
	return 0.0

func get_road_runtime_guard_stats() -> Dictionary:
	var stats := {
		"road_overlay_child_count": 0,
		"render_mesh_instance_count": 0,
		"render_multimesh_instance_count": 0,
		"path3d_count": 0,
		"forbidden_runtime_node_count": 0,
	}
	var road_overlay := get_node_or_null("NearGroup/RoadOverlay") as Node
	if road_overlay == null:
		return stats
	stats["road_overlay_child_count"] = road_overlay.get_child_count()
	_accumulate_road_runtime_guard_stats(road_overlay, stats)
	return stats

func get_vehicle_runtime_guard_stats() -> Dictionary:
	var stats := {
		"vehicle_root_child_count": 0,
		"farfield_multimesh_instance_count": 0,
		"tier2_node_count": 0,
		"tier3_node_count": 0,
		"path3d_count": 0,
		"forbidden_runtime_node_count": 0,
	}
	var vehicle_root := get_node_or_null("VehicleTraffic") as Node
	if vehicle_root == null:
		return stats
	stats["vehicle_root_child_count"] = vehicle_root.get_child_count()
	var vehicle_stats := get_vehicle_stats()
	stats["farfield_multimesh_instance_count"] = 1 if int(vehicle_stats.get("tier1_instance_count", 0)) > 0 else 0
	stats["tier2_node_count"] = int(vehicle_stats.get("tier2_node_count", 0))
	stats["tier3_node_count"] = int(vehicle_stats.get("tier3_node_count", 0))
	_accumulate_vehicle_runtime_guard_stats(vehicle_root, stats)
	return stats

func _accumulate_vehicle_runtime_guard_stats(root: Node, stats: Dictionary) -> void:
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var is_forbidden_runtime_node := false
		if child_node is Path3D:
			stats["path3d_count"] = int(stats.get("path3d_count", 0)) + 1
			is_forbidden_runtime_node = true
		var normalized_name := String(child_node.name).to_lower()
		if normalized_name.begins_with("vehiclelane") or normalized_name.begins_with("vehiclesegment") or normalized_name.begins_with("vehiclemanager"):
			is_forbidden_runtime_node = true
		if is_forbidden_runtime_node:
			stats["forbidden_runtime_node_count"] = int(stats.get("forbidden_runtime_node_count", 0)) + 1
		_accumulate_vehicle_runtime_guard_stats(child_node, stats)

func _accumulate_road_runtime_guard_stats(root: Node, stats: Dictionary) -> void:
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		if child_node is MeshInstance3D:
			stats["render_mesh_instance_count"] = int(stats.get("render_mesh_instance_count", 0)) + 1
		elif child_node is MultiMeshInstance3D:
			stats["render_multimesh_instance_count"] = int(stats.get("render_multimesh_instance_count", 0)) + 1
		var is_forbidden_runtime_node := false
		if child_node is Path3D:
			stats["path3d_count"] = int(stats.get("path3d_count", 0)) + 1
			is_forbidden_runtime_node = true
		var normalized_name := String(child_node.name).to_lower()
		if normalized_name.begins_with("roadlane") or normalized_name.begins_with("roadsegment") or normalized_name.begins_with("roadintersection") or normalized_name.begins_with("roadmanager"):
			is_forbidden_runtime_node = true
		if is_forbidden_runtime_node:
			stats["forbidden_runtime_node_count"] = int(stats.get("forbidden_runtime_node_count", 0)) + 1
		_accumulate_road_runtime_guard_stats(child_node, stats)

func get_renderer_stats() -> Dictionary:
	var prop_multimesh := get_prop_multimesh()
	var near_group := get_node_or_null("NearGroup") as Node3D
	var terrain_lod_contract := get_terrain_lod_contract()
	var pedestrian_crowd_stats := get_pedestrian_crowd_stats()
	var road_runtime_guard_stats := get_road_runtime_guard_stats()
	var vehicle_stats := get_vehicle_stats()
	var vehicle_runtime_guard_stats := get_vehicle_runtime_guard_stats()
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
		"lod_mode": _current_lod_mode,
		"visual_variant_id": get_visual_variant_id(),
		"profile_signature": get_profile_signature(),
		"setup_profile": get_setup_profile(),
		"multimesh_instance_count": prop_multimesh.multimesh.instance_count if prop_multimesh != null else 0,
		"near_child_count": near_group.get_child_count() if near_group != null else 0,
		"road_segment_count": (_profile.get("road_segments", []) as Array).size(),
		"curved_road_segment_count": int(_profile.get("curved_road_segment_count", 0)),
		"non_axis_road_segment_count": int(_profile.get("non_axis_road_segment_count", 0)),
		"bridge_count": int(_profile.get("bridge_count", 0)),
		"road_mesh_mode": str(_profile.get("road_mesh_mode", "ribbon")),
		"road_template_counts": (_profile.get("road_template_counts", {}) as Dictionary).duplicate(true),
		"road_runtime_guard_stats": road_runtime_guard_stats.duplicate(true),
		"road_collision_shape_count": get_road_collision_shape_count(),
		"bridge_collision_shape_count": get_bridge_collision_shape_count(),
		"bridge_min_clearance_m": get_bridge_min_clearance_m(),
		"bridge_deck_thickness_m": get_bridge_deck_thickness_m(),
		"terrain_relief_m": get_terrain_relief_m(),
		"building_collision_shape_count": get_building_collision_shape_count(),
		"building_count": get_building_count(),
		"surface_page_key": _surface_page_contract.get("page_key", Vector2i.ZERO),
		"terrain_page_key": _terrain_page_contract.get("page_key", Vector2i.ZERO),
		"terrain_current_grid_steps": int(terrain_lod_contract.get("current_grid_steps", 0)),
		"terrain_current_vertex_count": int(terrain_lod_contract.get("current_vertex_count", 0)),
		"terrain_lod_contract": terrain_lod_contract,
		"pedestrian_tier1_count": int(pedestrian_crowd_stats.get("tier1_count", 0)),
		"pedestrian_tier2_count": int(pedestrian_crowd_stats.get("tier2_count", 0)),
		"pedestrian_tier3_count": int(pedestrian_crowd_stats.get("tier3_count", 0)),
		"pedestrian_multimesh_instance_count": int(pedestrian_crowd_stats.get("tier1_instance_count", 0)),
		"vehicle_tier1_count": int(vehicle_stats.get("tier1_count", 0)),
		"vehicle_tier2_count": int(vehicle_stats.get("tier2_count", 0)),
		"vehicle_tier3_count": int(vehicle_stats.get("tier3_count", 0)),
		"vehicle_multimesh_instance_count": int(vehicle_stats.get("tier1_instance_count", 0)),
		"vehicle_runtime_guard_stats": vehicle_runtime_guard_stats.duplicate(true),
	}

func get_runtime_renderer_stats() -> Dictionary:
	var prop_multimesh := get_prop_multimesh()
	var pedestrian_crowd_stats := get_pedestrian_crowd_stats()
	var road_runtime_guard_stats := get_road_runtime_guard_stats()
	var vehicle_stats := get_vehicle_stats()
	var vehicle_runtime_guard_stats := get_vehicle_runtime_guard_stats()
	return {
		"chunk_id": str(_chunk_data.get("chunk_id", "")),
		"lod_mode": _current_lod_mode,
		"visual_variant_id": get_visual_variant_id(),
		"multimesh_instance_count": prop_multimesh.multimesh.instance_count if prop_multimesh != null and prop_multimesh.multimesh != null else 0,
		"road_segment_count": (_profile.get("road_segments", []) as Array).size(),
		"road_runtime_guard_stats": road_runtime_guard_stats.duplicate(true),
		"pedestrian_tier1_count": int(pedestrian_crowd_stats.get("tier1_count", 0)),
		"pedestrian_tier2_count": int(pedestrian_crowd_stats.get("tier2_count", 0)),
		"pedestrian_tier3_count": int(pedestrian_crowd_stats.get("tier3_count", 0)),
		"pedestrian_multimesh_instance_count": int(pedestrian_crowd_stats.get("tier1_instance_count", 0)),
		"vehicle_tier1_count": int(vehicle_stats.get("tier1_count", 0)),
		"vehicle_tier2_count": int(vehicle_stats.get("tier2_count", 0)),
		"vehicle_tier3_count": int(vehicle_stats.get("tier3_count", 0)),
		"vehicle_multimesh_instance_count": int(vehicle_stats.get("tier1_instance_count", 0)),
		"vehicle_runtime_guard_stats": vehicle_runtime_guard_stats.duplicate(true),
	}

func get_pedestrian_batch() -> MultiMeshInstance3D:
	if _pedestrian_crowd == null or not _pedestrian_crowd.has_method("get_batch"):
		return null
	return _pedestrian_crowd.get_batch()

func get_pedestrian_crowd_stats() -> Dictionary:
	if _pedestrian_crowd == null or not _pedestrian_crowd.has_method("get_crowd_stats"):
		return {
			"tier0_count": 0,
			"tier1_count": 0,
			"tier2_count": 0,
			"tier3_count": 0,
			"tier1_instance_count": 0,
			"tier1_transform_write_count": 0,
			"visible": _pedestrians_visible,
		}
	var crowd_stats: Dictionary = (_pedestrian_crowd.get_crowd_stats() as Dictionary).duplicate(true)
	crowd_stats["visible"] = _pedestrians_visible
	return crowd_stats

func get_vehicle_batch() -> MultiMeshInstance3D:
	if _vehicle_traffic == null or not _vehicle_traffic.has_method("get_batch"):
		return null
	return _vehicle_traffic.get_batch()

func get_vehicle_stats() -> Dictionary:
	if _vehicle_traffic == null or not _vehicle_traffic.has_method("get_vehicle_stats"):
		return {
			"tier0_count": 0,
			"tier1_count": 0,
			"tier2_count": 0,
			"tier3_count": 0,
			"tier1_instance_count": 0,
			"tier1_transform_write_count": 0,
			"tier2_node_count": 0,
			"tier3_node_count": 0,
		}
	return (_vehicle_traffic.get_vehicle_stats() as Dictionary).duplicate(true)

func apply_pedestrian_chunk_snapshot(snapshot: Dictionary) -> int:
	if _pedestrian_crowd == null or not _pedestrian_crowd.has_method("apply_chunk_snapshot"):
		return 0
	return _pedestrian_crowd.apply_chunk_snapshot(snapshot)

func apply_vehicle_chunk_snapshot(snapshot: Dictionary) -> int:
	if _vehicle_traffic == null or not _vehicle_traffic.has_method("apply_chunk_snapshot"):
		return 0
	return _vehicle_traffic.apply_chunk_snapshot(snapshot)

func spawn_pedestrian_death_visual(event: Dictionary) -> void:
	if _pedestrian_crowd == null or not _pedestrian_crowd.has_method("spawn_pedestrian_death_visual"):
		return
	_pedestrian_crowd.spawn_pedestrian_death_visual(event)

func remove_nearfield_pedestrian_visual(pedestrian_id: String) -> bool:
	if _pedestrian_crowd == null or not _pedestrian_crowd.has_method("remove_nearfield_pedestrian_visual"):
		return false
	return bool(_pedestrian_crowd.remove_nearfield_pedestrian_visual(pedestrian_id))

func drain_pedestrian_death_visuals(target_parent: Node3D) -> Array[Dictionary]:
	if _pedestrian_crowd == null or not _pedestrian_crowd.has_method("drain_death_visuals"):
		return []
	return _pedestrian_crowd.drain_death_visuals(target_parent)

func set_pedestrian_visibility(should_be_visible: bool) -> void:
	if _pedestrians_visible == should_be_visible:
		return
	_pedestrians_visible = should_be_visible
	if _pedestrian_crowd != null:
		_pedestrian_crowd.visible = should_be_visible

func are_pedestrians_visible() -> bool:
	return _pedestrians_visible

func _rebuild() -> void:
	var rebuild_started_usec := Time.get_ticks_usec()
	for child in get_children():
		remove_child(child)
		child.free()
	_building_collision_shapes.clear()
	_terrain_mesh_apply_count = 0
	_terrain_collision_apply_count = 0
	_pedestrian_crowd = null
	_vehicle_traffic = null
	_bridge_proxy = null

	var chunk_size_m := float(_chunk_data.get("chunk_size_m", 256.0))
	var setup_profile := {
		"ground_usec": 0,
		"ground_mesh_usec": 0,
		"ground_collision_usec": 0,
		"ground_collision_face_count": 0,
		"ground_material_usec": 0,
		"ground_mask_textures_usec": 0,
		"ground_mask_cache_hit": false,
		"ground_mask_cache_load_usec": 0,
		"ground_mask_cache_write_usec": 0,
		"ground_shader_material_usec": 0,
		"road_overlay_usec": 0,
		"buildings_usec": 0,
		"props_usec": 0,
		"proxies_usec": 0,
		"occluder_usec": 0,
		"set_lod_usec": 0,
	}

	var phase_started_usec := Time.get_ticks_usec()
	var ground_result := _build_ground_body(chunk_size_m, _profile)
	add_child(ground_result.get("body"))
	setup_profile["ground_usec"] = Time.get_ticks_usec() - phase_started_usec
	setup_profile["ground_mesh_usec"] = int(ground_result.get("mesh_usec", 0))
	setup_profile["ground_collision_usec"] = int(ground_result.get("collision_usec", 0))
	setup_profile["ground_collision_face_count"] = int(ground_result.get("collision_face_count", 0))
	setup_profile["ground_material_usec"] = int(ground_result.get("material_usec", 0))
	setup_profile["ground_mask_textures_usec"] = int(ground_result.get("mask_textures_usec", 0))
	setup_profile["ground_mask_cache_hit"] = bool(ground_result.get("mask_cache_hit", false))
	setup_profile["ground_mask_cache_load_usec"] = int(ground_result.get("mask_cache_load_usec", 0))
	setup_profile["ground_mask_cache_write_usec"] = int(ground_result.get("mask_cache_write_usec", 0))
	setup_profile["ground_shader_material_usec"] = int(ground_result.get("shader_material_usec", 0))
	setup_profile["ground_vertex_sample_count"] = int(ground_result.get("vertex_sample_count", 0))
	setup_profile["ground_unique_vertex_count"] = int(ground_result.get("unique_vertex_count", 0))
	setup_profile["ground_duplication_ratio"] = float(ground_result.get("duplication_ratio", 0.0))
	setup_profile["ground_runtime_page_hit"] = bool(ground_result.get("runtime_page_hit", false))

	if _current_lod_mode == LOD_NEAR:
		var near_build_stats := _build_near_group()
		setup_profile["road_overlay_usec"] = int(near_build_stats.get("road_overlay_usec", 0))
		setup_profile["buildings_usec"] = int(near_build_stats.get("buildings_usec", 0))
		setup_profile["props_usec"] = int(near_build_stats.get("props_usec", 0))
	_bridge_proxy = CityRoadMeshBuilder.build_bridge_proxy(_profile, _chunk_data)
	if _bridge_proxy != null:
		_bridge_proxy.visible = _current_lod_mode != LOD_NEAR
		add_child(_bridge_proxy)

	phase_started_usec = Time.get_ticks_usec()
	_pedestrian_crowd = CityPedestrianCrowdRenderer.new()
	_pedestrian_crowd.name = "PedestrianCrowd"
	_pedestrian_crowd.setup(_chunk_data)
	add_child(_pedestrian_crowd)
	set_pedestrian_visibility(_pedestrians_visible)
	setup_profile["pedestrians_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	_vehicle_traffic = CityVehicleTrafficRenderer.new()
	_vehicle_traffic.name = "VehicleTraffic"
	_vehicle_traffic.setup(_chunk_data)
	add_child(_vehicle_traffic)
	setup_profile["vehicles_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	add_child(CityChunkHlodBuilder.build_mid_proxy(_profile))
	add_child(CityChunkHlodBuilder.build_far_proxy(_profile))
	setup_profile["proxies_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	add_child(CityChunkOccluderBuilder.build_chunk_occluder(chunk_size_m))
	setup_profile["occluder_usec"] = Time.get_ticks_usec() - phase_started_usec

	phase_started_usec = Time.get_ticks_usec()
	set_lod_mode(_current_lod_mode)
	setup_profile["set_lod_usec"] = Time.get_ticks_usec() - phase_started_usec
	setup_profile["total_usec"] = Time.get_ticks_usec() - rebuild_started_usec
	_setup_profile = setup_profile

func _build_near_group() -> Dictionary:
	if get_node_or_null("NearGroup") != null:
		return {
			"road_overlay_usec": 0,
			"buildings_usec": 0,
			"props_usec": 0,
		}
	var near_group := Node3D.new()
	near_group.name = "NearGroup"
	add_child(near_group)

	var stats := {
		"road_overlay_usec": 0,
		"buildings_usec": 0,
		"props_usec": 0,
	}
	var phase_started_usec := Time.get_ticks_usec()
	var road_overlay := _chunk_data.get("prepared_road_overlay") as Node3D
	if road_overlay == null:
		road_overlay = CityRoadMeshBuilder.build_road_overlay(_profile, _chunk_data)
	near_group.add_child(road_overlay)
	stats["road_overlay_usec"] = int(Time.get_ticks_usec() - phase_started_usec)

	var water_surfaces := Node3D.new()
	water_surfaces.name = "WaterSurfaces"
	near_group.add_child(water_surfaces)
	for water_entry_variant in _chunk_data.get("water_surface_entries", []):
		if not (water_entry_variant is Dictionary):
			continue
		var water_node := _build_water_surface(water_entry_variant as Dictionary)
		if water_node != null:
			water_surfaces.add_child(water_node)

	var props := Node3D.new()
	props.name = "Props"
	near_group.add_child(props)
	phase_started_usec = Time.get_ticks_usec()
	for building in _profile.get("buildings", []):
		near_group.add_child(_build_building(building))
	stats["buildings_usec"] = int(Time.get_ticks_usec() - phase_started_usec)
	phase_started_usec = Time.get_ticks_usec()
	var street_lamps := _chunk_data.get("prepared_street_lamps") as MultiMeshInstance3D
	if street_lamps == null:
		street_lamps = CityChunkMultimeshBuilder.build_street_lamps(_profile)
	props.add_child(street_lamps)
	var scene_landmarks := Node3D.new()
	scene_landmarks.name = "SceneLandmarks"
	near_group.add_child(scene_landmarks)
	for landmark_entry_variant in _chunk_data.get("scene_landmark_entries", []):
		if not (landmark_entry_variant is Dictionary):
			continue
		var landmark_node := _build_scene_landmark(landmark_entry_variant as Dictionary)
		if landmark_node != null:
			scene_landmarks.add_child(landmark_node)
	var scene_minigame_venues := Node3D.new()
	scene_minigame_venues.name = "SceneMinigameVenues"
	near_group.add_child(scene_minigame_venues)
	for venue_entry_variant in _chunk_data.get("scene_minigame_venue_entries", []):
		if not (venue_entry_variant is Dictionary):
			continue
		var venue_node := _build_scene_minigame_venue(venue_entry_variant as Dictionary)
		if venue_node != null:
			scene_minigame_venues.add_child(venue_node)
	var scene_interactive_props := Node3D.new()
	scene_interactive_props.name = "SceneInteractiveProps"
	near_group.add_child(scene_interactive_props)
	for prop_entry_variant in _chunk_data.get("scene_interactive_prop_entries", []):
		if not (prop_entry_variant is Dictionary):
			continue
		var prop_node := _build_scene_interactive_prop(prop_entry_variant as Dictionary)
		if prop_node != null:
			scene_interactive_props.add_child(prop_node)
	stats["props_usec"] = int(Time.get_ticks_usec() - phase_started_usec)
	return stats

func _build_building(building: Dictionary) -> Node3D:
	var building_id := str(building.get("building_id", ""))
	var prepared_service_roots: Dictionary = _chunk_data.get("prepared_service_roots", {})
	if building_id != "" and prepared_service_roots.has(building_id):
		var prepared_service_root := prepared_service_roots.get(building_id) as Node3D
		if prepared_service_root != null and is_instance_valid(prepared_service_root):
			_register_building_collision_shapes(prepared_service_root)
			return prepared_service_root
	var override_entry := _resolve_building_override_entry(building)
	if not override_entry.is_empty():
		var override_node := _build_building_override(building, override_entry)
		if override_node != null:
			_attach_destructible_building_runtime(override_node)
			return override_node
	var service_root := CityBuildingSceneBuilder.build_service_scene_root(building)
	service_root.position = CityBuildingSceneBuilder.resolve_ground_anchor(building)
	service_root.rotation.y = float(building.get("yaw_rad", 0.0))
	var inspection_payload: Dictionary = (building.get("inspection_payload", {}) as Dictionary).duplicate(true)
	if not inspection_payload.is_empty():
		service_root.set_meta("city_inspection_payload", inspection_payload.duplicate(true))
		CityBuildingSceneBuilder.apply_inspection_payload_recursive(service_root, inspection_payload)
	_register_building_collision_shapes(service_root)
	_attach_destructible_building_runtime(service_root, building, service_root.get_node_or_null("GeneratedBuilding") as StaticBody3D)
	return service_root

func _build_building_override(building: Dictionary, override_entry: Dictionary) -> Node3D:
	var scene_path := str(override_entry.get("scene_path", ""))
	if scene_path == "":
		return null
	var scene_resource := _load_cached_building_override_scene(scene_path)
	if scene_resource == null:
		return null
	var instantiated_variant: Variant = scene_resource.instantiate()
	var override_root := instantiated_variant as Node3D
	if override_root == null:
		if not (instantiated_variant is Node):
			return null
		override_root = Node3D.new()
		override_root.name = "BuildingOverrideRoot"
		override_root.add_child(instantiated_variant as Node)
	var inspection_payload: Dictionary = (building.get("inspection_payload", {}) as Dictionary).duplicate(true)
	var building_id := str(building.get("building_id", ""))
	var ground_anchor := CityBuildingSceneBuilder.resolve_ground_anchor(building)
	override_root.position = ground_anchor
	override_root.rotation.y = float(building.get("yaw_rad", 0.0))
	if building_id != "":
		override_root.set_meta("city_building_id", building_id)
	override_root.set_meta("city_building_override", true)
	override_root.set_meta("city_building_override_scene_path", scene_path)
	if not inspection_payload.is_empty():
		override_root.set_meta("city_inspection_payload", inspection_payload.duplicate(true))
		CityBuildingSceneBuilder.apply_inspection_payload_recursive(override_root, inspection_payload)
	_register_building_collision_shapes(override_root)
	_attach_destructible_building_runtime(override_root)
	return override_root

func _resolve_building_override_entry(building: Dictionary) -> Dictionary:
	var building_id := str(building.get("building_id", ""))
	if building_id == "":
		return {}
	var override_entries: Dictionary = _chunk_data.get("building_override_entries", {})
	return (override_entries.get(building_id, {}) as Dictionary).duplicate(true)

func _build_scene_landmark(entry: Dictionary) -> Node3D:
	var scene_path := str(entry.get("scene_path", "")).strip_edges()
	if scene_path == "":
		return null
	var scene_resource := _load_cached_scene_landmark_scene(scene_path)
	if scene_resource == null:
		return null
	var instantiated_variant: Variant = scene_resource.instantiate()
	var landmark_root := instantiated_variant as Node3D
	if landmark_root == null:
		if not (instantiated_variant is Node):
			return null
		landmark_root = Node3D.new()
		landmark_root.name = "SceneLandmarkRoot"
		landmark_root.add_child(instantiated_variant as Node)
	var world_position_variant: Variant = entry.get("world_position", Vector3.ZERO)
	var world_position := Vector3.ZERO
	if world_position_variant is Vector3:
		world_position = world_position_variant as Vector3
	var chunk_center: Vector3 = _chunk_data.get("chunk_center", Vector3.ZERO)
	landmark_root.position = world_position - chunk_center
	landmark_root.rotation.y = float(entry.get("yaw_rad", 0.0))
	var landmark_id := str(entry.get("landmark_id", "")).strip_edges()
	if landmark_id != "":
		landmark_root.set_meta("city_scene_landmark_id", landmark_id)
	landmark_root.set_meta("city_scene_landmark", true)
	landmark_root.set_meta("city_scene_landmark_scene_path", scene_path)
	landmark_root.set_meta("city_scene_landmark_feature_kind", str(entry.get("feature_kind", "")))
	landmark_root.set_meta("city_scene_landmark_manifest_path", str(entry.get("manifest_path", "")))
	return landmark_root

func _build_scene_interactive_prop(entry: Dictionary) -> Node3D:
	var scene_path := str(entry.get("scene_path", "")).strip_edges()
	if scene_path == "":
		return null
	var scene_resource := _load_cached_scene_interactive_prop_scene(scene_path)
	if scene_resource == null:
		return null
	var instantiated_variant: Variant = scene_resource.instantiate()
	var prop_root := instantiated_variant as Node3D
	if prop_root == null:
		if not (instantiated_variant is Node):
			return null
		prop_root = Node3D.new()
		prop_root.name = "SceneInteractivePropRoot"
		prop_root.add_child(instantiated_variant as Node)
	if prop_root.has_method("configure_interactive_prop"):
		prop_root.configure_interactive_prop(entry.duplicate(true))
	var world_position_variant: Variant = entry.get("world_position", Vector3.ZERO)
	var world_position := Vector3.ZERO
	if world_position_variant is Vector3:
		world_position = world_position_variant as Vector3
	var root_offset_variant: Variant = entry.get("scene_root_offset", Vector3.ZERO)
	var root_offset := Vector3.ZERO
	if root_offset_variant is Vector3:
		root_offset = root_offset_variant as Vector3
	var chunk_center: Vector3 = _chunk_data.get("chunk_center", Vector3.ZERO)
	prop_root.position = world_position + root_offset - chunk_center
	prop_root.rotation.y = float(entry.get("yaw_rad", 0.0))
	var prop_id := str(entry.get("prop_id", "")).strip_edges()
	if prop_id != "":
		prop_root.set_meta("city_scene_interactive_prop_id", prop_id)
	prop_root.set_meta("city_scene_interactive_prop", true)
	prop_root.set_meta("city_scene_interactive_prop_scene_path", scene_path)
	prop_root.set_meta("city_scene_interactive_prop_feature_kind", str(entry.get("feature_kind", "")))
	prop_root.set_meta("city_scene_interactive_prop_manifest_path", str(entry.get("manifest_path", "")))
	return prop_root

func _build_scene_minigame_venue(entry: Dictionary) -> Node3D:
	var scene_path := str(entry.get("scene_path", "")).strip_edges()
	if scene_path == "":
		return null
	var scene_resource := _load_cached_scene_minigame_venue_scene(scene_path)
	if scene_resource == null:
		return null
	var instantiated_variant: Variant = scene_resource.instantiate()
	var venue_root := instantiated_variant as Node3D
	if venue_root == null:
		if not (instantiated_variant is Node):
			return null
		venue_root = Node3D.new()
		venue_root.name = "SceneMinigameVenueRoot"
		venue_root.add_child(instantiated_variant as Node)
	if venue_root.has_method("configure_minigame_venue"):
		venue_root.configure_minigame_venue(entry.duplicate(true))
	var world_position_variant: Variant = entry.get("world_position", Vector3.ZERO)
	var world_position := Vector3.ZERO
	if world_position_variant is Vector3:
		world_position = world_position_variant as Vector3
	var root_offset_variant: Variant = entry.get("scene_root_offset", Vector3.ZERO)
	var root_offset := Vector3.ZERO
	if root_offset_variant is Vector3:
		root_offset = root_offset_variant as Vector3
	var chunk_center: Vector3 = _chunk_data.get("chunk_center", Vector3.ZERO)
	venue_root.position = world_position + root_offset - chunk_center
	venue_root.rotation.y = float(entry.get("yaw_rad", 0.0))
	var venue_id := str(entry.get("venue_id", "")).strip_edges()
	if venue_id != "":
		venue_root.set_meta("city_scene_minigame_venue_id", venue_id)
	venue_root.set_meta("city_scene_minigame_venue", true)
	venue_root.set_meta("city_scene_minigame_venue_scene_path", scene_path)
	venue_root.set_meta("city_scene_minigame_venue_feature_kind", str(entry.get("feature_kind", "")))
	venue_root.set_meta("city_scene_minigame_venue_manifest_path", str(entry.get("manifest_path", "")))
	venue_root.set_meta("city_scene_minigame_venue_primary_ball_prop_id", str(entry.get("primary_ball_prop_id", "")))
	return venue_root

func _build_water_surface(entry: Dictionary) -> Node3D:
	var chunk_center: Vector3 = _chunk_data.get("chunk_center", Vector3.ZERO)
	return CityLakeBasinCarrierBuilder.build_water_surface_node(entry, chunk_center)

func _get_water_surface_material() -> StandardMaterial3D:
	if _shared_water_surface_material_template == null:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.16, 0.44, 0.68, 0.72)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.roughness = 0.08
		material.metallic = 0.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_shared_water_surface_material_template = material
	return _shared_water_surface_material_template

func _register_building_collision_shapes(root: Node) -> void:
	var shapes: Array[CollisionShape3D] = CityBuildingSceneBuilder.collect_collision_shapes(root)
	for collision_shape in shapes:
		collision_shape.disabled = not _building_collisions_enabled
		_building_collision_shapes.append(collision_shape)

func _attach_destructible_building_runtime(root: Node3D, building_contract: Dictionary = {}, generated_building: StaticBody3D = null) -> void:
	if root == null:
		return
	var existing_runtime := root.get_node_or_null("DestructibleBuildingRuntime") as Node3D
	if existing_runtime != null:
		return
	var runtime := CityDestructibleBuildingRuntime.new()
	runtime.name = "DestructibleBuildingRuntime"
	if runtime.has_method("prime_runtime_context"):
		runtime.prime_runtime_context(root, generated_building, building_contract)
	root.add_child(runtime)

func _find_building_override_node_recursive(root: Node, building_id: String) -> Node:
	if root == null:
		return null
	if bool(root.get_meta("city_building_override", false)) and str(root.get_meta("city_building_id", "")) == building_id:
		return root
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var match_node := _find_building_override_node_recursive(child_node, building_id)
		if match_node != null:
			return match_node
	return null

func _find_scene_landmark_node_recursive(root: Node, landmark_id: String) -> Node:
	if root == null:
		return null
	if bool(root.get_meta("city_scene_landmark", false)) and str(root.get_meta("city_scene_landmark_id", "")) == landmark_id:
		return root
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var match_node := _find_scene_landmark_node_recursive(child_node, landmark_id)
		if match_node != null:
			return match_node
	return null

func _find_scene_interactive_prop_node_recursive(root: Node, prop_id: String) -> Node:
	if root == null:
		return null
	if bool(root.get_meta("city_scene_interactive_prop", false)) and str(root.get_meta("city_scene_interactive_prop_id", "")) == prop_id:
		return root
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var match_node := _find_scene_interactive_prop_node_recursive(child_node, prop_id)
		if match_node != null:
			return match_node
	return null

func _find_scene_minigame_venue_node_recursive(root: Node, venue_id: String) -> Node:
	if root == null:
		return null
	if bool(root.get_meta("city_scene_minigame_venue", false)) and str(root.get_meta("city_scene_minigame_venue_id", "")) == venue_id:
		return root
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var match_node := _find_scene_minigame_venue_node_recursive(child_node, venue_id)
		if match_node != null:
			return match_node
	return null

static func _load_cached_building_override_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if _shared_building_override_scene_cache.has(scene_path):
		return _shared_building_override_scene_cache.get(scene_path) as PackedScene
	var scene_resource := load(scene_path)
	if scene_resource == null or not (scene_resource is PackedScene):
		_shared_building_override_scene_cache[scene_path] = null
		return null
	var packed_scene := scene_resource as PackedScene
	_shared_building_override_scene_cache[scene_path] = packed_scene
	return packed_scene

static func _load_cached_scene_landmark_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if _shared_scene_landmark_scene_cache.has(scene_path):
		return _shared_scene_landmark_scene_cache.get(scene_path) as PackedScene
	var scene_resource := load(scene_path)
	if scene_resource == null or not (scene_resource is PackedScene):
		_shared_scene_landmark_scene_cache[scene_path] = null
		return null
	var packed_scene := scene_resource as PackedScene
	_shared_scene_landmark_scene_cache[scene_path] = packed_scene
	return packed_scene

static func _load_cached_scene_interactive_prop_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if _shared_scene_interactive_prop_scene_cache.has(scene_path):
		return _shared_scene_interactive_prop_scene_cache.get(scene_path) as PackedScene
	var scene_resource := load(scene_path)
	if scene_resource == null or not (scene_resource is PackedScene):
		_shared_scene_interactive_prop_scene_cache[scene_path] = null
		return null
	var packed_scene := scene_resource as PackedScene
	_shared_scene_interactive_prop_scene_cache[scene_path] = packed_scene
	return packed_scene

static func _load_cached_scene_minigame_venue_scene(scene_path: String) -> PackedScene:
	if scene_path == "":
		return null
	if _shared_scene_minigame_venue_scene_cache.has(scene_path):
		return _shared_scene_minigame_venue_scene_cache.get(scene_path) as PackedScene
	var scene_resource := load(scene_path)
	if scene_resource == null or not (scene_resource is PackedScene):
		_shared_scene_minigame_venue_scene_cache[scene_path] = null
		return null
	var packed_scene := scene_resource as PackedScene
	_shared_scene_minigame_venue_scene_cache[scene_path] = packed_scene
	return packed_scene

func _build_static_box(node_name: String, center: Vector3, size: Vector3, color: Color, yaw_rad: float = 0.0, collision_size: Vector3 = Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.rotation.y = yaw_rad

	var collision_shape := CollisionShape3D.new()
	var shape := _get_shared_box_shape(collision_size if collision_size != Vector3.ZERO else size)
	collision_shape.shape = shape
	body.add_child(collision_shape)
	_building_collision_shapes.append(collision_shape)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := _get_shared_box_mesh(size)
	mesh_instance.mesh = mesh
	var material := _get_shared_box_material(color)
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	return body

func _add_local_box(parent: Node3D, node_name: String, local_center: Vector3, size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = local_center
	var mesh := _get_shared_box_mesh(size)
	mesh_instance.mesh = mesh
	var material := _get_shared_box_material(color)
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)

func _get_shared_box_shape(size: Vector3) -> BoxShape3D:
	var key := _vector3_cache_key(size)
	if _shared_box_shape_cache.has(key):
		return _shared_box_shape_cache[key]
	var shape := BoxShape3D.new()
	shape.size = size
	_shared_box_shape_cache[key] = shape
	return shape

func _get_shared_box_mesh(size: Vector3) -> BoxMesh:
	var key := _vector3_cache_key(size)
	if _shared_box_mesh_cache.has(key):
		return _shared_box_mesh_cache[key]
	var mesh := BoxMesh.new()
	mesh.size = size
	_shared_box_mesh_cache[key] = mesh
	return mesh

func _get_shared_box_material(color: Color) -> StandardMaterial3D:
	var key := _color_cache_key(color)
	if _shared_box_material_cache.has(key):
		return _shared_box_material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	_shared_box_material_cache[key] = material
	return material

func _vector3_cache_key(value: Vector3) -> String:
	return "%.3f|%.3f|%.3f" % [value.x, value.y, value.z]

func _color_cache_key(value: Color) -> String:
	return "%.4f|%.4f|%.4f|%.4f" % [value.r, value.g, value.b, value.a]

func _add_roof_box(parent: Node3D, node_name: String, base_size: Vector3, roof_offset_xz: Vector2, size: Vector3, color: Color) -> void:
	_add_local_box(
		parent,
		node_name,
		Vector3(
			roof_offset_xz.x,
			base_size.y * 0.5 + size.y * 0.5 - BUILDING_ORNAMENT_OVERLAP_M,
			roof_offset_xz.y
		),
		size,
		color
	)

func _add_roof_stack_box(parent: Node3D, node_name: String, base_size: Vector3, roof_offset_xz: Vector2, stack_height_m: float, size: Vector3, color: Color) -> void:
	_add_local_box(
		parent,
		node_name,
		Vector3(
			roof_offset_xz.x,
			base_size.y * 0.5 + stack_height_m + size.y * 0.5 - BUILDING_ORNAMENT_OVERLAP_M,
			roof_offset_xz.y
		),
		size,
		color
	)

func _add_ground_box(parent: Node3D, node_name: String, base_size: Vector3, ground_offset_xz: Vector2, size: Vector3, color: Color) -> void:
	_add_local_box(
		parent,
		node_name,
		Vector3(
			ground_offset_xz.x,
			-base_size.y * 0.5 + size.y * 0.5 - BUILDING_ORNAMENT_OVERLAP_M,
			ground_offset_xz.y
		),
		size,
		color
	)

func _add_side_box(parent: Node3D, node_name: String, base_size: Vector3, side: String, lateral_offset_m: float, vertical_offset_m: float, size: Vector3, color: Color) -> void:
	var local_center := Vector3.ZERO
	match side:
		"west":
			local_center = Vector3(-base_size.x * 0.5 - size.x * 0.5 + BUILDING_ORNAMENT_OVERLAP_M, vertical_offset_m, lateral_offset_m)
		"east":
			local_center = Vector3(base_size.x * 0.5 + size.x * 0.5 - BUILDING_ORNAMENT_OVERLAP_M, vertical_offset_m, lateral_offset_m)
		"north":
			local_center = Vector3(lateral_offset_m, vertical_offset_m, -base_size.z * 0.5 - size.z * 0.5 + BUILDING_ORNAMENT_OVERLAP_M)
		"south":
			local_center = Vector3(lateral_offset_m, vertical_offset_m, base_size.z * 0.5 + size.z * 0.5 - BUILDING_ORNAMENT_OVERLAP_M)
		_:
			local_center = Vector3(lateral_offset_m, vertical_offset_m, 0.0)
	_add_local_box(parent, node_name, local_center, size, color)

func _build_ground_body(chunk_size_m: float, profile: Dictionary) -> Dictionary:
	var ground_body := StaticBody3D.new()
	ground_body.name = "GroundBody"

	var mesh_started_usec := Time.get_ticks_usec()
	var terrain_build_result := _build_terrain_mesh(chunk_size_m)
	var terrain_mesh := terrain_build_result.get("mesh") as ArrayMesh
	var mesh_usec := Time.get_ticks_usec() - mesh_started_usec
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var collision_started_usec := Time.get_ticks_usec()
	var shape := ConcavePolygonShape3D.new()
	var collision_mesh_result: Dictionary = _terrain_mesh_results_by_lod.get(LOD_NEAR, terrain_build_result)
	var collision_faces: PackedVector3Array = collision_mesh_result.get("collision_faces", PackedVector3Array())
	if collision_faces.is_empty():
		var collision_mesh := collision_mesh_result.get("mesh") as ArrayMesh
		if collision_mesh == null:
			collision_mesh = terrain_mesh
		collision_faces = collision_mesh.get_faces()
	shape.set_faces(collision_faces)
	var collision_usec := Time.get_ticks_usec() - collision_started_usec
	collision_shape.shape = shape
	ground_body.add_child(collision_shape)
	_current_terrain_collision_mode = LOD_NEAR if _terrain_mesh_results_by_lod.has(LOD_NEAR) else _current_lod_mode
	_terrain_collision_apply_count = 1

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	mesh_instance.mesh = terrain_mesh
	_terrain_mesh_apply_count = 1
	var material_started_usec := Time.get_ticks_usec()
	var material_result := _build_ground_material(chunk_size_m, profile, _current_surface_detail_mode)
	mesh_instance.material_override = material_result.get("material")
	var material_usec := Time.get_ticks_usec() - material_started_usec
	ground_body.add_child(mesh_instance)
	return {
		"body": ground_body,
		"mesh_usec": mesh_usec,
		"collision_usec": collision_usec,
		"collision_face_count": int(collision_faces.size() / 3.0),
		"material_usec": material_usec,
		"mask_textures_usec": int(material_result.get("mask_textures_usec", 0)),
		"mask_cache_hit": bool(material_result.get("mask_cache_hit", false)),
		"mask_cache_load_usec": int(material_result.get("mask_cache_load_usec", 0)),
		"mask_cache_write_usec": int(material_result.get("mask_cache_write_usec", 0)),
		"shader_material_usec": int(material_result.get("shader_material_usec", 0)),
		"vertex_sample_count": int(terrain_build_result.get("vertex_sample_count", 0)),
		"unique_vertex_count": int(terrain_build_result.get("unique_vertex_count", 0)),
		"duplication_ratio": float(terrain_build_result.get("duplication_ratio", 0.0)),
		"runtime_page_hit": bool(terrain_build_result.get("runtime_page_hit", false)),
	}

func _build_flat_ground_mesh_result(chunk_size_m: float) -> Dictionary:
	var half_size := chunk_size_m * 0.5
	var top_left := Vector3(-half_size, 0.0, -half_size)
	var top_right := Vector3(half_size, 0.0, -half_size)
	var bottom_left := Vector3(-half_size, 0.0, half_size)
	var bottom_right := Vector3(half_size, 0.0, half_size)

	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.set_uv(Vector2(0.0, 0.0))
	surface_tool.add_vertex(top_left)
	surface_tool.set_uv(Vector2(1.0, 0.0))
	surface_tool.add_vertex(top_right)
	surface_tool.set_uv(Vector2(0.0, 1.0))
	surface_tool.add_vertex(bottom_left)
	surface_tool.set_uv(Vector2(0.0, 1.0))
	surface_tool.add_vertex(bottom_left)
	surface_tool.set_uv(Vector2(1.0, 0.0))
	surface_tool.add_vertex(top_right)
	surface_tool.set_uv(Vector2(1.0, 1.0))
	surface_tool.add_vertex(bottom_right)
	surface_tool.generate_normals()
	var mesh: ArrayMesh = surface_tool.commit()
	var collision_faces := PackedVector3Array([
		top_left,
		top_right,
		bottom_left,
		bottom_left,
		top_right,
		bottom_right,
	])
	var chunk_key: Vector2i = _chunk_data.get("chunk_key", Vector2i.ZERO)
	var page_contract := {
		"page_key": chunk_key,
		"uv_rect": Rect2(Vector2.ZERO, Vector2.ONE),
		"chunks_per_page": 1,
		"page_world_size_m": chunk_size_m,
		"page_origin_chunk_key": chunk_key,
		"grid_steps": FLAT_GROUND_GRID_STEPS,
		"flat_ground": true,
	}
	return {
		"mesh": mesh,
		"collision_faces": collision_faces,
		"grid_steps": FLAT_GROUND_GRID_STEPS,
		"sample_stats": {
			"current_vertex_sample_count": 4,
			"unique_vertex_sample_count": 4,
			"duplication_ratio": 1.0,
		},
		"page_contract": page_contract,
		"runtime_hit": false,
	}

func _build_ground_material(chunk_size_m: float, profile: Dictionary, detail_mode: String = SURFACE_DETAIL_FULL) -> Dictionary:
	var palette: Dictionary = profile.get("palette", {})
	var mask_started_usec := Time.get_ticks_usec()
	var surface_binding := _resolve_surface_binding(profile, chunk_size_m, detail_mode)
	var mask_resolve_usec := Time.get_ticks_usec() - mask_started_usec
	var mask_stats: Dictionary = surface_binding.get("mask_profile_stats", {})
	var uv_rect: Rect2 = surface_binding.get("uv_rect", Rect2(Vector2.ZERO, Vector2.ONE))
	_surface_page_contract = (surface_binding.get("page_contract", {
		"page_key": surface_binding.get("page_key", Vector2i.ZERO),
		"uv_rect": uv_rect,
		"chunks_per_page": 1,
		"page_world_size_m": chunk_size_m,
		"page_origin_chunk_key": _chunk_data.get("chunk_key", Vector2i.ZERO),
	}) as Dictionary).duplicate(true)
	var material_started_usec := Time.get_ticks_usec()
	var material := _instantiate_ground_overlay_material()
	material.set_shader_parameter("chunk_size_m", chunk_size_m)
	material.set_shader_parameter("ground_color", palette.get("ground", Color(0.12549, 0.333333, 0.168627, 1.0)))
	material.set_shader_parameter("road_color", palette.get("road", Color(0.16, 0.17, 0.19, 1.0)))
	material.set_shader_parameter("stripe_color", palette.get("stripe", Color(0.9, 0.8, 0.5, 1.0)))
	material.set_shader_parameter(
		"stripe_enabled",
		detail_mode == SURFACE_DETAIL_FULL and bool(mask_stats.get("stripe_paint_enabled", true))
	)
	material.set_shader_parameter("road_mask_texture", surface_binding.get("road_mask_texture"))
	material.set_shader_parameter("stripe_mask_texture", surface_binding.get("stripe_mask_texture"))
	material.set_shader_parameter("surface_uv_offset", uv_rect.position)
	material.set_shader_parameter("surface_uv_scale", uv_rect.size)
	return {
		"material": material,
		"mask_textures_usec": maxi(int(surface_binding.get("commit_usec", 0)), mask_resolve_usec),
		"mask_cache_hit": bool(mask_stats.get("cache_hit", false)),
		"mask_cache_load_usec": int(mask_stats.get("cache_load_usec", 0)),
		"mask_cache_write_usec": int(mask_stats.get("cache_write_usec", 0)),
		"shader_material_usec": Time.get_ticks_usec() - material_started_usec,
	}

func _resolve_surface_binding(profile: Dictionary, chunk_size_m: float, detail_mode: String) -> Dictionary:
	var existing_binding: Dictionary = _chunk_data.get("surface_page_binding", {})
	if not existing_binding.is_empty() and str(existing_binding.get("detail_mode", "")) == detail_mode:
		return existing_binding

	var surface_page_provider = _chunk_data.get("surface_page_provider")
	if surface_page_provider != null and surface_page_provider.has_method("resolve_chunk_surface_binding"):
		var resolved_binding: Dictionary = surface_page_provider.resolve_chunk_surface_binding(_chunk_data, detail_mode)
		_chunk_data["surface_page_binding"] = resolved_binding
		return resolved_binding

	var fallback_result: Dictionary = CityRoadMaskBuilder.build_surface_textures(profile, chunk_size_m, detail_mode)
	var fallback_stats: Dictionary = fallback_result.get("mask_profile_stats", {})
	var fallback_binding := {
		"page_contract": {
			"page_key": _chunk_data.get("chunk_key", Vector2i.ZERO),
			"uv_rect": Rect2(Vector2.ZERO, Vector2.ONE),
			"chunks_per_page": 1,
			"page_world_size_m": chunk_size_m,
			"page_origin_chunk_key": _chunk_data.get("chunk_key", Vector2i.ZERO),
		},
		"page_key": _chunk_data.get("chunk_key", Vector2i.ZERO),
		"uv_rect": Rect2(Vector2.ZERO, Vector2.ONE),
		"detail_mode": detail_mode,
		"road_mask_texture": fallback_result.get("road_mask_texture"),
		"stripe_mask_texture": fallback_result.get("stripe_mask_texture"),
		"mask_profile_stats": fallback_stats,
		"commit_usec": int(fallback_stats.get("commit_total_usec", 0)),
		"runtime_hit": false,
	}
	_chunk_data["surface_page_binding"] = fallback_binding
	return fallback_binding

func _apply_ground_surface_detail_mode(detail_mode: String) -> void:
	var mesh_instance := get_node_or_null("GroundBody/MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return
	var chunk_size_m := float(_chunk_data.get("chunk_size_m", 256.0))
	var material_result := _build_ground_material(chunk_size_m, _profile, detail_mode)
	mesh_instance.material_override = material_result.get("material")
	_current_surface_detail_mode = detail_mode

func _resolve_surface_detail_mode_for_lod(mode: String) -> String:
	return SURFACE_DETAIL_FULL if mode == LOD_NEAR else SURFACE_DETAIL_COARSE

func _normalize_lod_mode(mode: String) -> String:
	if mode == LOD_MID or mode == LOD_FAR:
		return mode
	return LOD_NEAR

func _build_terrain_mesh(chunk_size_m: float) -> Dictionary:
	_terrain_mesh_results_by_lod.clear()
	_terrain_mesh_apply_count = 0
	_terrain_collision_apply_count = 0
	_current_terrain_collision_mode = ""
	var terrain_build_result: Dictionary = _ensure_terrain_mesh_result(_current_lod_mode, chunk_size_m)
	var sample_stats: Dictionary = terrain_build_result.get("sample_stats", {})
	_terrain_page_contract = (terrain_build_result.get("page_contract", {}) as Dictionary).duplicate(true)
	return {
		"mesh": terrain_build_result.get("mesh"),
		"vertex_sample_count": int(sample_stats.get("current_vertex_sample_count", 0)),
		"unique_vertex_count": int(sample_stats.get("unique_vertex_sample_count", 0)),
		"duplication_ratio": float(sample_stats.get("duplication_ratio", 0.0)),
		"runtime_page_hit": bool(terrain_build_result.get("runtime_hit", false)),
	}

func _apply_terrain_lod_mode(mode: String) -> void:
	var mesh_instance := get_node_or_null("GroundBody/MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return
	var normalized_mode := _normalize_lod_mode(mode)
	var terrain_mesh_result: Dictionary = _ensure_terrain_mesh_result(normalized_mode)
	var target_mesh := terrain_mesh_result.get("mesh") as ArrayMesh
	if target_mesh == null or mesh_instance.mesh == target_mesh:
		return
	mesh_instance.mesh = target_mesh
	_terrain_page_contract = (terrain_mesh_result.get("page_contract", {}) as Dictionary).duplicate(true)
	_terrain_mesh_apply_count += 1

func _apply_terrain_collision_mode(mode: String) -> void:
	var collision_shape := get_node_or_null("GroundBody/CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		return
	var normalized_mode := _normalize_lod_mode(mode)
	var target_collision_mode := LOD_NEAR if _terrain_mesh_results_by_lod.has(LOD_NEAR) else normalized_mode
	if target_collision_mode == "":
		return
	if target_collision_mode == _current_terrain_collision_mode:
		return
	var terrain_mesh_result: Dictionary = _ensure_terrain_mesh_result(target_collision_mode)
	var collision_faces: PackedVector3Array = terrain_mesh_result.get("collision_faces", PackedVector3Array())
	if collision_faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision_faces)
	collision_shape.shape = shape
	_current_terrain_collision_mode = target_collision_mode
	_terrain_collision_apply_count += 1

func _terrain_lod_grid_steps_by_mode() -> Dictionary:
	return {
		LOD_NEAR: TERRAIN_GRID_STEPS,
		LOD_MID: TERRAIN_GRID_STEPS_MID,
		LOD_FAR: TERRAIN_GRID_STEPS_FAR,
	}

func _ensure_all_terrain_lod_mesh_results() -> void:
	for lod_mode in _terrain_lod_grid_steps_by_mode().keys():
		_ensure_terrain_mesh_result(str(lod_mode))

func _ensure_terrain_mesh_result(mode: String, chunk_size_override: float = -1.0) -> Dictionary:
	var normalized_mode := _normalize_lod_mode(mode)
	if _terrain_mesh_results_by_lod.has(normalized_mode):
		var cached_result: Dictionary = (_terrain_mesh_results_by_lod.get(normalized_mode, {}) as Dictionary).duplicate(false)
		if (cached_result.get("mesh", null) as ArrayMesh) == null:
			cached_result = _materialize_terrain_mesh_result(cached_result, normalized_mode)
			_terrain_mesh_results_by_lod[normalized_mode] = cached_result
		return cached_result
	var chunk_size_m := chunk_size_override if chunk_size_override > 0.0 else float(_chunk_data.get("chunk_size_m", 256.0))
	var mesh_result: Dictionary = {}
	var provided_results: Dictionary = _chunk_data.get("terrain_lod_mesh_results", {})
	if provided_results.has(normalized_mode):
		mesh_result = (provided_results.get(normalized_mode, {}) as Dictionary).duplicate(false)
	if mesh_result.is_empty():
		var terrain_page_binding: Dictionary = _resolve_terrain_page_binding(chunk_size_m)
		if terrain_page_binding.is_empty():
			mesh_result = _build_flat_ground_mesh_result(chunk_size_m)
		else:
			var builder := CityTerrainMeshBuilder.new()
			var source_grid_steps := int(terrain_page_binding.get("grid_steps", TERRAIN_GRID_STEPS))
			var target_grid_steps := int(_terrain_lod_grid_steps_by_mode().get(normalized_mode, source_grid_steps))
			if target_grid_steps == source_grid_steps:
				mesh_result = builder.build_profiled_terrain_arrays_from_binding(chunk_size_m, target_grid_steps, terrain_page_binding)
			else:
				var lod_results: Dictionary = builder.build_profiled_terrain_lod_arrays_from_binding(
					chunk_size_m,
					source_grid_steps,
					terrain_page_binding,
					{normalized_mode: target_grid_steps}
				)
				mesh_result = (lod_results.get(normalized_mode, {}) as Dictionary).duplicate(true)
	mesh_result = _materialize_terrain_mesh_result(mesh_result, normalized_mode)
	_terrain_mesh_results_by_lod[normalized_mode] = mesh_result
	return mesh_result

func _resolve_terrain_page_binding(chunk_size_m: float) -> Dictionary:
	var existing_binding: Dictionary = _chunk_data.get("terrain_page_binding", {})
	if not existing_binding.is_empty():
		return existing_binding.duplicate(false)
	var terrain_page_provider = _chunk_data.get("terrain_page_provider")
	if terrain_page_provider != null and terrain_page_provider.has_method("resolve_chunk_sample_binding"):
		var resolved_binding: Dictionary = terrain_page_provider.resolve_chunk_sample_binding(_chunk_data, TERRAIN_GRID_STEPS)
		if not resolved_binding.is_empty():
			resolved_binding["chunk_size_m"] = chunk_size_m
			_chunk_data["terrain_page_binding"] = resolved_binding
			return resolved_binding
	return {}

func _materialize_terrain_mesh_result(mesh_result: Dictionary, mode: String) -> Dictionary:
	if mesh_result.is_empty():
		return {}
	var resolved_result: Dictionary = mesh_result.duplicate(false)
	if not resolved_result.has("grid_steps"):
		resolved_result["grid_steps"] = int(_terrain_lod_grid_steps_by_mode().get(mode, TERRAIN_GRID_STEPS))
	if (resolved_result.get("mesh", null) as ArrayMesh) == null:
		resolved_result["mesh"] = CityTerrainMeshBuilder.new().commit_terrain_mesh(resolved_result)
	return resolved_result

func _set_building_collisions_enabled(enabled: bool) -> void:
	_building_collisions_enabled = enabled
	for collision_shape in _building_collision_shapes:
		collision_shape.disabled = not enabled
