extends Node3D

signal fracture_prepared(summary: Dictionary)
signal collapse_started(summary: Dictionary)
signal collapse_finished(summary: Dictionary)
signal cleanup_completed(summary: Dictionary)

const CityBuildingFractureRecipeBuilder := preload("res://city_game/combat/buildings/CityBuildingFractureRecipeBuilder.gd")

@export var collapse_settle_delay_sec := 1.4
@export var debris_sleep_delay_sec := 10.0
@export var debris_cleanup_delay_sec := 30.0

var _prepare_thread: Thread = null
var _prepare_in_progress := false
var _prepare_pending_result: Dictionary = {}
var _prepare_request: Dictionary = {}
var _fracture_recipe: Dictionary = {}
var _recipe_ready := false
var _collapse_root: Node3D = null
var _residual_base: StaticBody3D = null
var _dynamic_chunks: Array[RigidBody3D] = []
var _collapse_active := false
var _collapse_finished_flag := false
var _cleanup_done := false
var _collapse_elapsed_sec := 0.0
var _dynamic_chunks_stabilized := false
var _explosion_impulse_enabled := false
var _impact_zone_average_launch_speed_mps := 0.0
var _far_zone_average_launch_speed_mps := 0.0
var _impact_zone_average_blast_alignment := 0.0

func _ready() -> void:
	set_process(true)

func _exit_tree() -> void:
	if _prepare_thread != null:
		var thread_result: Variant = _prepare_thread.wait_to_finish()
		if thread_result is Dictionary:
			_prepare_pending_result = (thread_result as Dictionary).duplicate(true)
		_prepare_thread = null

func begin_prepare(request: Dictionary) -> Dictionary:
	if _prepare_in_progress:
		return {"accepted": false, "reason": "prepare_in_progress"}
	if _recipe_ready:
		return {"accepted": false, "reason": "recipe_ready"}
	_prepare_request = request.duplicate(true)
	var thread := Thread.new()
	var start_error := thread.start(Callable(self, "_run_prepare_thread").bind(_prepare_request.duplicate(true)))
	if start_error != OK:
		_prepare_pending_result = _run_prepare_thread(_prepare_request.duplicate(true))
		_prepare_in_progress = false
	else:
		_prepare_thread = thread
		_prepare_in_progress = true
	return {
		"accepted": true,
		"started_async": start_error == OK,
	}

func has_recipe_ready() -> bool:
	return _recipe_ready

func is_prepare_in_progress() -> bool:
	return _prepare_in_progress

func get_recipe_summary() -> Dictionary:
	return {
		"recipe_ready": _recipe_ready,
		"dynamic_chunk_count": int(_fracture_recipe.get("dynamic_chunk_count", 0)),
		"impact_side": str(_fracture_recipe.get("impact_side", "")),
	}

func get_debug_state() -> Dictionary:
	var dynamic_chunk_metrics := _build_dynamic_chunk_metrics()
	return {
		"prepare_in_progress": _prepare_in_progress,
		"recipe_ready": _recipe_ready,
		"collapse_active": _collapse_active,
		"collapse_finished": _collapse_finished_flag,
		"cleanup_done": _cleanup_done,
		"dynamic_chunk_count": int(dynamic_chunk_metrics.get("dynamic_chunk_count", 0)),
		"dynamic_chunk_sleeping_count": int(dynamic_chunk_metrics.get("dynamic_chunk_sleeping_count", 0)),
		"dynamic_chunk_mesh_instance_count": int(dynamic_chunk_metrics.get("dynamic_chunk_mesh_instance_count", 0)),
		"dynamic_chunk_collision_shape_count": int(dynamic_chunk_metrics.get("dynamic_chunk_collision_shape_count", 0)),
		"dynamic_chunk_shadow_caster_count": int(dynamic_chunk_metrics.get("dynamic_chunk_shadow_caster_count", 0)),
		"dynamic_chunk_total_linear_speed_mps": float(dynamic_chunk_metrics.get("dynamic_chunk_total_linear_speed_mps", 0.0)),
		"dynamic_chunk_peak_linear_speed_mps": float(dynamic_chunk_metrics.get("dynamic_chunk_peak_linear_speed_mps", 0.0)),
		"dynamic_chunk_sleeping_ratio": float(dynamic_chunk_metrics.get("dynamic_chunk_sleeping_ratio", 0.0)),
		"dynamic_chunk_airborne_count": int(dynamic_chunk_metrics.get("dynamic_chunk_airborne_count", 0)),
		"dynamic_chunk_sleeping_airborne_count": int(dynamic_chunk_metrics.get("dynamic_chunk_sleeping_airborne_count", 0)),
		"residual_base_visible": _residual_base != null and is_instance_valid(_residual_base) and _residual_base.visible,
		"debris_sleep_delay_sec": debris_sleep_delay_sec,
		"cleanup_delay_sec": debris_cleanup_delay_sec,
		"recipe_unique_size_count": int(_fracture_recipe.get("unique_size_count", 0)),
		"residual_base_height_m": float((_fracture_recipe.get("base_size", Vector3.ZERO) as Vector3).y),
		"explosion_impulse_enabled": _explosion_impulse_enabled,
		"impact_zone_average_launch_speed_mps": _impact_zone_average_launch_speed_mps,
		"far_zone_average_launch_speed_mps": _far_zone_average_launch_speed_mps,
		"impact_zone_average_blast_alignment": _impact_zone_average_blast_alignment,
		"chunk_face_count_min": int(_fracture_recipe.get("chunk_face_count_min", 0)),
		"chunk_face_count_max": int(_fracture_recipe.get("chunk_face_count_max", 0)),
		"recipe_preserves_building_envelope": bool(_fracture_recipe.get("preserves_building_envelope", false)),
		"impact_zone_smallest_volume_m3": float(_fracture_recipe.get("impact_zone_smallest_volume_m3", 0.0)),
		"far_zone_average_volume_m3": float(_fracture_recipe.get("far_zone_average_volume_m3", 0.0)),
	}

