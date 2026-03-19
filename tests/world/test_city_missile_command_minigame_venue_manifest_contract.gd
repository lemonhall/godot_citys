extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REGISTRY_PATH := "res://city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json"
const VENUE_ID := "venue:v29:missile_command_battery:chunk_183_152"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v29_missile_command_battery_chunk_183_152/missile_command_minigame_venue.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v29_missile_command_battery_chunk_183_152/minigame_venue_manifest.json"
const EXPECTED_WORLD_POSITION := Vector3(11925.63, -4.74, 4126.84)
const EXPECTED_SURFACE_NORMAL := Vector3(-0.01, 1.0, 0.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Missile Command venue manifest contract requires venue registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Missile Command venue manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(VENUE_ID), "Missile Command venue manifest contract requires the v29 venue registry entry"):
		return

	var registry_entry: Dictionary = entries.get(VENUE_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Missile Command venue registry entry must point at the canonical venue scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Missile Command venue registry entry must point at the canonical venue manifest path"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_SCENE_PATH), "Missile Command venue manifest contract requires the authored venue scene resource to exist"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Missile Command venue manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("venue_id", "")) == VENUE_ID, "Missile Command venue manifest must preserve the formal venue_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_minigame_venue", "Missile Command venue manifest must declare feature_kind = scene_minigame_venue"):
		return
	if not T.require_true(self, str(manifest.get("game_kind", "")) == "missile_command_battery", "Missile Command venue manifest must declare game_kind = missile_command_battery"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_183_152", "Missile Command venue manifest must declare anchor_chunk_id = chunk_183_152"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(183, 152), "Missile Command venue manifest must preserve anchor_chunk_key = (183,152)"):
		return
	var world_position_variant: Variant = _decode_vector3(manifest.get("world_position", null))
	if not T.require_true(self, world_position_variant is Vector3 and (world_position_variant as Vector3).distance_to(EXPECTED_WORLD_POSITION) <= 0.01, "Missile Command venue manifest must preserve the authored world_position"):
		return
	var surface_normal_variant: Variant = _decode_vector3(manifest.get("surface_normal", null))
	if not T.require_true(self, surface_normal_variant is Vector3 and (surface_normal_variant as Vector3).distance_to(EXPECTED_SURFACE_NORMAL) <= 0.02, "Missile Command venue manifest must preserve the probed surface_normal"):
		return
	var scene_root_offset_variant: Variant = _decode_vector3(manifest.get("scene_root_offset", null))
	if not T.require_true(self, scene_root_offset_variant is Vector3, "Missile Command venue manifest must expose scene_root_offset as Vector3"):
		return
	var scene_root_offset := scene_root_offset_variant as Vector3
	if not T.require_true(self, absf(scene_root_offset.x) <= 0.001 and absf(scene_root_offset.z) <= 0.001, "Missile Command venue manifest must keep scene_root_offset lateral components frozen at zero"):
		return
	if not T.require_true(self, scene_root_offset.y >= 2.0, "Missile Command venue manifest must raise the battery platform above raw terrain instead of hugging the ground probe directly"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Missile Command venue manifest must keep scene_path aligned with the registry entry"):
		return
	if not T.require_true(self, str(manifest.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Missile Command venue manifest must self-report the canonical manifest_path"):
		return
	var full_map_pin: Dictionary = manifest.get("full_map_pin", {})
	if not T.require_true(self, bool(full_map_pin.get("visible", false)), "Missile Command venue manifest must opt into a visible full-map pin"):
		return
	if not T.require_true(self, str(full_map_pin.get("icon_id", "")) == "missile_command", "Missile Command venue manifest must declare icon_id = missile_command"):
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
	return Vector3(float(payload.get("x", 0.0)), float(payload.get("y", 0.0)), float(payload.get("z", 0.0)))

func _decode_vector2i(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector2i":
		return null
	return Vector2i(int(payload.get("x", 0)), int(payload.get("y", 0)))
