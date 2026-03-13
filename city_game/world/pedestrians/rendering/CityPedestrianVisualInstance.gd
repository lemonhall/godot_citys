extends Node3D

const CityPedestrianVisualCatalog := preload("res://city_game/world/pedestrians/rendering/CityPedestrianVisualCatalog.gd")

const DEFAULT_SOURCE_HEIGHT_M := 1.75

static var _shared_catalog: RefCounted = null

var _selected_entry: Dictionary = {}
var _model_root: Node3D = null
var _animation_player: AnimationPlayer = null
var _current_animation_name := ""
var _uses_placeholder_box_mesh := false

static func prewarm_shared_catalog() -> void:
	if _shared_catalog == null:
		_shared_catalog = CityPedestrianVisualCatalog.new()

func apply_state(state, chunk_center: Vector3) -> void:
	var catalog := _get_catalog()
	var entry := catalog.select_entry_for_state(state)
	_ensure_visual_entry(catalog, entry)
	_apply_transform(state, chunk_center)
	_apply_animation(catalog, state)

func get_current_animation_name() -> String:
	return _current_animation_name

func uses_placeholder_box_mesh() -> bool:
	return _uses_placeholder_box_mesh

func get_animation_player() -> AnimationPlayer:
	return _animation_player

func get_model_id() -> String:
	return str(_selected_entry.get("model_id", ""))

func _ensure_visual_entry(catalog: CityPedestrianVisualCatalog, entry: Dictionary) -> void:
	var next_model_id := str(entry.get("model_id", ""))
	var current_model_id := str(_selected_entry.get("model_id", ""))
	if next_model_id != "" and current_model_id == next_model_id and _model_root != null and is_instance_valid(_model_root):
		return
	if _model_root != null and is_instance_valid(_model_root):
		_model_root.queue_free()
	_model_root = null
	_animation_player = null
	_selected_entry = entry.duplicate(true)
	_current_animation_name = ""
	_uses_placeholder_box_mesh = false
	if entry.is_empty():
		return
	var model_root := catalog.instantiate_scene_for_entry(entry)
	if model_root == null:
		_uses_placeholder_box_mesh = true
		return
	_model_root = model_root
	_model_root.name = "Model"
	add_child(_model_root)
	_animation_player = catalog.resolve_cached_animation_player(_model_root, entry)
	_uses_placeholder_box_mesh = catalog.entry_uses_placeholder_box_mesh(entry)

func _apply_transform(state, chunk_center: Vector3) -> void:
	var world_position := _state_world_position(state)
	var local_position := world_position - chunk_center
	var heading := _state_heading(state)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	position = local_position
	rotation.y = atan2(heading.x, heading.z)
	if _model_root != null:
		# source_height_m is calibrated from live skeleton bounds so rigs with misleading mesh AABBs still normalize correctly.
		var source_height_m := maxf(float(_selected_entry.get("source_height_m", DEFAULT_SOURCE_HEIGHT_M)), 0.001)
		var target_visual_height_m := _resolve_target_visual_height_m(state)
		var height_scale := maxf(target_visual_height_m / source_height_m, 0.01)
		var source_ground_offset_m := float(_selected_entry.get("source_ground_offset_m", 0.0))
		_model_root.scale = Vector3.ONE * height_scale
		_model_root.position = Vector3(0.0, source_ground_offset_m * height_scale, 0.0)

func _apply_animation(catalog: CityPedestrianVisualCatalog, state) -> void:
	if _animation_player == null:
		_current_animation_name = ""
		return
	var next_animation := catalog.resolve_animation_name(_selected_entry, state)
	if next_animation == "":
		_current_animation_name = ""
		return
	var is_death_animation := catalog.animation_name_has_any_token(next_animation, ["death", "dead"])
	if next_animation != _current_animation_name:
		_animation_player.play(next_animation)
		_current_animation_name = next_animation
		return
	if not _animation_player.is_playing() and not is_death_animation:
		_animation_player.play(next_animation)
		_current_animation_name = next_animation

func _state_world_position(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("world_position", Vector3.ZERO)
	return state.world_position if state != null else Vector3.ZERO

func _state_heading(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("heading", Vector3.FORWARD)
	return state.heading if state != null else Vector3.FORWARD

func _state_height_m(state) -> float:
	if state is Dictionary:
		return float((state as Dictionary).get("height_m", DEFAULT_SOURCE_HEIGHT_M))
	return float(state.height_m) if state != null else DEFAULT_SOURCE_HEIGHT_M

func _resolve_target_visual_height_m(state) -> float:
	var manifest_target_height_m := float(_selected_entry.get("visual_target_height_m", 0.0))
	if manifest_target_height_m > 0.0:
		return manifest_target_height_m
	return _state_height_m(state)

func _get_catalog() -> CityPedestrianVisualCatalog:
	if _shared_catalog == null:
		_shared_catalog = CityPedestrianVisualCatalog.new()
	return _shared_catalog as CityPedestrianVisualCatalog
