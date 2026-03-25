extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const SAMPLE_LOCAL_YAW_DEG := 100.0
const LOW_PITCH_DEG := 0.0
const HIGH_PITCH_DEG := 30.0
const MAX_VISIBLE_PITCH_DELTA_DEG := 8.0
const MIN_VISIBLE_BARREL_LENGTH_M := 4.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 visual pitch contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null, "M777 visual pitch contract must instantiate the formal howitzer runtime"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	var low_probe := await _capture_visible_barrel_probe(howitzer, LOW_PITCH_DEG)
	var high_probe := await _capture_visible_barrel_probe(howitzer, HIGH_PITCH_DEG)
	var low_length_m := float(low_probe.get("length_m", 0.0))
	var high_length_m := float(high_probe.get("length_m", 0.0))
	var low_visible_pitch_deg := float(low_probe.get("pitch_deg", 0.0))
	var high_visible_pitch_deg := float(high_probe.get("pitch_deg", 0.0))
	var low_pitch_delta_deg := absf(low_visible_pitch_deg - LOW_PITCH_DEG)
	var high_pitch_delta_deg := absf(high_visible_pitch_deg - HIGH_PITCH_DEG)

	if not T.require_true(self, low_length_m >= MIN_VISIBLE_BARREL_LENGTH_M and high_length_m >= MIN_VISIBLE_BARREL_LENGTH_M, "Visible M777 barrel pitch probe must resolve a meaningful long-axis muzzle direction instead of collapsing onto a short local face (low_length=%0.3f high_length=%0.3f)" % [low_length_m, high_length_m]):
		return
	if not T.require_true(self, low_pitch_delta_deg <= MAX_VISIBLE_PITCH_DELTA_DEG, "At 0° displayed pitch, the visible M777 barrel must stay near level instead of already sitting nose-up (displayed=%0.2f visible=%0.2f delta=%0.2f)" % [LOW_PITCH_DEG, low_visible_pitch_deg, low_pitch_delta_deg]):
		return
	if not T.require_true(self, high_pitch_delta_deg <= MAX_VISIBLE_PITCH_DELTA_DEG, "At 30° displayed pitch, the visible M777 barrel must visually lift by roughly the same amount instead of drifting toward another elevation band (displayed=%0.2f visible=%0.2f delta=%0.2f)" % [HIGH_PITCH_DEG, high_visible_pitch_deg, high_pitch_delta_deg]):
		return
	if not T.require_true(self, high_visible_pitch_deg > low_visible_pitch_deg + 10.0, "Increasing displayed pitch from 0° to 30° must raise the visible barrel instead of lowering it or leaving it nearly unchanged (visible_low=%0.2f visible_high=%0.2f)" % [low_visible_pitch_deg, high_visible_pitch_deg]):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _capture_visible_barrel_probe(howitzer: Node3D, pitch_deg: float) -> Dictionary:
	howitzer.set_axis_angles_degrees(SAMPLE_LOCAL_YAW_DEG, pitch_deg)
	await process_frame
	await process_frame
	return _resolve_visible_barrel_probe(howitzer)

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
	var normalized_direction := direction_world.normalized()
	var visible_pitch_deg := rad_to_deg(asin(clampf(normalized_direction.y, -1.0, 1.0))) if direction_world.length_squared() > 0.0001 else 0.0
	return {
		"direction_world": normalized_direction,
		"length_m": direction_world.length(),
		"pitch_deg": visible_pitch_deg,
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
