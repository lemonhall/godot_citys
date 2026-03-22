extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(SPIDER_SCENE_PATH, "PackedScene"), "Spider leg visual contract requires CitySpiderCrawler.tscn"):
		return
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider leg visual contract must load CitySpiderCrawler as PackedScene"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	if not T.require_true(self, spider.has_method("get_leg_visual_state"), "Spider leg visual contract requires get_leg_visual_state()"):
		return
	if not T.require_true(self, spider.get_node_or_null("LegVisualRoot") != null, "Spider leg visual contract requires a dedicated LegVisualRoot under the spider scene"):
		return

	var leg_visuals: Array = spider.get_leg_visual_state()
	if not T.require_true(self, leg_visuals.size() == 8, "Spider leg visual contract must expose one visual state per leg"):
		return

	for leg_id in [
		"lf_front",
		"rf_front",
		"lf_mid_a",
		"rf_mid_a",
		"lf_mid_b",
		"rf_mid_b",
		"lf_rear",
		"rf_rear",
	]:
		if not T.require_true(self, spider.get_node_or_null("LegVisualRoot/%s" % leg_id) != null, "Spider leg visual contract requires authored visual nodes for %s" % leg_id):
			return
		if not T.require_true(self, spider.get_node_or_null("LegVisualRoot/%s/UpperSegment" % leg_id) != null, "Spider leg visual contract requires UpperSegment for %s" % leg_id):
			return
		if not T.require_true(self, spider.get_node_or_null("LegVisualRoot/%s/LowerSegment" % leg_id) != null, "Spider leg visual contract requires LowerSegment for %s" % leg_id):
			return
		if not T.require_true(self, spider.get_node_or_null("LegVisualRoot/%s/KneeJoint" % leg_id) != null, "Spider leg visual contract requires KneeJoint for %s" % leg_id):
			return

	var front_left_visual: Dictionary = _find_leg_visual_state(leg_visuals, "lf_front")
	if not T.require_true(self, float(front_left_visual.get("upper_length", 0.0)) > 0.4, "Spider leg visual contract requires a readable upper leg segment length"):
		return
	if not T.require_true(self, float(front_left_visual.get("lower_length", 0.0)) > 0.4, "Spider leg visual contract requires a readable lower leg segment length"):
		return
	if not T.require_true(self, float(front_left_visual.get("knee_offset_m", 0.0)) > 0.08, "Spider leg visual contract requires a non-zero knee bend so the leg is visually legible"):
		return

	spider.set_debug_motion_velocity(Vector3(2.4, 0.0, 0.0))
	for _step in range(6):
		spider.tick_crawler(0.20)
	var moved_visuals: Array = spider.get_leg_visual_state()
	if not T.require_true(self, _count_moved_knees(leg_visuals, moved_visuals) >= 1, "Spider leg visual contract requires at least one knee joint to update as gait state changes"):
		return

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _find_leg_visual_state(leg_visuals: Array, leg_id: String) -> Dictionary:
	for leg_variant in leg_visuals:
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		if str(leg_state.get("leg_id", "")) == leg_id:
			return leg_state
	return {}

func _count_moved_knees(before_visuals: Array, after_visuals: Array) -> int:
	var moved_count := 0
	for before_variant in before_visuals:
		if not (before_variant is Dictionary):
			continue
		var before_state: Dictionary = before_variant as Dictionary
		var leg_id: String = str(before_state.get("leg_id", ""))
		if leg_id == "":
			continue
		var after_state: Dictionary = _find_leg_visual_state(after_visuals, leg_id)
		var before_knee: Vector3 = before_state.get("knee_world_position", Vector3.ZERO)
		var after_knee: Vector3 = after_state.get("knee_world_position", Vector3.ZERO)
		if before_knee.distance_to(after_knee) > 0.02:
			moved_count += 1
	return moved_count
