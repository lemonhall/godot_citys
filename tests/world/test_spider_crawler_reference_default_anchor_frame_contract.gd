extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const MAX_ALLOWED_DEFAULT_ANCHOR_ERROR_M := 0.08

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider reference default anchor frame contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("teleport_spider_to_world_position"), "Spider reference default anchor frame contract requires deterministic spider teleportation"):
		return
	if not T.require_true(self, lab.has_method("force_spider_replan"), "Spider reference default anchor frame contract requires force_spider_replan()"):
		return
	if not T.require_true(self, lab.has_method("get_spider_crawler"), "Spider reference default anchor frame contract requires get_spider_crawler()"):
		return
	if not T.require_true(self, lab.has_method("get_crawler_debug_state"), "Spider reference default anchor frame contract requires get_crawler_debug_state()"):
		return

	lab.teleport_spider_to_world_position(Vector3(18.0, 0.0, 0.0))
	lab.force_spider_replan()
	lab.step_spider(0.18, 4)

	var spider := lab.get_spider_crawler() as Node3D
	if not T.require_true(self, spider != null, "Spider reference default anchor frame contract requires a live crawler node"):
		return
	if not T.require_true(self, spider.has_method("get_profile_contract"), "Spider reference default anchor frame contract requires get_profile_contract() on crawler"):
		return

	var profile_contract: Dictionary = spider.get_profile_contract()
	var foothold_by_leg_id := _build_default_foothold_lookup(profile_contract.get("legs", []))
	var debug_state: Dictionary = lab.get_crawler_debug_state()
	var max_anchor_error_m := 0.0

	for leg_variant in debug_state.get("legs", []):
		if not (leg_variant is Dictionary):
			continue
		var leg_state: Dictionary = leg_variant as Dictionary
		var leg_id := str(leg_state.get("leg_id", ""))
		if leg_id == "" or not foothold_by_leg_id.has(leg_id):
			continue
		var default_foothold_local: Vector3 = foothold_by_leg_id.get(leg_id, Vector3.ZERO)
		var expected_root_frame_anchor := spider.global_position + spider.global_basis * default_foothold_local
		var actual_anchor: Vector3 = leg_state.get("default_anchor_world_position", Vector3.ZERO)
		max_anchor_error_m = maxf(max_anchor_error_m, actual_anchor.distance_to(expected_root_frame_anchor))

	if not T.require_true(
		self,
		max_anchor_error_m <= MAX_ALLOWED_DEFAULT_ANCHOR_ERROR_M,
		"Spider reference default anchor frame contract requires default anchors to stay root-frame anchored during terrain tilt; torso tilt must not rotate the stepping anchor lattice (max error %.3fm)" % max_anchor_error_m
	):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _build_default_foothold_lookup(legs: Array) -> Dictionary:
	var lookup := {}
	for leg_variant in legs:
		if not (leg_variant is Dictionary):
			continue
		var leg_contract: Dictionary = leg_variant as Dictionary
		var leg_id := str(leg_contract.get("leg_id", ""))
		if leg_id == "":
			continue
		lookup[leg_id] = leg_contract.get("default_foothold", Vector3.ZERO)
	return lookup
