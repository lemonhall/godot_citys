extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider reference surface search contract requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	spider.set_debug_motion_velocity(Vector3(0.0, 0.0, 3.0))

	var captured_leg_state: Dictionary = {}
	for _tick in range(12):
		spider.tick_crawler(0.12)
		var state: Dictionary = spider.get_debug_state()
		for leg_variant in state.get("legs", []):
			if not (leg_variant is Dictionary):
				continue
			var leg_state: Dictionary = leg_variant as Dictionary
			if str(leg_state.get("mode", "stance")) == "stance":
				continue
			captured_leg_state = leg_state.duplicate(true)
			break
		if not captured_leg_state.is_empty():
			break

	if not T.require_true(self, not captured_leg_state.is_empty(), "Spider reference surface search contract requires at least one active stepping leg during forward motion"):
		return
	if not T.require_true(self, captured_leg_state.has("step_surface_search_source"), "Spider reference surface search contract requires step_surface_search_source debug state on stepping legs"):
		return
	if not T.require_true(self, captured_leg_state.has("step_surface_search_candidates"), "Spider reference surface search contract requires step_surface_search_candidates debug state on stepping legs"):
		return
	var source_id := str(captured_leg_state.get("step_surface_search_source", ""))
	var candidate_ids: Array = captured_leg_state.get("step_surface_search_candidates", [])
	if not T.require_true(self, candidate_ids.size() >= 8, "Spider reference surface search contract requires a structured multi-candidate search order rather than a single down ray"):
		return
	if not T.require_true(self, str(candidate_ids[0]).begins_with("prediction_"), "Spider reference surface search contract requires prediction candidates to be checked before default candidates"):
		return
	if not T.require_true(self, _contains_default_candidate(candidate_ids), "Spider reference surface search contract requires fallback default-anchor candidates in addition to prediction candidates"):
		return
	if not T.require_true(self, candidate_ids.has(source_id), "Spider reference surface search contract requires the chosen search source to come from the declared candidate order"):
		return

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _contains_default_candidate(candidate_ids: Array) -> bool:
	for candidate_variant in candidate_ids:
		if str(candidate_variant).begins_with("default_"):
			return true
	return false
