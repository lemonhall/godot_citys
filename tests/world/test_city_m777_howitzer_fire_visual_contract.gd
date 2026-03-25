extends SceneTree

const T := preload("res://tests/_test_util.gd")
const OrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const SAMPLE_YAW_DEG := 100.0
const SAMPLE_PITCH_DEG := 7.0
const MAX_VISUAL_BEARING_DELTA_DEG := 8.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 fire visual contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("set_axis_angles_degrees") and howitzer.has_method("request_fire"), "M777 fire visual contract must instantiate the formal howitzer runtime with live fire controls"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	howitzer.set_axis_angles_degrees(SAMPLE_YAW_DEG, SAMPLE_PITCH_DEG)
	await process_frame
	await process_frame

	var orientation := OrientationScript.new()
	var visible_probe := _resolve_visible_barrel_probe(howitzer)
	var visible_direction_world := visible_probe.get("direction_world", Vector3.ZERO) as Vector3
	var flash_burst := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/FlashBurst") as Node3D
	var smoke_burst := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/SmokeBurst") as Node3D
	var flash_spout := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/FlashBurst/FlashSpout") as Node3D
	var smoke_spout := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/SmokeBurst/SmokeSpout") as Node3D
	if not T.require_true(self, flash_burst != null and smoke_burst != null and flash_spout != null and smoke_spout != null, "M777 fire visual contract requires the rebuilt MuzzleFxRig with authored forward spout meshes"):
		return

	var flash_visual_direction_world := (flash_spout.global_position - flash_burst.global_position).normalized()
	var smoke_visual_direction_world := (smoke_spout.global_position - smoke_burst.global_position).normalized()
	var visible_bearing_deg := float(orientation.bearing_deg_from_world_vector(visible_direction_world))
	var flash_bearing_deg := float(orientation.bearing_deg_from_world_vector(flash_visual_direction_world))
	var smoke_bearing_deg := float(orientation.bearing_deg_from_world_vector(smoke_visual_direction_world))
	var flash_bearing_delta_deg := absf(float(orientation.shortest_bearing_delta_deg(visible_bearing_deg, flash_bearing_deg)))
	var smoke_bearing_delta_deg := absf(float(orientation.shortest_bearing_delta_deg(visible_bearing_deg, smoke_bearing_deg)))

	if not T.require_true(self, flash_bearing_delta_deg <= MAX_VISUAL_BEARING_DELTA_DEG, "Visible muzzle flash geometry must erupt in the same direction as the current barrel bearing instead of extending out of the breech/backside (barrel=%0.2f flash=%0.2f delta=%0.2f)" % [visible_bearing_deg, flash_bearing_deg, flash_bearing_delta_deg]):
		return
	if not T.require_true(self, smoke_bearing_delta_deg <= MAX_VISUAL_BEARING_DELTA_DEG, "Visible muzzle smoke geometry must trail from the same forward barrel direction instead of jetting out behind the weapon (barrel=%0.2f smoke=%0.2f delta=%0.2f)" % [visible_bearing_deg, smoke_bearing_deg, smoke_bearing_delta_deg]):
		return

	howitzer.queue_free()
	await physics_frame
	await process_frame
	await physics_frame
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
