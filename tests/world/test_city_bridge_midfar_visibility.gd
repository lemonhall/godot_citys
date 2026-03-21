extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)

	var scene := CityChunkScene.new()
	root.add_child(scene)
	await process_frame
	scene.setup(_make_chunk_payload(config, world_data, Vector2i(136, 136)))

	var near_group := scene.get_node_or_null("NearGroup") as Node3D
	if not T.require_true(self, near_group != null, "Chunk scene must keep NearGroup for bridge visibility validation"):
		return
	var bridge_proxy := scene.get_node_or_null("BridgeProxy") as Node3D
	if not T.require_true(self, bridge_proxy == null, "Flat-ground pivot must remove the dedicated BridgeProxy node entirely"):
		return

	scene.set_lod_mode(CityChunkScene.LOD_MID)
	if not T.require_true(self, near_group.visible == false, "NearGroup must still hide in mid LOD so bridge visibility does not fall back to full nearfield rendering"):
		return

	scene.set_lod_mode(CityChunkScene.LOD_FAR)

	scene.queue_free()
	T.pass_and_quit(self)

func _make_chunk_payload(config: CityWorldConfig, world_data: Dictionary, chunk_key: Vector2i) -> Dictionary:
	var bounds: Rect2 = config.get_world_bounds()
	return {
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": Vector3(
			bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
			0.0,
			bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
		),
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	}
