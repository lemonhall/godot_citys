extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fast inspection mode")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_control_mode"), "CityPrototype must expose set_control_mode()"):
		return
	if not T.require_true(self, world.has_method("get_control_mode"), "CityPrototype must expose get_control_mode()"):
		return

	var player = world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player for fast inspection mode"):
		return
	if not T.require_true(self, player.has_method("get_speed_profile"), "PlayerController must expose get_speed_profile()"):
		return
	if not T.require_true(self, player.has_method("get_walk_speed_mps"), "PlayerController must expose get_walk_speed_mps()"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "PlayerController must support teleport_to_world_position()"):
		return
	if not T.require_true(self, world.get_node_or_null("InspectionCar") == null, "CityPrototype must not include InspectionCar once fast inspection mode replaces it"):
		return

	world.set_control_mode("inspection")
	if not T.require_true(self, world.get_control_mode() == "inspection", "CityPrototype must switch into inspection control mode"):
		return
	if not T.require_true(self, player.get_speed_profile() == "inspection", "PlayerController must switch into inspection speed profile"):
		return
	if not T.require_true(self, float(player.get_walk_speed_mps()) >= 80.0, "Inspection speed profile must provide fast traversal speed"):
		return

	var target_position := Vector3(2048.0, 2.0, 26.0)
	player.teleport_to_world_position(target_position)
	world.update_streaming_for_position(target_position)
	await process_frame

	var report: Dictionary = world.build_runtime_report(player.global_position)
	if not T.require_true(self, str(report.get("control_mode", "")) == "inspection", "Runtime report must expose inspection control mode"):
		return

	var snapshot: Dictionary = world.get_streaming_snapshot()
	if not T.require_true(self, str(snapshot.get("current_chunk_id", "")) != "", "Inspection mode must still report current_chunk_id"):
		return
	if not T.require_true(self, int(snapshot.get("active_chunk_count", 0)) <= 25, "Inspection mode must preserve chunk streaming guardrails"):
		return

	world.queue_free()
	T.pass_and_quit(self)
