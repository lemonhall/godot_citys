extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REGISTRY_PATH := "res://city_game/serviceability/interactive_props/generated/interactive_prop_registry.json"
const TENNIS_PROP_ID := "prop:v28:tennis_ball:chunk_158_140"
const EXPECTED_SCENE_PATH := "res://city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/tennis_ball_prop.tscn"
const EXPECTED_MANIFEST_PATH := "res://city_game/serviceability/interactive_props/generated/prop_v28_tennis_ball_chunk_158_140/interactive_prop_manifest.json"
const EXPECTED_WORLD_POSITION := Vector3(5489.46, 20.62, 1029.73)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not T.require_true(self, registry_variant is Dictionary, "Tennis ball prop manifest contract requires interactive prop registry json to parse as Dictionary"):
		return
	var registry: Dictionary = registry_variant
	var entries_variant = registry.get("entries", {})
	if not T.require_true(self, entries_variant is Dictionary, "Tennis ball prop manifest contract requires registry entries payload"):
		return
	var entries: Dictionary = entries_variant
	if not T.require_true(self, entries.has(TENNIS_PROP_ID), "Tennis ball prop manifest contract requires the tennis ball registry entry"):
		return

	var registry_entry: Dictionary = entries.get(TENNIS_PROP_ID, {})
	if not T.require_true(self, str(registry_entry.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Tennis ball registry entry must point at the canonical tennis ball scene path"):
		return
	if not T.require_true(self, str(registry_entry.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Tennis ball registry entry must point at the canonical tennis ball manifest path"):
		return
	if not T.require_true(self, ResourceLoader.exists(EXPECTED_SCENE_PATH), "Tennis ball prop manifest contract requires the authored tennis ball scene resource to exist"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(EXPECTED_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Tennis ball manifest must parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	if not T.require_true(self, str(manifest.get("prop_id", "")) == TENNIS_PROP_ID, "Tennis ball manifest must preserve the formal prop_id"):
		return
	if not T.require_true(self, str(manifest.get("feature_kind", "")) == "scene_interactive_prop", "Tennis ball manifest must declare feature_kind = scene_interactive_prop"):
		return
	if not T.require_true(self, str(manifest.get("anchor_chunk_id", "")) == "chunk_158_140", "Tennis ball manifest must declare anchor_chunk_id = chunk_158_140"):
		return
	if not T.require_true(self, _decode_vector2i(manifest.get("anchor_chunk_key", null)) == Vector2i(158, 140), "Tennis ball manifest must preserve anchor_chunk_key = (158,140)"):
		return
	if not T.require_true(self, _decode_vector3(manifest.get("world_position", null)).distance_to(EXPECTED_WORLD_POSITION) <= 0.001, "Tennis ball manifest must preserve the authored world_position"):
		return
	var scene_root_offset_variant: Variant = _decode_vector3(manifest.get("scene_root_offset", null))
	if not T.require_true(self, scene_root_offset_variant is Vector3, "Tennis ball manifest must expose scene_root_offset as Vector3"):
		return
	var scene_root_offset := scene_root_offset_variant as Vector3
	if not T.require_true(self, scene_root_offset.y >= 2.8, "Tennis ball manifest must preserve the ECN-0026 lifted resting center above the raised tennis court"):
		return
	if not T.require_true(self, str(manifest.get("interaction_kind", "")) == "swing", "Tennis ball manifest must freeze interaction_kind = swing"):
		return
	if not T.require_true(self, str(manifest.get("prompt_text", "")) == "按 E 击球", "Tennis ball manifest must expose the formal swing prompt text"):
		return
	if not T.require_true(self, float(manifest.get("interaction_radius_m", 0.0)) >= 3.8, "Tennis ball manifest must align shared prompt radius with the tennis strike window instead of freezing a tiny generic prop radius"):
		return
	if not T.require_true(self, float(manifest.get("target_diameter_m", 0.0)) >= 0.27 and float(manifest.get("target_diameter_m", 0.0)) <= 0.36, "Tennis ball manifest must freeze an oversized third-person-readable target diameter after ECN-0026"):
		return
	if not T.require_true(self, float(manifest.get("physics_mass_kg", 0.0)) > 0.03 and float(manifest.get("physics_mass_kg", 0.0)) < 0.2, "Tennis ball manifest must use a tennis-scale physics mass"):
		return
	if not T.require_true(self, str(manifest.get("scene_path", "")) == EXPECTED_SCENE_PATH, "Tennis ball manifest must keep scene_path aligned with registry entry"):
		return
	if not T.require_true(self, str(manifest.get("manifest_path", "")) == EXPECTED_MANIFEST_PATH, "Tennis ball manifest must self-report the canonical manifest_path"):
		return

	var ball_scene := load(EXPECTED_SCENE_PATH)
	if not T.require_true(self, ball_scene is PackedScene, "Tennis ball manifest contract requires the authored tennis ball scene to load as PackedScene"):
		return
	var ball_node := (ball_scene as PackedScene).instantiate()
	root.add_child(ball_node)
	if ball_node.has_method("configure_interactive_prop"):
		ball_node.configure_interactive_prop(manifest.duplicate(true))
	await process_frame
	var collision_shape := ball_node.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not T.require_true(self, collision_shape != null and collision_shape.shape is SphereShape3D, "Tennis ball prop contract requires a sphere collision shape"):
		return
	var sphere_shape := collision_shape.shape as SphereShape3D
	if not T.require_true(self, is_equal_approx(sphere_shape.radius, float(manifest.get("target_diameter_m", 0.0)) * 0.5), "Tennis ball prop contract must drive the collision radius from target_diameter_m"):
		return
	var visual_root := ball_node.get_node_or_null("VisualRoot") as Node3D
	if not T.require_true(self, visual_root != null and visual_root.scale.x > 1.8, "Tennis ball prop contract must upscale the visual mesh instead of leaving the ball at its tiny import size"):
		return
	ball_node.queue_free()

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
