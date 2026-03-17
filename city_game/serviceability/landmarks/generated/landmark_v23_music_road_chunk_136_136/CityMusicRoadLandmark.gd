extends Node3D

const CityMusicRoadDefinition := preload("res://city_game/world/features/music_road/CityMusicRoadDefinition.gd")
const CityMusicRoadRunState := preload("res://city_game/world/features/music_road/CityMusicRoadRunState.gd")
const CityMusicRoadNotePlayer := preload("res://city_game/world/features/music_road/CityMusicRoadNotePlayer.gd")

const DEFAULT_DEFINITION_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_definition.json"
const KEY_SHADER_PATH := "res://city_game/world/features/music_road/MusicRoadKeyStrip.gdshader"
const ADOPTED_TEXTURE_PATH := "res://city_game/assets/environment/source/music_road/road_generator_frozen/road_texture@4x.png"
const ADOPTED_EDGE_BARRIER_SCENE_PATH := "res://city_game/assets/environment/source/music_road/road_generator_frozen/edge_barrier.tscn"
const SAMPLE_BANK_MANIFEST_PATH := "res://city_game/assets/audio/music_road/grand_piano/grand_piano_sample_bank.json"
const ROAD_SURFACE_TOP_Y := 0.4
const KEY_SURFACE_CLEARANCE_M := 0.035
const RAIL_WIDTH_M := 0.22
const RAIL_HEIGHT_M := 0.64
const VISIBLE_WINDOW_BACK_M := 28.0
const VISIBLE_WINDOW_FORWARD_M := 132.0
const VISIBLE_WINDOW_REBUILD_MARGIN_M := 18.0
const VISUAL_CLUSTER_SPACING_M := 2.4
const VISUAL_CLUSTER_MAX_LENGTH_M := 2.8

var _music_road_entry: Dictionary = {}
var _definition = null
var _run_state := CityMusicRoadRunState.new()
var _note_player = null
var _strip_visual_root: MultiMeshInstance3D = null
var _visuals_built := false
var _shared_key_material: ShaderMaterial = null
var _shared_key_mesh: BoxMesh = null
var _adopted_asset_paths: Array[String] = []
var _adopted_road_texture: Texture2D = null
var _configured_landmark_id := ""
var _configured_definition_path := ""
var _visible_cluster_ids: Array[String] = []
var _visible_cluster_members_by_id: Dictionary = {}
var _visible_window_min_z := -INF
var _visible_window_max_z := INF

func _ready() -> void:
	_ensure_runtime_ready()

func configure_music_road(entry: Dictionary, definition_variant: Variant = null) -> void:
	var next_landmark_id := str(entry.get("landmark_id", "")).strip_edges()
	var next_definition_path := ""
	_music_road_entry = entry.duplicate(true)
	if definition_variant != null and definition_variant.has_method("get_note_strips"):
		if definition_variant.has_method("get_value"):
			next_definition_path = str(definition_variant.get_value("source_path", "")).strip_edges()
		_definition = definition_variant
	if next_definition_path == "" and _definition != null and _definition.has_method("get_value"):
		next_definition_path = str(_definition.get_value("source_path", "")).strip_edges()
	var requires_run_state_reset := _definition == null \
		or next_landmark_id != _configured_landmark_id \
		or next_definition_path != _configured_definition_path
	if requires_run_state_reset:
		_run_state.setup(_definition)
		_configured_landmark_id = next_landmark_id
		_configured_definition_path = next_definition_path
	_ensure_runtime_ready()

func apply_music_road_vehicle_state(vehicle_state: Dictionary, time_sec: float) -> Dictionary:
	return debug_apply_music_road_vehicle_state(vehicle_state, time_sec)

