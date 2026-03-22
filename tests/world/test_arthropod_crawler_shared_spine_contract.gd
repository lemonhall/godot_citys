extends SceneTree

const T := preload("res://tests/_test_util.gd")

const PROFILE_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodLocomotionProfile.gd"
const LEG_RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodLegRuntime.gd"
const FOOTHOLD_RESOLVER_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodFootholdResolver.gd"
const BODY_SOLVER_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodBodySolver.gd"
const CRAWLER_RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for required_path in [
		PROFILE_SCRIPT_PATH,
		LEG_RUNTIME_SCRIPT_PATH,
		FOOTHOLD_RESOLVER_SCRIPT_PATH,
		BODY_SOLVER_SCRIPT_PATH,
		CRAWLER_RUNTIME_SCRIPT_PATH,
	]:
		if not T.require_true(self, ResourceLoader.exists(required_path, "Script"), "Arthropod shared spine contract requires %s" % required_path):
			return

	var profile_script := load(PROFILE_SCRIPT_PATH)
	var resolver_script := load(FOOTHOLD_RESOLVER_SCRIPT_PATH)
	var solver_script := load(BODY_SOLVER_SCRIPT_PATH)
	var crawler_script := load(CRAWLER_RUNTIME_SCRIPT_PATH)
	if not T.require_true(self, profile_script != null and resolver_script != null and solver_script != null and crawler_script != null, "Arthropod shared spine contract must load every runtime script"):
		return

	var spider_profile = profile_script.new()
	var hexapod_profile = profile_script.new()
	var resolver = resolver_script.new()
	var solver = solver_script.new()
	var spider_runtime := crawler_script.new() as Node3D
	var hexapod_runtime := crawler_script.new() as Node3D
	if not T.require_true(self, spider_runtime != null and hexapod_runtime != null, "Arthropod shared spine contract requires crawler runtime to instantiate as Node3D"):
		return

	spider_profile.configure({
		"profile_id": "arthropod_spider_ground_v1",
		"species_id": "spider",
		"gait_profile_id": "tetrapod_ground",
		"phase_duration_seconds": 1.6,
		"duty_factor": 0.62,
		"body_clearance_m": 0.72,
		"legs": [
			{"leg_id": "lf_front", "phase_offset": 0.00, "default_foothold": Vector3(-0.9, 0.0, 1.2)},
			{"leg_id": "rf_front", "phase_offset": 0.50, "default_foothold": Vector3(0.9, 0.0, 1.2)},
			{"leg_id": "lf_mid_a", "phase_offset": 0.50, "default_foothold": Vector3(-1.0, 0.0, 0.4)},
			{"leg_id": "rf_mid_a", "phase_offset": 0.00, "default_foothold": Vector3(1.0, 0.0, 0.4)},
			{"leg_id": "lf_mid_b", "phase_offset": 0.00, "default_foothold": Vector3(-1.0, 0.0, -0.4)},
			{"leg_id": "rf_mid_b", "phase_offset": 0.50, "default_foothold": Vector3(1.0, 0.0, -0.4)},
			{"leg_id": "lf_rear", "phase_offset": 0.50, "default_foothold": Vector3(-0.9, 0.0, -1.2)},
			{"leg_id": "rf_rear", "phase_offset": 0.00, "default_foothold": Vector3(0.9, 0.0, -1.2)},
		],
	})
	hexapod_profile.configure({
		"profile_id": "arthropod_hexapod_probe_v1",
		"species_id": "probe_hexapod",
		"gait_profile_id": "tripod_probe",
		"phase_duration_seconds": 1.1,
		"duty_factor": 0.54,
		"body_clearance_m": 0.58,
		"legs": [
			{"leg_id": "lf", "phase_offset": 0.00, "default_foothold": Vector3(-0.8, 0.0, 0.8)},
			{"leg_id": "rf", "phase_offset": 0.50, "default_foothold": Vector3(0.8, 0.0, 0.8)},
			{"leg_id": "lm", "phase_offset": 0.50, "default_foothold": Vector3(-0.9, 0.0, 0.0)},
			{"leg_id": "rm", "phase_offset": 0.00, "default_foothold": Vector3(0.9, 0.0, 0.0)},
			{"leg_id": "lr", "phase_offset": 0.00, "default_foothold": Vector3(-0.8, 0.0, -0.8)},
			{"leg_id": "rr", "phase_offset": 0.50, "default_foothold": Vector3(0.8, 0.0, -0.8)},
		],
	})

	resolver.configure()
	root.add_child(spider_runtime)
	root.add_child(hexapod_runtime)
	spider_runtime.configure(spider_profile, resolver, solver)
	hexapod_runtime.configure(hexapod_profile)

	var initial_state: Dictionary = spider_runtime.get_debug_state()
	if not T.require_true(self, str(initial_state.get("species_id", "")) == "spider", "Shared arthropod runtime must expose species_id from the configured profile"):
		return
	if not T.require_true(self, str(initial_state.get("gait_profile_id", "")) == "tetrapod_ground", "Shared arthropod runtime must expose gait_profile_id from the configured profile"):
		return
	var initial_legs: Array = initial_state.get("legs", [])
	if not T.require_true(self, initial_legs.size() == 8, "Spider shared arthropod runtime must preserve all 8 configured legs"):
		return
	var first_leg: Dictionary = initial_legs[0] as Dictionary
	if not T.require_true(self, str(first_leg.get("leg_id", "")) == "lf_front", "Per-leg debug state must preserve stable leg ids"):
		return
	if not T.require_true(self, str(first_leg.get("mode", "")) == "stance", "Leg runtimes must boot in stance mode before gait stepping begins"):
		return
	if not T.require_true(self, bool(first_leg.get("is_grounded", false)), "Stance legs must boot grounded"):
		return
	if not T.require_true(self, first_leg.get("locked_foothold", null) == Vector3(-0.9, 0.0, 1.2), "Shared arthropod runtime must boot locked footholds from the profile contract"):
		return
	var body_target_transform: Dictionary = initial_state.get("body_target_transform", {})
	if not T.require_true(self, body_target_transform.get("origin", null) == Vector3(0.0, 0.72, 0.0), "Shared arthropod runtime must derive a body target origin from the grounded footholds plus clearance"):
		return

	var mutated_state: Dictionary = initial_state.duplicate(true)
	mutated_state["species_id"] = "corrupted"
	var mutated_legs: Array = mutated_state.get("legs", [])
	if not mutated_legs.is_empty():
		(mutated_legs[0] as Dictionary)["mode"] = "airborne"
	var fresh_state_after_mutation: Dictionary = spider_runtime.get_debug_state()
	if not T.require_true(self, str(fresh_state_after_mutation.get("species_id", "")) == "spider", "get_debug_state() must return a defensive snapshot instead of a shared mutable dictionary"):
		return
	if not T.require_true(self, str(((fresh_state_after_mutation.get("legs", []) as Array)[0] as Dictionary).get("mode", "")) == "stance", "Per-leg debug state must also be duplicated defensively"):
		return

	spider_runtime.tick(0.40)
	hexapod_runtime.tick(0.40)

	var spider_ticked_state: Dictionary = spider_runtime.get_debug_state()
	var hexapod_ticked_state: Dictionary = hexapod_runtime.get_debug_state()
	if not T.require_true(self, float(spider_ticked_state.get("phase_time", 0.0)) > 0.0, "Shared arthropod runtime must accumulate phase_time when ticked"):
		return
	var spider_phase := float((((spider_ticked_state.get("legs", []) as Array)[0] as Dictionary).get("phase", -1.0)))
	var hexapod_phase := float((((hexapod_ticked_state.get("legs", []) as Array)[0] as Dictionary).get("phase", -1.0)))
	if not T.require_true(self, absf(spider_phase - hexapod_phase) >= 0.05, "Profile changes must affect the resulting gait phase instead of sharing one hard-coded timing loop"):
		return
	if not T.require_true(self, int((hexapod_ticked_state.get("legs", []) as Array).size()) == 6, "Shared arthropod runtime must support non-octopedal leg counts"):
		return

	var replan_result: Dictionary = spider_runtime.replan_leg_foothold("lf_front", Vector3(-1.1, 1.7, 1.5))
	if not T.require_true(self, bool(replan_result.get("success", false)), "Shared arthropod runtime must expose per-leg foothold replanning"):
		return
	var replanned_state: Dictionary = spider_runtime.get_debug_state()
	var replanned_leg := _find_leg_state(replanned_state.get("legs", []), "lf_front")
	if not T.require_true(self, replanned_leg.get("locked_foothold", null) == Vector3(-1.1, 0.0, 1.5), "Default foothold resolver must project replanned footholds onto the ground plane when no custom resolver is installed"):
		return
	if not T.require_true(self, int(replanned_leg.get("replan_count", 0)) == 1, "Leg debug state must count successful foothold replans"):
		return
	if not T.require_true(self, int(replanned_state.get("failed_replan_count", -1)) == 0, "Successful replans must not increment failed_replan_count"):
		return

	spider_runtime.queue_free()
	hexapod_runtime.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _find_leg_state(legs: Array, leg_id: String) -> Dictionary:
	for leg_variant in legs:
		var leg_state: Dictionary = leg_variant as Dictionary
		if str(leg_state.get("leg_id", "")) == leg_id:
			return leg_state
	return {}
