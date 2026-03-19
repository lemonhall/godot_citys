extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REGISTRY_PATH := "res://city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json"
const TENNIS_VENUE_ID := "venue:v28:tennis_court:chunk_158_140"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/tennis_minigame_venue.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/minigame_venue_manifest.json"
const EXPECTED_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)
const EXPECTED_SURFACE_NORMAL := Vector3(-0.02, 1.0, -0.02)
const EXPECTED_PRIMARY_BALL_PROP_ID := "prop:v28:tennis_ball:chunk_158_140"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Tennis minigame venue manifest contract requires venue registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Tennis minigame venue manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(TENNIS_VENUE_ID), "Tennis minigame venue manifest contract requires the tennis venue registry entry"):
		return

	var registry_entry: Dictionary = entries.get(TENNIS_VENUE_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Tennis venue registry entry must point at the canonical tennis venue scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Tennis venue registry entry must point at the canonical tennis venue manifest path"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_SCENE_PATH), "Tennis minigame venue manifest contract requires the authored tennis venue scene resource to exist"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Tennis minigame venue manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("venue_id", "")) == TENNIS_VENUE_ID, "Tennis minigame venue manifest must preserve the formal venue_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_minigame_venue", "Tennis minigame venue manifest must declare feature_kind = scene_minigame_venue"):
		return
	if not T.require_true(self, str(manifest.get("game_kind", "")) == "tennis_court", "Tennis minigame venue manifest must declare game_kind = tennis_court"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_158_140", "Tennis minigame venue manifest must declare anchor_chunk_id = chunk_158_140"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(158, 140), "Tennis minigame venue manifest must preserve anchor_chunk_key = (158,140)"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("world_position", null)).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Tennis minigame venue manifest must preserve the authored world_position"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("surface_normal", null)).distance_to(EXPECTED_SURFACE_NORMAL) <= 0.001, "Tennis minigame venue manifest must preserve the probed surface_normal"):
		return
	var scene_root_offset_variant: Variant = _decode_vector3(manifest.get("scene_root_offset", null))
	if not T.require_true(self, scene_root_offset_variant is Vector3, "Tennis minigame venue manifest must expose scene_root_offset as Vector3"):
		return
	var scene_root_offset := scene_root_offset_variant as Vector3
	if not T.require_true(self, absf(scene_root_offset.x) <= 0.001 and absf(scene_root_offset.z) <= 0.001, "Tennis minigame venue manifest must keep scene_root_offset lateral components frozen at zero"):
		return
	if not T.require_true(self, is_equal_approx(scene_root_offset.y, 2.74), "Tennis minigame venue manifest must preserve the ECN-0026 total court lift freeze of +2.0m over the raw authored baseline"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Tennis minigame venue manifest must keep scene_path aligned with registry entry"):
		return
	if not T.require_true(self, str(manifest.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Tennis minigame venue manifest must self-report the canonical manifest_path"):
		return
	if not T.require_true(self, str(manifest.get("primary_ball_prop_id", "")) == EXPECTED_PRIMARY_BALL_PROP_ID, "Tennis minigame venue manifest must bind to the canonical v28 tennis ball prop"):
		return
	var full_map_pin: Dictionary = manifest.get("full_map_pin", {})
	if not T.require_true(self, bool(full_map_pin.get("visible", false)), "Tennis minigame venue manifest must opt into a visible full-map pin"):
		return
	if not T.require_true(self, str(full_map_pin.get("icon_id", "")) == "tennis", "Tennis minigame venue manifest must declare icon_id = tennis"):
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
