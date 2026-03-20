extends Node3D

signal fracture_prepared(summary: Dictionary)
signal collapse_started(summary: Dictionary)
signal collapse_finished(summary: Dictionary)
signal cleanup_completed(summary: Dictionary)

const CityBuildingFractureRecipeBuilder := preload("res://city_game/combat/buildings/CityBuildingFractureRecipeBuilder.gd")

@export var collapse_settle_delay_sec := 1.4
@export var debris_cleanup_delay_sec := 5.5

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
	return {
		"prepare_in_progress": _prepare_in_progress,
		"recipe_ready": _recipe_ready,
		"collapse_active": _collapse_active,
		"collapse_finished": _collapse_finished_flag,
		"cleanup_done": _cleanup_done,
		"dynamic_chunk_count": _count_live_dynamic_chunks(),
		"residual_base_visible": _residual_base != null and is_instance_valid(_residual_base) and _residual_base.visible,
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
		mesh_instance.material_override = chunk_material
		body.add_child(mesh_instance)
		_collapse_root.add_child(body)
		var impulse_direction: Vector3 = chunk.get("impulse_direction", Vector3.UP)
		var impulse_speed := float(chunk.get("impulse_speed", 6.0))
		body.linear_velocity = impulse_direction * impulse_speed
		body.angular_velocity = (chunk.get("angular_axis", Vector3.UP) as Vector3) * float(chunk.get("angular_speed", 1.2))
		_dynamic_chunks.append(body)

func _build_chunk_material(albedo_color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo_color
	material.roughness = 1.0
	return material

func _cleanup_dynamic_chunks() -> void:
	for body in _dynamic_chunks:
		if body != null and is_instance_valid(body):
			body.queue_free()
	_dynamic_chunks.clear()

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