func start_collapse() -> Dictionary:
	if not _recipe_ready:
		return {"accepted": false, "reason": "recipe_not_ready"}
	if _collapse_active:
		return {"accepted": false, "reason": "collapse_active"}
	_clear_collapse_nodes()
	_spawn_residual_base()
	_spawn_dynamic_chunks()
	_collapse_active = true
	_collapse_finished_flag = false
	_cleanup_done = false
	_collapse_elapsed_sec = 0.0
	_dynamic_chunks_stabilized = false
	var summary := {
		"accepted": true,
		"dynamic_chunk_count": _count_live_dynamic_chunks(),
	}
	collapse_started.emit(summary.duplicate(true))
	return summary

func _process(delta: float) -> void:
	_collect_prepare_result()
	if not _collapse_active:
		return
	_collapse_elapsed_sec += maxf(delta, 0.0)
	if not _dynamic_chunks_stabilized and _collapse_elapsed_sec >= debris_sleep_delay_sec:
		_stabilize_dynamic_chunks()
		_dynamic_chunks_stabilized = true
	if not _collapse_finished_flag and _collapse_elapsed_sec >= collapse_settle_delay_sec:
		_collapse_finished_flag = true
		collapse_finished.emit({
			"dynamic_chunk_count": _count_live_dynamic_chunks(),
		})
	if not _cleanup_done and _collapse_elapsed_sec >= collapse_settle_delay_sec + debris_cleanup_delay_sec:
		_cleanup_dynamic_chunks()
		_cleanup_done = true
		cleanup_completed.emit({
			"dynamic_chunk_count": _count_live_dynamic_chunks(),
		})

func _collect_prepare_result() -> void:
	if _prepare_thread != null:
		if _prepare_thread.is_alive():
			return
		var thread_result: Variant = _prepare_thread.wait_to_finish()
		_prepare_thread = null
		if thread_result is Dictionary:
			_prepare_pending_result = (thread_result as Dictionary).duplicate(true)
	if _prepare_pending_result.is_empty():
		return
	var result := _prepare_pending_result.duplicate(true)
	_prepare_pending_result.clear()
	_prepare_in_progress = false
	if not bool(result.get("success", false)):
		return
	_fracture_recipe = result.duplicate(true)
	_recipe_ready = true
	fracture_prepared.emit(get_recipe_summary())

func _run_prepare_thread(request: Dictionary) -> Dictionary:
	return CityBuildingFractureRecipeBuilder.build_recipe(request)

func _spawn_residual_base() -> void:
	var base_size: Vector3 = _fracture_recipe.get("base_size", Vector3(10.0, 3.0, 10.0))
	var base_center: Vector3 = _fracture_recipe.get("base_center", Vector3.ZERO)
	var base_color: Color = Color(_prepare_request.get("main_color", Color(0.58, 0.56, 0.52, 1.0))) * Color(0.82, 0.82, 0.82, 1.0)
	_residual_base = StaticBody3D.new()
	_residual_base.name = "ResidualBase"
	add_child(_residual_base)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = base_size
	collision.shape = shape
	_residual_base.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = base_size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _build_chunk_material(base_color)
	_residual_base.add_child(mesh_instance)
	_residual_base.transform = Transform3D(Basis.IDENTITY, base_center)

