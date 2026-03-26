extends SceneTree

const T := preload("res://tests/_test_util.gd")

const RUNTIME_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDogControlRuntime.tscn"
const MIN_REAR_CAMERA_DOT := 0.72
const MAX_SIDE_CAMERA_DOT := 0.28
const MIN_DOG_LENGTH_M := 3.0
const MAX_DOG_LENGTH_M := 5.4
const MIN_DOG_HEIGHT_M := 1.6
const MAX_DOG_HEIGHT_M := 3.1
const MIN_CAMERA_HEIGHT_ABOVE_CENTER_M := 2.1
const MIN_CAMERA_DOWNLOOK_DEG := 24.0
const MAX_CAMERA_DOWNLOOK_DEG := 38.0
const MAX_FOOT_GROUND_OFFSET_M := 0.08

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(RUNTIME_SCENE_PATH, "PackedScene"), "Robot dog presentation contract requires CityRobotDogControlRuntime.tscn"):
		return
	var scene := load(RUNTIME_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog presentation contract must load CityRobotDogControlRuntime as PackedScene"):
		return

	var stage := Node3D.new()
	root.add_child(stage)
	stage.add_child(_build_ground())

	var runtime := scene.instantiate() as CharacterBody3D
	stage.add_child(runtime)
	await process_frame
	await process_frame

	if not T.require_true(self, runtime.has_method("activate_at"), "Robot dog presentation contract requires activate_at() on the control runtime"):
		return
	if not T.require_true(self, runtime.has_method("get_visual_robot_dog"), "Robot dog presentation contract requires get_visual_robot_dog() on the control runtime"):
		return

	runtime.activate_at(Vector3.ZERO, 0.0)
	await _settle_frames(12)

	var visual_robot_dog := runtime.get_visual_robot_dog() as Node3D
	var camera := runtime.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, visual_robot_dog != null and visual_robot_dog.has_method("get_joint_anchor_state"), "Robot dog presentation contract requires joint anchor introspection on the formal visual dog scene"):
		return
	if not T.require_true(self, camera != null, "Robot dog presentation contract requires the formal chase camera node"):
		return

	var presentation_metrics := _measure_presentation(visual_robot_dog, camera)
	if not T.require_true(self, float(presentation_metrics.get("camera_rear_dot", 0.0)) >= MIN_REAR_CAMERA_DOT, "Robot dog chase camera must sit behind the dog's rear axis instead of mostly seeing a side profile"):
		return
	if not T.require_true(self, absf(float(presentation_metrics.get("camera_side_dot", 1.0))) <= MAX_SIDE_CAMERA_DOT, "Robot dog chase camera must not be offset to the dog's flank like a side-view camera"):
		return
	if not T.require_true(self, float(presentation_metrics.get("dog_length_m", 0.0)) >= MIN_DOG_LENGTH_M and float(presentation_metrics.get("dog_length_m", 0.0)) <= MAX_DOG_LENGTH_M, "Robot dog presentation scale must stay within the formal size envelope instead of spawning oversized"):
		return
	if not T.require_true(self, float(presentation_metrics.get("dog_height_m", 0.0)) >= MIN_DOG_HEIGHT_M and float(presentation_metrics.get("dog_height_m", 0.0)) <= MAX_DOG_HEIGHT_M, "Robot dog presentation height must stay within the formal size envelope instead of spawning oversized"):
		return
	if not T.require_true(self, float(presentation_metrics.get("camera_height_above_center_m", 0.0)) >= MIN_CAMERA_HEIGHT_ABOVE_CENTER_M, "Robot dog chase camera must sit clearly above the dog's body center instead of hugging a low side-on profile"):
		return
	if not T.require_true(self, float(presentation_metrics.get("camera_downlook_deg", 0.0)) >= MIN_CAMERA_DOWNLOOK_DEG and float(presentation_metrics.get("camera_downlook_deg", 0.0)) <= MAX_CAMERA_DOWNLOOK_DEG, "Robot dog chase camera must keep a deliberate 20-30 degree style downlook instead of a flatter eye-line"):
		return
	if not T.require_true(self, absf(float(presentation_metrics.get("foot_ground_offset_m", 999.0))) <= MAX_FOOT_GROUND_OFFSET_M, "Robot dog visible feet must land close to the ground plane instead of visibly floating or burying into terrain"):
		return

	stage.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _build_ground() -> StaticBody3D:
	var ground := StaticBody3D.new()
	var collision_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80.0, 2.0, 80.0)
	collision_shape.shape = shape
	collision_shape.position = Vector3(0.0, -1.0, 0.0)
	ground.add_child(collision_shape)
	return ground

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _measure_presentation(visual_robot_dog: Node3D, camera: Camera3D) -> Dictionary:
	var anchor_state: Dictionary = visual_robot_dog.get_joint_anchor_state()
	var front_left: Vector3 = (anchor_state.get("lf_hip", {}) as Dictionary).get("global_position", Vector3.ZERO)
	var front_right: Vector3 = (anchor_state.get("rf_hip", {}) as Dictionary).get("global_position", Vector3.ZERO)
	var rear_left: Vector3 = (anchor_state.get("lr_hip", {}) as Dictionary).get("global_position", Vector3.ZERO)
	var rear_right: Vector3 = (anchor_state.get("rr_hip", {}) as Dictionary).get("global_position", Vector3.ZERO)
	var front_mid := (front_left + front_right) * 0.5
	var rear_mid := (rear_left + rear_right) * 0.5
	var forward_axis := (front_mid - rear_mid).normalized()
	var rear_axis := -forward_axis
	var dog_center := (front_mid + rear_mid) * 0.5
	var camera_direction := (camera.global_position - dog_center).normalized()
	var camera_to_center := dog_center - camera.global_position
	var camera_to_center_horizontal_len := Vector2(camera_to_center.x, camera_to_center.z).length()
	var bounds: Dictionary = _measure_visual_bounds(visual_robot_dog)
	var bounds_size: Vector3 = bounds.get("size", Vector3.ZERO)
	var min_y := float(bounds.get("min_y", 0.0))
	return {
		"camera_rear_dot": camera_direction.dot(rear_axis),
		"camera_side_dot": camera_direction.dot((front_right - front_left).normalized()),
		"camera_height_above_center_m": camera.global_position.y - dog_center.y,
		"camera_downlook_deg": rad_to_deg(atan2(absf(camera_to_center.y), maxf(camera_to_center_horizontal_len, 0.001))),
		"dog_length_m": maxf(bounds_size.x, bounds_size.z),
		"dog_height_m": bounds_size.y,
		"foot_ground_offset_m": min_y,
	}

func _measure_visual_bounds(visual_robot_dog: Node3D) -> Dictionary:
	var mesh_nodes: Array = visual_robot_dog.find_children("*", "MeshInstance3D", true, false)
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	for node_variant in mesh_nodes:
		var mesh_node := node_variant as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var aabb := mesh_node.get_aabb()
		for corner in _aabb_corners(aabb):
			var world_corner: Vector3 = mesh_node.global_transform * corner
			min_corner.x = minf(min_corner.x, world_corner.x)
			min_corner.y = minf(min_corner.y, world_corner.y)
			min_corner.z = minf(min_corner.z, world_corner.z)
			max_corner.x = maxf(max_corner.x, world_corner.x)
			max_corner.y = maxf(max_corner.y, world_corner.y)
			max_corner.z = maxf(max_corner.z, world_corner.z)
	return {
		"size": max_corner - min_corner,
		"min_y": min_corner.y,
	}

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]
