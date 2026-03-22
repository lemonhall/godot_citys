extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REGISTRY_PATH := "res://city_game/serviceability/terrain_regions/generated/terrain_region_registry.json"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/terrain_region_manifest.json"
const EXPECTED_SHORELINE_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/lake_shoreline_profile.json"
const EXPECTED_BATHYMETRY_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/lake_bathymetry_profile.json"
const EXPECTED_HABITAT_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/fish_habitat_profile.json"
const EXPECTED_WORLD_POSITION := Vector3(2844.59, 0.0, 11508.18)
const EXPECTED_LINKED_VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Lake region manifest contract requires terrain region registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Lake region manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(REGION_ID), "Lake region manifest contract requires the v38 lake registry entry"):
		return

	var registry_entry: Dictionary = entries.get(REGION_ID, {})
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Lake region registry entry must point at the canonical manifest path"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_MANIFEST_PATH), "Lake region manifest contract requires the canonical terrain region manifest resource to exist"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Lake region manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("region_id", "")) == REGION_ID, "Lake region manifest must preserve the formal region_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "terrain_region_feature", "Lake region manifest must declare feature_kind = terrain_region_feature"):
		return
	if not T.require_true(self, str(manifest.get("region_kind", "")) == "lake_basin", "Lake region manifest must declare region_kind = lake_basin"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_147_181", "Lake region manifest must declare anchor_chunk_id = chunk_147_181"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(147, 181), "Lake region manifest must preserve anchor_chunk_key = (147,181)"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("world_position", null)).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Lake region manifest must preserve the authored world_position"):
		return
	if not T.require_true(self, is_equal_approx(float(manifest.get("water_level_y_m", 999.0)), 0.0), "Lake region manifest must freeze water_level_y_m = 0.0"):
		return
	if not T.require_true(self, is_equal_approx(float(manifest.get("mean_depth_m", -1.0)), 10.0), "Lake region manifest must freeze mean_depth_m = 10.0"):
		return
	if not T.require_true(self, is_equal_approx(float(manifest.get("max_depth_m", -1.0)), 15.0), "Lake region manifest must freeze max_depth_m = 15.0"):
		return
	if not T.require_true(self, str(manifest.get("shoreline_profile_path", "")) == EXPECTED_SHORELINE_PATH, "Lake region manifest must self-report the canonical shoreline profile path"):
		return
	if not T.require_true(self, str(manifest.get("bathymetry_profile_path", "")) == EXPECTED_BATHYMETRY_PATH, "Lake region manifest must self-report the canonical bathymetry profile path"):
		return
	if not T.require_true(self, str(manifest.get("habitat_profile_path", "")) == EXPECTED_HABITAT_PATH, "Lake region manifest must self-report the canonical habitat profile path"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_SHORELINE_PATH), "Lake region manifest contract requires the shoreline profile json resource to exist"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_BATHYMETRY_PATH), "Lake region manifest contract requires the bathymetry profile json resource to exist"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_HABITAT_PATH), "Lake region manifest contract requires the habitat profile json resource to exist"):
		return
	var linked_venue_ids: Array = manifest.get("linked_venue_ids", [])
	if not T.require_true(self, linked_venue_ids.has(EXPECTED_LINKED_VENUE_ID), "Lake region manifest must preserve linked_venue_ids -> venue:v38:lakeside_fishing:chunk_147_181"):
		return

	T.pass_and_quit(self)

func _decode_vector3(value: Variant) -> Variant:
	if value is Vector3:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector3":
		return null
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)

func _decode_vector2i(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector2i":
		return null
	return Vector2i(
		int(payload.get("x", 0)),
		int(payload.get("y", 0))
	)
