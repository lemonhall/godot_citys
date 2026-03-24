extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const HOWITZER_SCRIPT_PATH := "res://city_game/combat/artillery/CityM777Howitzer.gd"
const HOWITZER_MODEL_PATH := "res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb"
const FIRE_AUDIO_PATH := "res://city_game/combat/helicopter/audio/rockt-explosions.wav"
const MIN_PRESENTED_LENGTH_M := 6.0
const EXPECTED_PITCH_ZERO_OFFSET_DEG := 14.7
const MIN_ELEVATION_DEG := 0.0
const MAX_ELEVATION_DEG := 71.0
const EXPECTED_FIRE_COOLDOWN_SEC := 6.0
const WRAPPED_YAW_SAMPLE_DEG := 523.11
const WRAPPED_YAW_EXPECTED_DEG := 163.11

const REQUIRED_NODE_PATHS := [
	"ModelRoot",
	"ModelRoot/LowerBaseMount",
	"ModelRoot/YawPivot",
	"ModelRoot/YawPivot/PitchPivot",
	"Anchors",
	"Anchors/YawPivotAnchor",
	"Anchors/PitchPivotAnchor",
	"Anchors/MuzzleFxAnchor",
	"Anchors/LanyardAnchor",
	"ModelRoot/LowerBaseMount/m777_lower_base",
	"ModelRoot/YawPivot/m777_upper_carriage",
	"ModelRoot/YawPivot/PitchPivot/m777_gun_assembly",
	"ModelRoot/YawPivot/PitchPivot/FirePresentationRoot",
	"ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFlash",
	"ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleSmoke",
	"ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/Lanyard",
	"ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/LanyardLine",
	"ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/FireAudio",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(HOWITZER_SCENE_PATH, "PackedScene"), "M777 howitzer contract requires a dedicated authored CityM777Howitzer.tscn scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(HOWITZER_SCRIPT_PATH, "Script"), "M777 howitzer contract requires a dedicated runtime script alongside the authored scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(HOWITZER_MODEL_PATH, "PackedScene"), "M777 howitzer contract requires the formal split three-part GLB under the artillery source directory"):
		return

	var scene_text := FileAccess.get_file_as_string(HOWITZER_SCENE_PATH)
	if not T.require_true(self, scene_text.find(HOWITZER_MODEL_PATH) >= 0, "M777 howitzer scene must wrap m777_3_parts.glb through the .tscn instead of rebuilding visuals from code"):
		return
	if not T.require_true(self, scene_text.find("[node name=\"YawPivotAnchor\"") >= 0, "M777 howitzer scene must author YawPivotAnchor as a formal Marker3D"):
		return
	if not T.require_true(self, scene_text.find("[node name=\"PitchPivotAnchor\"") >= 0, "M777 howitzer scene must author PitchPivotAnchor as a formal Marker3D"):
		return
	if not T.require_true(self, scene_text.find("[node name=\"MuzzleFxAnchor\"") >= 0, "M777 howitzer scene must author MuzzleFxAnchor so formal fire presentation has a stable muzzle reference"):
		return
	if not T.require_true(self, scene_text.find("[node name=\"LanyardAnchor\"") >= 0, "M777 howitzer scene must author LanyardAnchor so the pull-lanyard presentation is not hard-coded in script"):
		return

	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 howitzer contract must load CityM777Howitzer.tscn as PackedScene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null, "M777 howitzer contract must instantiate as Node3D"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	for required_method in [
		"get_visual_root",
		"set_yaw_degrees",
		"set_pitch_degrees",
		"set_axis_angles_degrees",
		"get_yaw_degrees",
		"get_pitch_degrees",
		"get_anchor_state",
		"can_fire",
		"request_fire",
		"get_fire_state",
		"get_debug_state",
	]:
		if not T.require_true(self, howitzer.has_method(required_method), "M777 howitzer root must expose %s()" % required_method):
			return

	for node_path in REQUIRED_NODE_PATHS:
		if not T.require_true(self, howitzer.get_node_or_null(node_path) != null, "M777 howitzer scene must author %s in the runtime hierarchy" % node_path):
			return

	var visual_root := howitzer.get_visual_root() as Node3D
	if not T.require_true(self, visual_root != null and visual_root.name == "ModelRoot", "M777 howitzer contract must expose ModelRoot as the visual root"):
		return

	var presented_length_m := _measure_presented_length_m(visual_root)
	if not T.require_true(
		self,
		presented_length_m >= MIN_PRESENTED_LENGTH_M,
		"M777 howitzer formal scene must normalize the AI-generated tiny source asset into a world-scale artillery platform instead of leaving it at toy size (presented=%.3fm min=%.3fm)" % [
			presented_length_m,
			MIN_PRESENTED_LENGTH_M,
		]
	):
		return

	var anchor_state := howitzer.get_anchor_state() as Dictionary
	if not T.require_true(self, anchor_state.get("yaw_anchor_local_position", null) is Vector3, "M777 howitzer anchor state must expose yaw_anchor_local_position as Vector3"):
		return
	if not T.require_true(self, anchor_state.get("pitch_anchor_local_position", null) is Vector3, "M777 howitzer anchor state must expose pitch_anchor_local_position as Vector3"):
		return
	if not T.require_true(self, anchor_state.get("muzzle_anchor_local_position", null) is Vector3, "M777 howitzer anchor state must expose muzzle_anchor_local_position as Vector3 for formal fire presentation tuning"):
		return
	if not T.require_true(self, anchor_state.get("lanyard_anchor_local_position", null) is Vector3, "M777 howitzer anchor state must expose lanyard_anchor_local_position as Vector3 for formal pull-lanyard tuning"):
		return

	var yaw_pivot := howitzer.get_node("ModelRoot/YawPivot") as Node3D
	var pitch_pivot := howitzer.get_node("ModelRoot/YawPivot/PitchPivot") as Node3D
	var yaw_before := yaw_pivot.rotation.y
	var pitch_before := pitch_pivot.rotation.x

	howitzer.set_axis_angles_degrees(18.0, 12.0)
	await process_frame

	if not T.require_true(self, absf(yaw_pivot.rotation.y - deg_to_rad(18.0)) <= 0.001, "M777 howitzer yaw API must drive the dedicated YawPivot node around the vertical axis"):
		return
	if not T.require_true(self, absf(howitzer.get_pitch_degrees() - 12.0) <= 0.001, "M777 howitzer pitch API must expose calibrated elevation degrees instead of leaking the model's internal raw pivot rotation"):
		return
	if not T.require_true(self, absf(pitch_pivot.rotation.x - deg_to_rad(EXPECTED_PITCH_ZERO_OFFSET_DEG - 12.0)) <= 0.001, "M777 howitzer positive pitch must raise the barrel, so the raw PitchPivot rotation must move opposite to the calibrated elevation value after applying the zero offset"):
		return
	if not T.require_true(self, absf(yaw_pivot.rotation.y - yaw_before) > 0.01, "M777 howitzer yaw API must visibly change yaw pivot rotation"):
		return
	if not T.require_true(self, absf(pitch_pivot.rotation.x - pitch_before) > 0.01, "M777 howitzer pitch API must visibly change pitch pivot rotation"):
		return

	howitzer.set_yaw_degrees(WRAPPED_YAW_SAMPLE_DEG)
	await process_frame
	if not T.require_true(self, absf(howitzer.get_yaw_degrees() - WRAPPED_YAW_EXPECTED_DEG) <= 0.01, "M777 howitzer yaw must wrap back into the 0-360 degree circle instead of accumulating beyond one full turn"):
		return
	if not T.require_true(self, absf(rad_to_deg(yaw_pivot.rotation.y) - WRAPPED_YAW_EXPECTED_DEG) <= 0.01, "M777 howitzer wrapped yaw must still drive YawPivot using the normalized circle angle instead of the raw accumulated turn count"):
		return
	howitzer.set_yaw_degrees(360.0)
	await process_frame
	if not T.require_true(self, absf(howitzer.get_yaw_degrees()) <= 0.01, "M777 howitzer yaw must resolve an exact 360 degree turn back to 0 instead of exposing a redundant full-turn state"):
		return

	howitzer.set_pitch_degrees(-18.0)
	await process_frame
	if not T.require_true(self, absf(howitzer.get_pitch_degrees() - MIN_ELEVATION_DEG) <= 0.001, "M777 howitzer pitch must clamp to 0 degrees instead of allowing negative depression below the current weapon's authored lower bound"):
		return
	if not T.require_true(self, absf(pitch_pivot.rotation.x - deg_to_rad(EXPECTED_PITCH_ZERO_OFFSET_DEG)) <= 0.001, "M777 howitzer clamped zero elevation must still preserve the model calibration offset on PitchPivot"):
		return

	howitzer.set_pitch_degrees(100.0)
	await process_frame
	if not T.require_true(self, absf(howitzer.get_pitch_degrees() - MAX_ELEVATION_DEG) <= 0.001, "M777 howitzer pitch must clamp to the 71 degree upper elevation limit instead of allowing unrealistic over-elevation"):
		return
	if not T.require_true(self, absf(pitch_pivot.rotation.x - deg_to_rad(EXPECTED_PITCH_ZERO_OFFSET_DEG - MAX_ELEVATION_DEG)) <= 0.001, "M777 howitzer upper elevation clamp must still preserve the correct sign convention, meaning larger elevation raises the barrel instead of lowering it"):
		return

	var debug_state := howitzer.get_debug_state() as Dictionary
	if not T.require_true(self, str(debug_state.get("source_asset_path", "")) == HOWITZER_MODEL_PATH, "M777 howitzer debug state must preserve the wrapped three-part GLB path"):
		return
	if not T.require_true(self, bool(debug_state.get("lower_base_present", false)), "M777 howitzer debug state must confirm the lower base mesh is mounted under the formal wrapper scene"):
		return
	if not T.require_true(self, bool(debug_state.get("upper_carriage_present", false)), "M777 howitzer debug state must confirm the upper carriage mesh is mounted under YawPivot"):
		return
	if not T.require_true(self, bool(debug_state.get("gun_assembly_present", false)), "M777 howitzer debug state must confirm the gun assembly mesh is mounted under PitchPivot"):
		return
	if not T.require_true(self, absf(float(debug_state.get("pitch_zero_offset_deg", 0.0)) - EXPECTED_PITCH_ZERO_OFFSET_DEG) <= 0.001, "M777 howitzer debug state must expose the model-specific pitch zero calibration offset so authored tuning is inspectable"):
		return
	var pitch_limits := debug_state.get("pitch_limits_deg", {}) as Dictionary
	if not T.require_true(self, absf(float(pitch_limits.get("min", -999.0)) - MIN_ELEVATION_DEG) <= 0.001 and absf(float(pitch_limits.get("max", -999.0)) - MAX_ELEVATION_DEG) <= 0.001, "M777 howitzer debug state must expose the calibrated elevation clamp range"):
		return
	var fire_state := howitzer.get_fire_state() as Dictionary
	if not T.require_true(self, bool(fire_state.get("can_fire", false)), "Fresh M777 howitzer runtime must report can_fire=true before any accepted shot"):
		return
	if not T.require_true(self, absf(float(fire_state.get("cooldown_duration_sec", 0.0)) - EXPECTED_FIRE_COOLDOWN_SEC) <= 0.001, "M777 howitzer fire contract must freeze the default cooldown at 6.0s"):
		return
	var weapon_fire_audio := debug_state.get("weapon_fire_audio", {}) as Dictionary
	if not T.require_true(self, bool(weapon_fire_audio.get("stream_bound", false)), "M777 howitzer debug state must confirm the formal weapon fire audio stream is bound"):
		return
	if not T.require_true(self, str(weapon_fire_audio.get("stream_path", "")) == FIRE_AUDIO_PATH, "M777 howitzer formal weapon fire audio must point at the frozen current artillery placeholder stream"):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _measure_presented_length_m(root_node: Node) -> float:
	var visuals: Array = []
	_collect_visuals(root_node, visuals)
	var has_any := false
	var merged := AABB()
	for visual_variant in visuals:
		var visual := visual_variant as VisualInstance3D
		if visual == null:
			continue
		var visual_aabb := visual.get_aabb()
		if visual_aabb.size == Vector3.ZERO:
			continue
		var world_aabb := _transform_aabb(visual.global_transform, visual_aabb)
		if not has_any:
			merged = world_aabb
			has_any = true
		else:
			merged = merged.merge(world_aabb)
	if not has_any:
		return 0.0
	return maxf(merged.size.x, maxf(merged.size.y, merged.size.z))

func _collect_visuals(node: Node, visuals: Array) -> void:
	if node is VisualInstance3D:
		visuals.append(node)
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_collect_visuals(child_node, visuals)

func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var corners := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	var first_corner: Vector3 = transform * corners[0]
	var min_corner := first_corner
	var max_corner := first_corner
	for corner in corners:
		var transformed_corner: Vector3 = transform * corner
		min_corner = Vector3(
			minf(min_corner.x, transformed_corner.x),
			minf(min_corner.y, transformed_corner.y),
			minf(min_corner.z, transformed_corner.z)
		)
		max_corner = Vector3(
			maxf(max_corner.x, transformed_corner.x),
			maxf(max_corner.y, transformed_corner.y),
			maxf(max_corner.z, transformed_corner.z)
		)
	return AABB(min_corner, max_corner - min_corner)
