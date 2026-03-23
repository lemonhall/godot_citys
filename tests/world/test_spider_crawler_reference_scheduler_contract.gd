extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"
const EXPECTED_STEP_SCHEDULER_ID := "reference_tetrapod_timer_v2"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider reference scheduler contract requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	if not T.require_true(self, spider.has_method("get_debug_state"), "Spider reference scheduler contract requires get_debug_state()"):
		return

	var boot_state: Dictionary = spider.get_debug_state()
	if not T.require_true(self, str(boot_state.get("step_scheduler_id", "")) == EXPECTED_STEP_SCHEDULER_ID, "Spider reference scheduler contract requires an explicit timer-based scheduler id"):
		return
	if not T.require_true(self, boot_state.has("active_step_group_id"), "Spider reference scheduler contract requires active_step_group_id debug state"):
		return
	if not T.require_true(self, boot_state.has("next_group_switch_time"), "Spider reference scheduler contract requires next_group_switch_time debug state"):
		return
	if not T.require_true(self, boot_state.has("group_step_time_seconds"), "Spider reference scheduler contract requires group_step_time_seconds debug state"):
		return
	if not T.require_true(self, boot_state.has("group_switch_count"), "Spider reference scheduler contract requires group_switch_count debug state"):
		return
	if not T.require_true(self, boot_state.has("step_clock_seconds"), "Spider reference scheduler contract requires step_clock_seconds debug state"):
		return

	spider.set_debug_motion_velocity(Vector3(0.0, 0.0, 3.0))

	var first_switch_clock := -1.0
	var first_group_step_time := -1.0
	var first_group_id := ""
	var second_switch_clock := -1.0
	var second_group_id := ""
	var sampled_step_durations: Array[float] = []

	for _step in range(40):
		spider.tick_crawler(0.06)
		var state: Dictionary = spider.get_debug_state()
		var switch_count := int(state.get("group_switch_count", -1))
		if switch_count >= 1 and first_switch_clock < 0.0:
			first_switch_clock = float(state.get("step_clock_seconds", -1.0))
			first_group_step_time = float(state.get("group_step_time_seconds", -1.0))
			first_group_id = str(state.get("active_step_group_id", ""))
			sampled_step_durations = _collect_active_step_durations(state.get("legs", []))
		elif switch_count >= 2 and second_switch_clock < 0.0:
			second_switch_clock = float(state.get("step_clock_seconds", -1.0))
			second_group_id = str(state.get("active_step_group_id", ""))
			break

	if not T.require_true(self, first_switch_clock >= 0.0, "Spider reference scheduler contract requires at least one observed timer-driven group switch"):
		return
	if not T.require_true(self, first_group_step_time > 0.0, "Spider reference scheduler contract requires a positive group step time after the first switch"):
		return
	if not T.require_true(self, sampled_step_durations.size() > 0, "Spider reference scheduler contract requires at least one active stepping leg when a group switch occurs"):
		return
	if not T.require_true(self, _durations_match_group_step_time(sampled_step_durations, first_group_step_time), "Spider reference scheduler contract requires all legs launched in one scheduler group to share the same group step time"):
		return
	if not T.require_true(self, second_switch_clock >= 0.0, "Spider reference scheduler contract requires a second observed timer-driven group switch"):
		return
	if not T.require_true(self, second_group_id != first_group_id, "Spider reference scheduler contract requires alternating gait groups across switches"):
		return
	var switch_interval := second_switch_clock - first_switch_clock
	if not T.require_true(self, absf(switch_interval - first_group_step_time) <= 0.12, "Spider reference scheduler contract requires switch cadence to follow the previous group step time rather than a fixed phase window"):
		return

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _collect_active_step_durations(leg_states: Array) -> Array[float]:
	var durations: Array[float] = []
	for leg_variant in leg_states:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		if str(leg_state.get("mode", "stance")) == "stance":
			continue
		durations.append(float(leg_state.get("step_duration_seconds", -1.0)))
	return durations

func _durations_match_group_step_time(durations: Array[float], expected_duration: float) -> bool:
	for duration in durations:
		if absf(duration - expected_duration) > 0.001:
			return false
	return true
