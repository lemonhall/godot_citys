extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const MAX_FOLLOW_SLOT_ERROR_M := 1.25
const MIN_FORWARD_ALIGNMENT := 0.72
const MAX_LOOK_AT_PLAYER_DOT := 0.6

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Player robot dog follow contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_player_robot_dog_debug_state"), "Player robot dog follow contract requires CityPrototype.get_player_robot_dog_debug_state()"):
		return
	if not T.require_true(self, world.has_method("get_active_player_robot_dog"), "Player robot dog follow contract requires CityPrototype.get_active_player_robot_dog()"):
		return

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Player robot dog follow contract requires the main-world Player node"):
		return

	_press_world_key(world, KEY_KP_4)
	await _settle_frames(10)

	var runtime := world.get_active_player_robot_dog() as Node3D
	if not T.require_true(self, runtime != null, "Robot dog follow contract requires an active runtime after KP_4 summon"):
		return

	player.global_position += Vector3(6.0, 0.0, -4.0)
	player.rotation.y = deg_to_rad(60.0)
	await _settle_frames(96)

	var follow_state := world.get_player_robot_dog_debug_state() as Dictionary
	if not T.require_true(self, str(follow_state.get("behavior_mode", "")) == "follow", "Robot dog follow contract requires the runtime to stay in follow mode while accompanying the player"):
		return

	var follow_anchor := follow_state.get("follow_anchor_world_position", Vector3.ZERO) as Vector3
	var slot_error_m := Vector2(runtime.global_position.x - follow_anchor.x, runtime.global_position.z - follow_anchor.z).length()
	if not T.require_true(self, slot_error_m <= MAX_FOLLOW_SLOT_ERROR_M, "Follow-mode robot dog must converge near the formal right-side companion slot instead of drifting away from the player"):
		return

	var player_forward := _planar_forward(player.global_transform.basis)
	var runtime_forward := _planar_forward(runtime.global_transform.basis)
	if not T.require_true(self, player_forward.length_squared() > 0.0001 and runtime_forward.length_squared() > 0.0001, "Robot dog follow contract requires measurable player/runtime forward vectors"):
		return
	if not T.require_true(self, player_forward.dot(runtime_forward) >= MIN_FORWARD_ALIGNMENT, "Follow-mode robot dog must broadly face the same forward direction as the player instead of constantly turning to stare at the player"):
		return

	var to_player := player.global_position - runtime.global_position
	to_player.y = 0.0
	if not T.require_true(self, to_player.length_squared() > 0.0001, "Robot dog follow contract requires a measurable vector from the dog back to the player"):
		return
	to_player = to_player.normalized()
	if not T.require_true(self, absf(runtime_forward.dot(to_player)) <= MAX_LOOK_AT_PLAYER_DOT, "Follow-mode robot dog must not keep its nose locked onto the player like a hostile target tracker"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _press_world_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _settle_frames(frame_count: int) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame

func _planar_forward(basis: Basis) -> Vector3:
	var forward := -basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		return Vector3.ZERO
	return forward.normalized()
