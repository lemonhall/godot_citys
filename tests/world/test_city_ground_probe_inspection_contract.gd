extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CONFIG_PATH := "res://city_game/world/model/CityWorldConfig.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for ground probe inspection contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Ground probe inspection contract requires Player node"):
		return
	if not T.require_true(self, world.has_method("inspect_laser_designator_segment"), "Ground probe inspection contract requires deterministic inspection entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_last_laser_designator_result"), "Ground probe inspection contract requires inspection result introspection"):
		return
	if not T.require_true(self, world.has_method("get_last_laser_designator_clipboard_text"), "Ground probe inspection contract requires clipboard introspection"):
		return
	if not T.require_true(self, world.has_method("_perform_laser_designator_trace"), "Ground probe inspection contract requires direct laser trace helper"):
		return

	var ground_sample: Dictionary = {}
	for _frame in range(24):
		ground_sample = _find_vertical_ground_sample(world, player.global_position)
		if not ground_sample.is_empty():
			break
		await process_frame
	if not T.require_true(self, not ground_sample.is_empty(), "Ground probe inspection contract requires a deterministic ground sample"):
		return

	var result_started: Dictionary = world.inspect_laser_designator_segment(
		ground_sample.get("origin", Vector3.ZERO),
		ground_sample.get("target", Vector3.ZERO)
	)
	await process_frame
	if not T.require_true(self, not result_started.is_empty(), "Ground probe inspection contract must produce a non-empty inspection result"):
		return

	var result: Dictionary = world.get_last_laser_designator_result()
	if not T.require_true(self, str(result.get("inspection_kind", "")) == "ground_probe", "Ground hits must resolve to formal ground_probe inspection kind"):
		return
	if not T.require_true(self, str(result.get("chunk_id", "")) != "", "Ground probe inspection must expose non-empty chunk_id"):
		return
	if not T.require_true(self, result.get("chunk_key", null) is Vector2i, "Ground probe inspection must expose chunk_key as Vector2i"):
		return
	if not T.require_true(self, result.get("world_position", null) is Vector3, "Ground probe inspection must expose world_position as Vector3"):
		return
	if not T.require_true(self, typeof(result.get("surface_y_m", null)) == TYPE_FLOAT, "Ground probe inspection must expose surface_y_m as float for authored placement"):
		return
	if not T.require_true(self, result.get("chunk_local_position", null) is Vector3, "Ground probe inspection must expose chunk_local_position as Vector3"):
		return
	if not T.require_true(self, result.get("surface_normal", null) is Vector3, "Ground probe inspection must expose surface_normal as Vector3"):
		return

	var config_script := load(CONFIG_PATH)
	if not T.require_true(self, config_script != null, "Ground probe inspection contract requires CityWorldConfig.gd to recompute chunk-local coordinates"):
		return
	var config = config_script.new()
	if not T.require_true(self, config != null, "Ground probe inspection contract must instantiate CityWorldConfig"):
		return

	var chunk_key := result.get("chunk_key", Vector2i.ZERO) as Vector2i
	var expected_chunk_center := _chunk_center_from_key(config, chunk_key)
	var world_position := result.get("world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, absf(float(result.get("surface_y_m", 0.0)) - world_position.y) <= 0.01, "Ground probe surface_y_m must round-trip the hit world_position.y"):
		return
	var expected_local_position := world_position - expected_chunk_center
	var chunk_local_position := result.get("chunk_local_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, chunk_local_position.distance_to(expected_local_position) <= 0.01, "Ground probe chunk_local_position must round-trip from world_position and chunk center"):
		return

	var clipboard_text := str(world.get_last_laser_designator_clipboard_text())
	if not T.require_true(self, clipboard_text.find(str(result.get("chunk_id", ""))) >= 0, "Ground probe clipboard text must include chunk_id"):
		return
	if not T.require_true(self, clipboard_text.find("y=") >= 0, "Ground probe clipboard text must include the explicit sampled y value"):
		return
	if not T.require_true(self, clipboard_text.find("world=") >= 0, "Ground probe clipboard text must include serialized world coordinates"):
		return
	if not T.require_true(self, clipboard_text.find("local=") >= 0, "Ground probe clipboard text must include serialized local chunk coordinates"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _find_vertical_ground_sample(world, center_world_position: Vector3) -> Dictionary:
	if world == null or not world.has_method("_perform_laser_designator_trace"):
		return {}
	var directions := [
		Vector2.ZERO,
		Vector2(0.0, -1.0),
		Vector2(1.0, 0.0),
		Vector2(-1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.707, -0.707),
		Vector2(-0.707, -0.707),
		Vector2(0.707, 0.707),
		Vector2(-0.707, 0.707),
	]
	for distance_m in [0.0, 28.0, 56.0, 84.0, 112.0, 140.0]:
		for direction_variant in directions:
			var direction: Vector2 = direction_variant
			var sample_origin := Vector3(
				center_world_position.x + direction.x * distance_m,
				center_world_position.y + 180.0,
				center_world_position.z + direction.y * distance_m
			)
			var sample_target := sample_origin + Vector3.DOWN * 320.0
			var hit: Dictionary = world._perform_laser_designator_trace(sample_origin, sample_target)
			if hit.is_empty():
				continue
			var collider := hit.get("collider") as Node
			if collider == null or not collider.has_meta("city_inspection_payload"):
				return {
					"origin": sample_origin,
					"target": sample_target,
				}
	return {}

func _chunk_center_from_key(config, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_size_m := float(config.chunk_size_m)
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * chunk_size_m,
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * chunk_size_m
	)
