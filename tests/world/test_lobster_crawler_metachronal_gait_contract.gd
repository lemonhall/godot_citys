extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LobsterCrawlerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Lobster metachronal gait contract requires LobsterCrawlerLab.tscn"):
		return
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lobster metachronal gait contract must load LobsterCrawlerLab as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("set_lobster_motion_velocity"), "Lobster metachronal gait contract requires lab velocity control for deterministic stepping"):
		return
	if not T.require_true(self, lab.has_method("step_lobster"), "Lobster metachronal gait contract requires step_lobster()"):
		return

	var lobster: Node = lab.get_lobster_crawler()
	if not T.require_true(self, lobster != null and lobster.has_method("get_profile_contract"), "Lobster metachronal gait contract requires crawler profile introspection"):
		return

	var boot_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, int(boot_state.get("leg_count", 0)) == 10, "Lobster metachronal gait contract must start with 10 configured limbs"):
		return
	if not T.require_true(self, float(boot_state.get("phase_time", 0.0)) == 0.0, "Lobster metachronal gait contract must boot with zero phase_time before stepping"):
		return

	var profile_contract: Dictionary = lobster.get_profile_contract()
	if not T.require_true(self, float(profile_contract.get("body_clearance_m", 1.0)) < 0.5, "Lobster metachronal gait contract requires lower body clearance than the spider profile"):
		return
	var claw_contract := _find_leg_contract(profile_contract.get("legs", []), "lf_claw")
	var rear_contract := _find_leg_contract(profile_contract.get("legs", []), "lf_rear")
	if not T.require_true(self, float(claw_contract.get("step_height_m", 1.0)) < 0.16, "Lobster metachronal gait contract requires shorter limb lift than the spider profile"):
		return
	if not T.require_true(self, float(claw_contract.get("stride_scale", 0.0)) < float(rear_contract.get("stride_scale", 0.0)), "Lobster metachronal gait contract requires chelipeds to contribute less stride than the rear walking legs"):
		return

	lab.set_lobster_motion_velocity(Vector3(3.4, 0.0, 0.0))
	lab.step_lobster(0.18, 10)

	var stepped_state: Dictionary = lab.get_crawler_debug_state()
	var phase_time := float(stepped_state.get("phase_time", 0.0))
	if not T.require_true(self, absf(phase_time - 1.8) <= 0.03, "Lobster metachronal gait contract must accumulate phase_time after repeated stepping"):
		return
	var legs: Array = stepped_state.get("legs", [])
	var airborne_count := 0
	var total_replans := 0
	var left_phase_chain := []
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		if str(leg_state.get("mode", "")) != "stance":
			airborne_count += 1
		total_replans += int(leg_state.get("replan_count", 0))
	for leg_id in ["lf_rear", "lf_mid_b", "lf_mid_a", "lf_front", "lf_claw"]:
		left_phase_chain.append(float(_find_leg_state(legs, leg_id).get("phase_offset", -1.0)))
	if not T.require_true(self, _is_strictly_increasing(left_phase_chain), "Lobster metachronal gait contract requires rear-to-front phase ordering on the left side instead of spider-style paired offsets"):
		return
	if not T.require_true(self, airborne_count <= 3, "Lobster metachronal gait contract requires a low airborne concurrency consistent with a wave gait"):
		return
	if not T.require_true(self, total_replans > 0, "Lobster metachronal gait contract requires forward stepping to trigger foothold replans"):
		return
	if not T.require_true(self, int(stepped_state.get("failed_replan_count", -1)) == 0, "Lobster metachronal gait contract should not accumulate failed foothold replans on the authored dry lane"):
		return

	var body_visual_world_position: Vector3 = stepped_state.get("body_visual_world_position", Vector3.ZERO)
	if not T.require_true(self, body_visual_world_position.y > 0.2 and body_visual_world_position.y < 1.2, "Lobster metachronal gait contract requires the body to stay low instead of hovering at spider height"):
		return

	lab.reset_lab_state()
	var reset_state: Dictionary = lab.get_crawler_debug_state()
	if not T.require_true(self, float(reset_state.get("phase_time", 999.0)) == 0.0, "Resetting LobsterCrawlerLab must restore phase_time to zero"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _find_leg_contract(legs: Array, leg_id: String) -> Dictionary:
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		var leg_contract: Dictionary = leg_variant as Dictionary
		if str(leg_contract.get("leg_id", "")) == leg_id:
			return leg_contract
	return {}

func _find_leg_state(legs: Array, leg_id: String) -> Dictionary:
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		if str(leg_state.get("leg_id", "")) == leg_id:
			return leg_state
	return {}

func _is_strictly_increasing(values: Array) -> bool:
	if values.size() <= 1:
		return true
	for index in range(1, values.size()):
		if float(values[index]) <= float(values[index - 1]):
			return false
	return true
