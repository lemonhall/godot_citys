extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for large world E2E")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("plan_macro_route"), "CityPrototype must expose plan_macro_route()"):
		return
	if not T.require_true(self, world.has_method("get_chunk_streamer"), "CityPrototype must expose get_chunk_streamer()"):
		return
	if not T.require_true(self, world.has_method("build_runtime_report"), "CityPrototype must expose build_runtime_report()"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for large world E2E"):
		return
	if not T.require_true(self, player.has_method("advance_toward_world_position"), "PlayerController must expose advance_toward_world_position()"):
		return

	var start := Vector3(-1400.0, 1.1, 26.0)
	var goal := Vector3(1400.0, 1.1, 26.0)
	player.teleport_to_world_position(start)
	world.update_streaming_for_position(start)
	world.get_chunk_streamer().clear_transition_log()

	var route: Array = world.plan_macro_route(start, goal)
	var total_distance := 0.0
	var seen_chunk_ids: Dictionary = {}

	for waypoint in route:
		var target_position: Vector3 = waypoint["target_position"]
		var guard := 0
		while player.global_position.distance_to(target_position) > 1.0 and guard < 200:
			var before: Vector3 = player.global_position
			player.advance_toward_world_position(target_position, 64.0)
			world.update_streaming_for_position(player.global_position)
			await process_frame
			total_distance += before.distance_to(player.global_position)

			var snapshot: Dictionary = world.get_streaming_snapshot()
			if not T.require_true(self, snapshot.get("active_chunk_count", 0) <= 25, "Large world E2E must keep active_chunk_count <= 25"):
				return
			var current_chunk_id := str(snapshot.get("current_chunk_id", ""))
			if not T.require_true(self, current_chunk_id != "", "Large world E2E must emit current_chunk_id"):
				return
			seen_chunk_ids[current_chunk_id] = true
			guard += 1

		if not T.require_true(self, guard < 200, "Large world E2E must reach each waypoint without stalling"):
			return

	if not T.require_true(self, total_distance >= 2048.0, "Large world E2E must travel at least 2048 meters"):
		return
	if not T.require_true(self, seen_chunk_ids.size() >= 8, "Large world E2E must cross at least 8 unique chunks"):
		return
	if not T.require_true(self, player.global_position.distance_to(goal) <= 96.0, "Large world E2E must finish near the target goal"):
		return

	var transition_log: Array = world.get_chunk_streamer().get_transition_log()
	if not T.require_true(self, transition_log.size() > 0, "Large world E2E must record chunk transition evidence"):
		return

	var report: Dictionary = world.build_runtime_report(player.global_position)
	if not T.require_true(self, report.has("final_position"), "Large world E2E report must include final_position"):
		return
	if not T.require_true(self, int(report.get("transition_count", 0)) > 0, "Large world E2E report must include transition_count"):
		return
	print("CITY_E2E_REPORT %s" % JSON.stringify(report))

	world.queue_free()
	T.pass_and_quit(self)
