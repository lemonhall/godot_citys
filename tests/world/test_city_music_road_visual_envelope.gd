extends SceneTree

const T := preload("res://tests/_test_util.gd")

const MANIFEST_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/landmark_manifest.json"
const MUSIC_ROAD_LANDMARK_ID := "landmark:v23:music_road:chunk_136_136"
const MIN_VISUAL_WIDTH_M := 14.0
const MIN_VISUAL_LENGTH_M := 1000.0
const MAX_BOTTOM_OFFSET_M := 1.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for music road visual envelope")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var manifest := _load_music_road_manifest()
	if manifest.is_empty():
		T.fail_and_quit(self, "Music road visual envelope requires a decodable landmark manifest")
		return
	var music_road_world_position: Vector3 = _decode_vector3(manifest.get("world_position", null))
	var player := world.get_node_or_null("Player")
	var chunk_renderer = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Music road visual envelope requires Player teleport API"):
		return
	if not T.require_true(self, chunk_renderer != null and chunk_renderer.has_method("find_scene_landmark_node"), "Music road visual envelope requires chunk renderer landmark lookup"):
		return

	player.teleport_to_world_position(music_road_world_position + Vector3(0.0, 8.0, 18.0))
	world.update_streaming_for_position(player.global_position, 0.0)

	var mounted_landmark: Node3D = null
	for _frame in range(180):
		await process_frame
		mounted_landmark = chunk_renderer.find_scene_landmark_node(MUSIC_ROAD_LANDMARK_ID) as Node3D
		if mounted_landmark != null:
			break
	if not T.require_true(self, mounted_landmark != null, "Music road visual envelope must mount the landmark after the player approaches the authored road corridor"):
		return
	if not T.require_true(self, mounted_landmark.has_method("get_music_road_debug_state"), "Music road visual envelope requires mounted landmark debug state"):
		return

	var debug_state: Dictionary = mounted_landmark.get_music_road_debug_state()
	if not T.require_true(self, int(debug_state.get("strip_count", 0)) >= 900, "Music road visual envelope must author the full jue_bie_shu strip set in the mounted landmark"):
		return
	if not T.require_true(self, int(debug_state.get("white_key_count", 0)) > 0, "Music road visual envelope must expose at least one white-key strip visual"):
		return
	if not T.require_true(self, int(debug_state.get("black_key_count", 0)) > 0, "Music road visual envelope must expose at least one black-key strip visual"):
		return
	if not T.require_true(self, int(debug_state.get("key_instance_count", 0)) >= int(debug_state.get("strip_count", 0)), "Music road visual envelope must materialize the full key-strip set through the active render backend"):
		return
	if not T.require_true(self, bool(debug_state.get("uses_project_owned_assets", false)), "Music road visual envelope must only reference project-owned adopted highway assets"):
		return

	var visual_extents := _collect_visual_extents(mounted_landmark)
	if not T.require_true(self, int(visual_extents.get("visual_count", 0)) > 0, "Music road landmark must contribute visible VisualInstance3D geometry"):
		return
	if not T.require_true(self, float(visual_extents.get("footprint_x_m", 0.0)) >= MIN_VISUAL_WIDTH_M, "Music road visual envelope must present a readable drivable width"):
		return
	var longitudinal_footprint_m := maxf(float(visual_extents.get("footprint_x_m", 0.0)), float(visual_extents.get("footprint_z_m", 0.0)))
	if not T.require_true(self, longitudinal_footprint_m >= MIN_VISUAL_LENGTH_M, "Music road visual envelope must author a long-form piano road instead of a short placeholder pad"):
		return
	if not T.require_true(self, absf(float(visual_extents.get("bottom_y", 0.0)) - music_road_world_position.y) <= MAX_BOTTOM_OFFSET_M, "Music road visual bottom must stay near the authored ground-aligned world_position"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _collect_visual_extents(root_node: Node3D) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var min_z := INF
	var max_z := -INF
	var visual_count := 0
	for child in root_node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var world_corner := visual.global_transform * corner
			min_x = minf(min_x, world_corner.x)
			max_x = maxf(max_x, world_corner.x)
			min_y = minf(min_y, world_corner.y)
			max_y = maxf(max_y, world_corner.y)
			min_z = minf(min_z, world_corner.z)
			max_z = maxf(max_z, world_corner.z)
		visual_count += 1
	if visual_count <= 0:
		return {
			"visual_count": 0,
		}
	return {
		"visual_count": visual_count,
		"footprint_x_m": max_x - min_x,
		"footprint_z_m": max_z - min_z,
		"height_m": max_y - min_y,
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

func _load_music_road_manifest() -> Dictionary:
	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not (manifest_variant is Dictionary):
		return {}
	return (manifest_variant as Dictionary).duplicate(true)

func _decode_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var payload: Dictionary = value
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)
