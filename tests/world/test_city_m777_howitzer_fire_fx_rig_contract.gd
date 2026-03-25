extends SceneTree

const T := preload("res://tests/_test_util.gd")

const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(HOWITZER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 fire FX rig contract requires the formal howitzer scene"):
		return

	var howitzer := scene.instantiate() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("request_fire"), "M777 fire FX rig contract must instantiate the formal howitzer runtime"):
		return

	root.add_child(howitzer)
	await process_frame
	await process_frame

	var pitch_pivot := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot") as Node3D
	var muzzle_anchor := howitzer.get_node_or_null("Anchors/MuzzleFxAnchor") as Marker3D
	var muzzle_fx_rig := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig") as Node3D
	var flash_burst := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/FlashBurst") as Node3D
	var smoke_burst := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/MuzzleFxRig/SmokeBurst") as Node3D
	if not T.require_true(self, pitch_pivot != null and muzzle_anchor != null and muzzle_fx_rig != null and flash_burst != null and smoke_burst != null, "M777 fire FX rig contract requires the rebuilt single-root MuzzleFxRig hierarchy under FirePresentationRoot"):
		return

	var expected_muzzle_local := pitch_pivot.global_transform.affine_inverse() * muzzle_anchor.global_transform
	if not _require_transform_close(self, muzzle_fx_rig.transform, expected_muzzle_local, "MuzzleFxRig must inherit the authored MuzzleFxAnchor transform as the single WYSIWYG source of truth"):
		return

	var fire_result := howitzer.request_fire() as Dictionary
	if not T.require_true(self, bool(fire_result.get("accepted", false)), "M777 fire FX rig contract requires an accepted fire event"):
		return
	await physics_frame
	await process_frame

	if not T.require_true(self, flash_burst.visible and smoke_burst.visible, "The rebuilt MuzzleFxRig must expose both flash and smoke presentations during an accepted shot"):
		return
	if not T.require_true(self, muzzle_fx_rig.global_position.distance_to(muzzle_anchor.global_position) <= 0.001, "The rebuilt MuzzleFxRig must stay welded to MuzzleFxAnchor in world space during firing"):
		return

	howitzer.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _require_transform_close(tree: SceneTree, actual: Transform3D, expected: Transform3D, message: String, tolerance: float = 0.001) -> bool:
	if actual.origin.distance_to(expected.origin) > tolerance:
		T.fail_and_quit(tree, "%s (origin actual=%s expected=%s)" % [message, actual.origin, expected.origin])
		return false
	for basis_index in 3:
		var actual_axis := actual.basis[basis_index]
		var expected_axis := expected.basis[basis_index]
		if actual_axis.length_squared() <= 0.000001 or expected_axis.length_squared() <= 0.000001:
			T.fail_and_quit(tree, "%s (basis[%d] degenerate actual=%s expected=%s)" % [message, basis_index, actual_axis, expected_axis])
			return false
		if actual_axis.normalized().distance_to(expected_axis.normalized()) > tolerance:
			T.fail_and_quit(tree, "%s (basis[%d] actual=%s expected=%s)" % [message, basis_index, actual_axis.normalized(), expected_axis.normalized()])
			return false
	return true
