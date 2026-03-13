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

const DEATH_RETENTION_ASSERT_SEC := 0.75
const REMOUNT_JUMP := Vector3(4096.0, 0.0, 4096.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian death visual persistence")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_chunk_renderer"), "CityPrototype must expose get_chunk_renderer() for death visual persistence validation"):
		return
	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for death visual persistence validation"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for death visual persistence validation"):
		return

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Death visual persistence test requires PlayerController teleport support"):
		return

	var live_target := await _find_tier2_target(world, player)
	if not T.require_true(self, not live_target.is_empty(), "Death visual persistence test needs a mounted Tier2 target"):
		return

	var chunk_renderer = world.get_chunk_renderer()
	var chunk_id := str(live_target.get("chunk_id", ""))
	var pedestrian_id := str(live_target.get("pedestrian_id", ""))
	var target_position: Vector3 = live_target.get("target_position", Vector3.ZERO)
	var aim_position: Vector3 = live_target.get("aim_position", Vector3.ZERO)
	player.teleport_to_world_position(target_position + Vector3(-4.0, 1.1, -4.0))
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame

	var fired_any := false
	for _burst_index in range(4):
		var live_target_state := _find_state(world.get_pedestrian_runtime_snapshot(), pedestrian_id)
		if live_target_state.is_empty():
			break
		var projectile = world.fire_player_projectile_toward(_resolve_projectile_aim_position(live_target_state))
		if projectile == null:
			await process_frame
			continue
		fired_any = true
		for _frame_index in range(10):
			await physics_frame
			world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
			await process_frame
		if _find_state(world.get_pedestrian_runtime_snapshot(), pedestrian_id).is_empty():
			break
	if not T.require_true(self, fired_any, "Death visual persistence test must fire a live projectile burst at the mounted target"):
		return
	var pre_retire_chunk_scene = chunk_renderer.get_chunk_scene(chunk_id)

	var far_position := target_position + REMOUNT_JUMP
	player.teleport_to_world_position(Vector3(far_position.x, 1.1, far_position.z))
	var elapsed_sec := 0.0
	var global_death_visual: Node = null
	while elapsed_sec < DEATH_RETENTION_ASSERT_SEC:
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await physics_frame
		await process_frame
		elapsed_sec += 1.0 / 60.0
		global_death_visual = _find_global_death_visual(chunk_renderer)
		if global_death_visual != null:
			break

	if not T.require_true(self, chunk_renderer.get_chunk_scene(chunk_id) == null, "Death visual persistence test must retire the original chunk to verify remount-safe visuals"):
		return
	if not T.require_true(self, global_death_visual != null, "Retiring the source chunk must not make the casualty visual disappear before %.2fs" % DEATH_RETENTION_ASSERT_SEC):
		return
	if not T.require_true(self, global_death_visual.has_method("get_current_animation_name"), "Global death visual must expose get_current_animation_name() after chunk retirement"):
		return
	if not T.require_true(self, _has_any_token(str(global_death_visual.call("get_current_animation_name")), ["death", "dead"]), "Global death visual must keep routing the casualty into a death/dead clip after chunk retirement"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _find_tier2_target(world, player) -> Dictionary:
	var chunk_renderer = world.get_chunk_renderer()
	for search_position_variant in SEARCH_POSITIONS:
		var search_position: Vector3 = search_position_variant
		player.teleport_to_world_position(search_position)
		world.update_streaming_for_position(search_position, 0.25)
		for _guard_index in range(12):
			await process_frame
			world.update_streaming_for_position(search_position, 0.1)
			var snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
			var states := _collect_states(snapshot)
			for state_variant in snapshot.get("tier2_states", []):
				var state: Dictionary = state_variant
				var shooter_position: Vector3 = state.get("world_position", Vector3.ZERO) + Vector3(-4.0, 0.0, -4.0)
				if not _has_clear_shot(state, states, shooter_position):
					continue
				var chunk_scene = chunk_renderer.get_chunk_scene(str(state.get("chunk_id", ""))) if chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene") else null
				if chunk_scene == null:
					continue
				var visual_node := _find_visual_node(chunk_scene, str(state.get("pedestrian_id", "")))
				if visual_node == null:
					continue
				return {
					"pedestrian_id": str(state.get("pedestrian_id", "")),
					"chunk_id": str(state.get("chunk_id", "")),
					"target_position": state.get("world_position", Vector3.ZERO),
					"aim_position": _resolve_projectile_aim_position(state),
				}
	return {}

func _find_visual_node(chunk_scene: Node, pedestrian_id: String) -> Node:
	var crowd_root := chunk_scene.get_node_or_null("PedestrianCrowd") as Node
	if crowd_root == null:
		return null
	var tier2_root := crowd_root.get_node_or_null("Tier2Agents") as Node
	if tier2_root == null:
		return null
	var expected_name := pedestrian_id.replace(":", "_")
	return tier2_root.get_node_or_null(expected_name)

func _find_global_death_visual(chunk_renderer) -> Node:
	if chunk_renderer == null:
		return null
	var global_root := chunk_renderer.get_node_or_null("PedestrianDeathVisualsGlobal") as Node
	if global_root == null or global_root.get_child_count() == 0:
		return null
	return global_root.get_child(0) as Node

func _chunk_death_visual_count(chunk_scene: Node) -> int:
	if chunk_scene == null:
		return 0
	var crowd_root := chunk_scene.get_node_or_null("PedestrianCrowd") as Node
	if crowd_root == null:
		return 0
	var death_root := crowd_root.get_node_or_null("DeathVisuals") as Node
	return 0 if death_root == null else death_root.get_child_count()

func _global_death_visual_count(chunk_renderer) -> int:
	if chunk_renderer == null:
		return 0
	var global_root := chunk_renderer.get_node_or_null("PedestrianDeathVisualsGlobal") as Node
	return 0 if global_root == null else global_root.get_child_count()

func _resolve_projectile_aim_position(state: Dictionary) -> Vector3:
	var world_position: Vector3 = state.get("world_position", Vector3.ZERO)
	var height_m := float(state.get("height_m", 1.75))
	return world_position + Vector3.UP * maxf(height_m * 0.5, 0.9)

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier3_states", "tier2_states", "tier1_states"]:
		for state_variant in snapshot.get(tier_key, []):
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _has_clear_shot(center: Dictionary, states: Array, shooter_position: Vector3) -> bool:
	var target_id := str(center.get("pedestrian_id", ""))
	var target_position: Vector3 = center.get("world_position", Vector3.ZERO)
	var shooter_2d := Vector2(shooter_position.x, shooter_position.z)
	var target_2d := Vector2(target_position.x, target_position.z)
	var segment := target_2d - shooter_2d
	var segment_length_squared := segment.length_squared()
	if segment_length_squared <= 0.001:
		return false
	for other_variant in states:
		var other: Dictionary = other_variant
		if str(other.get("pedestrian_id", "")) == target_id:
			continue
		var other_position: Vector3 = other.get("world_position", Vector3.ZERO)
		var point_2d := Vector2(other_position.x, other_position.z)
		var t := clampf((point_2d - shooter_2d).dot(segment) / segment_length_squared, 0.0, 1.0)
		if t >= 0.98:
			continue
		var closest_point := shooter_2d + segment * t
		if point_2d.distance_to(closest_point) <= 0.6:
			return false
	return true

func _has_any_token(animation_name: String, tokens: Array[String]) -> bool:
	var normalized_animation := animation_name.to_lower()
	for token in tokens:
		if normalized_animation.find(token) >= 0:
			return true
	return false
