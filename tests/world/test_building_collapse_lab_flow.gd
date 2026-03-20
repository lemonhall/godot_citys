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

	var hit_world_position: Vector3 = target_runtime.get_primary_target_world_position()
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
	if not T.require_true(self, bool(collapsed_debug_state.get("residual_base_visible", false)), "Collapsed buildings must preserve a residual base or rubble stump"):
		return

	var chunk_count_before_cleanup := int(collapsed_debug_state.get("dynamic_chunk_count", 0))
	for _frame in range(420):
		await physics_frame
	var cleaned_debug_state: Dictionary = target_runtime.get_debug_state()
	if not T.require_true(
		self,
		int(cleaned_debug_state.get("dynamic_chunk_count", 0)) < chunk_count_before_cleanup,
		"Collapse cleanup must remove most debris chunks after the cleanup window"
	):
		return

	lab.queue_free()
	T.pass_and_quit(self)
