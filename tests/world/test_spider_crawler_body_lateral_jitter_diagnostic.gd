extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SPIDER_SCENE_PATH := "res://city_game/world/creatures/arthropods/CitySpiderCrawler.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SPIDER_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider body jitter diagnostic requires CitySpiderCrawler.tscn"):
		return

	var spider := scene.instantiate() as Node3D
	root.add_child(spider)
	await process_frame
	await process_frame

	spider.set_debug_motion_velocity(Vector3(0.0, 0.0, 3.0))

	var previous_body_x := 0.0
	var previous_centroid_x := 0.0
	var saw_previous := false
	var max_adjacent_body_dx := 0.0
	var max_adjacent_centroid_dx := 0.0
	var sample_lines: Array[String] = []

	for tick in range(24):
		spider.tick_crawler(0.06)
		var state: Dictionary = spider.get_debug_state()
		var body_visual_world_position: Vector3 = state.get("body_visual_world_position", Vector3.ZERO)
		var body_target_transform: Dictionary = state.get("body_target_transform", {})
		var leg_centroid_world_position: Vector3 = body_target_transform.get("leg_centroid_world_position", Vector3.ZERO)
		var plane_normal: Vector3 = body_target_transform.get("plane_normal", Vector3.ZERO)
		var support_center: Vector3 = body_target_transform.get("support_center", Vector3.ZERO)
		var centroid_tangent_offset: Vector3 = body_target_transform.get("centroid_tangent_offset", Vector3.ZERO)
		if saw_previous:
			max_adjacent_body_dx = maxf(max_adjacent_body_dx, absf(body_visual_world_position.x - previous_body_x))
			max_adjacent_centroid_dx = maxf(max_adjacent_centroid_dx, absf(leg_centroid_world_position.x - previous_centroid_x))
		previous_body_x = body_visual_world_position.x
		previous_centroid_x = leg_centroid_world_position.x
		saw_previous = true
		sample_lines.append(
			"tick=%02d body_x=%.4f centroid_x=%.4f support_x=%.4f tangent_x=%.4f normal=(%.3f,%.3f,%.3f)" % [
				tick,
				body_visual_world_position.x,
				leg_centroid_world_position.x,
				support_center.x,
				centroid_tangent_offset.x,
				plane_normal.x,
				plane_normal.y,
				plane_normal.z,
			]
		)

	print("--- spider body jitter diagnostic ---")
	for line in sample_lines:
		print(line)
	print("max_adjacent_body_dx=%.6f" % max_adjacent_body_dx)
	print("max_adjacent_centroid_dx=%.6f" % max_adjacent_centroid_dx)

	spider.queue_free()
	await process_frame
	T.pass_and_quit(self)
