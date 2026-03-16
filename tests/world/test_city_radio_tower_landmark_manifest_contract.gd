extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REGISTRY_PATH := "res://city_game/serviceability/landmarks/generated/landmark_override_registry.json"
const RADIO_TOWER_LANDMARK_ID := "landmark:v21:radio_tower:chunk_131_138"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_radio_tower_chunk_131_138/radio_tower_landmark.tscn"
const EXPECTED_PROXY_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_radio_tower_chunk_131_138/radio_tower_far_proxy.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_radio_tower_chunk_131_138/landmark_manifest.json"
const EXPECTED_WORLD_POSITION := Vector3(-1296.81, -7.25, 433.84)
const EXPECTED_VISIBILITY_RADIUS_M := 3200.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Radio tower landmark manifest contract requires registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Radio tower landmark manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(RADIO_TOWER_LANDMARK_ID), "Radio tower landmark manifest contract requires the radio tower registry entry"):
		return

	var registry_entry: Dictionary = entries.get(RADIO_TOWER_LANDMARK_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Radio tower registry entry must point at the canonical radio tower scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Radio tower registry entry must point at the canonical radio tower manifest path"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Radio tower landmark manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("landmark_id", "")) == RADIO_TOWER_LANDMARK_ID, "Radio tower manifest must preserve the formal landmark_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_landmark", "Radio tower manifest must declare feature_kind = scene_landmark"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_131_138", "Radio tower manifest must declare anchor_chunk_id = chunk_131_138"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(131, 138), "Radio tower manifest must preserve anchor_chunk_key = (131,138)"):
		return
	var decoded_world_position: Variant = _decode_vector3(manifest.get("world_position", null))
	if not T.require_true(self, decoded_world_position is Vector3 and (decoded_world_position as Vector3).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Radio tower manifest must preserve the authored absolute world_position from the ground probe"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Radio tower manifest must keep scene_path aligned with registry entry"):
		return

	var full_map_pin: Dictionary = manifest.get("full_map_pin", {})
	if not T.require_true(self, bool(full_map_pin.get("visible", false)), "Radio tower manifest must opt into full-map pin visibility"):
		return
	if not T.require_true(self, str(full_map_pin.get("icon_id", "")) == "radio_tower", "Radio tower manifest must declare icon_id = radio_tower"):
		return

	var far_visibility: Dictionary = manifest.get("far_visibility", {})
	if not T.require_true(self, bool(far_visibility.get("enabled", false)), "Radio tower manifest must enable far_visibility for the tall landmark consumer"):
		return
	if not T.require_true(self, str(far_visibility.get("proxy_scene_path", "")) == EXPECTED_PROXY_SCENE_PATH, "Radio tower far_visibility must point at the canonical proxy scene path"):
		return
	if not T.require_true(self, absf(float(far_visibility.get("visibility_radius_m", 0.0)) - EXPECTED_VISIBILITY_RADIUS_M) <= 0.01, "Radio tower far_visibility must preserve the authored visibility radius"):
		return
	var lod_modes: Array = far_visibility.get("lod_modes", [])
	if not T.require_true(self, lod_modes.size() == 2 and lod_modes.has("mid") and lod_modes.has("far"), "Radio tower far_visibility must target mid/far lod modes"):
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
