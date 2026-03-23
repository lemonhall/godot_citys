extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider reference step desire contract requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	spider.set_debug_motion_velocity(Vector3.ZERO)
	for _tick in range(6):
		spider.tick_crawler(0.12)

	var boot_state: Dictionary = spider.get_debug_state()
	if not T.require_true(self, boot_state.has("time_standing_still_seconds"), "Spider reference step desire contract requires time_standing_still_seconds debug state"):
		return
	if not T.require_true(self, boot_state.has("stop_stepping_after_seconds_still"), "Spider reference step desire contract requires stop_stepping_after_seconds_still debug state"):
		return
	if not T.require_true(self, boot_state.has("body_is_moving"), "Spider reference step desire contract requires body_is_moving debug state"):
		return

	spider.global_position += Vector3(20.0, 0.0, 0.0)

	for _tick in range(10):
		spider.tick_crawler(0.12)

	var final_state: Dictionary = spider.get_debug_state()
	var time_standing_still_seconds := float(final_state.get("time_standing_still_seconds", 0.0))
	var stop_stepping_after_seconds_still := float(final_state.get("stop_stepping_after_seconds_still", 999.0))
	if not T.require_true(self, time_standing_still_seconds > stop_stepping_after_seconds_still, "Spider reference step desire contract requires the spider to have exceeded the stillness gate before assertions"):
		return
	if not T.require_true(self, not bool(final_state.get("body_is_moving", true)), "Spider reference step desire contract requires the body to be considered idle after the stillness gate"):
		return

	var saw_large_anchor_drift := false
	var saw_step_desire_while_still := false
	var saw_active_step_while_still := false
	for leg_variant in final_state.get("legs", []):
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var locked_foothold: Vector3 = leg_state.get("locked_foothold", Vector3.ZERO)
		var default_anchor_world_position: Vector3 = leg_state.get("default_anchor_world_position", locked_foothold)
		if locked_foothold.distance_to(default_anchor_world_position) > 2.0:
			saw_large_anchor_drift = true
		if bool(leg_state.get("step_desire", false)):
			saw_step_desire_while_still = true
		if str(leg_state.get("mode", "stance")) != "stance":
			saw_active_step_while_still = true

	if not T.require_true(self, saw_large_anchor_drift, "Spider reference step desire contract requires unresolved anchor drift while the spider is idle, otherwise the stillness gate is not meaningfully exercised"):
		return
	if not T.require_true(self, not saw_step_desire_while_still, "Spider reference step desire contract requires step desire to be suppressed once the spider has stood still long enough, even if anchors remain displaced"):
		return
	if not T.require_true(self, not saw_active_step_while_still, "Spider reference step desire contract forbids new active stepping once the stillness gate is active"):
		return

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)
