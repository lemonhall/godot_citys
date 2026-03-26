extends SceneTree

const T := preload("res://tests/_test_util.gd")

const MIN_FORMATION_SEPARATION_M := 2.4
const MAX_TOTAL_DRONES := 10

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone squadron summon contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone squadron summon contract requires leader debug-state introspection"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_squadron_debug_state"), "Player drone squadron summon contract requires squadron debug-state introspection"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_leader_state := await _wait_for_leader_state(world, "active", 180)
	if not T.require_true(self, str(active_leader_state.get("camera_owner", "")) == "drone", "Player drone squadron summon contract requires the first drone to stay the formal leader camera owner"):
		return
	var squadron_state := world.get_player_drone_squadron_debug_state() as Dictionary
	if not T.require_true(self, int(squadron_state.get("desired_total_count", -1)) == 1, "The first KP_5 deploy must leave desired_total_count at 1"):
		return
	if not T.require_true(self, int(squadron_state.get("active_total_count", -1)) == 1, "Once leader deploy completes, the active squadron count must be exactly 1"):
		return

	_tap_world_key(world, KEY_KP_5)
	await _settle_frames(18)
	_tap_world_key(world, KEY_KP_5)
	await _settle_frames(30)
	squadron_state = world.get_player_drone_squadron_debug_state() as Dictionary
	if not T.require_true(self, int(squadron_state.get("desired_total_count", -1)) == 3, "Two additional short KP_5 taps must grow the squadron to three total drones"):
		return
	if not T.require_true(self, int(squadron_state.get("wingman_count", -1)) == 2, "A three-drone squadron must expose two wingmen instead of silently collapsing back to the leader only"):
		return

	var leader_state := world.get_player_drone_debug_state() as Dictionary
	if not T.require_true(self, str(leader_state.get("camera_owner", "")) == "drone" and str(leader_state.get("input_owner", "")) == "drone", "Wingman summons must not steal camera/input ownership away from the leader"):
		return

	var member_positions := _extract_member_positions(squadron_state)
	if not T.require_true(self, member_positions.size() >= 3, "Squadron summon contract requires at least three visible member positions once the third drone is summoned"):
		return
	if not T.require_true(self, _compute_min_pairwise_distance(member_positions) >= MIN_FORMATION_SEPARATION_M, "Summoned squadron members must not overlap in world space; minimum separation dropped below %0.2fm" % MIN_FORMATION_SEPARATION_M):
		return

	for _spawn_index in range(14):
		_tap_world_key(world, KEY_KP_5)
		await _settle_frames(2)
	await _settle_frames(30)
	squadron_state = world.get_player_drone_squadron_debug_state() as Dictionary
	if not T.require_true(self, int(squadron_state.get("desired_total_count", -1)) == MAX_TOTAL_DRONES, "Repeated short KP_5 taps must clamp the squadron at the frozen max_total_count=%d" % MAX_TOTAL_DRONES):
		return
	if not T.require_true(self, int(squadron_state.get("max_total_count", -1)) == MAX_TOTAL_DRONES, "Squadron debug state must expose the frozen max_total_count contract"):
		return

	await _hold_world_key(world, KEY_KP_5, 40)
	var stowed_leader_state := await _wait_for_leader_state(world, "stowed", 240)
	squadron_state = world.get_player_drone_squadron_debug_state() as Dictionary
	if not T.require_true(self, str(stowed_leader_state.get("camera_owner", "")) == "player", "Long-hold squadron recall must restore camera ownership to the player once the leader finishes recovering"):
		return
	if not T.require_true(self, int(squadron_state.get("desired_total_count", -1)) == 0 and int(squadron_state.get("active_total_count", -1)) == 0, "Long-hold squadron recall must leave both desired_total_count and active_total_count at zero"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_leader_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var debug_state := world.get_player_drone_debug_state() as Dictionary
		if str(debug_state.get("system_state", "")) == expected_state:
			return debug_state
	return world.get_player_drone_debug_state() as Dictionary

func _extract_member_positions(squadron_state: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var member_positions_variant: Variant = squadron_state.get("member_world_positions", [])
	if not (member_positions_variant is Array):
		return result
	for position_variant: Variant in member_positions_variant:
		if position_variant is Vector3:
			result.append(position_variant as Vector3)
	return result

func _compute_min_pairwise_distance(points: Array[Vector3]) -> float:
	if points.size() <= 1:
		return 999999.0
	var min_distance := INF
	for point_index in range(points.size()):
		for other_index in range(point_index + 1, points.size()):
			min_distance = minf(min_distance, points[point_index].distance_to(points[other_index]))
	return min_distance

func _press_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _release_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = false
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _tap_world_key(world: Node, keycode: Key) -> void:
	_press_world_key(world, keycode)
	_release_world_key(world, keycode)

func _hold_world_key(world: Node, keycode: Key, frame_count: int) -> void:
	_press_world_key(world, keycode)
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
	_release_world_key(world, keycode)

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
