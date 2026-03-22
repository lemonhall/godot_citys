extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CRAWLER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CityLobsterCrawler.tscn"
const SHARED_RUNTIME_SCRIPT_PATH := "res://city_game/world/creatures/arthropods/CityArthropodCrawlerRuntime.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(CRAWLER_SCENE_PATH, "PackedScene"), "Lobster shared-runtime contract requires CityLobsterCrawler.tscn"):
		return
	var scene := load(CRAWLER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lobster shared-runtime contract must load CityLobsterCrawler as PackedScene"):
		return

	var crawler := scene.instantiate() as Node3D
	root.add_child(crawler)
	await process_frame
	await process_frame

	for required_method in [
		"get_debug_state",
		"get_profile_contract",
		"get_portability_contract",
		"tick_crawler",
		"debug_force_replan_all_legs",
	]:
		if not T.require_true(self, crawler.has_method(required_method), "Lobster shared-runtime contract requires %s()" % required_method):
			return

	var shared_runtime := crawler.get_node_or_null("SharedRuntime") as Node
	if not T.require_true(self, shared_runtime != null, "Lobster shared-runtime contract requires a dedicated SharedRuntime child node"):
		return
	var runtime_script := shared_runtime.get_script() as Script
	if not T.require_true(self, runtime_script != null and str(runtime_script.resource_path) == SHARED_RUNTIME_SCRIPT_PATH, "Lobster shared-runtime contract must wire the formal CityArthropodCrawlerRuntime.gd script instead of a lobster-only runtime"):
		return

	var debug_state: Dictionary = crawler.get_debug_state()
	if not T.require_true(self, str(debug_state.get("species_id", "")) == "lobster", "Lobster shared-runtime contract must preserve lobster as species_id"):
		return
	if not T.require_true(self, str(debug_state.get("gait_profile_id", "")) == "metachronal_forward", "Lobster shared-runtime contract must preserve the metachronal gait id"):
		return
	if not T.require_true(self, int(debug_state.get("leg_count", 0)) == 10, "Lobster shared-runtime contract must configure 10 limbs through the shared runtime"):
		return

	var profile_contract: Dictionary = crawler.get_profile_contract()
	if not T.require_true(self, float(profile_contract.get("body_clearance_m", 1.0)) < 0.5, "Lobster shared-runtime contract must preserve the low-clearance profile via shared runtime configuration"):
		return
	if not T.require_true(self, int((profile_contract.get("legs", []) as Array).size()) == 10, "Lobster shared-runtime contract must expose all limb contracts through get_profile_contract()"):
		return

	var portability_contract: Dictionary = crawler.get_portability_contract()
	if not T.require_true(self, str((portability_contract.get("debug_passthrough", {}) as Dictionary).get("method", "")) == "get_debug_state", "Lobster shared-runtime contract must wire future portability debug passthrough back to get_debug_state()"):
		return
	if not T.require_true(self, str((portability_contract.get("world_anchor", {}) as Dictionary).get("kind", "")) == "external_anchor_node3d", "Lobster shared-runtime contract must freeze an external world-anchor portability hook"):
		return

	crawler.queue_free()
	await process_frame
	T.pass_and_quit(self)