func debug_apply_music_road_vehicle_state(vehicle_state: Dictionary, time_sec: float) -> Dictionary:
	_ensure_runtime_ready()
	var local_vehicle_state := _build_local_vehicle_state(vehicle_state)
	var update_result: Dictionary = _run_state.advance_local_vehicle_state(local_vehicle_state, time_sec)
	_refresh_visible_strip_window(local_vehicle_state)
	for note_event in update_result.get("frame_triggered_events", []):
		if _note_player != null:
			_note_player.play_note_event(note_event)
	_apply_visual_phases()
	return _run_state.get_state()

func get_music_road_strip_phase(strip_id: String) -> Dictionary:
	_ensure_runtime_ready()
	return _run_state.get_strip_phase(strip_id)

func get_music_road_runtime_state() -> Dictionary:
	_ensure_runtime_ready()
	var state := _run_state.get_state()
	if _note_player != null:
		state["note_player"] = _note_player.get_state()
	return state

func get_music_road_debug_state() -> Dictionary:
	_ensure_runtime_ready()
	var white_key_count := 0
	var black_key_count := 0
	if _definition != null:
		for strip in _definition.get_note_strips():
			if str(strip.get("visual_key_kind", "")) == "black":
				black_key_count += 1
			else:
				white_key_count += 1
	return {
		"strip_count": _definition.get_strip_count() if _definition != null else 0,
		"white_key_count": white_key_count,
		"black_key_count": black_key_count,
		"visual_instance_count": _count_visual_instances(),
		"key_instance_count": _get_key_instance_count(),
		"visible_key_instance_count": _get_visible_key_instance_count(),
		"render_backend": "multimesh" if _strip_visual_root != null else "none",
		"uses_project_owned_assets": _uses_project_owned_assets(),
		"adopted_asset_paths": _adopted_asset_paths.duplicate(),
		"last_completed_run": get_music_road_runtime_state().get("last_completed_run", {}),
	}

func _ensure_runtime_ready() -> void:
	if _definition == null:
		_definition = CityMusicRoadDefinition.load_from_path(DEFAULT_DEFINITION_PATH)
		_run_state.setup(_definition)
	_collect_adopted_asset_paths()
	_ensure_note_player()
	_ensure_adopted_road_texture()
	_ensure_deck_materials()
	_ensure_barrier_visuals()
	_ensure_strip_visuals()
	_apply_visual_phases()

func _collect_adopted_asset_paths() -> void:
	_adopted_asset_paths.clear()
	for path in [ADOPTED_TEXTURE_PATH, ADOPTED_EDGE_BARRIER_SCENE_PATH]:
		if ResourceLoader.exists(path):
			_adopted_asset_paths.append(path)

func _ensure_note_player() -> void:
	if _note_player != null and is_instance_valid(_note_player):
		return
	_note_player = CityMusicRoadNotePlayer.new()
	_note_player.name = "MusicRoadNotePlayer"
	add_child(_note_player)
	_note_player.configure(SAMPLE_BANK_MANIFEST_PATH)

func _ensure_adopted_road_texture() -> void:
	if _adopted_road_texture != null:
		return
	var global_texture_path := ProjectSettings.globalize_path(ADOPTED_TEXTURE_PATH)
	if not FileAccess.file_exists(global_texture_path):
		return
	var image := Image.new()
	if image.load(global_texture_path) != OK:
		return
	_adopted_road_texture = ImageTexture.create_from_image(image)

func _ensure_strip_visuals() -> void:
	if _visuals_built or _definition == null:
		return
	_shared_key_material = _build_shared_key_material()
	_shared_key_mesh = BoxMesh.new()
	_shared_key_mesh.size = Vector3.ONE
	_strip_visual_root = MultiMeshInstance3D.new()
	_strip_visual_root.name = "KeyStrips"
	_strip_visual_root.material_override = _shared_key_material
	_strip_visual_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _shared_key_mesh
	multimesh.instance_count = _definition.get_strip_count()
	multimesh.visible_instance_count = 0
	_strip_visual_root.multimesh = multimesh
	add_child(_strip_visual_root)
	_visuals_built = true
	_refresh_visible_strip_window({}, true)

