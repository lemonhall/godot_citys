extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian travel flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for crowd travel validation"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for pedestrian reactive E2E"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node for pedestrian travel flow"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for pedestrian travel flow"):
		return

	var seen_chunk_ids: Dictionary = {}
	var peak_tier3_count := 0
	for step in range(9):
		var travel_position := Vector3(-1200.0 + float(step) * 300.0, 1.1, 26.0)
		player.teleport_to_world_position(travel_position)
		world.update_streaming_for_position(travel_position)
		await process_frame

		var streaming_snapshot: Dictionary = world.get_streaming_snapshot()
		var pedestrian_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var current_chunk_id := str(streaming_snapshot.get("current_chunk_id", ""))
		if not T.require_true(self, current_chunk_id != "", "Pedestrian travel flow must report current_chunk_id"):
			return
		seen_chunk_ids[current_chunk_id] = true
		peak_tier3_count = maxi(peak_tier3_count, int(pedestrian_snapshot.get("tier3_count", 0)))

		if not T.require_true(self, int(pedestrian_snapshot.get("tier3_count", 0)) <= 24, "Pedestrian travel flow must keep Tier 3 agents within the hard cap of 24"):
			return
		if not T.require_true(self, int(pedestrian_snapshot.get("duplicate_page_load_count", 0)) == 0, "Pedestrian travel flow must not duplicate page loads across 8-chunk travel"):
			return

		if step == 4:
			var candidate := _pick_candidate_state(pedestrian_snapshot)
			if not T.require_true(self, not candidate.is_empty(), "Pedestrian travel flow requires a visible candidate for reactive projectile validation"):
				return
			var reactive_position: Vector3 = candidate.get("world_position", Vector3.ZERO) + Vector3(2.0, 0.0, 2.0)
			player.teleport_to_world_position(reactive_position)
			world.update_streaming_for_position(reactive_position)
			await process_frame
			var projectile = world.fire_player_projectile_toward(candidate.get("world_position", Vector3.ZERO))
			if not T.require_true(self, projectile != null, "Reactive projectile validation must spawn a projectile during travel flow"):
				return
			for _frame_index in range(3):
				world.update_streaming_for_position(player.global_position)
				await process_frame
			pedestrian_snapshot = world.get_pedestrian_runtime_snapshot()
			peak_tier3_count = maxi(peak_tier3_count, int(pedestrian_snapshot.get("tier3_count", 0)))

	if not T.require_true(self, seen_chunk_ids.size() >= 8, "Pedestrian travel flow must cross at least 8 unique chunks"):
		return
	if not T.require_true(self, peak_tier3_count > 0, "Travel flow must trigger at least one Tier 3 pedestrian reaction during the mixed travel + combat scenario"):
		return

	var final_pedestrian_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	print("CITY_PEDESTRIAN_TRAVEL_FLOW %s" % JSON.stringify(final_pedestrian_snapshot))

	world.queue_free()
	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
	return {}
