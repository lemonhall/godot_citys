extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for autodrive shortcut contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("enter_vehicle_drive_mode"), "Autodrive shortcut contract requires synthetic drive-mode setup support"):
		return
	if not T.require_true(self, world.has_method("get_autodrive_state"), "Autodrive shortcut contract requires autodrive state introspection"):
		return
	if not T.require_true(self, world.has_method("is_autodrive_active"), "Autodrive shortcut contract requires active-state introspection"):
		return

	var start_travel: Dictionary = world.fast_travel_to_target(Vector3(128.0, 0.0, 14.0))
	if not T.require_true(self, bool(start_travel.get("success", false)), "Autodrive shortcut contract requires a stable drive-mode start surface"):
		return

	player.enter_vehicle_drive_mode(_build_synthetic_vehicle_state(player))
	world.update_streaming_for_position(player.global_position, 0.0)
	var selection_contract: Dictionary = world.select_map_destination_from_world_point(Vector3(512.0, 0.0, 40.0))
	if not T.require_true(self, not selection_contract.is_empty(), "Autodrive shortcut contract requires an active destination before the shortcut is pressed"):
		return

	_press_key(world, KEY_G)
	await process_frame

	var armed_state: Dictionary = world.get_autodrive_state()
	if not T.require_true(self, world.is_autodrive_active(), "Pressing G while driving with an active destination must arm autodrive"):
		return
	if not T.require_true(self, str(armed_state.get("state", "")) == "following_route", "Autodrive shortcut must enter following_route instead of staying inactive"):
		return

	_press_key(world, KEY_G)
	await process_frame

	var stopped_state: Dictionary = world.get_autodrive_state()
	if not T.require_true(self, not world.is_autodrive_active(), "Pressing G again while autodrive is active must stop autodrive"):
		return
	if not T.require_true(self, str(stopped_state.get("state", "")) == "interrupted", "Stopping autodrive from the shortcut must surface the interrupted state"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _press_key(world: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.echo = false
	event.keycode = keycode
	event.physical_keycode = keycode
	world._unhandled_input(event)

func _build_synthetic_vehicle_state(player) -> Dictionary:
	var standing_height := _estimate_standing_height(player)
	return {
		"vehicle_id": "veh:test:autodrive_shortcut",
		"model_id": "car_b",
		"heading": Vector3(1.0, 0.0, 0.0),
		"world_position": player.global_position - Vector3.UP * standing_height,
		"length_m": 4.4,
		"width_m": 1.9,
		"height_m": 1.6,
		"speed_mps": 0.0,
	}

func _estimate_standing_height(player) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0