func _build_shared_key_material() -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	var shader = load(KEY_SHADER_PATH)
	if shader != null:
		shader_material.shader = shader
	return shader_material

func _ensure_deck_materials() -> void:
	var road_deck := get_node_or_null("RoadDeck") as MeshInstance3D
	if road_deck != null:
		road_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		road_deck.material_override = _build_road_material()
	var entry_plate := get_node_or_null("EntryPlate") as MeshInstance3D
	if entry_plate != null:
		entry_plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var entry_material := StandardMaterial3D.new()
		entry_material.albedo_color = Color(0.175, 0.184, 0.209, 1.0)
		entry_material.emission_enabled = true
		entry_material.emission = Color(0.98, 0.84, 0.38, 1.0)
		entry_material.emission_energy_multiplier = 0.22
		entry_plate.material_override = entry_material
	for marker_name in ["EntryMarkerLeft", "EntryMarkerRight"]:
		var marker := get_node_or_null(marker_name) as MeshInstance3D
		if marker == null:
			continue
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var marker_material := StandardMaterial3D.new()
		marker_material.albedo_color = Color(0.98, 0.91, 0.68, 1.0)
		marker_material.emission_enabled = true
		marker_material.emission = Color(1.0, 0.93, 0.48, 1.0)
		marker_material.emission_energy_multiplier = 0.65
		marker.material_override = marker_material

func _build_road_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.roughness = 0.92
	material.albedo_color = Color(0.25, 0.27, 0.29, 1.0)
	var adopted_texture := _adopted_road_texture
	if adopted_texture != null:
		material.albedo_texture = adopted_texture
		material.uv1_scale = Vector3(2.0, 1.0, maxf(float(_definition.get_value("road_length_m", 256.0)) / 64.0, 1.0))
	return material

func _ensure_barrier_visuals() -> void:
	if get_node_or_null("BarrierLeft") != null or get_node_or_null("BarrierRight") != null:
		return
	var road_length_m := float(_definition.get_value("road_length_m", 0.0)) if _definition != null else 0.0
	for barrier_config in [
		{"name": "BarrierLeft", "x": -8.85},
		{"name": "BarrierRight", "x": 8.85},
	]:
		var barrier_mesh := MeshInstance3D.new()
		barrier_mesh.name = str(barrier_config.get("name", "Barrier"))
		barrier_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(RAIL_WIDTH_M, RAIL_HEIGHT_M, maxf(road_length_m, 1.0))
		barrier_mesh.mesh = box_mesh
		barrier_mesh.position = Vector3(float(barrier_config.get("x", 0.0)), RAIL_HEIGHT_M * 0.5, road_length_m * 0.5)
		var barrier_material := StandardMaterial3D.new()
		barrier_material.albedo_color = Color(0.72, 0.74, 0.77, 1.0)
		barrier_material.roughness = 0.82
		barrier_material.metallic = 0.08
		barrier_mesh.material_override = barrier_material
		add_child(barrier_mesh)

func _build_local_vehicle_state(vehicle_state: Dictionary) -> Dictionary:
	var local_position := Vector3.ZERO
	var local_variant = vehicle_state.get("local_position", null)
	if local_variant is Vector3:
		local_position = local_variant
	else:
		var world_variant = vehicle_state.get("world_position", null)
		if world_variant is Vector3:
			local_position = to_local(world_variant)
	return {
		"driving": bool(vehicle_state.get("driving", false)),
		"local_position": local_position,
	}

func _apply_visual_phases() -> void:
	if _strip_visual_root == null or _strip_visual_root.multimesh == null:
		return
	var multimesh := _strip_visual_root.multimesh
	var instance_index := 0
	for cluster_id in _visible_cluster_ids:
		if instance_index >= multimesh.visible_instance_count:
			break
		var member_ids: Array = _visible_cluster_members_by_id.get(cluster_id, [])
		var phase_state := _resolve_cluster_phase(member_ids)
		var strip: Dictionary = _definition.get_strip(cluster_id)
		var key_kind := 1.0 if str(strip.get("visual_key_kind", "white")) == "black" else 0.0
		var encoded_phase_index := clampf(float(phase_state.get("phase_index", 0.0)) / 3.0, 0.0, 1.0)
		var phase_strength := clampf(float(phase_state.get("phase_strength", 0.0)), 0.0, 1.0)
		multimesh.set_instance_custom_data(instance_index, Color(key_kind, encoded_phase_index, phase_strength, 1.0))
		instance_index += 1

