extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pin priority contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	var task_world_position: Vector3 = player.global_position + Vector3(40.0, 0.0, 22.0) if player != null else Vector3(40.0, 0.0, 22.0)
	world.register_task_pin("task:test", task_world_position, "Debug Task", "Priority Contract")
	var destination_world_position: Vector3 = player.global_position + Vector3(640.0, 0.0, 64.0) if player != null else Vector3(640.0, 0.0, 64.0)
	var selection_contract: Dictionary = world.select_map_destination_from_world_point(destination_world_position)
	if not T.require_true(self, not selection_contract.is_empty(), "Pin priority contract requires an active destination pin"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	var markers: Array = pin_overlay.get("markers", [])
	if not T.require_true(self, markers.size() >= 2, "Pin priority contract requires at least task and destination markers in the minimap overlay"):
		return
	var last_marker: Dictionary = markers[markers.size() - 1]
	if not T.require_true(self, str(last_marker.get("pin_type", "")) == "destination", "Higher-priority destination pins must render after task pins so they stay visually on top"):
		return

	world.queue_free()
	T.pass_and_quit(self)
