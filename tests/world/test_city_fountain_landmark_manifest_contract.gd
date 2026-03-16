extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_PATH := "res://city_game/serviceability/landmarks/generated/landmark_override_registry.json"
const FOUNTAIN_LANDMARK_ID := "landmark:v21:fountain:chunk_129_142"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_fountain_chunk_129_142/fountain_landmark.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_fountain_chunk_129_142/landmark_manifest.json"
const EXPECTED_WORLD_POSITION := Vector3(-1848.0, 14.545391, 1480.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Fountain landmark manifest contract requires registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Fountain landmark manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(FOUNTAIN_LANDMARK_ID), "Fountain landmark manifest contract requires the fountain registry entry"):
		return

	var registry_entry: Dictionary = entries.get(FOUNTAIN_LANDMARK_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Fountain registry entry must point at the canonical fountain scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Fountain registry entry must point at the canonical fountain manifest path"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Fountain landmark manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("landmark_id", "")) == FOUNTAIN_LANDMARK_ID, "Fountain manifest must preserve the formal landmark_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_landmark", "Fountain manifest must declare feature_kind = scene_landmark"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_129_142", "Fountain manifest must declare anchor_chunk_id = chunk_129_142"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(129, 142), "Fountain manifest must preserve anchor_chunk_key = (129,142)"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("world_position", null)).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Fountain manifest must preserve the authored fountain world_position at chunk center with sampled terrain height"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Fountain manifest must keep scene_path aligned with registry entry"):
		return
	var full_map_pin: Dictionary = manifest.get("full_map_pin", {})
	if not T.require_true(self, bool(full_map_pin.get("visible", false)), "Fountain manifest must opt into full-map pin visibility"):
		return
	if not T.require_true(self, str(full_map_pin.get("icon_id", "")) == "fountain", "Fountain manifest must declare icon_id = fountain"):
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
