extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for artillery fire-mission contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("request_artillery_fire_mission_from_world_point"), "Artillery fire-mission contract requires CityPrototype.request_artillery_fire_mission_from_world_point()"):
		return
	if not T.require_true(self, world.has_method("get_artillery_fire_mission_state"), "Artillery fire-mission contract requires CityPrototype.get_artillery_fire_mission_state()"):
		return

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Artillery fire-mission contract requires the main-world Player node"):
		return

	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var target_world_position := player.global_position + forward * 3200.0

	var mission_contract := world.request_artillery_fire_mission_from_world_point(target_world_position) as Dictionary
	if not T.require_true(self, not mission_contract.is_empty(), "Requesting a map artillery fire mission must return a formal mission contract instead of silently mutating hidden state"):
		return
	for required_key in ["mission_id", "target_world_position", "battery_snapshot", "solution_state", "resolved_battery_snapshot"]:
		if not T.require_true(self, mission_contract.has(required_key), "Artillery fire-mission contract must expose %s" % required_key):
			return

	var mission_state := world.get_artillery_fire_mission_state() as Dictionary
	if not T.require_true(self, bool(mission_state.get("active", false)), "CityPrototype must keep a formal active artillery fire-mission state after mission planning"):
		return

	var solution_state: Dictionary = mission_state.get("solution_state", {})
	if not T.require_true(self, not bool(solution_state.get("solved", false)), "Map artillery fire missions must stay pending after target marking instead of exposing a solved bearing/pitch solution before a live howitzer is being operated"):
		return
	if not T.require_true(self, str(solution_state.get("reason", "")) == "requires_live_howitzer_operation", "Pending artillery fire missions must explain that the player needs to enter live howitzer operation before firing data can be solved"):
		return
	if not T.require_true(self, (mission_state.get("resolved_battery_snapshot", {}) as Dictionary).is_empty(), "Before the live howitzer is operated, artillery fire missions must not pretend that a solved live battery snapshot already exists"):
		return

	world.set_full_map_open(true)
	await process_frame
	var map_state: Dictionary = world.get_map_screen_state()
	var pin_markers: Array = map_state.get("pin_markers", [])
	var saw_fire_mission_pin := false
	for pin_variant in pin_markers:
		var pin: Dictionary = pin_variant
		if str(pin.get("pin_type", "")) != "artillery_fire_mission":
			continue
		saw_fire_mission_pin = true
		if not T.require_true(self, str(pin.get("pin_id", "")) == str(mission_state.get("mission_id", "")), "Full map artillery marker must preserve the formal mission_id as its pin_id"):
			return
	if not T.require_true(self, saw_fire_mission_pin, "Full map pin stack must contain the single active artillery fire-mission marker"):
		return
	world.set_full_map_open(false)
	await process_frame

	var battery_snapshot: Dictionary = mission_state.get("battery_snapshot", {})
	var planned_spawn_root_world_position := battery_snapshot.get("spawn_root_world_position", Vector3.ZERO) as Vector3
	if not T.require_true(self, planned_spawn_root_world_position != Vector3.ZERO, "Artillery fire-mission planning must freeze a formal planned battery snapshot even before the howitzer is summoned"):
		return

	player.global_position += Vector3(48.0, 0.0, 22.0)
	player.rotation.y += deg_to_rad(90.0)
	await _settle_frames()

	var spawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, spawned, "The main-world howitzer summon shortcut must stay usable after an artillery fire mission is planned"):
		return
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null, "Artillery fire-mission contract requires the summoned howitzer instance after pressing KP_8"):
		return
	if not T.require_true(self, howitzer.global_position.distance_to(planned_spawn_root_world_position) <= 0.75, "With an active artillery fire mission, KP_8 summon must reuse the planned battery snapshot instead of jumping to the player's new position"):
		return
	mission_state = world.get_artillery_fire_mission_state() as Dictionary
	solution_state = mission_state.get("solution_state", {})
	if not T.require_true(self, not bool(solution_state.get("solved", false)), "Summoning the howitzer alone must not expose artillery firing data before the player actually enters操炮状态"):
		return

	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.global_position = anchor_world + Vector3(0.0, 0.0, 4.2)
	await _settle_frames()

	_press_key(world, KEY_E)
	await _settle_frames()

	mission_state = world.get_artillery_fire_mission_state() as Dictionary
	solution_state = mission_state.get("solution_state", {})
	if not T.require_true(self, bool(solution_state.get("solved", false)), "Entering live howitzer operation with an active artillery marker must solve the formal bearing/pitch firing data from the real spawned gun"):
		return
	if not T.require_true(self, float(solution_state.get("horizontal_distance_m", 0.0)) >= 1500.0, "Solved artillery fire-mission data must expose the formal gameplay horizontal distance to the target"):
		return
	if not T.require_true(self, float(solution_state.get("pitch_deg", -1.0)) >= 0.0, "Solved artillery fire-mission data must preserve the howitzer pitch contract instead of returning a private negative angle"):
		return
	var resolved_battery_snapshot: Dictionary = mission_state.get("resolved_battery_snapshot", {})
	if not T.require_true(self, not resolved_battery_snapshot.is_empty(), "Once the player enters操炮状态, the fire mission must retain the live battery snapshot used for solving the displayed firing data"):
		return
	var resolved_spawn_root_world_position := resolved_battery_snapshot.get("spawn_root_world_position", Vector3.INF) as Vector3
	if not T.require_true(self, resolved_spawn_root_world_position.distance_to(howitzer.global_position) <= 0.75, "The solved artillery firing data must come from the real spawned howitzer instead of a stale player-side planning origin"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()
	mission_state = world.get_artillery_fire_mission_state() as Dictionary
	solution_state = mission_state.get("solution_state", {})
	if not T.require_true(self, not bool(solution_state.get("solved", false)), "After exiting操炮状态, the full-map artillery marker must hide solved firing data again instead of leaking stale live-gun parameters"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _build_key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.pressed = pressed
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event

func _press_key(target: Node, keycode: Key) -> void:
	target._unhandled_input(_build_key_event(keycode, true))
