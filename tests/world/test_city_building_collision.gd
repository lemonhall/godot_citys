extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var chunk_scene_script := load("res://city_game/world/rendering/CityChunkScene.gd")
	if chunk_scene_script == null:
		T.fail_and_quit(self, "Missing CityChunkScene.gd")
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var chunk_scene = chunk_scene_script.new()
	root.add_child(chunk_scene)
	await process_frame

	var chunk_key := Vector2i(136, 136)
	chunk_scene.setup({
		"chunk_id": config.format_chunk_id(chunk_key),
		"chunk_key": chunk_key,
		"chunk_center": Vector3.ZERO,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", chunk_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	})

	if not T.require_true(self, chunk_scene.has_method("get_building_collision_shape_count"), "Chunk scene must expose get_building_collision_shape_count()"):
		return
	if not T.require_true(self, chunk_scene.has_method("are_building_collisions_enabled"), "Chunk scene must expose are_building_collisions_enabled()"):
		return

	chunk_scene.set_lod_mode("near")
	if not T.require_true(self, int(chunk_scene.get_building_collision_shape_count()) > 0, "Near LOD must build collision shapes for buildings"):
		return
	if not T.require_true(self, chunk_scene.are_building_collisions_enabled(), "Near LOD must keep building collisions enabled"):
		return

	chunk_scene.set_lod_mode("mid")
	if not T.require_true(self, not chunk_scene.are_building_collisions_enabled(), "Mid LOD must disable invisible building collisions"):
		return

	chunk_scene.set_lod_mode("far")
	if not T.require_true(self, not chunk_scene.are_building_collisions_enabled(), "Far LOD must disable invisible building collisions"):
		return

	chunk_scene.set_lod_mode("near")
	if not T.require_true(self, chunk_scene.are_building_collisions_enabled(), "Returning to near LOD must re-enable building collisions"):
		return

	chunk_scene.queue_free()
	T.pass_and_quit(self)
