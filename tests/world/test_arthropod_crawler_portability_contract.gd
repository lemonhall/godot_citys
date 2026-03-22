extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_CRAWLER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"
const LOBSTER_CRAWLER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CityLobsterCrawler.tscn"
const SPIDER_LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const LOBSTER_LAB_SCENE_PATH := "res://city_game/scenes/labs/LobsterCrawlerLab.tscn"
const SHARED_RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var spider_scene := load(SPIDER_CRAWLER_SCENE_PATH) as PackedScene
	var lobster_scene := load(LOBSTER_CRAWLER_SCENE_PATH) as PackedScene
	if not T.require_true(self, spider_scene != null and lobster_scene != null, "Arthropod portability contract requires both species crawler scenes"):
		return

	var spider := spider_scene.instantiate() as Node3D
	var lobster := lobster_scene.instantiate() as Node3D
	root.add_child(spider)
	root.add_child(lobster)
	await process_frame
	await process_frame

	for crawler in [spider, lobster]:
		if not T.require_true(self, crawler.has_method("get_portability_contract"), "Arthropod portability contract requires every species wrapper to expose get_portability_contract()"):
			return
		if not T.require_true(self, crawler.has_method("get_debug_state"), "Arthropod portability contract requires every species wrapper to expose get_debug_state()"):
			return
		var shared_runtime := crawler.get_node_or_null("SharedRuntime") as Node
		if not T.require_true(self, shared_runtime != null, "Arthropod portability contract requires each species wrapper to host a SharedRuntime child"):
			return
		var runtime_script := shared_runtime.get_script() as Script
		if not T.require_true(self, runtime_script != null and str(runtime_script.resource_path) == SHARED_RUNTIME_SCRIPT_PATH, "Arthropod portability contract requires every species wrapper to point at the same shared locomotion runtime script"):
			return

	var spider_contract: Dictionary = spider.get_portability_contract()
	var lobster_contract: Dictionary = lobster.get_portability_contract()
	for contract in [spider_contract, lobster_contract]:
		for top_level_key in [
			"world_anchor",
			"ground_resolver",
			"activation_gate",
			"spawn_policy",
			"debug_passthrough",
		]:
			if not T.require_true(self, contract.has(top_level_key), "Arthropod portability contract must freeze %s for future main-world reuse" % top_level_key):
				return
		if not T.require_true(self, str((contract.get("world_anchor", {}) as Dictionary).get("kind", "")) == "external_anchor_node3d", "Arthropod portability contract must externalize world anchoring instead of depending on a lab root"):
			return
		if not T.require_true(self, str((contract.get("ground_resolver", {}) as Dictionary).get("kind", "")) == "callable", "Arthropod portability contract must freeze a callable ground resolver hook"):
			return
		if not T.require_true(self, str((contract.get("activation_gate", {}) as Dictionary).get("kind", "")) == "bool_gate", "Arthropod portability contract must freeze an activation gate hook instead of hard-wiring always-on lab stepping"):
			return
		if not T.require_true(self, str((contract.get("spawn_policy", {}) as Dictionary).get("kind", "")) == "external_chunk_gate", "Arthropod portability contract must freeze spawn/despawn policy as an external world concern"):
			return
		if not T.require_true(self, str((contract.get("debug_passthrough", {}) as Dictionary).get("method", "")) == "get_debug_state", "Arthropod portability contract must freeze debug passthrough onto the species wrapper debug API"):
			return

	if not T.require_true(self, str(spider_contract.get("species_id", "")) == "spider" and str(lobster_contract.get("species_id", "")) == "lobster", "Arthropod portability contract must preserve species identity across future wrappers"):
		return

	var spider_lab := (load(SPIDER_LAB_SCENE_PATH) as PackedScene).instantiate()
	var lobster_lab := (load(LOBSTER_LAB_SCENE_PATH) as PackedScene).instantiate()
	root.add_child(spider_lab)
	root.add_child(lobster_lab)
	await process_frame
	if not T.require_true(self, not spider_lab.has_method("get_portability_contract"), "Arthropod portability contract must not treat SpiderCrawlerLab itself as the future main-world wrapper"):
		return
	if not T.require_true(self, not lobster_lab.has_method("get_portability_contract"), "Arthropod portability contract must not treat LobsterCrawlerLab itself as the future main-world wrapper"):
		return

	spider.queue_free()
	lobster.queue_free()
	spider_lab.queue_free()
	lobster_lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
