extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const HOWITZER_SCRIPT_PATH := "res://city_game/combat/artillery/CityM777Howitzer.gd"
const HOWITZER_MODEL_PATH := "res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb"

const REQUIRED_NODE_PATHS := [
	"ModelRoot",
	"ModelRoot/LowerBaseMount",
	"ModelRoot/YawPivot",
	"ModelRoot/YawPivot/PitchPivot",
	"Anchors",
	"Anchors/YawPivotAnchor",
	"Anchors/PitchPivotAnchor",
	"ModelRoot/LowerBaseMount/m777_lower_base",
	"ModelRoot/YawPivot/m777_upper_carriage",
	"ModelRoot/YawPivot/PitchPivot/m777_gun_assembly",
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

	var anchor_state := howitzer.get_anchor_state() as Dictionary
	if not T.require_true(self, anchor_state.get("yaw_anchor_local_position", null) is Vector3, "M777 howitzer anchor state must expose yaw_anchor_local_position as Vector3"):
		return
	if not T.require_true(self, anchor_state.get("pitch_anchor_local_position", null) is Vector3, "M777 howitzer anchor state must expose pitch_anchor_local_position as Vector3"):
		return

	var yaw_pivot := howitzer.get_node("ModelRoot/YawPivot") as Node3D
	var pitch_pivot := howitzer.get_node("ModelRoot/YawPivot/PitchPivot") as Node3D
	var yaw_before := yaw_pivot.rotation.y
	var pitch_before := pitch_pivot.rotation.x

	howitzer.set_axis_angles_degrees(18.0, -7.0)
	await process_frame

	if not T.require_true(self, absf(yaw_pivot.rotation.y - deg_to_rad(18.0)) <= 0.001, "M777 howitzer yaw API must drive the dedicated YawPivot node around the vertical axis"):
		return
	if not T.require_true(self, absf(pitch_pivot.rotation.x - deg_to_rad(-7.0)) <= 0.001, "M777 howitzer pitch API must drive the dedicated PitchPivot node instead of rotating the whole upper assembly root"):
		return
	if not T.require_true(self, absf(yaw_pivot.rotation.y - yaw_before) > 0.01, "M777 howitzer yaw API must visibly change yaw pivot rotation"):
		return
	if not T.require_true(self, absf(pitch_pivot.rotation.x - pitch_before) > 0.01, "M777 howitzer pitch API must visibly change pitch pivot rotation"):
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

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

