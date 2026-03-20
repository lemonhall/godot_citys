extends Node3D

const CityBuildingCrackRuntime := preload("res://city_game/combat/buildings/CityBuildingCrackRuntime.gd")
const CityBuildingCollapseRuntime := preload("res://city_game/combat/buildings/CityBuildingCollapseRuntime.gd")

signal state_changed(state: Dictionary)

@export var max_health := 10000.0
@export_range(0.1, 0.95, 0.01) var damaged_threshold_ratio := 0.60
@export_range(0.01, 0.5, 0.01) var collapse_threshold_ratio := 0.05
@export var building_damage_multiplier := 240.0
@export var minimum_explosion_damage := 320.0

var _building_id := ""
var _current_health := 10000.0
var _damage_state := "intact"
var _last_hit_world_position := Vector3.ZERO
var _last_hit_local_position := Vector3.ZERO
var _service_scene_root: Node3D = null
var _generated_building: StaticBody3D = null
var _body_collision_shapes: Array[CollisionShape3D] = []
var _primary_body_size := Vector3(14.0, 66.0, 14.0)
var _primary_half_extents := Vector3(7.0, 33.0, 7.0)
var _main_color := Color(0.72, 0.74, 0.78, 1.0)
var _crack_runtime: Node3D = null
var _collapse_runtime: Node3D = null
var _fracture_requested := false
var _collapse_pending := false

func _ready() -> void:
	_current_health = max_health
	_resolve_building_nodes()
	_resolve_building_identity()
	_resolve_building_visual_profile()
	_install_runtime_helpers()
	add_to_group("city_destructible_building")
	set_meta("city_building_id", _building_id)

func get_state() -> Dictionary:
	return {
		"building_id": _building_id,
		"max_health": max_health,
		"current_health": _current_health,
		"last_hit_world_position": _last_hit_world_position,
		"last_hit_local_position": _last_hit_local_position,
		"damage_state": _damage_state,
	}

func get_debug_state() -> Dictionary:
	var crack_state: Dictionary = {}
	if _crack_runtime != null and _crack_runtime.has_method("get_debug_state"):
		crack_state = (_crack_runtime.call("get_debug_state") as Dictionary).duplicate(true)
	var collapse_state: Dictionary = {}
	if _collapse_runtime != null and _collapse_runtime.has_method("get_debug_state"):
		collapse_state = (_collapse_runtime.call("get_debug_state") as Dictionary).duplicate(true)
	return {
		"building_visible": _generated_building != null and is_instance_valid(_generated_building) and _generated_building.visible,
		"crack_visual_active": bool(crack_state.get("visual_active", false)),
		"fracture_recipe_ready": bool(collapse_state.get("recipe_ready", false)),
		"fracture_prepare_in_progress": bool(collapse_state.get("prepare_in_progress", false)),
		"collapse_active": bool(collapse_state.get("collapse_active", false)),
		"dynamic_chunk_count": int(collapse_state.get("dynamic_chunk_count", 0)),
		"residual_base_visible": bool(collapse_state.get("residual_base_visible", false)),
		"cleanup_delay_sec": float(collapse_state.get("cleanup_delay_sec", 0.0)),
		"recipe_unique_size_count": int(collapse_state.get("recipe_unique_size_count", 0)),
		"residual_base_height_m": float(collapse_state.get("residual_base_height_m", 0.0)),
		"chunk_face_count_min": int(collapse_state.get("chunk_face_count_min", 0)),
		"chunk_face_count_max": int(collapse_state.get("chunk_face_count_max", 0)),
		"recipe_preserves_building_envelope": bool(collapse_state.get("recipe_preserves_building_envelope", false)),
		"impact_zone_smallest_volume_m3": float(collapse_state.get("impact_zone_smallest_volume_m3", 0.0)),
		"far_zone_average_volume_m3": float(collapse_state.get("far_zone_average_volume_m3", 0.0)),
	}

func get_primary_target_world_position() -> Vector3:
	if _generated_building == null or not is_instance_valid(_generated_building):
		return global_position
	return _generated_building.global_transform.origin

