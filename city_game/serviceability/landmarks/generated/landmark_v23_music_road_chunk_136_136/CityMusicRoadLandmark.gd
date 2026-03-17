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

var _music_road_entry: Dictionary = {}
var _definition = null
var _run_state := CityMusicRoadRunState.new()
var _note_player = null
var _strip_visual_root: MultiMeshInstance3D = null
var _strip_instance_index_by_id: Dictionary = {}
var _strip_key_kind_by_id: Dictionary = {}
var _visuals_built := false
var _shared_key_material: ShaderMaterial = null
var _shared_key_mesh: BoxMesh = null
var _adopted_asset_paths: Array[String] = []
var _adopted_road_texture: Texture2D = null
var _configured_landmark_id := ""
var _configured_definition_path := ""

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
	_strip_visual_root.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _shared_key_mesh
	multimesh.instance_count = _definition.get_strip_count()
	_strip_visual_root.multimesh = multimesh
	add_child(_strip_visual_root)
	var instance_index := 0
	for strip in _definition.get_note_strips():
		var strip_id := str(strip.get("strip_id", ""))
		var local_center: Vector3 = strip.get("local_center", Vector3.ZERO)
		var is_black_key := str(strip.get("visual_key_kind", "white")) == "black"
		var visual_width_m := maxf(float(strip.get("visual_width_m", 1.0)) * (1.18 if is_black_key else 1.52), 2.8 if is_black_key else 4.2)
		var visual_length_m := maxf(float(strip.get("visual_length_m", 1.0)) * (1.08 if is_black_key else 1.24), 1.34 if is_black_key else 1.56)
		var visual_height_m := 0.18 if is_black_key else 0.14
		var key_center_y := ROAD_SURFACE_TOP_Y + visual_height_m * 0.5 + KEY_SURFACE_CLEARANCE_M + (0.055 if is_black_key else 0.0)
		var transform := Transform3D(
			Basis.IDENTITY.scaled(Vector3(visual_width_m, visual_height_m, visual_length_m)),
			Vector3(local_center.x, maxf(local_center.y, key_center_y), local_center.z)
		)
		multimesh.set_instance_transform(instance_index, transform)
		var key_kind := 1.0 if is_black_key else 0.0
		multimesh.set_instance_custom_data(instance_index, Color(key_kind, 0.0, 0.0, 1.0))
		_strip_instance_index_by_id[strip_id] = instance_index
		_strip_key_kind_by_id[strip_id] = key_kind
		instance_index += 1
	_visuals_built = true

func _build_shared_key_material() -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	var shader = load(KEY_SHADER_PATH)
	if shader != null:
		shader_material.shader = shader
	return shader_material

func _ensure_deck_materials() -> void:
	var road_deck := get_node_or_null("RoadDeck") as MeshInstance3D
	if road_deck != null:
		road_deck.material_override = _build_road_material()
	var entry_plate := get_node_or_null("EntryPlate") as MeshInstance3D
	if entry_plate != null:
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
	if not ResourceLoader.exists(ADOPTED_EDGE_BARRIER_SCENE_PATH):
		return
	var barrier_scene = load(ADOPTED_EDGE_BARRIER_SCENE_PATH)
	if barrier_scene == null or not (barrier_scene is PackedScene):
		return
	var road_length_m := float(_definition.get_value("road_length_m", 0.0)) if _definition != null else 0.0
	for barrier_config in [
		{"name": "BarrierLeft", "x": -8.85, "rotation_y": PI},
		{"name": "BarrierRight", "x": 8.85, "rotation_y": 0.0},
	]:
		var path := Path3D.new()
		path.name = str(barrier_config.get("name", "Barrier"))
		path.position = Vector3(float(barrier_config.get("x", 0.0)), 0.25, 0.0)
		var curve := Curve3D.new()
		curve.add_point(Vector3.ZERO)
		curve.add_point(Vector3(0.0, 0.0, road_length_m))
		path.curve = curve
		var barrier = (barrier_scene as PackedScene).instantiate()
		barrier.rotation.y = float(barrier_config.get("rotation_y", 0.0))
		path.add_child(barrier)
		add_child(path)

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
	for strip_id_variant in _strip_instance_index_by_id.keys():
		var strip_id := str(strip_id_variant)
		var instance_index := int(_strip_instance_index_by_id.get(strip_id, -1))
		if instance_index < 0 or instance_index >= multimesh.instance_count:
			continue
		var phase_state := _run_state.get_strip_phase(strip_id)
		var key_kind := float(_strip_key_kind_by_id.get(strip_id, 0.0))
		var encoded_phase_index := clampf(float(phase_state.get("phase_index", 0.0)) / 3.0, 0.0, 1.0)
		var phase_strength := clampf(float(phase_state.get("phase_strength", 0.0)), 0.0, 1.0)
		multimesh.set_instance_custom_data(instance_index, Color(key_kind, encoded_phase_index, phase_strength, 1.0))

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
