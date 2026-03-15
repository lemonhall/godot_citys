extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config_script := load("res://city_game/world/model/CityWorldConfig.gd")
	var generator_script := load("res://city_game/world/generation/CityWorldGenerator.gd")
	var cache_script := load("res://city_game/world/generation/CityPlaceIndexCache.gd")
	if config_script == null or generator_script == null or cache_script == null:
		T.fail_and_quit(self, "Place index cache test requires CityWorldConfig, CityWorldGenerator, and CityPlaceIndexCache")
		return

	var config = config_script.new()
	var generator = generator_script.new()
	var cache = cache_script.new()
	var world_a: Dictionary = generator.generate_world(config)
	var world_b: Dictionary = generator.generate_world(config)

	if not T.require_true(self, world_a.has("place_index"), "World generation must expose place_index before cache assertions can run"):
		return
	var place_index = world_a.get("place_index")
	if not T.require_true(self, place_index != null and place_index.has_method("get_cache_contract"), "place_index must expose get_cache_contract()"):
		return

	var cache_contract: Dictionary = place_index.get_cache_contract()
	var cache_path := str(cache_contract.get("path", ""))
	if not T.require_true(self, cache_path.begins_with("user://cache/world/place_index/place_index_"), "Place index cache path must live under user://cache/world/place_index/"):
		return
	if not T.require_true(self, str(cache_contract.get("world_signature", "")) != "", "Place index cache contract must expose world_signature"):
		return
	if not T.require_true(self, cache.build_cache_path(config, str(cache_contract.get("world_signature", ""))) == cache_path, "Place index cache helper must reproduce the frozen cache path"):
		return
	var place_index_b = world_b.get("place_index")
	if not T.require_true(self, place_index_b != null and place_index_b.has_method("get_cache_contract"), "Lazy place_index must still expose get_cache_contract() on the second world generation"):
		return
	var cache_contract_b: Dictionary = place_index_b.get_cache_contract()
	if not T.require_true(self, str(cache_contract_b.get("path", "")) != "", "Second world generation must materialize the place index cache contract on demand"):
		return
	var profile_b: Dictionary = world_b.get("generation_profile", {})
	if not T.require_true(self, bool(profile_b.get("place_index_cache_hit", false)), "Second world generation must hit the place index cache instead of rebuilding every time"):
		return

	T.pass_and_quit(self)