func apply_explosion_damage(world_position: Vector3, damage: float, radius_m: float) -> Dictionary:
	if _generated_building == null or not is_instance_valid(_generated_building):
		return {"accepted": false, "reason": "missing_building"}
	if _damage_state == "collapsing" or _damage_state == "collapsed":
		return {"accepted": false, "reason": "already_collapsed"}
	var local_point := _generated_building.to_local(world_position)
	var closest_local := _clamp_to_body(local_point)
	var distance_to_body := local_point.distance_to(closest_local)
	if distance_to_body > maxf(radius_m, 0.001):
		return {"accepted": false, "reason": "out_of_range"}
	var falloff := 1.0 - distance_to_body / maxf(radius_m, 0.001)
	var scaled_damage := maxf(damage * building_damage_multiplier * falloff, minimum_explosion_damage * falloff)
	return apply_damage(scaled_damage, _generated_building.to_global(closest_local))

func apply_damage(amount: float, hit_world_position: Vector3) -> Dictionary:
	if amount <= 0.0:
		return {"accepted": false, "reason": "non_positive_damage"}
	if _damage_state == "collapsing" or _damage_state == "collapsed":
		return {"accepted": false, "reason": "already_collapsed"}
	_last_hit_world_position = hit_world_position
	_last_hit_local_position = _generated_building.to_local(hit_world_position) if _generated_building != null else Vector3.ZERO
	_current_health = maxf(_current_health - amount, 0.0)
	if _damage_state == "intact":
		_damage_state = "damaged"
	if _current_health <= _damaged_threshold_health():
		_show_crack()
		_begin_fracture_prepare()
	if _current_health <= _collapse_threshold_health():
		_collapse_pending = true
		_try_start_collapse()
	_emit_state_changed()
	return {
		"accepted": true,
		"current_health": _current_health,
		"damage_state": _damage_state,
	}

func _resolve_building_nodes() -> void:
	_service_scene_root = _find_service_scene_root(self)
	if _service_scene_root == null:
		_service_scene_root = get_node_or_null("ServiceBuildingRoot") as Node3D
	_generated_building = _find_generated_building(_service_scene_root)
	_body_collision_shapes.clear()
	if _generated_building == null:
		return
	for child in _generated_building.get_children():
		var collision := child as CollisionShape3D
		if collision != null:
			_body_collision_shapes.append(collision)
			if collision.shape is BoxShape3D:
				_primary_body_size = (collision.shape as BoxShape3D).size
				_primary_half_extents = _primary_body_size * 0.5
				break

func _resolve_building_identity() -> void:
	if _service_scene_root != null and _service_scene_root.has_meta("city_building_id"):
		_building_id = str(_service_scene_root.get_meta("city_building_id", ""))
	if _building_id == "" and _generated_building != null and _generated_building.has_meta("city_building_id"):
		_building_id = str(_generated_building.get_meta("city_building_id", ""))

func _resolve_building_visual_profile() -> void:
	if _generated_building == null:
		return
	for child in _generated_building.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance == null:
			continue
		var material := mesh_instance.material_override as StandardMaterial3D
		if material != null:
			_main_color = material.albedo_color
			return

