extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/BuildingCollapseLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if scene == null:
		T.fail_and_quit(self, "Building collapse lab damage contract requires the dedicated lab scene")
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame

	var player := lab.get_node_or_null("Player")
	var target_runtime: Variant = lab.call("get_target_building_runtime")
	if not T.require_true(self, player != null and target_runtime != null, "Damage contract requires both Player and target runtime"):
		return

	var initial_state: Dictionary = target_runtime.get_state()
	var aim_world_position: Vector3 = target_runtime.get_primary_target_world_position()
	lab.aim_player_at_world_position(aim_world_position)
	await physics_frame

	var missile: Variant = lab.fire_missile_at_world_position(aim_world_position)
	if not T.require_true(self, missile != null, "Building collapse lab must spawn a live missile toward the target building"):
		return

	var health_decreased := false
	for _frame in range(120):
		await physics_frame
		var state: Dictionary = target_runtime.get_state()
		if float(state.get("current_health", 0.0)) < float(initial_state.get("current_health", 0.0)):
			health_decreased = true
			break
	if not T.require_true(self, health_decreased, "A live player-fired missile must reduce the target building health"):
		return

	var missile_damage_state: Dictionary = target_runtime.get_state()
	if not T.require_true(self, missile_damage_state.get("last_hit_world_position", null) is Vector3, "Missile damage must record the formal hit world position"):
		return
	if not T.require_true(self, missile_damage_state.get("last_hit_local_position", null) is Vector3, "Missile damage must record the formal hit local position"):
		return

	var cross_threshold_result: Dictionary = target_runtime.apply_damage(4100.0, aim_world_position)
	if not T.require_true(self, bool(cross_threshold_result.get("accepted", false)), "Runtime damage API must accept a threshold-crossing hit"):
		return

	var cracked := false
	for _frame in range(45):
		await process_frame
		var debug_state: Dictionary = target_runtime.get_debug_state()
		if bool(debug_state.get("crack_visual_active", false)):
			cracked = true
			break
	if not T.require_true(self, cracked, "Crossing the damaged threshold must activate a crack visual near the hit zone"):
		return

	var post_damage_state: Dictionary = target_runtime.get_state()
	if not T.require_true(
		self,
		str(post_damage_state.get("damage_state", "")) == "fracture_preparing" or str(post_damage_state.get("damage_state", "")) == "collapse_ready",
		"Crossing the damaged threshold must enter fracture preparation instead of staying intact forever"
	):
		return

	lab.queue_free()
	T.pass_and_quit(self)
