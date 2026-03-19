extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FOUNTAIN_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_fountain_chunk_129_142/fountain_landmark.tscn"
const LOBSTER_MODEL_PATH := "res://city_game/assets/environment/source/creatures/lobster_02.glb"
const LOBSTER_PROP_ID := "prop:v27:fountain_lobster:chunk_129_142"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(FOUNTAIN_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Fountain lobster scene contract requires the fountain landmark scene to load as PackedScene"):
		return
	var scene_root := (scene as PackedScene).instantiate()
	if not T.require_true(self, scene_root is Node3D, "Fountain lobster scene contract requires the fountain landmark scene to instantiate as Node3D"):
		return
	root.add_child(scene_root)
	await process_frame

	var lobster := scene_root.get_node_or_null("Lobster") as Node3D
	if not T.require_true(self, lobster != null, "Fountain lobster scene contract requires a dedicated Lobster node under the fountain landmark root"):
		return
	if not T.require_true(self, lobster.has_method("get_interaction_contract"), "Fountain lobster scene contract requires the lobster node to expose an interactive prop contract"):
		return
	if not T.require_true(self, lobster.has_method("apply_player_interaction"), "Fountain lobster scene contract requires the lobster node to handle player interaction"):
		return
	if not T.require_true(self, lobster.has_method("get_debug_state"), "Fountain lobster scene contract requires lobster debug state for regression coverage"):
		return

	var lobster_model := lobster.get_node_or_null("Model") as Node3D
	if not T.require_true(self, lobster_model != null, "Fountain lobster scene contract requires a Model child under Lobster"):
		return
	if not T.require_true(self, str(lobster_model.scene_file_path) == LOBSTER_MODEL_PATH, "Fountain lobster scene contract must source the curated lobster glb from the formal environment asset directory"):
		return

	var interaction_contract: Dictionary = lobster.get_interaction_contract()
	if not T.require_true(self, str(interaction_contract.get("prop_id", "")) == LOBSTER_PROP_ID, "Fountain lobster scene contract must preserve the formal prop_id"):
		return
	if not T.require_true(self, str(interaction_contract.get("interaction_kind", "")) == "wave", "Fountain lobster scene contract must expose wave as the interaction kind"):
		return
	if not T.require_true(self, float(interaction_contract.get("interaction_radius_m", 0.0)) >= 2.0, "Fountain lobster scene contract must expose a readable interaction radius"):
		return
	if not T.require_true(self, str(interaction_contract.get("prompt_text", "")).find("E") >= 0, "Fountain lobster scene contract prompt must describe the E key interaction"):
		return

	var debug_state: Dictionary = lobster.get_debug_state()
	if not T.require_true(self, str(debug_state.get("wave_animation_name", "")) == "wave", "Fountain lobster scene contract must resolve the imported wave clip by name"):
		return
	if not T.require_true(self, not bool(debug_state.get("is_playing", true)), "Fountain lobster scene contract must keep wave stopped until the player interacts"):
		return
	if not T.require_true(self, int(debug_state.get("wave_play_count", -1)) == 0, "Fountain lobster scene contract must boot with zero wave interactions recorded"):
		return

	var visual_extents := _collect_visual_extents(lobster)
	if not T.require_true(self, int(visual_extents.get("visual_count", 0)) > 0, "Fountain lobster scene contract requires visible geometry"):
		return
	if not T.require_true(self, absf(float(visual_extents.get("bottom_y", 999.0))) <= 0.2, "Fountain lobster scene contract must keep the lobster grounded instead of floating above the landmark origin"):
		return

	scene_root.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _collect_visual_extents(root_node: Node3D) -> Dictionary:
	var min_y := INF
	var visual_count := 0
	for child in root_node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var world_corner := visual.global_transform * corner
			min_y = minf(min_y, world_corner.y)
		visual_count += 1
	if visual_count <= 0:
		return {
			"visual_count": 0,
		}
	return {
		"visual_count": visual_count,
		"bottom_y": min_y,
	}

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]