func _install_runtime_helpers() -> void:
	_crack_runtime = get_node_or_null("CrackRuntime") as Node3D
	if _crack_runtime == null:
		_crack_runtime = CityBuildingCrackRuntime.new()
		_crack_runtime.name = "CrackRuntime"
		add_child(_crack_runtime)
	if _generated_building != null and _crack_runtime.has_method("configure"):
		_crack_runtime.call("configure", _generated_building.transform)

	_collapse_runtime = get_node_or_null("CollapseRuntime") as Node3D
	if _collapse_runtime == null:
		_collapse_runtime = CityBuildingCollapseRuntime.new()
		_collapse_runtime.name = "CollapseRuntime"
		add_child(_collapse_runtime)
	if _collapse_runtime == null:
		return
	if _collapse_runtime.has_signal("fracture_prepared"):
		var prepared_callable := Callable(self, "_on_fracture_prepared")
		if not _collapse_runtime.fracture_prepared.is_connected(prepared_callable):
			_collapse_runtime.fracture_prepared.connect(prepared_callable)
	if _collapse_runtime.has_signal("collapse_finished"):
		var finished_callable := Callable(self, "_on_collapse_finished")
		if not _collapse_runtime.collapse_finished.is_connected(finished_callable):
			_collapse_runtime.collapse_finished.connect(finished_callable)
	if _collapse_runtime.has_signal("cleanup_completed"):
		var cleanup_callable := Callable(self, "_on_cleanup_completed")
		if not _collapse_runtime.cleanup_completed.is_connected(cleanup_callable):
			_collapse_runtime.cleanup_completed.connect(cleanup_callable)

func _show_crack() -> void:
	if _crack_runtime == null or not _crack_runtime.has_method("show_crack"):
		return
	_crack_runtime.call("show_crack", _last_hit_local_position, _primary_half_extents)

func _begin_fracture_prepare() -> void:
	if _fracture_requested or _collapse_runtime == null or not _collapse_runtime.has_method("begin_prepare"):
		return
	_fracture_requested = true
	_damage_state = "fracture_preparing"
	_collapse_runtime.call("begin_prepare", {
		"building_id": _building_id,
		"source_transform": _generated_building.transform if _generated_building != null else Transform3D.IDENTITY,
		"body_size": _primary_body_size,
		"hit_local_position": _last_hit_local_position,
		"main_color": _main_color,
	})

func _try_start_collapse() -> void:
	if _collapse_runtime == null or not _collapse_runtime.has_method("has_recipe_ready"):
		return
	if not bool(_collapse_runtime.call("has_recipe_ready")):
		return
	if _damage_state == "collapsing" or _damage_state == "collapsed":
		return
	_set_original_building_visible(false)
	_damage_state = "collapsing"
	_collapse_pending = false
	_collapse_runtime.call("start_collapse")

func _set_original_building_visible(is_visible_value: bool) -> void:
	if _generated_building == null or not is_instance_valid(_generated_building):
		return
	_generated_building.visible = is_visible_value
	for collision in _body_collision_shapes:
		if collision == null or not is_instance_valid(collision):
			continue
		collision.disabled = not is_visible_value

func _on_fracture_prepared(_summary: Dictionary) -> void:
	if _current_health <= _collapse_threshold_health() or _collapse_pending:
		_try_start_collapse()
		return
	_damage_state = "collapse_ready"
	_emit_state_changed()

func _on_collapse_finished(_summary: Dictionary) -> void:
	_damage_state = "collapsed"
	_emit_state_changed()

func _on_cleanup_completed(_summary: Dictionary) -> void:
	_emit_state_changed()

func _emit_state_changed() -> void:
	state_changed.emit(get_state())

func _damaged_threshold_health() -> float:
	return max_health * damaged_threshold_ratio

func _collapse_threshold_health() -> float:
	return max_health * collapse_threshold_ratio

func _clamp_to_body(local_point: Vector3) -> Vector3:
	return Vector3(
		clampf(local_point.x, -_primary_half_extents.x, _primary_half_extents.x),
		clampf(local_point.y, -_primary_half_extents.y, _primary_half_extents.y),
		clampf(local_point.z, -_primary_half_extents.z, _primary_half_extents.z)
	)

func _find_service_scene_root(root: Node) -> Node3D:
	if root == null:
		return null
	if root is Node3D and root.has_meta("city_service_scene_root"):
		return root as Node3D
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var resolved := _find_service_scene_root(child_node)
		if resolved != null:
			return resolved
	return null

func _find_generated_building(root: Node) -> StaticBody3D:
	if root == null:
		return null
	if root is StaticBody3D and root.has_meta("city_generated_building"):
		return root as StaticBody3D
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var resolved := _find_generated_building(child_node)
		if resolved != null:
			return resolved
	return null
