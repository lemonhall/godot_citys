extends SceneTree

const T := preload("res://tests/_test_util.gd")
const OrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const SAMPLE_LOCAL_YAW_DEG := 260.0
const SAMPLE_PITCH_DEG := 7.0
const MAX_VISIBLE_BEARING_DELTA_DEG := 8.0
const MIN_VISIBLE_BARREL_LENGTH_M := 4.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 visual yaw contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null, "M777 visual yaw contract must instantiate the formal howitzer runtime"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	var orientation := OrientationScript.new()
	howitzer.set_axis_angles_degrees(SAMPLE_LOCAL_YAW_DEG, SAMPLE_PITCH_DEG)
	await process_frame
	await process_frame

	var firing_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	var expected_world_bearing_deg := float(firing_solution.get("world_bearing_deg", 0.0))
	var visible_probe := _resolve_visible_barrel_probe(howitzer)
	var visible_length_m := float(visible_probe.get("length_m", 0.0))
	var visible_direction_world := visible_probe.get("direction_world", Vector3.ZERO) as Vector3
	var visible_world_bearing_deg := float(orientation.bearing_deg_from_world_vector(visible_direction_world))
	var visible_bearing_delta_deg := absf(float(orientation.shortest_bearing_delta_deg(expected_world_bearing_deg, visible_world_bearing_deg)))

	if not T.require_true(self, visible_length_m >= MIN_VISIBLE_BARREL_LENGTH_M, "Visible M777 barrel probe must resolve a meaningful long-axis muzzle direction instead of collapsing onto a short local corner (length=%0.3f)" % visible_length_m):
		return
	if not T.require_true(self, visible_bearing_delta_deg <= MAX_VISIBLE_BEARING_DELTA_DEG, "Visible M777 barrel yaw must visually agree with the current firing-solution bearing instead of pointing off toward the opposite side of the battery (solution=%0.2f visible=%0.2f delta=%0.2f local_yaw=%0.2f)" % [expected_world_bearing_deg, visible_world_bearing_deg, visible_bearing_delta_deg, SAMPLE_LOCAL_YAW_DEG]):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _resolve_visible_barrel_probe(howitzer: Node3D) -> Dictionary:
	var pitch_pivot := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot") as Node3D
	var gun_assembly := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/m777_gun_assembly") as VisualInstance3D
	if pitch_pivot == null or gun_assembly == null:
		return {}
	var pivot_world_position := pitch_pivot.global_position
	var aabb := gun_assembly.get_aabb()
	var axis_index := _resolve_long_axis_index(aabb.size)
	var local_tip_point := _resolve_forward_face_center_local(aabb, gun_assembly.transform, axis_index)
	var world_tip_point: Vector3 = gun_assembly.global_transform * local_tip_point
	var direction_world := world_tip_point - pivot_world_position
	return {
		"direction_world": direction_world.normalized(),
		"length_m": direction_world.length(),
	}

func _resolve_long_axis_index(size: Vector3) -> int:
	if size.y >= size.x and size.y >= size.z:
		return 1
	if size.z >= size.x and size.z >= size.y:
		return 2
	return 0

func _resolve_forward_face_center_local(aabb: AABB, local_transform: Transform3D, axis_index: int) -> Vector3:
	var local_face_min := aabb.position + aabb.size * 0.5
	var local_face_max := local_face_min
	match axis_index:
		0:
			local_face_min.x = aabb.position.x
			local_face_max.x = aabb.position.x + aabb.size.x
		1:
			local_face_min.y = aabb.position.y
			local_face_max.y = aabb.position.y + aabb.size.y
		2:
			local_face_min.z = aabb.position.z
			local_face_max.z = aabb.position.z + aabb.size.z
	var parent_face_min: Vector3 = local_transform * local_face_min
	var parent_face_max: Vector3 = local_transform * local_face_max
	if parent_face_max.length_squared() >= parent_face_min.length_squared():
		return local_face_max
	return local_face_min
