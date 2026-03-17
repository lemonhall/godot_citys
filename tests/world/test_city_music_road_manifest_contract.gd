extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REGISTRY_PATH := "res://city_game/serviceability/landmarks/generated/landmark_override_registry.json"
const MUSIC_ROAD_LANDMARK_ID := "landmark:v23:music_road:chunk_136_136"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_landmark.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/landmark_manifest.json"
const EXPECTED_DEFINITION_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_definition.json"
const EXPECTED_ANCHOR_CHUNK_ID := "chunk_108_209"
const EXPECTED_ANCHOR_CHUNK_KEY := Vector2i(108, 209)
const EXPECTED_WORLD_POSITION := Vector3(-7278.5, -6.33, 18504.83)
const EXPECTED_YAW_RAD := PI * 0.5

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Music road manifest contract requires registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Music road manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(MUSIC_ROAD_LANDMARK_ID), "Music road manifest contract requires the music road registry entry"):
		return

	var registry_entry: Dictionary = entries.get(MUSIC_ROAD_LANDMARK_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Music road registry entry must point at the canonical music road scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Music road registry entry must point at the canonical music road manifest path"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Music road manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("landmark_id", "")) == MUSIC_ROAD_LANDMARK_ID, "Music road manifest must preserve the formal landmark_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_landmark", "Music road manifest must declare feature_kind = scene_landmark"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == EXPECTED_ANCHOR_CHUNK_ID, "Music road manifest must keep the re-authored anchor_chunk_id away from the spawn corridor"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == EXPECTED_ANCHOR_CHUNK_KEY, "Music road manifest must preserve the re-authored anchor_chunk_key"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("world_position", null)).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Music road manifest must preserve the re-authored start world_position"):
		return
	if not T.require_true(self, absf(float(manifest.get("yaw_rad", 0.0)) - EXPECTED_YAW_RAD) <= 0.0001, "Music road manifest must rotate the straight road onto the chosen empty horizontal corridor"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Music road manifest must keep scene_path aligned with registry entry"):
		return
	if not T.require_true(self, str(manifest.get("music_road_definition_path", "")) == EXPECTED_DEFINITION_PATH, "Music road manifest must point at the formal music_road_definition sidecar"):
		return
	var persistent_mount: Dictionary = manifest.get("persistent_mount", {})
	if not T.require_true(self, bool(persistent_mount.get("enabled", false)), "Music road manifest must enable persistent_mount so the full-length road survives beyond the anchor chunk window"):
		return
	if not T.require_true(self, float(persistent_mount.get("activation_radius_m", 0.0)) >= 1500.0, "Music road manifest must keep a persistent activation radius large enough to cover the authored road length"):
		return
	var full_map_pin: Dictionary = manifest.get("full_map_pin", {})
	if not T.require_true(self, bool(full_map_pin.get("visible", false)), "Music road manifest must opt into full-map pin visibility"):
		return
	if not T.require_true(self, str(full_map_pin.get("icon_id", "")) == "music_road", "Music road manifest must declare icon_id = music_road"):
		return
	if not T.require_true(self, str(full_map_pin.get("visibility_scope", "")) == "full_map", "Music road manifest must stay full_map only"):
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