func _spawn_dynamic_chunks() -> void:
	_collapse_root = Node3D.new()
	_collapse_root.name = "CollapseRoot"
	_collapse_root.transform = _prepare_request.get("source_transform", Transform3D.IDENTITY)
	add_child(_collapse_root)
	var chunk_color := Color(_prepare_request.get("main_color", Color(0.72, 0.74, 0.78, 1.0)))
	var chunk_material := _build_chunk_material(chunk_color)
	var explosion_center: Vector3 = _fracture_recipe.get("hit_local_position", Vector3.ZERO)
	var body_size: Vector3 = _fracture_recipe.get("body_size", Vector3.ONE)
	var half_extents := body_size * 0.5
	var base_height_m := float(_fracture_recipe.get("base_height_m", 0.0))
	var impact_launch_speed_sum := 0.0
	var impact_alignment_sum := 0.0
	var impact_count := 0
	var far_launch_speed_sum := 0.0
	var far_count := 0
	_explosion_impulse_enabled = false
	_impact_zone_average_launch_speed_mps = 0.0
	_far_zone_average_launch_speed_mps = 0.0
	_impact_zone_average_blast_alignment = 0.0
	for chunk_variant in _fracture_recipe.get("chunks", []):
		var chunk: Dictionary = chunk_variant
		var body := RigidBody3D.new()
		body.name = "DynamicChunk"
		body.mass = clampf(float((chunk.get("size", Vector3.ONE) as Vector3).length()) * 0.25, 1.0, 8.0)
		body.linear_damp = 0.12
		body.angular_damp = 0.04
		body.position = chunk.get("center", Vector3.ZERO)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		var size: Vector3 = chunk.get("size", Vector3.ONE)
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		var mesh_instance := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = size
		mesh_instance.mesh = mesh
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh_instance.material_override = chunk_material
		body.add_child(mesh_instance)
		_collapse_root.add_child(body)
		var impulse_direction: Vector3 = chunk.get("impulse_direction", Vector3.UP)
		var impulse_speed := float(chunk.get("impulse_speed", 6.0))
		var chunk_center: Vector3 = chunk.get("center", Vector3.ZERO)
		var impact_distance_norm := float(chunk.get("impact_distance_norm", chunk_center.distance_to(explosion_center) / maxf(body_size.length(), 0.001)))
		var launch_metrics := _build_explosion_launch_velocity(chunk, explosion_center, impulse_direction * impulse_speed, half_extents, base_height_m, impact_distance_norm)
		var launch_velocity: Vector3 = launch_metrics.get("launch_velocity", impulse_direction * impulse_speed)
		var blast_speed := float(launch_metrics.get("blast_speed", 0.0))
		var blast_alignment := float(launch_metrics.get("blast_alignment", 0.0))
		body.linear_velocity = launch_velocity
		body.angular_velocity = (chunk.get("angular_axis", Vector3.UP) as Vector3) * float(chunk.get("angular_speed", 1.2))
		_dynamic_chunks.append(body)
		if blast_speed > 0.01:
			_explosion_impulse_enabled = true
		if impact_distance_norm <= 0.22:
			impact_launch_speed_sum += launch_velocity.length()
			impact_alignment_sum += blast_alignment
			impact_count += 1
		elif impact_distance_norm >= 0.35:
			far_launch_speed_sum += launch_velocity.length()
			far_count += 1
	if impact_count > 0:
		_impact_zone_average_launch_speed_mps = impact_launch_speed_sum / float(impact_count)
		_impact_zone_average_blast_alignment = impact_alignment_sum / float(impact_count)
	if far_count > 0:
		_far_zone_average_launch_speed_mps = far_launch_speed_sum / float(far_count)

