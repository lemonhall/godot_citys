extends SceneTree

# v63 M5: the slice chunk must render the river and at least one plan landmark,
# while a chunk outside the slice must not.
# REQ-0034-006.

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var center_scene = CityChunkScene.new()
	root.add_child(center_scene)
	await process_frame
	center_scene.setup(_chunk_data(config, world_data, Vector2i(136, 136), Vector3.ZERO))
	var slice := center_scene.find_child("CityPlanSlice", true, false)
	if not T.require_true(self, slice != null, "center chunk must build the CityPlanSlice node"):
		return
	var water := center_scene.find_child("CityPlanWater", true, false)
	if not T.require_true(self, water != null, "slice must render the river surface"):
		return
	var landmarks := center_scene.find_child("CityPlanLandmarks", true, false)
	if not T.require_true(self, landmarks != null and landmarks.get_child_count() >= 1, "slice must place at least one plan landmark in the center chunk"):
		return
	for child in landmarks.get_children():
		if not T.require_true(self, str(child.get_meta("city_landmark_id", "")) != "", "every plan landmark needs a city_landmark_id"):
			return
		if not T.require_true(self, float(child.get_meta("city_landmark_height_m", 0.0)) >= 120.0, "landmarks must keep their plan height"):
			return

	var far_scene = CityChunkScene.new()
	root.add_child(far_scene)
	await process_frame
	far_scene.setup(_chunk_data(config, world_data, Vector2i(150, 136), Vector3(3584.0, 0.0, 0.0)))
	if not T.require_true(self, far_scene.find_child("CityPlanSlice", true, false) == null, "chunks outside the slice must keep the v62 path"):
		return
	T.pass_and_quit(self)

func _chunk_data(config, world_data: Dictionary, key: Vector2i, center: Vector3) -> Dictionary:
	return {
		"chunk_id": config.format_chunk_id(key),
		"chunk_key": key,
		"chunk_center": center,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	}
