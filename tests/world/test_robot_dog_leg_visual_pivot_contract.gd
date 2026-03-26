extends SceneTree

const T := preload("res://tests/_test_util.gd")

const ROBOT_DOG_SCENE_PATH := "res://city_game/world/creatures/quadrupeds/CityRobotDog.tscn"
const ROBOT_DOG_ASSET_PATH := "res://city_game/assets/environment/source/creatures/robot_dog_02/robot_dog_02.glb"
const LEG_VISUAL_SPECS := [
	{
		"leg_id": "lf",
		"hip_mesh_name": "L_Fore_Hip",
		"calf_mesh_name": "L_Fore_Calf",
	},
	{
		"leg_id": "rf",
		"hip_mesh_name": "R_Fore_Hip",
		"calf_mesh_name": "R_Fore_Calf",
	},
	{
		"leg_id": "lr",
		"hip_mesh_name": "L_Hind_Hip",
		"calf_mesh_name": "L_Hind_Calf",
	},
	{
		"leg_id": "rr",
		"hip_mesh_name": "R_Hind_Hip",
		"calf_mesh_name": "R_Hind_Calf",
	},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(ROBOT_DOG_SCENE_PATH, "PackedScene"), "Robot dog leg visual pivot contract requires CityRobotDog.tscn"):
		return
	if not T.require_true(self, ResourceLoader.exists(ROBOT_DOG_ASSET_PATH, "PackedScene"), "Robot dog leg visual pivot contract requires robot_dog_02.glb"):
		return

	var raw_leg_offsets := await _capture_raw_import_positions()
	if not T.require_true(self, raw_leg_offsets.size() == 8, "Robot dog leg visual pivot contract must capture 8 raw imported leg mesh positions"):
		return

	var scene := load(ROBOT_DOG_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Robot dog leg visual pivot contract must load CityRobotDog as PackedScene"):
		return
	var robot_dog := scene.instantiate() as Node3D
	root.add_child(robot_dog)
	await process_frame
	await process_frame

	for required_method in [
		"set_crouch_requested",
		"tick_robot_dog",
	]:
		if not T.require_true(self, robot_dog.has_method(required_method), "Robot dog leg visual pivot contract requires %s()" % required_method):
			return

	var leg_pivot_root := robot_dog.get_node_or_null("BodyPivot/LegPivotRoot") as Node3D
	if not T.require_true(self, leg_pivot_root != null, "Robot dog leg visual pivot contract requires a dedicated BodyPivot/LegPivotRoot hierarchy"):
		return

	var rest_local_offsets := {}
	for leg_spec_variant in LEG_VISUAL_SPECS:
		var leg_spec := leg_spec_variant as Dictionary
		var leg_id := str(leg_spec.get("leg_id", ""))
		var leg_root := leg_pivot_root.get_node_or_null(leg_id) as Node3D
		if not T.require_true(self, leg_root != null, "Robot dog leg visual pivot contract requires LegPivotRoot/%s" % leg_id):
			return
		var hip_pivot := leg_root.get_node_or_null("HipPivot") as Node3D
		var calf_pivot := leg_root.get_node_or_null("CalfPivot") as Node3D
		if not T.require_true(self, hip_pivot != null and calf_pivot != null, "Robot dog leg visual pivot contract requires HipPivot/CalfPivot for %s" % leg_id):
			return

		var hip_mesh_name := str(leg_spec.get("hip_mesh_name", ""))
		var calf_mesh_name := str(leg_spec.get("calf_mesh_name", ""))
		var hip_mesh := hip_pivot.get_node_or_null(hip_mesh_name) as Node3D
		var calf_mesh := calf_pivot.get_node_or_null(calf_mesh_name) as Node3D
		if not T.require_true(self, hip_mesh != null and calf_mesh != null, "Robot dog leg visual pivot contract must reparent %s and %s under pivots" % [hip_mesh_name, calf_mesh_name]):
			return

		var expected_hip_rest_local: Vector3 = raw_leg_offsets.get(hip_mesh_name, Vector3.ZERO) - hip_pivot.position
		var expected_calf_rest_local: Vector3 = raw_leg_offsets.get(calf_mesh_name, Vector3.ZERO) - calf_pivot.position
		if not T.require_true(self, hip_mesh.position.distance_to(expected_hip_rest_local) <= 0.001, "Robot dog leg visual pivot contract must preserve authored hip mesh offset for %s" % hip_mesh_name):
			return
		if not T.require_true(self, calf_mesh.position.distance_to(expected_calf_rest_local) <= 0.001, "Robot dog leg visual pivot contract must preserve authored calf mesh offset for %s" % calf_mesh_name):
			return
		if not T.require_true(self, hip_mesh.position.length() > 0.001, "Robot dog leg visual pivot contract must keep a non-zero authored hip mesh offset for %s" % hip_mesh_name):
			return
		if not T.require_true(self, calf_mesh.position.length() > 0.001, "Robot dog leg visual pivot contract must keep a non-zero authored calf mesh offset for %s" % calf_mesh_name):
			return
		rest_local_offsets["%s_hip" % leg_id] = hip_mesh.position
		rest_local_offsets["%s_calf" % leg_id] = calf_mesh.position

	robot_dog.set_crouch_requested(true)
	for _step in range(24):
		robot_dog.tick_robot_dog(0.1)
		await process_frame

	for leg_spec_variant in LEG_VISUAL_SPECS:
		var leg_spec := leg_spec_variant as Dictionary
		var leg_id := str(leg_spec.get("leg_id", ""))
		var hip_mesh := robot_dog.get_node_or_null("BodyPivot/LegPivotRoot/%s/HipPivot/%s" % [leg_id, str(leg_spec.get("hip_mesh_name", ""))]) as Node3D
		var calf_mesh := robot_dog.get_node_or_null("BodyPivot/LegPivotRoot/%s/CalfPivot/%s" % [leg_id, str(leg_spec.get("calf_mesh_name", ""))]) as Node3D
		if not T.require_true(self, hip_mesh != null and calf_mesh != null, "Robot dog leg visual pivot contract must keep the visual meshes mounted under pivots while crouching for %s" % leg_id):
			return
		if not T.require_true(self, hip_mesh.position.distance_to(rest_local_offsets.get("%s_hip" % leg_id, Vector3.ZERO)) <= 0.001, "Robot dog leg visual pivot contract must not drift hip mesh local offset while crouching for %s" % leg_id):
			return
		if not T.require_true(self, calf_mesh.position.distance_to(rest_local_offsets.get("%s_calf" % leg_id, Vector3.ZERO)) <= 0.001, "Robot dog leg visual pivot contract must not drift calf mesh local offset while crouching for %s" % leg_id):
			return

	robot_dog.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _capture_raw_import_positions() -> Dictionary:
	var asset_scene := load(ROBOT_DOG_ASSET_PATH) as PackedScene
	if asset_scene == null:
		return {}
	var asset_root := asset_scene.instantiate() as Node3D
	root.add_child(asset_root)
	await process_frame
	var raw_positions := {}
	for leg_spec_variant in LEG_VISUAL_SPECS:
		var leg_spec := leg_spec_variant as Dictionary
		for mesh_name in [str(leg_spec.get("hip_mesh_name", "")), str(leg_spec.get("calf_mesh_name", ""))]:
			var mesh_node := asset_root.get_node_or_null("ParentNode/%s" % mesh_name) as Node3D
			if mesh_node == null:
				continue
			raw_positions[mesh_name] = mesh_node.position
	asset_root.queue_free()
	await process_frame
	return raw_positions
