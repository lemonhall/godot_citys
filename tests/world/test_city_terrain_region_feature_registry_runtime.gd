extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_SCRIPT_PATH := "res://city_game/world/features/CityTerrainRegionFeatureRegistry.gd"
const RUNTIME_SCRIPT_PATH := "res://city_game/world/features/CityTerrainRegionFeatureRuntime.gd"
const REGISTRY_PATH := "res://city_game/serviceability/terrain_regions/generated/terrain_region_registry.json"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"
const ANCHOR_CHUNK_ID := "chunk_147_181"
const LINKED_VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_script := load(REGISTRY_SCRIPT_PATH)
	if not T.require_true(self, registry_script != null, "Terrain region registry runtime contract requires CityTerrainRegionFeatureRegistry.gd"):
		return
	var runtime_script := load(RUNTIME_SCRIPT_PATH)
	if not T.require_true(self, runtime_script != null, "Terrain region registry runtime contract requires CityTerrainRegionFeatureRuntime.gd"):
		return

	var registry = registry_script.new()
	if not T.require_true(self, registry != null and registry.has_method("configure"), "Terrain region registry runtime contract requires configure()"):
		return
	if not T.require_true(self, registry.has_method("load_registry"), "Terrain region registry runtime contract requires load_registry()"):
		return
	var runtime = runtime_script.new()
	if not T.require_true(self, runtime != null and runtime.has_method("configure"), "Terrain region runtime contract requires configure()"):
		return
	if not T.require_true(self, runtime.has_method("get_entries_for_chunk"), "Terrain region runtime contract requires get_entries_for_chunk()"):
		return
	if not T.require_true(self, runtime.has_method("get_state"), "Terrain region runtime contract requires get_state()"):
		return

	registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var entries: Dictionary = registry.load_registry()
	if not T.require_true(self, entries.has(REGION_ID), "Terrain region registry must load the generated v38 lake region entry from registry json"):
		return

	runtime.configure(entries)
	var runtime_state: Dictionary = runtime.get_state()
	if not T.require_true(self, int(runtime_state.get("entry_count", 0)) >= 1, "Terrain region runtime must cache at least one resolved lake entry"):
		return
	if not T.require_true(self, int(runtime_state.get("manifest_read_count", 0)) >= 1, "Terrain region runtime must read terrain manifests instead of synthesizing entries"):
		return

	var chunk_entries: Array = runtime.get_entries_for_chunk(ANCHOR_CHUNK_ID)
	if not T.require_true(self, chunk_entries.size() >= 1, "Terrain region runtime must index the fishing lake under chunk_147_181"):
		return
	var lake_entry: Dictionary = chunk_entries[0]
	if not T.require_true(self, str(lake_entry.get("region_id", "")) == REGION_ID, "Terrain region runtime chunk lookup must preserve the formal lake region_id"):
		return
	if not T.require_true(self, str(lake_entry.get("feature_kind", "")) == "terrain_region_feature", "Terrain region runtime must preserve feature_kind = terrain_region_feature"):
		return
	if not T.require_true(self, str(lake_entry.get("region_kind", "")) == "lake_basin", "Terrain region runtime must preserve region_kind = lake_basin"):
		return
	var linked_venue_ids: Array = lake_entry.get("linked_venue_ids", [])
	if not T.require_true(self, linked_venue_ids.has(LINKED_VENUE_ID), "Lake region runtime must preserve linked_venue_ids -> venue:v38:lakeside_fishing:chunk_147_181"):
		return

	var second_registry = registry_script.new()
	second_registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var second_entries: Dictionary = second_registry.load_registry()
	var second_runtime = runtime_script.new()
	second_runtime.configure(second_entries)
	var second_chunk_entries: Array = second_runtime.get_entries_for_chunk(ANCHOR_CHUNK_ID)
	if not T.require_true(self, second_chunk_entries.size() >= 1, "Terrain region registry/runtime contract must reload the lake on a second session"):
		return

	T.pass_and_quit(self)
