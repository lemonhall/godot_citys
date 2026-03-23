extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player drone streaming anchor contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_streaming_snapshot"), "Player drone streaming anchor contract requires CityPrototype.get_streaming_snapshot()"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "Player drone streaming anchor contract requires CityPrototype.build_minimap_snapshot()"):
		return
	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone streaming anchor contract requires CityPrototype.get_player_drone_debug_state()"):
		return

	var runtime := world.get_node_or_null("PlayerDroneRuntime") as CharacterBody3D
	if not T.require_true(self, runtime != null, "Player drone streaming anchor contract requires the mounted PlayerDroneRuntime node"):
		return
	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Player drone streaming anchor contract requires the grounded Player node for anchor comparison"):
		return

	_press_world_key(world, KEY_KP_5)
	var active_state := await _wait_for_state(world, "active", 180)
	if not T.require_true(self, str(active_state.get("system_state", "")) == "active", "Player drone streaming anchor contract requires the drone to reach active mode before streaming can follow it"):
		return

	var initial_snapshot: Dictionary = world.get_streaming_snapshot()
	var initial_chunk_id := str(initial_snapshot.get("current_chunk_id", ""))
	if not T.require_true(self, initial_chunk_id != "", "Player drone streaming anchor contract requires a valid initial current_chunk_id"):
		return

	runtime.global_position += Vector3(768.0, 0.0, 0.0)
	runtime.velocity = Vector3.ZERO
	await _advance_frames(12)

	var moved_snapshot: Dictionary = world.get_streaming_snapshot()
	var moved_chunk_id := str(moved_snapshot.get("current_chunk_id", ""))
	if not T.require_true(self, moved_chunk_id != initial_chunk_id, "Active drone movement across chunk boundaries must retarget streaming to the drone instead of staying stuck on the grounded player chunk"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var center_world: Dictionary = minimap_snapshot.get("center_world", {})
	var center_x := float(center_world.get("x", 0.0))
	var center_z := float(center_world.get("z", 0.0))
	if not T.require_true(self, absf(center_x - runtime.global_position.x) <= 256.0, "Drone-mode minimap center must stay inside the drone's quantized refresh cell instead of lagging an entire player-centered region behind"):
		return
	if not T.require_true(self, absf(center_z - runtime.global_position.z) <= 256.0, "Drone-mode minimap center must stay inside the drone's quantized refresh cell on z instead of lagging behind the active aircraft"):
		return
	if not T.require_true(self, absf(center_x - runtime.global_position.x) < absf(center_x - player.global_position.x), "Drone-mode minimap center must resolve closer to the drone than the frozen player body"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_state(world: Node, expected_state: String, max_frames: int) -> Dictionary:
	for _frame_index in range(max_frames):
		await physics_frame
		await process_frame
		var debug_state: Dictionary = world.get_player_drone_debug_state()
		if str(debug_state.get("system_state", "")) == expected_state:
			return debug_state
	return world.get_player_drone_debug_state()

func _advance_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _press_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)
