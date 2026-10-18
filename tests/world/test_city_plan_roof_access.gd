extends SceneTree

# v63 M4: landmark roof access is reachable from its ground pad.
# REQ-0034-006.

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")
const RoofAccess := preload("res://city_game/world/generation/plan/CityPlanRoofAccess.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_scene = CityChunkScene.new()
	root.add_child(chunk_scene)
	await process_frame
	chunk_scene.setup({
		"chunk_id": config.format_chunk_id(Vector2i(136, 136)),
		"chunk_key": Vector2i(136, 136),
		"chunk_center": Vector3.ZERO,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", Vector2i(136, 136)),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	})
	var access_node := chunk_scene.find_child("RoofAccess", true, false)
	if not T.require_true(self, access_node != null, "the slice landmark must expose a RoofAccess pad"):
		return
	var access := access_node as Node3D
	var height := float(access.get_meta("city_landmark_height_m", 0.0))
	if not T.require_true(self, height >= 120.0, "roof access must carry the landmark height"):
		return
	var player := Node3D.new()
	root.add_child(player)
	player.global_position = access.global_position
	if not T.require_true(self, RoofAccess.try_travel(player, access), "standing on the pad must travel to the roof"):
		return
	var climbed: float = player.global_position.y - access.global_position.y
	if not T.require_true(self, climbed >= height * 0.9, "player must reach at least 90%% of the landmark height (got %.1f of %.1f)" % [climbed, height]):
		return
	var far_player := Node3D.new()
	root.add_child(far_player)
	far_player.global_position = access.global_position + Vector3(50.0, 0.0, 0.0)
	if not T.require_true(self, not RoofAccess.try_travel(far_player, access), "roof access must only fire from the pad"):
		return
	T.pass_and_quit(self)