func _build_chunk_material(albedo_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo_color
	material.roughness = 1.0
	return material

func _build_explosion_launch_velocity(chunk: Dictionary, explosion_center: Vector3, base_velocity: Vector3, half_extents: Vector3, base_height_m: float, impact_distance_norm: float) -> Dictionary:
	var chunk_center: Vector3 = chunk.get("center", Vector3.ZERO)
	var outward_vector := chunk_center - explosion_center
	if outward_vector.length_squared() <= 0.0001:
		outward_vector = chunk.get("impulse_direction", Vector3.UP)
	var outward_direction := outward_vector.normalized()
	var near_alpha := pow(1.0 - clampf(impact_distance_norm / 0.62, 0.0, 1.0), 1.35)
	var height_alpha := clampf((chunk_center.y + half_extents.y) / maxf(half_extents.y * 2.0, 0.001), 0.0, 1.0)
	var base_line_y := -half_extents.y + base_height_m
	var base_clearance_alpha := clampf((chunk_center.y - (base_line_y - 1.2)) / maxf(base_height_m * 0.9, 1.0), 0.18, 1.0)
	var favored_bonus := 1.14 if bool(chunk.get("impact_favored", false)) else 1.0
	var blast_direction := (outward_direction + Vector3.UP * lerpf(0.18, 0.44, near_alpha)).normalized()
	var blast_speed := near_alpha * 11.5 * lerpf(0.45, 1.0, height_alpha) * base_clearance_alpha * favored_bonus
	var launch_velocity := base_velocity + blast_direction * blast_speed
	var blast_alignment := maxf(launch_velocity.normalized().dot(outward_direction), 0.0) if launch_velocity.length_squared() > 0.0001 else 0.0
	return {
		"launch_velocity": launch_velocity,
		"blast_speed": blast_speed,
		"blast_alignment": blast_alignment,
	}

func _cleanup_dynamic_chunks() -> void:
	for body in _dynamic_chunks:
		if body != null and is_instance_valid(body):
			body.queue_free()
	_dynamic_chunks.clear()
	_dynamic_chunks_stabilized = false
	_explosion_impulse_enabled = false
	_impact_zone_average_launch_speed_mps = 0.0
	_far_zone_average_launch_speed_mps = 0.0
	_impact_zone_average_blast_alignment = 0.0

func _clear_collapse_nodes() -> void:
	_cleanup_dynamic_chunks()
	if _residual_base != null and is_instance_valid(_residual_base):
		_residual_base.queue_free()
	_residual_base = null
	if _collapse_root != null and is_instance_valid(_collapse_root):
		_collapse_root.queue_free()
	_collapse_root = null

func _count_live_dynamic_chunks() -> int:
	var live_count := 0
	for body in _dynamic_chunks:
		if body != null and is_instance_valid(body):
			live_count += 1
	return live_count

func _stabilize_dynamic_chunks() -> void:
	for body in _dynamic_chunks:
		if body == null or not is_instance_valid(body):
			continue
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = true

func _build_dynamic_chunk_metrics() -> Dictionary:
	var live_count := 0
	var sleeping_count := 0
	var mesh_instance_count := 0
	var collision_shape_count := 0
	var shadow_caster_count := 0
	var total_linear_speed_mps := 0.0
	var peak_linear_speed_mps := 0.0
	var airborne_count := 0
	var sleeping_airborne_count := 0
	var base_size: Vector3 = _fracture_recipe.get("base_size", Vector3.ZERO)
	var base_center: Vector3 = _fracture_recipe.get("base_center", Vector3.ZERO)
	var base_top_y := base_center.y + base_size.y * 0.5
	for body in _dynamic_chunks:
		if body == null or not is_instance_valid(body):
			continue
		live_count += 1
		if body.sleeping:
			sleeping_count += 1
		var linear_speed_mps := body.linear_velocity.length()
		total_linear_speed_mps += linear_speed_mps
		peak_linear_speed_mps = maxf(peak_linear_speed_mps, linear_speed_mps)
		for child in body.get_children():
			var child_node := child as Node
			if child_node == null:
				continue
			if child_node is CollisionShape3D:
				collision_shape_count += 1
			elif child_node is MeshInstance3D:
				mesh_instance_count += 1
				var mesh_instance := child_node as MeshInstance3D
				if mesh_instance.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					shadow_caster_count += 1
		var half_height := _resolve_dynamic_chunk_half_height(body)
		var bottom_y := body.position.y - half_height
		if bottom_y > base_top_y + 0.25:
			airborne_count += 1
			if body.sleeping:
				sleeping_airborne_count += 1
	var sleeping_ratio := float(sleeping_count) / float(live_count) if live_count > 0 else 0.0
	return {
		"dynamic_chunk_count": live_count,
		"dynamic_chunk_sleeping_count": sleeping_count,
		"dynamic_chunk_mesh_instance_count": mesh_instance_count,
		"dynamic_chunk_collision_shape_count": collision_shape_count,
		"dynamic_chunk_shadow_caster_count": shadow_caster_count,
		"dynamic_chunk_total_linear_speed_mps": total_linear_speed_mps,
		"dynamic_chunk_peak_linear_speed_mps": peak_linear_speed_mps,
		"dynamic_chunk_sleeping_ratio": sleeping_ratio,
		"dynamic_chunk_airborne_count": airborne_count,
		"dynamic_chunk_sleeping_airborne_count": sleeping_airborne_count,
	}

func _resolve_dynamic_chunk_half_height(body: RigidBody3D) -> float:
	for child in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null or collision.shape == null:
			continue
		if collision.shape is BoxShape3D:
			return (collision.shape as BoxShape3D).size.y * 0.5
	return 0.5