func _refresh_visible_strip_window(local_vehicle_state: Dictionary, force: bool = false) -> void:
	if _definition == null or _strip_visual_root == null or _strip_visual_root.multimesh == null:
		return
	var focus_local_z := float(_definition.get_value("lead_in_m", 20.0)) + 12.0
	var local_position_variant = local_vehicle_state.get("local_position", null)
	if local_position_variant is Vector3:
		focus_local_z = float((local_position_variant as Vector3).z)
	if not force:
		if focus_local_z >= _visible_window_min_z + VISIBLE_WINDOW_REBUILD_MARGIN_M \
				and focus_local_z <= _visible_window_max_z - VISIBLE_WINDOW_REBUILD_MARGIN_M:
			return
	var next_min_z := focus_local_z - VISIBLE_WINDOW_BACK_M
	var next_max_z := focus_local_z + VISIBLE_WINDOW_FORWARD_M
	var selected_strips: Array[Dictionary] = []
	for strip_variant in _definition.get_note_strips():
		var strip: Dictionary = strip_variant
		var local_center: Vector3 = strip.get("local_center", Vector3.ZERO)
		if local_center.z < next_min_z or local_center.z > next_max_z:
			continue
		selected_strips.append(strip)
	if selected_strips.is_empty():
		for strip_variant in _definition.get_note_strips().slice(0, min(96, _definition.get_strip_count())):
			selected_strips.append(strip_variant as Dictionary)
	var multimesh := _strip_visual_root.multimesh
	var instance_index := 0
	_visible_cluster_ids.clear()
	_visible_cluster_members_by_id.clear()
	var clusters := _build_visual_clusters(selected_strips)
	for cluster_variant in clusters:
		var cluster: Dictionary = cluster_variant
		var cluster_id := str(cluster.get("cluster_id", ""))
		var center_z := float(cluster.get("center_z", 0.0))
		var cluster_length_m := float(cluster.get("length_m", 1.8))
		var is_black_key := bool(cluster.get("is_black_key", false))
		var visual_width_m := 8.4 if is_black_key else 14.2
		var visual_height_m := 0.18 if is_black_key else 0.14
		var key_center_y := ROAD_SURFACE_TOP_Y + visual_height_m * 0.5 + KEY_SURFACE_CLEARANCE_M + (0.055 if is_black_key else 0.0)
		var transform := Transform3D(
			Basis.IDENTITY.scaled(Vector3(visual_width_m, visual_height_m, cluster_length_m)),
			Vector3(0.0, key_center_y, center_z)
		)
		multimesh.set_instance_transform(instance_index, transform)
		var key_kind := 1.0 if is_black_key else 0.0
		multimesh.set_instance_custom_data(instance_index, Color(key_kind, 0.0, 0.0, 1.0))
		_visible_cluster_ids.append(cluster_id)
		_visible_cluster_members_by_id[cluster_id] = (cluster.get("member_ids", []) as Array).duplicate(true)
		instance_index += 1
	multimesh.visible_instance_count = instance_index
	_visible_window_min_z = next_min_z
	_visible_window_max_z = next_max_z

