extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_CONTRACTS := [
	{
		"path": "res://city_game/scenes/labs/SpiderCrawlerMorphologyLab.tscn",
		"root_name": "SpiderCrawlerMorphologyLab",
		"variant_id": "morphology_focus",
		"gait_profile_id": "tetrapod_ground",
	},
	{
		"path": "res://city_game/scenes/labs/SpiderCrawlerGaitLab.tscn",
		"root_name": "SpiderCrawlerGaitLab",
		"variant_id": "gait_focus",
		"gait_profile_id": "tetrapod_ground_async",
	},
	{
		"path": "res://city_game/scenes/labs/SpiderCrawlerHybridLab.tscn",
		"root_name": "SpiderCrawlerHybridLab",
		"variant_id": "hybrid_focus",
		"gait_profile_id": "tetrapod_ground_async",
	},
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var seen_variants: Dictionary = {}
	for contract_variant in LAB_CONTRACTS:
		var contract: Dictionary = contract_variant as Dictionary
		var scene_path: String = str(contract.get("path", ""))
		if not T.require_true(self, ResourceLoader.exists(scene_path, "PackedScene"), "Spider variant lab contract requires %s" % scene_path):
			return
		var scene := load(scene_path) as PackedScene
		if not T.require_true(self, scene != null, "Spider variant lab contract must load %s as PackedScene" % scene_path):
			return
		var lab := scene.instantiate() as Node3D
		root.add_child(lab)
		await process_frame
		await process_frame
		if not T.require_true(self, lab.name == str(contract.get("root_name", "")), "Spider variant lab contract requires %s root name" % str(contract.get("root_name", ""))):
			return
		if not T.require_true(self, lab.has_method("get_crawler_debug_state"), "Spider variant lab contract requires get_crawler_debug_state() on %s" % scene_path):
			return
		if not T.require_true(self, lab.get_node_or_null("CrawlerRoot") != null, "Spider variant lab contract requires CrawlerRoot in %s" % scene_path):
			return
		var debug_state: Dictionary = lab.get_crawler_debug_state()
		var variant_id: String = str(debug_state.get("variant_id", ""))
		if not T.require_true(self, variant_id == str(contract.get("variant_id", "")), "Spider variant lab contract requires %s to expose variant_id=%s" % [scene_path, str(contract.get("variant_id", ""))]):
			return
		if not T.require_true(self, str(debug_state.get("gait_profile_id", "")) == str(contract.get("gait_profile_id", "")), "Spider variant lab contract requires %s to expose gait_profile_id=%s" % [scene_path, str(contract.get("gait_profile_id", ""))]):
			return
		if not T.require_true(self, int(debug_state.get("leg_count", 0)) == 8, "Spider variant lab contract requires %s to preserve 8 legs" % scene_path):
			return
		seen_variants[variant_id] = true
		lab.queue_free()
		await process_frame
	if not T.require_true(self, seen_variants.size() == LAB_CONTRACTS.size(), "Spider variant lab contract requires each lab to expose a distinct variant_id"):
		return
	T.pass_and_quit(self)
