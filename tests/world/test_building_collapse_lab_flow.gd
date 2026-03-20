extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/BuildingCollapseLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if scene == null:
		T.fail_and_quit(self, "Building collapse lab flow contract requires the dedicated lab scene")
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame

	var target_runtime: Variant = lab.call("get_target_building_runtime")
	if not T.require_true(self, target_runtime != null, "Flow contract requires the target building runtime"):
		return

	var hit_world_position: Vector3 = target_runtime.get_primary_target_world_position() + Vector3.UP * 14.0
	var prepare_result: Dictionary = target_runtime.apply_damage(4100.0, hit_world_position)
	if not T.require_true(self, bool(prepare_result.get("accepted", false)), "Flow contract requires the damaged-threshold hit to be accepted"):
		return

	var fracture_ready := false
	for _frame in range(180):
		await process_frame
		var state: Dictionary = target_runtime.get_state()
		if str(state.get("damage_state", "")) == "collapse_ready":
			fracture_ready = true
			break
	if not T.require_true(self, fracture_ready, "Damaged buildings must eventually finish fracture preparation before collapse"):
		return

	var prepared_debug_state: Dictionary = target_runtime.get_debug_state()
	if not T.require_true(self, bool(prepared_debug_state.get("fracture_recipe_ready", false)), "Flow contract requires a reusable fracture recipe before collapse"):
		return
	if not T.require_true(self, not bool(prepared_debug_state.get("collapse_active", false)), "Preparing fracture data must not replace the intact building early"):
		return

	var collapse_result: Dictionary = target_runtime.apply_damage(5600.0, hit_world_position)
	if not T.require_true(self, bool(collapse_result.get("accepted", false)), "Flow contract requires the collapse-threshold hit to be accepted"):
		return

	var collapsed := false
	for _frame in range(240):
		await physics_frame
		var state: Dictionary = target_runtime.get_state()
		if str(state.get("damage_state", "")) == "collapsed":
			collapsed = true
			break
	if not T.require_true(self, collapsed, "Near-destroyed buildings must transition through collapsing into collapsed"):
		return

	var collapsed_debug_state: Dictionary = target_runtime.get_debug_state()
	if not T.require_true(self, int(collapsed_debug_state.get("dynamic_chunk_count", 0)) > 0, "Collapsed buildings must instantiate dynamic debris chunks instead of only hiding the mesh"):
		return
	if not T.require_true(self, bool(collapsed_debug_state.get("explosion_impulse_enabled", false)), "Collapse must apply an outward explosion impulse from the hit center instead of only letting boxes peel away with a generic fall vector"):
		return
	if not T.require_true(self, float(collapsed_debug_state.get("impact_zone_average_launch_speed_mps", 0.0)) > float(collapsed_debug_state.get("far_zone_average_launch_speed_mps", 0.0)), "Chunks nearest the blast center must receive the strongest launch speed so the collapse reads like an explosion"):
		return
	if not T.require_true(self, float(collapsed_debug_state.get("impact_zone_average_blast_alignment", 0.0)) >= 0.55, "Impact-zone chunks must launch outward from the hit center instead of mostly following an unrelated collapse direction"):
		return
	if not T.require_true(self, bool(collapsed_debug_state.get("residual_base_visible", false)), "Collapsed buildings must preserve a residual base or rubble stump"):
		return
	if not T.require_true(self, int(collapsed_debug_state.get("dynamic_chunk_count", 0)) >= 20, "Collapsed buildings must break into a denser debris field than a handful of long regular bars"):
		return
	if not T.require_true(self, int(collapsed_debug_state.get("recipe_unique_size_count", 0)) >= 6, "Collapse recipe must expose multiple distinct chunk sizes to avoid a too-regular fracture silhouette"):
		return
	if not T.require_true(self, int(collapsed_debug_state.get("chunk_face_count_min", 0)) == 6, "Box-fracture mode must keep cubic six-face debris instead of irregular shard geometry"):
		return
	if not T.require_true(self, int(collapsed_debug_state.get("chunk_face_count_max", 0)) == 6, "Box-fracture mode must report six-face debris consistently across all spawned chunks"):
		return
	if not T.require_true(self, bool(collapsed_debug_state.get("recipe_preserves_building_envelope", false)), "Box-fracture recipe must still reassemble into the original building envelope instead of drifting away from the tower silhouette"):
		return
	if not T.require_true(self, float(collapsed_debug_state.get("impact_zone_smallest_volume_m3", 0.0)) < float(collapsed_debug_state.get("far_zone_average_volume_m3", 0.0)), "Box chunks near the impact point must still be the smallest, with box size expanding away from the blast origin"):
		return
	if not T.require_true(self, float(collapsed_debug_state.get("residual_base_height_m", 0.0)) >= 14.0, "Upper-half impacts must preserve a substantial lower ruin instead of erasing the whole tower to the ground"):
		return
	if not T.require_true(self, absf(float(collapsed_debug_state.get("cleanup_delay_sec", 0.0)) - 30.0) <= 0.01, "Lab debris cleanup window must be frozen to 30 seconds for manual observation"):
		return

	lab.reset_lab_state()
	await process_frame
	target_runtime = lab.call("get_target_building_runtime")
	if not T.require_true(self, target_runtime != null, "Resetting the lab must remount a fresh target runtime"):
		return
	var reset_state: Dictionary = target_runtime.get_state()
	if not T.require_true(self, str(reset_state.get("damage_state", "")) == "intact", "Lab reset must restore the building to intact state"):
		return
	if not T.require_true(self, is_equal_approx(float(reset_state.get("current_health", 0.0)), float(reset_state.get("max_health", 0.0))), "Lab reset must restore full building health"):
		return
	if not T.require_true(self, int(lab.get_active_missile_count()) == 0, "Lab reset must clear any residual live missiles"):
		return

	lab.queue_free()
	T.pass_and_quit(self)
