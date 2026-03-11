extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for inspection vehicle")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_control_mode"), "CityPrototype must expose set_control_mode()"):
		return
	if not T.require_true(self, world.has_method("get_control_mode"), "CityPrototype must expose get_control_mode()"):
		return

	var inspection_car = world.get_node_or_null("InspectionCar")
	if not T.require_true(self, inspection_car != null, "CityPrototype must include InspectionCar"):
		return
	if not T.require_true(self, inspection_car.has_method("teleport_to_world_position"), "InspectionCar must support teleport_to_world_position()"):
		return

	world.set_control_mode("car")
	if not T.require_true(self, world.get_control_mode() == "car", "CityPrototype must switch into car control mode"):
		return

	var target_position := Vector3(2048.0, 3.0, 26.0)
	inspection_car.teleport_to_world_position(target_position)
	world.update_streaming_for_position(target_position)
	await process_frame

	var snapshot: Dictionary = world.get_streaming_snapshot()
	if not T.require_true(self, str(snapshot.get("current_chunk_id", "")) != "", "Inspection car mode must still report current_chunk_id"):
		return
	if not T.require_true(self, int(snapshot.get("active_chunk_count", 0)) <= 25, "Inspection car mode must preserve chunk streaming guardrails"):
		return

	world.queue_free()
	T.pass_and_quit(self)
