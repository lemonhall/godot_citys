extends SceneTree

const T := preload("res://tests/_test_util.gd")

const RADIO_TOWER_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v21_radio_tower_chunk_131_138/radio_tower_landmark.tscn"
const TEST_BASE_POSITION := Vector3(100000.0, 0.0, 100000.0)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var city_scene := load("res://city_game/scenes/CityPrototype.tscn")
	if city_scene == null or not (city_scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for radio tower climbable contract")
		return

	var tower_scene := load(RADIO_TOWER_SCENE_PATH)
	if not T.require_true(self, tower_scene != null and tower_scene is PackedScene, "Radio tower climbable contract requires the authored landmark scene"):
		return

	var world := (city_scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	if not T.require_true(self, player != null, "Radio tower climbable contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("request_wall_climb"), "Radio tower climbable contract requires request_wall_climb()"):
		return
	if not T.require_true(self, player.has_method("get_traversal_state"), "Radio tower climbable contract requires traversal state introspection"):
		return

	var floor := StaticBody3D.new()
	floor.name = "RadioTowerTestFloor"
	floor.position = TEST_BASE_POSITION + Vector3(0.0, -0.5, 0.0)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(1600.0, 1.0, 1600.0)
	floor_collision.shape = floor_shape
	floor.add_child(floor_collision)
	world.add_child(floor)

	var tower_root := (tower_scene as PackedScene).instantiate() as Node3D
	if not T.require_true(self, tower_root != null, "Radio tower climbable contract requires a Node3D root"):
		return
	tower_root.position = TEST_BASE_POSITION
	world.add_child(tower_root)
	await process_frame
	await physics_frame
	await physics_frame

	var probe_hit := _find_climb_probe_hit(world, tower_root)
	if not T.require_true(self, not probe_hit.is_empty(), "Radio tower precise collision must expose at least one climbable wall hit around the tower perimeter"):
		return

	var hit_position: Vector3 = probe_hit.get("position", TEST_BASE_POSITION + Vector3(0.0, 2.0, 0.0))
	var hit_normal: Vector3 = probe_hit.get("normal", Vector3.BACK)
	player.teleport_to_world_position(Vector3(
		hit_position.x + hit_normal.x * 1.2,
		TEST_BASE_POSITION.y + 1.0,
		hit_position.z + hit_normal.z * 1.2
	))
	player.look_at(Vector3(hit_position.x, TEST_BASE_POSITION.y + 1.0, hit_position.z), Vector3.UP)
	await physics_frame

	var start_height := player.global_position.y
	var climb_started: bool = player.request_wall_climb()
	if not T.require_true(self, climb_started, "Player must be able to enter wall_climb when facing the radio tower's precise collision surface"):
		return

	for _frame in range(18):
		await physics_frame

	var climb_state: Dictionary = player.get_traversal_state()
	if not T.require_true(self, str(climb_state.get("mode", "")) == "wall_climb", "Radio tower climbable contract must keep the player in wall_climb mode while ascending the tower"):
		return
	if not T.require_true(self, player.global_position.y >= start_height + 2.0, "Radio tower climbable contract must let the player gain noticeable height while climbing"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _find_climb_probe_hit(world: Node, tower_root: Node3D) -> Dictionary:
	if world.get_world_3d() == null or world.get_world_3d().direct_space_state == null:
		return {}
	var extents := _collect_visual_extents(tower_root)
	var half_radius := maxf(float(extents.get("footprint_x_m", 0.0)), float(extents.get("footprint_z_m", 0.0))) * 0.5
	if half_radius <= 0.0:
		half_radius = 32.0
	var ray_y := TEST_BASE_POSITION.y + 2.0
	var space_state: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	for radius_offset_variant in [1.4, 2.0, 3.0]:
		var radius_offset: float = float(radius_offset_variant)
		var radius: float = half_radius + radius_offset
		for index in range(48):
			var angle := TAU * float(index) / 48.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			var origin: Vector3 = TEST_BASE_POSITION + direction * radius
			origin.y = ray_y
			var target: Vector3 = TEST_BASE_POSITION - direction * radius
			target.y = ray_y
			var query := PhysicsRayQueryParameters3D.create(origin, target)
			query.collide_with_areas = false
			var hit: Dictionary = space_state.intersect_ray(query)
			if hit.is_empty():
				continue
			var hit_normal: Vector3 = hit.get("normal", Vector3.UP)
			if absf(hit_normal.y) > 0.3:
				continue
			return hit
	return {}

func _collect_visual_extents(root_node: Node3D) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_z := INF
	var max_z := -INF
	var visual_count := 0
	for child in root_node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var world_corner := visual.global_transform * corner
			min_x = minf(min_x, world_corner.x)
			max_x = maxf(max_x, world_corner.x)
			min_z = minf(min_z, world_corner.z)
			max_z = maxf(max_z, world_corner.z)
		visual_count += 1
	if visual_count <= 0:
		return {
			"footprint_x_m": 0.0,
			"footprint_z_m": 0.0,
		}
	return {
		"footprint_x_m": max_x - min_x,
		"footprint_z_m": max_z - min_z,
	}

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]
