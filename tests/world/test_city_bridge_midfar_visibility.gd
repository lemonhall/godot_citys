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
	var bridge_chunk_payload := _find_bridge_chunk_payload(config, world_data)
	if not T.require_true(self, not bridge_chunk_payload.is_empty(), "Mid/far bridge visibility validation requires at least one bridge chunk near the city center"):
		return

	var scene := CityChunkScene.new()
	root.add_child(scene)
	await process_frame
	scene.setup(bridge_chunk_payload)

	var near_group := scene.get_node_or_null("NearGroup") as Node3D
	if not T.require_true(self, near_group != null, "Chunk scene must keep NearGroup for bridge visibility validation"):
		return
	var bridge_proxy := scene.get_node_or_null("BridgeProxy") as Node3D
	if not T.require_true(self, bridge_proxy != null, "Bridge chunks must expose a dedicated BridgeProxy so bridge decks stay visible outside near LOD"):
		return
	if not T.require_true(self, bridge_proxy.get_child_count() > 0, "BridgeProxy must contain visible bridge geometry and not be an empty placeholder"):
		return
	if not T.require_true(self, not bridge_proxy.visible, "BridgeProxy should stay hidden in near LOD while the detailed bridge overlay is active"):
		return

	scene.set_lod_mode(CityChunkScene.LOD_MID)

	if not T.require_true(self, near_group.visible == false, "NearGroup must still hide in mid LOD so bridge visibility does not fall back to full nearfield rendering"):
		return
	if not T.require_true(self, bridge_proxy.visible, "BridgeProxy must stay visible in mid LOD so elevated roads do not collapse into grass"):
		return

	scene.set_lod_mode(CityChunkScene.LOD_FAR)
	if not T.require_true(self, bridge_proxy.visible, "BridgeProxy must stay visible in far LOD so elevated roads remain readable under distant traffic"):
		return

	scene.queue_free()
	T.pass_and_quit(self)

func _find_bridge_chunk_payload(config: CityWorldConfig, world_data: Dictionary) -> Dictionary:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var center_chunk := Vector2i(chunk_grid.x / 2, chunk_grid.y / 2)
	for offset_y in range(-4, 5):
		for offset_x in range(-4, 5):
			var chunk_key := center_chunk + Vector2i(offset_x, offset_y)
			if chunk_key.x < 0 or chunk_key.y < 0 or chunk_key.x >= chunk_grid.x or chunk_key.y >= chunk_grid.y:
				continue
			var payload := _make_chunk_payload(config, world_data, chunk_key)
			var scene := CityChunkScene.new()
			root.add_child(scene)
			scene.setup(payload)
			var stats: Dictionary = scene.get_renderer_stats()
			scene.queue_free()
			if int(stats.get("bridge_count", 0)) > 0:
				return payload
	return {}

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
