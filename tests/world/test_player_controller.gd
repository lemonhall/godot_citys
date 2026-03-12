extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for player controller contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "CityPrototype must keep Player node"):
		return
	if not T.require_true(self, player.has_method("get_pitch_limits_degrees"), "PlayerController must expose get_pitch_limits_degrees()"):
		return
	if not T.require_true(self, player.has_method("get_floor_snap_config"), "PlayerController must expose get_floor_snap_config()"):
		return
	if not T.require_true(self, player.has_method("get_mobility_tuning"), "PlayerController must expose get_mobility_tuning() for traversal tuning verification"):
		return

	var limits: Dictionary = player.get_pitch_limits_degrees()
	if not T.require_true(self, float(limits.get("min", 0.0)) <= -60.0, "Player look-down limit must stay natural"):
		return
	if not T.require_true(self, float(limits.get("max", 0.0)) >= 30.0, "Player must be able to look upward by at least 30 degrees"):
		return

	var floor_snap: Dictionary = player.get_floor_snap_config()
	if not T.require_true(self, float(floor_snap.get("player", 0.0)) >= 0.6, "Normal player mode must keep a non-zero floor snap length"):
		return
	if not T.require_true(self, float(floor_snap.get("inspection", 0.0)) >= float(floor_snap.get("player", 0.0)), "Inspection mode must keep at least as much floor snap support as normal mode"):
		return

	var mobility: Dictionary = player.get_mobility_tuning()
	if not T.require_true(self, float(mobility.get("sprint_speed", 0.0)) >= 17.0, "Shift sprint must stay fast enough for aggressive traversal previews"):
		return
	if not T.require_true(self, float(mobility.get("jump_velocity", 0.0)) >= 6.5, "Space jump must have a noticeably higher launch than the base prototype hop"):
		return
	if not T.require_true(self, float(mobility.get("wall_climb_speed", 0.0)) >= 14.0, "Wall climb speed must feel decisively faster than the first traversal prototype"):
		return
	if not T.require_true(self, float(mobility.get("ground_slam_initial_speed", 0.0)) >= 28.0, "Ground slam must start with a steep downward burst instead of a soft drop"):
		return
	if not T.require_true(self, float(mobility.get("ground_slam_max_speed", 0.0)) >= 70.0, "Ground slam must be allowed to reach a brutal terminal speed on the way down"):
		return

	world.queue_free()
	T.pass_and_quit(self)
