extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_SCRIPT_PATH := "res://city_game/world/features/CityTerrainRegionFeatureRegistry.gd"
const RUNTIME_SCRIPT_PATH := "res://city_game/world/features/CityTerrainRegionFeatureRuntime.gd"
const WATER_PROVIDER_PATH := "res://city_game/world/rendering/CityWaterSurfacePageProvider.gd"
const REGISTRY_PATH := "res://city_game/serviceability/terrain_regions/generated/terrain_region_registry.json"
const ANCHOR_CHUNK_ID := "chunk_147_181"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_script := load(REGISTRY_SCRIPT_PATH)
	var runtime_script := load(RUNTIME_SCRIPT_PATH)
	var provider_script := load(WATER_PROVIDER_PATH)
	if not T.require_true(self, registry_script != null, "Lake water surface contract requires CityTerrainRegionFeatureRegistry.gd"):
		return
	if not T.require_true(self, runtime_script != null, "Lake water surface contract requires CityTerrainRegionFeatureRuntime.gd"):
		return
	if not T.require_true(self, provider_script != null, "Lake water surface contract requires CityWaterSurfacePageProvider.gd"):
		return

	var registry = registry_script.new()
	registry.configure(REGISTRY_PATH, [REGISTRY_PATH])
	var runtime = runtime_script.new()
	runtime.configure(registry.load_registry())

	var provider = provider_script.new()
	if not T.require_true(self, provider != null and provider.has_method("setup"), "Lake water surface contract requires setup()"):
		return
	if not T.require_true(self, provider.has_method("get_entries_for_chunk"), "Lake water surface contract requires get_entries_for_chunk()"):
		return
	provider.setup(runtime)
	var entries: Array = provider.get_entries_for_chunk(ANCHOR_CHUNK_ID)
	if not T.require_true(self, entries.size() >= 1, "Lake water surface contract must expose at least one water surface entry for chunk_147_181"):
		return
	var water_entry: Dictionary = entries[0]
	if not T.require_true(self, str(water_entry.get("region_id", "")) == REGION_ID, "Lake water surface entry must preserve the formal region_id"):
		return
	if not T.require_true(self, is_equal_approx(float(water_entry.get("water_level_y_m", 999.0)), 0.0), "Lake water surface entry must keep water_level_y_m = 0.0"):
		return
	if not T.require_true(self, str(water_entry.get("render_owner_chunk_id", "")) == ANCHOR_CHUNK_ID, "Lake water surface must stay owned by the anchor chunk for shared rendering reuse"):
		return
	var polygon_points: Array = water_entry.get("polygon_world_points", [])
	if not T.require_true(self, polygon_points.size() >= 6, "Lake water surface contract must carry an authored irregular polygon instead of a trivial rectangle placeholder"):
		return

	T.pass_and_quit(self)
