extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SEARCH_POSITIONS := [
	Vector3(-1280.0, 1.1, -1024.0),
	Vector3(-2048.0, 1.1, 0.0),
	Vector3(-1200.0, 1.1, 26.0),
	Vector3(-600.0, 1.1, 26.0),
	Vector3(300.0, 1.1, 26.0),
	Vector3(768.0, 1.1, 26.0),
	Vector3(1536.0, 1.1, 26.0),
	Vector3(2048.0, 1.1, 768.0),
	Vector3.ZERO,
]

const VIOLENT_REACTIONS := ["panic", "flee"]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for live burst-fire stability")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Live burst-fire stability needs CityPrototype.get_chunk_renderer()"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "Live burst-fire stability needs CityPrototype.get_pedestrian_runtime_snapshot()"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Live burst-fire stability requires Player teleport support"):
		return

	var candidate := await _find_calm_candidate(world, player)
	if not T.require_true(self, not candidate.is_empty(), "Live burst-fire stability needs a calm pedestrian candidate inside streamed chunks"):
		return

	var pedestrian_id := str(candidate.get("pedestrian_id", ""))
	var live_position: Vector3 = candidate.get("world_position", Vector3.ZERO)
	player.teleport_to_world_position(live_position + Vector3(24.0, 0.0, 24.0))
	world.update_streaming_for_position(player.global_position, 0.25)
	await process_frame

	var chunk_renderer = world.get_chunk_renderer()
	chunk_renderer.notify_projectile_event(live_position + Vector3(-18.0, 0.0, -6.0), Vector3.RIGHT, 36.0)
	await _tick_world(world, player, 0.12)
	var baseline_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var baseline_state := _find_state(baseline_snapshot, pedestrian_id)
	if not T.require_true(self, not baseline_state.is_empty(), "Burst-fire stability candidate must remain loaded after the first audible shot"):
		return
	if not T.require_true(self, str(baseline_state.get("reaction_state", "")) == "panic", "The first off-path gunshot must push the live witness into panic"):
		return

	var reaction_history: Array[String] = [str(baseline_state.get("reaction_state", ""))]
	live_position = baseline_state.get("world_position", live_position)
	for path_z in [-1.0, -0.8, -1.2, -0.9]:
		chunk_renderer.notify_projectile_event(live_position + Vector3(-18.0, 0.0, path_z), Vector3.RIGHT, 36.0)
		await _tick_world(world, player, 0.12)
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		var live_state := _find_state(snapshot, pedestrian_id)
		if not T.require_true(self, not live_state.is_empty(), "Burst-fire stability candidate must stay loaded while validating reaction history"):
			return
		reaction_history.append(str(live_state.get("reaction_state", "none")))
		live_position = live_state.get("world_position", live_position)

	print("CITY_PEDESTRIAN_LIVE_BURST_FIRE_STABILITY %s" % JSON.stringify({
		"pedestrian_id": pedestrian_id,
		"reaction_history": reaction_history,
	}))

	for reaction_state in reaction_history:
		if not T.require_true(self, VIOLENT_REACTIONS.has(reaction_state), "Live burst fire must not knock a panic/flee witness back into walk/sidestep mid-burst"):
			return

	world.queue_free()
	T.pass_and_quit(self)

func _tick_world(world, player, delta: float) -> void:
	world.update_streaming_for_position(player.global_position, delta)
	await physics_frame
	await process_frame

func _find_calm_candidate(world, player) -> Dictionary:
	for search_position in SEARCH_POSITIONS:
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		await process_frame
		var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
		for tier_key in ["tier2_states", "tier1_states"]:
			for state_variant in snapshot.get(tier_key, []):
				var state: Dictionary = state_variant
				if str(state.get("life_state", "alive")) != "alive":
					continue
				if str(state.get("reaction_state", "none")) != "none":
					continue
				return state
	return {}

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier3_states", "tier2_states", "tier1_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}
