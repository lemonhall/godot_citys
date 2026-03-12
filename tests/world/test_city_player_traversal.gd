extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for traversal contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null, "Traversal contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("request_wall_climb"), "PlayerController must expose request_wall_climb() for building traversal"):
		return
	if not T.require_true(self, player.has_method("request_ground_slam"), "PlayerController must expose request_ground_slam() for aerial slam attacks"):
		return
	if not T.require_true(self, player.has_method("get_traversal_state"), "PlayerController must expose get_traversal_state() for traversal verification"):
		return
	if not T.require_true(self, player.has_method("get_traversal_fx_state"), "PlayerController must expose get_traversal_fx_state() for slam feedback verification"):
		return

	var traversal_rig := _build_traversal_rig()
	world.add_child(traversal_rig)
	player.rotation = Vector3.ZERO
	player.teleport_to_world_position(Vector3(0.0, 1.0, 2.15))
	await physics_frame

	var start_height := player.global_position.y
	var climb_started: bool = player.request_wall_climb()
	if not T.require_true(self, climb_started, "Player must be able to enter wall-climb mode when facing a climbable building surface"):
		return

	for _frame in range(24):
		await physics_frame

	var climb_state: Dictionary = player.get_traversal_state()
	if not T.require_true(self, str(climb_state.get("mode", "")) == "wall_climb", "Player must report wall_climb mode while scaling a building facade"):
		return
	if not T.require_true(self, player.global_position.y >= start_height + 3.8, "Wall climb must now pull the player up the facade much faster than the initial prototype"):
		return

	var slam_start_height := player.global_position.y
	var slam_started: bool = player.request_ground_slam()
	if not T.require_true(self, slam_started, "Player must be able to trigger a ground slam from wall climb / air state"):
		return

	for _frame in range(6):
		await physics_frame

	var slam_state: Dictionary = player.get_traversal_state()
	if not T.require_true(self, str(slam_state.get("mode", "")) == "ground_slam", "Player must switch into ground_slam mode after triggering the aerial slam"):
		return
	if not T.require_true(self, float(slam_state.get("vertical_speed", 0.0)) <= -30.0, "Ground slam must now yank the player downward with a much harsher initial velocity"):
		return
	if not T.require_true(self, player.global_position.y <= slam_start_height - 2.8, "Ground slam must chew through altitude fast enough to feel like a real dive-bomb"):
		return

	for _frame in range(90):
		await physics_frame
		if player.is_on_floor():
			break

	var landed_state: Dictionary = player.get_traversal_state()
	var fx_state: Dictionary = player.get_traversal_fx_state()
	if not T.require_true(self, player.is_on_floor(), "Ground slam must resolve back onto the ground surface"):
		return
	if not T.require_true(self, str(landed_state.get("mode", "")) == "grounded", "After the slam landing, Player must return to grounded traversal mode"):
		return
	if not T.require_true(self, int(fx_state.get("slam_impact_count", 0)) >= 1, "Ground slam landing must emit an impact event for feedback systems"):
		return
	if not T.require_true(self, bool(fx_state.get("shockwave_visible", false)), "Ground slam landing must spawn a visible shockwave effect"):
		return
	if not T.require_true(self, float(fx_state.get("camera_shake_remaining_sec", 0.0)) > 0.0, "Ground slam landing must kick camera shake instead of ending with a dead stop"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _build_traversal_rig() -> Node3D:
	var root := Node3D.new()
	root.name = "TraversalRig"

	var wall := StaticBody3D.new()
	wall.name = "TraversalWall"
	wall.position = Vector3(0.0, 8.0, 0.0)
	var wall_collision_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(10.0, 16.0, 0.8)
	wall_collision_shape.shape = wall_box
	wall.add_child(wall_collision_shape)
	root.add_child(wall)

	var floor := StaticBody3D.new()
	floor.name = "TraversalFloor"
	floor.position = Vector3(0.0, -0.5, 0.0)
	var floor_collision_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(30.0, 1.0, 30.0)
	floor_collision_shape.shape = floor_box
	floor.add_child(floor_collision_shape)
	root.add_child(floor)

	return root