func _build_visual_clusters(selected_strips: Array[Dictionary]) -> Array[Dictionary]:
	var clusters: Array[Dictionary] = []
	var current_cluster := {}
	for strip in selected_strips:
		var strip_id := str(strip.get("strip_id", ""))
		var local_center: Vector3 = strip.get("local_center", Vector3.ZERO)
		var is_black_key := str(strip.get("visual_key_kind", "white")) == "black"
		if current_cluster.is_empty():
			current_cluster = {
				"cluster_id": strip_id,
				"member_ids": [strip_id],
				"min_z": local_center.z,
				"max_z": local_center.z,
				"center_sum_z": local_center.z,
				"count": 1,
				"black_count": 1 if is_black_key else 0,
			}
			continue
		var cluster_max_z := float(current_cluster.get("max_z", local_center.z))
		if local_center.z - cluster_max_z > VISUAL_CLUSTER_SPACING_M:
			clusters.append(_finalize_visual_cluster(current_cluster))
			current_cluster = {
				"cluster_id": strip_id,
				"member_ids": [strip_id],
				"min_z": local_center.z,
				"max_z": local_center.z,
				"center_sum_z": local_center.z,
				"count": 1,
				"black_count": 1 if is_black_key else 0,
			}
			continue
		var member_ids: Array = current_cluster.get("member_ids", [])
		member_ids.append(strip_id)
		current_cluster["member_ids"] = member_ids
		current_cluster["max_z"] = local_center.z
		current_cluster["center_sum_z"] = float(current_cluster.get("center_sum_z", 0.0)) + local_center.z
		current_cluster["count"] = int(current_cluster.get("count", 0)) + 1
		if is_black_key:
			current_cluster["black_count"] = int(current_cluster.get("black_count", 0)) + 1
	if not current_cluster.is_empty():
		clusters.append(_finalize_visual_cluster(current_cluster))
	return clusters

func _finalize_visual_cluster(cluster: Dictionary) -> Dictionary:
	var min_z: float = float(cluster.get("min_z", 0.0))
	var max_z: float = float(cluster.get("max_z", min_z))
	var count: int = max(int(cluster.get("count", 1)), 1)
	var center_z: float = float(cluster.get("center_sum_z", min_z)) / float(count)
	var length_m: float = clampf((max_z - min_z) + 1.2, 1.4, VISUAL_CLUSTER_MAX_LENGTH_M)
	var black_count: int = int(cluster.get("black_count", 0))
	return {
		"cluster_id": str(cluster.get("cluster_id", "")),
		"member_ids": (cluster.get("member_ids", []) as Array).duplicate(true),
		"center_z": center_z,
		"length_m": length_m,
		"is_black_key": black_count * 2 >= count,
	}

func _resolve_cluster_phase(member_ids: Array) -> Dictionary:
	var best_rank := -1
	var best_phase := {
		"phase": "idle",
		"phase_index": 0,
		"phase_strength": 0.0,
	}
	for member_id_variant in member_ids:
		var phase_state := _run_state.get_strip_phase(str(member_id_variant))
		var phase_name := str(phase_state.get("phase", "idle"))
		var rank := 0
		match phase_name:
			"active":
				rank = 3
			"approach":
				rank = 2
			"decay":
				rank = 1
			_:
				rank = 0
		if rank > best_rank:
			best_rank = rank
			best_phase = phase_state
		elif rank == best_rank and float(phase_state.get("phase_strength", 0.0)) > float(best_phase.get("phase_strength", 0.0)):
			best_phase = phase_state
	return best_phase

func _uses_project_owned_assets() -> bool:
	if _adopted_asset_paths.is_empty():
		return false
	for path in _adopted_asset_paths:
		if not str(path).begins_with("res://city_game/assets/"):
			return false
		if str(path).find("/refs/") >= 0:
			return false
	return true

func _count_visual_instances() -> int:
	var count := 0
	for child in find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual != null and visual.visible:
			count += 1
	return count

func _get_key_instance_count() -> int:
	if _strip_visual_root == null or _strip_visual_root.multimesh == null:
		return 0
	return _strip_visual_root.multimesh.instance_count

func _get_visible_key_instance_count() -> int:
	if _strip_visual_root == null or _strip_visual_root.multimesh == null:
		return 0
	return _strip_visual_root.multimesh.visible_instance_count
