extends Node3D

const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")

static var _shared_catalog: RefCounted = null

var _catalog: CityVehicleVisualCatalog = null
var _selected_entry: Dictionary = {}
var _model_root: Node3D = null

static func prewarm_shared_catalog() -> void:
	if _shared_catalog == null:
		_shared_catalog = CityVehicleVisualCatalog.new()

func setup(catalog: CityVehicleVisualCatalog = null) -> void:
	_catalog = catalog if catalog != null else _get_catalog()

func apply_state(state, chunk_center: Vector3) -> void:
	var catalog := _catalog if _catalog != null else _get_catalog()
	var entry := catalog.select_entry_for_state(state)
	_ensure_visual_entry(catalog, entry)
	_apply_transform(state, chunk_center, catalog, entry)

func get_model_id() -> String:
	return str(_selected_entry.get("model_id", ""))

func uses_placeholder_box_mesh() -> bool:
	return _model_root == null

func _ensure_visual_entry(catalog: CityVehicleVisualCatalog, entry: Dictionary) -> void:
	var next_model_id := str(entry.get("model_id", ""))
	var current_model_id := str(_selected_entry.get("model_id", ""))
	if next_model_id != "" and current_model_id == next_model_id and _model_root != null and is_instance_valid(_model_root):
		return
	if _model_root != null and is_instance_valid(_model_root):
		_model_root.queue_free()
	_model_root = null
	_selected_entry = entry.duplicate(true)
	if entry.is_empty():
		return
	var model_root := catalog.instantiate_scene_for_entry(entry)
	if model_root == null:
		return
	_model_root = model_root
	_model_root.name = "Model"
	add_child(_model_root)

func _apply_transform(state, chunk_center: Vector3, catalog: CityVehicleVisualCatalog, entry: Dictionary) -> void:
	var world_position := _state_world_position(state)
	var local_position := world_position - chunk_center
	var heading := _state_heading(state)
	heading.y = 0.0
	if heading.length_squared() <= 0.0001:
		heading = Vector3.FORWARD
	heading = heading.normalized()
	position = local_position
	rotation.y = atan2(heading.x, heading.z)
	if _model_root == null:
		return
	var runtime_scale := catalog.resolve_runtime_scale(entry)
	var ground_offset_m := catalog.resolve_ground_offset_m(entry)
	_model_root.scale = Vector3.ONE * runtime_scale
	_model_root.position = Vector3(0.0, ground_offset_m * runtime_scale, 0.0)

func _state_world_position(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("world_position", Vector3.ZERO)
	return state.world_position if state != null else Vector3.ZERO

func _state_heading(state) -> Vector3:
	if state is Dictionary:
		return (state as Dictionary).get("heading", Vector3.FORWARD)
	return state.heading if state != null else Vector3.FORWARD

func _get_catalog() -> CityVehicleVisualCatalog:
	if _shared_catalog == null:
		_shared_catalog = CityVehicleVisualCatalog.new()
	return _shared_catalog as CityVehicleVisualCatalog
