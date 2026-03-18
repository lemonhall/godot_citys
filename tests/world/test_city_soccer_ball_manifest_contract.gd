extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_PATH := "res://city_game/serviceability/interactive_props/generated/interactive_prop_registry.json"
const SOCCER_PROP_ID := "prop:v25:soccer_ball:chunk_129_139"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/soccer_ball_prop.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/interactive_props/generated/prop_v25_soccer_ball_chunk_129_139/interactive_prop_manifest.json"
const EXPECTED_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const EXPECTED_SURFACE_NORMAL := Vector3(-0.02, 1.0, -0.02)
const EXPECTED_SCENE_ROOT_OFFSET := Vector3(0.0, 0.60, 0.0)
const EXPECTED_TARGET_DIAMETER_M := 1.20

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Soccer ball manifest contract requires interactive prop registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Soccer ball manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(SOCCER_PROP_ID), "Soccer ball manifest contract requires the soccer ball registry entry"):
		return

	var registry_entry: Dictionary = entries.get(SOCCER_PROP_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Soccer ball registry entry must point at the canonical soccer prop scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Soccer ball registry entry must point at the canonical soccer prop manifest path"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Soccer ball manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("prop_id", "")) == SOCCER_PROP_ID, "Soccer ball manifest must preserve the formal prop_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_interactive_prop", "Soccer ball manifest must declare feature_kind = scene_interactive_prop"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_129_139", "Soccer ball manifest must declare anchor_chunk_id = chunk_129_139"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(129, 139), "Soccer ball manifest must preserve anchor_chunk_key = (129,139)"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("world_position", null)).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Soccer ball manifest must preserve the user-authored ground anchor world_position"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("surface_normal", null)).distance_to(EXPECTED_SURFACE_NORMAL) <= 0.001, "Soccer ball manifest must preserve the authored surface_normal"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("scene_root_offset", null)).distance_to(EXPECTED_SCENE_ROOT_OFFSET) <= 0.001, "Soccer ball manifest must preserve the formal scene_root_offset that lifts the ball center above ground"):
		return
	if not T.require_true(self, absf(float(manifest.get("target_diameter_m", 0.0)) - EXPECTED_TARGET_DIAMETER_M) <= 0.001, "Soccer ball manifest must preserve the oversized gameplay target_diameter_m freeze"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Soccer ball manifest must keep scene_path aligned with registry entry"):
		return
	if not T.require_true(self, not manifest.has("full_map_pin"), "Soccer ball manifest must not opt into full-map pin semantics"):
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
