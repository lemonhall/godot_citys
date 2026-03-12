extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LETHAL_RADIUS_M := 4.0
const THREAT_RADIUS_M := 12.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian combat flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_pedestrian_runtime_snapshot"), "CityPrototype must expose get_pedestrian_runtime_snapshot() for pedestrian combat flow"):
		return
	if not T.require_true(self, world.has_method("fire_player_projectile_toward"), "CityPrototype must expose fire_player_projectile_toward() for pedestrian combat flow"):
		return
	if not T.require_true(self, world.has_method("resolve_pedestrian_explosion"), "CityPrototype must expose resolve_pedestrian_explosion() for grenade casualty/flee flow"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Pedestrian combat flow requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must expose teleport_to_world_position() for pedestrian combat flow"):
		return

	var initial_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var projectile_target := _pick_candidate_state(initial_snapshot)
	if not T.require_true(self, not projectile_target.is_empty(), "Pedestrian combat flow requires a live projectile target pedestrian"):
		return

	var target_id := str(projectile_target.get("pedestrian_id", ""))
	var target_position: Vector3 = projectile_target.get("world_position", Vector3.ZERO)
	player.teleport_to_world_position(target_position + Vector3(-8.0, 1.1, -8.0))
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame

	var projectile = world.fire_player_projectile_toward(target_position)
	if not T.require_true(self, projectile != null, "Pedestrian combat flow must spawn a real projectile for the direct-hit phase"):
		return

	var projectile_killed := false
	for _frame_index in range(30):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame
		if not _snapshot_contains_pedestrian(world.get_pedestrian_runtime_snapshot(), target_id):
			projectile_killed = true
			break
	if not T.require_true(self, projectile_killed, "Projectile combat flow must remove the direct-hit victim from the live crowd snapshot"):
		return

	var post_projectile_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var cluster := _pick_explosion_cluster(post_projectile_snapshot)
	if not T.require_true(self, not cluster.is_empty(), "Pedestrian combat flow requires a follow-up explosion cluster with flee survivors and an unaffected bystander"):
		return

	var center_position: Vector3 = cluster.get("center_position", Vector3.ZERO)
	player.teleport_to_world_position(center_position + Vector3(2.0, 1.1, 2.0))
	world.update_streaming_for_position(player.global_position, 0.1)
	await process_frame

	var explosion_result: Dictionary = world.resolve_pedestrian_explosion(center_position, LETHAL_RADIUS_M, THREAT_RADIUS_M)
	for _frame_index in range(6):
		await physics_frame
		world.update_streaming_for_position(player.global_position, 1.0 / 60.0)
		await process_frame

	var final_snapshot: Dictionary = world.get_pedestrian_runtime_snapshot()
	var threat_state := _find_state(final_snapshot, str(cluster.get("threat_id", "")))
	var far_state := _find_state(final_snapshot, str(cluster.get("far_id", "")))
	print("CITY_PEDESTRIAN_COMBAT_FLOW %s" % JSON.stringify({
		"explosion_result": explosion_result,
		"cluster": cluster,
		"final_snapshot": final_snapshot,
	}))

	if not T.require_true(self, int(explosion_result.get("killed_count", 0)) >= 1, "Explosion combat flow must kill at least one pedestrian inside the lethal radius"):
		return
	if not T.require_true(self, ["panic", "flee"].has(str(threat_state.get("reaction_state", ""))), "Explosion combat flow must push nearby survivors into panic-or-flee state"):
		return
	if not T.require_true(self, not ["panic", "flee"].has(str(far_state.get("reaction_state", ""))), "Explosion combat flow must keep threat-radius outsiders out of the panic response"):
		return
	if not T.require_true(self, int(final_snapshot.get("tier3_count", 0)) <= 24, "Pedestrian combat flow must keep Tier 3 agents within the hard cap of 24"):
		return
	if not T.require_true(self, int(final_snapshot.get("duplicate_page_load_count", 0)) == 0, "Pedestrian combat flow must not introduce duplicate page loads or travel-time count leaks"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _pick_candidate_state(snapshot: Dictionary) -> Dictionary:
	for tier_key in ["tier2_states", "tier1_states"]:
		var states: Array = snapshot.get(tier_key, [])
		if not states.is_empty():
			return states[0]
	return {}

func _pick_explosion_cluster(snapshot: Dictionary) -> Dictionary:
	var states := _collect_states(snapshot)
	for center_variant in states:
		var center: Dictionary = center_variant
		var center_position: Vector3 = center.get("world_position", Vector3.ZERO)
		var threat_candidate := {}
		var far_candidate := {}
		for other_variant in states:
			var other: Dictionary = other_variant
			if str(other.get("pedestrian_id", "")) == str(center.get("pedestrian_id", "")):
				continue
			var distance_m := center_position.distance_to(other.get("world_position", Vector3.ZERO))
			if threat_candidate.is_empty() and distance_m > LETHAL_RADIUS_M + 0.75 and distance_m <= THREAT_RADIUS_M - 0.75:
				threat_candidate = other
			elif far_candidate.is_empty() and distance_m >= THREAT_RADIUS_M + 3.0:
				far_candidate = other
		if threat_candidate.is_empty() or far_candidate.is_empty():
			continue
		return {
			"center_position": center_position,
			"threat_id": str(threat_candidate.get("pedestrian_id", "")),
			"far_id": str(far_candidate.get("pedestrian_id", "")),
		}
	return {}

func _collect_states(snapshot: Dictionary) -> Array:
	var states: Array = []
	for tier_key in ["tier2_states", "tier1_states", "tier3_states"]:
		for state_variant in snapshot.get(tier_key, []):
			states.append(state_variant)
	return states

func _snapshot_contains_pedestrian(snapshot: Dictionary, pedestrian_id: String) -> bool:
	return not _find_state(snapshot, pedestrian_id).is_empty()

func _find_state(snapshot: Dictionary, pedestrian_id: String) -> Dictionary:
	for tier_key in ["tier1_states", "tier2_states", "tier3_states"]:
		var states: Array = snapshot.get(tier_key, [])
		for state_variant in states:
			var state: Dictionary = state_variant
			if str(state.get("pedestrian_id", "")) == pedestrian_id:
				return state
	return {}
