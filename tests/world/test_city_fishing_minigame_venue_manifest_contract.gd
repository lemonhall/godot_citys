extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REGISTRY_PATH := "res://city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json"
const MANIFEST_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/minigame_venue_manifest.json"
const SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/lake_fishing_minigame_venue.tscn"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(REGISTRY_PATH), "Fishing venue manifest contract requires the shared minigame venue registry json"):
		return
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Fishing venue manifest contract requires the venue registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Fishing venue manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(VENUE_ID), "Fishing venue manifest contract requires the v38 lakeside fishing venue entry in the shared registry"):
		return

	var registry_entry: Dictionary = entries.get(VENUE_ID, {})
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == MANIFEST_PATH, "Fishing venue registry entry must point at the canonical v38 fishing manifest"):
		return
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == SCENE_PATH, "Fishing venue registry entry must point at the canonical v38 fishing scene path"):
		return
	if not T.require_true(self, ResourceLoader.exists(MANIFEST_PATH), "Fishing venue manifest contract requires the canonical manifest resource"):
		return
	if not T.require_true(self, ResourceLoader.exists(SCENE_PATH, "PackedScene"), "Fishing venue manifest contract requires the canonical venue scene resource"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Fishing venue manifest contract requires manifest json to parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("venue_id", "")) == VENUE_ID, "Fishing venue manifest must preserve the formal venue_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_minigame_venue", "Fishing venue manifest must preserve feature_kind = scene_minigame_venue"):
		return
	if not T.require_true(self, str(manifest.get("game_kind", "")) == "lakeside_fishing", "Fishing venue manifest must declare game_kind = lakeside_fishing"):
		return
	if not T.require_true(self, str(manifest.get("linked_region_id", "")) == REGION_ID, "Fishing venue manifest must bind back to the formal lake region_id"):
		return
	var seat_anchor_ids: Array = manifest.get("seat_anchor_ids", [])
	if not T.require_true(self, seat_anchor_ids.size() >= 1, "Fishing venue manifest must declare at least one authored seat_anchor_id"):
		return
	if not T.require_true(self, str(manifest.get("cast_origin_anchor_id", "")) != "", "Fishing venue manifest must declare a cast_origin_anchor_id"):
		return
	var bite_zone_ids: Array = manifest.get("bite_zone_ids", [])
	if not T.require_true(self, bite_zone_ids.size() >= 1, "Fishing venue manifest must declare at least one bite zone id"):
		return
	if not T.require_true(self, float(manifest.get("trigger_radius_m", 0.0)) >= 4.0, "Fishing venue manifest must author a non-trivial trigger radius for entering the fishing seat flow"):
		return
	if not T.require_true(self, is_equal_approx(float(manifest.get("release_buffer_m", -1.0)), 32.0), "Fishing venue manifest must freeze release_buffer_m = 32.0"):
		return
	var full_map_pin_variant = manifest.get("full_map_pin", {})
	if not T.require_true(self, full_map_pin_variant is Dictionary, "Fishing venue manifest must define full_map_pin payload"):
		return
	var full_map_pin: Dictionary = full_map_pin_variant
	if not T.require_true(self, bool(full_map_pin.get("visible", false)), "Fishing venue manifest full_map_pin must be visible"):
		return
	if not T.require_true(self, str(full_map_pin.get("icon_id", "")) == "fishing", "Fishing venue manifest full_map_pin must freeze icon_id = fishing"):
		return

	T.pass_and_quit(self)
