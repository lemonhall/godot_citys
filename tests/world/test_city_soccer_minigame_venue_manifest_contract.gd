extends SceneTree

const T := preload("res://tests/_test_util.gd")
const REGISTRY_PATH := "res://city_game/serviceability/minigame_venues/generated/minigame_venue_registry.json"
const SOCCER_VENUE_ID := "venue:v26:soccer_pitch:chunk_129_139"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/soccer_minigame_venue.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/minigame_venue_manifest.json"
const EXPECTED_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const EXPECTED_SURFACE_NORMAL := Vector3.UP
const MIN_SCENE_ROOT_OFFSET_Y_M := 2.8
const EXPECTED_PRIMARY_BALL_PROP_ID := "prop:v25:soccer_ball:chunk_129_139"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Soccer minigame venue manifest contract requires venue registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Soccer minigame venue manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(SOCCER_VENUE_ID), "Soccer minigame venue manifest contract requires the soccer venue registry entry"):
		return

	var registry_entry: Dictionary = entries.get(SOCCER_VENUE_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Soccer minigame venue registry entry must point at the canonical soccer venue scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Soccer minigame venue registry entry must point at the canonical soccer venue manifest path"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_SCENE_PATH), "Soccer minigame venue manifest contract requires the authored soccer venue scene resource to exist"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Soccer minigame venue manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("venue_id", "")) == SOCCER_VENUE_ID, "Soccer minigame venue manifest must preserve the formal venue_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_minigame_venue", "Soccer minigame venue manifest must declare feature_kind = scene_minigame_venue"):
		return
	if not T.require_true(self, str(manifest.get("game_kind", "")) == "soccer_pitch", "Soccer minigame venue manifest must declare game_kind = soccer_pitch"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_129_139", "Soccer minigame venue manifest must declare anchor_chunk_id = chunk_129_139"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(129, 139), "Soccer minigame venue manifest must preserve anchor_chunk_key = (129,139)"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("world_position", null)).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Soccer minigame venue manifest must preserve the kickoff anchor world_position"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("surface_normal", null)).distance_to(EXPECTED_SURFACE_NORMAL) <= 0.001, "Soccer minigame venue manifest must preserve the flat playable surface_normal"):
		return
	var scene_root_offset_variant: Variant = _decode_vector3(manifest.get("scene_root_offset", null))
	if not T.require_true(self, scene_root_offset_variant is Vector3, "Soccer minigame venue manifest must expose scene_root_offset as Vector3"):
		return
	var scene_root_offset := scene_root_offset_variant as Vector3
	if not T.require_true(self, absf(scene_root_offset.x) <= 0.001 and absf(scene_root_offset.z) <= 0.001, "Soccer minigame venue manifest must keep scene_root_offset lateral components frozen at zero"):
		return
	if not T.require_true(self, scene_root_offset.y >= MIN_SCENE_ROOT_OFFSET_Y_M, "Soccer minigame venue manifest must raise the authored pitch root above terrain instead of keeping the venue glued to the raw ground height"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Soccer minigame venue manifest must keep scene_path aligned with registry entry"):
		return
	if not T.require_true(self, str(manifest.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Soccer minigame venue manifest must self-report the canonical manifest_path"):
		return
	if not T.require_true(self, str(manifest.get("primary_ball_prop_id", "")) == EXPECTED_PRIMARY_BALL_PROP_ID, "Soccer minigame venue manifest must bind to the canonical v25 soccer ball prop"):
		return
	if not T.require_true(self, not manifest.has("persistent_mount"), "Soccer minigame venue manifest must not opt into landmark-style persistent mount semantics"):
		return
	if not T.require_true(self, not manifest.has("full_map_pin"), "Soccer minigame venue manifest must not opt into full-map pin semantics in v26"):
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
