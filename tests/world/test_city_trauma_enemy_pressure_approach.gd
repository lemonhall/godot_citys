extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for trauma pressure approach contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Trauma pressure approach contract requires Player node"):
		return
	if not T.require_true(self, world.has_method("spawn_trauma_enemy_at_world_position"), "CityPrototype must expose spawn_trauma_enemy_at_world_position() for pressure approach tests"):
		return

	var enemy = world.spawn_trauma_enemy_at_world_position(player.global_position + Vector3(0.0, 0.0, -34.0))
	if not T.require_true(self, enemy != null, "Pressure approach test must spawn a trauma enemy"):
		return
	if not T.require_true(self, enemy.has_method("get_pressure_state"), "Trauma enemy must expose get_pressure_state() for pressure-dash verification"):
		return
	if not T.require_true(self, enemy.has_method("get_camouflage_state"), "Trauma enemy must expose get_camouflage_state() for pressure-dash verification"):
		return

	var initial_distance: float = enemy.global_position.distance_to(player.global_position)
	var camouflage_seen := false
	var depleted_seen := false
	var max_dash_count := 0
	var dash_frames: Array[int] = []
	var dash_distances: Array[float] = []
	var previous_dash_count := 0

	for frame_index in range(240):
		await physics_frame
		if not is_instance_valid(enemy):
			break
		var pressure_state: Dictionary = enemy.get_pressure_state()
		var dash_count := int(pressure_state.get("dash_count", 0))
		max_dash_count = maxi(max_dash_count, dash_count)
		if dash_count > previous_dash_count:
			dash_frames.append(frame_index)
			dash_distances.append(enemy.global_position.distance_to(player.global_position))
			previous_dash_count = dash_count
		if not bool(pressure_state.get("can_dash", true)):
			depleted_seen = true
		var camouflage_state: Dictionary = enemy.get_camouflage_state()
		if bool(camouflage_state.get("active", false)):
			camouflage_seen = true

	if not T.require_true(self, is_instance_valid(enemy), "Pressure approach test requires the trauma enemy to stay alive"):
		return

	var pressure_state: Dictionary = enemy.get_pressure_state()
	var sign_history: Array = pressure_state.get("sign_history", [])
	var final_distance: float = enemy.global_position.distance_to(player.global_position)
	if not T.require_true(self, max_dash_count >= 6, "Trauma enemy must chain roughly six pressure dashes before fully running out of burst energy"):
		return
	if not T.require_true(self, sign_history.has(-1) and sign_history.has(1), "Pressure approach must zigzag across both lateral directions instead of blinking in a straight line"):
		return
	if not T.require_true(self, camouflage_seen, "Pressure dashes must visibly couple to the optical camouflage effect"):
		return
	if not T.require_true(self, depleted_seen, "Pressure dashes must hit an energy-limited lull instead of chaining forever"):
		return
	if not T.require_true(self, final_distance <= initial_distance - 10.0, "Pressure approach must aggressively collapse distance instead of hovering at the original stand-off range"):
		return
	if not T.require_true(self, float(pressure_state.get("energy_ratio", 1.0)) >= 0.0, "Pressure energy ratio must stay bounded after repeated dashes"):
		return
	if not T.require_true(self, dash_frames.size() >= 6, "Pressure approach test must observe at least six discrete dash beats"):
		return
	for dash_index in range(1, mini(dash_frames.size(), 6)):
		var frame_gap := dash_frames[dash_index] - dash_frames[dash_index - 1]
		if not T.require_true(self, frame_gap >= 22 and frame_gap <= 40, "Pressure dashes must land roughly every 0.5 seconds so the left-right beat stays readable"):
			return
	if not T.require_true(self, dash_distances.size() >= 3, "Pressure approach must capture at least three dash distances for close-in verification"):
		return
	if not T.require_true(self, dash_distances[2] <= initial_distance - 8.0, "The first three dashes must already create strong forward pressure instead of mostly lateral showmanship"):
		return

	var near_enemy = world.spawn_trauma_enemy_at_world_position(player.global_position + Vector3(0.0, 0.0, -18.0))
	if not T.require_true(self, near_enemy != null, "Pressure approach test must also spawn a near-range trauma enemy"):
		return
	var near_dash_seen := false
	for _frame in range(96):
		await physics_frame
		if not is_instance_valid(near_enemy):
			break
		var near_pressure_state: Dictionary = near_enemy.get_pressure_state()
		if int(near_pressure_state.get("dash_count", 0)) > 0:
			near_dash_seen = true
			break
	if not T.require_true(self, near_dash_seen, "Trauma enemy must still pressure-dash from near range while it has energy instead of reserving the behavior for mid/far distance only"):
		return

	world.queue_free()
	T.pass_and_quit(self)
