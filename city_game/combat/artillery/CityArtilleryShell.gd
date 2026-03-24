extends Node3D

signal exploded(result: Dictionary)

@export var gravity_mps2 := 9.81
@export var ballistic_time_scale := 4.0
@export var max_lifetime_sec := 45.0
@export var explosion_radius_m := 24.0
@export var explosion_damage := 34.0
@export var explosion_effect_duration_sec := 0.92
@export var explosion_camera_shake_duration_sec := 0.7
@export var explosion_camera_shake_amplitude_m := 0.74
@export var tail_length_m := 4.8

var _velocity := Vector3.ZERO
var _owner_node: Node = null
var _player_target: Node = null
var _world_runtime: Node = null
var _firing_solution: Dictionary = {}
var _distance_travelled_m := 0.0
var _flight_time_sec := 0.0
var _lifetime_sec := 0.0
var _exploded := false
var _explosion_elapsed_sec := 0.0
var _last_explosion_result: Dictionary = {}

var _visual_root: Node3D = null
var _shell_body: MeshInstance3D = null
var _tail_mesh: MeshInstance3D = null
var _explosion_ring: MeshInstance3D = null
var _explosion_sphere: MeshInstance3D = null

func _ready() -> void:
	add_to_group("city_artillery_shell")
	_ensure_visuals()

func configure_from_firing_solution(firing_solution: Dictionary, owner_node: Node = null, player_target: Node = null, world_runtime: Node = null) -> void:
	_firing_solution = firing_solution.duplicate(true)
	_owner_node = owner_node
	_player_target = player_target
	_world_runtime = world_runtime
	global_position = _firing_solution.get("origin_world_position", Vector3.ZERO) as Vector3
	var direction := (_firing_solution.get("muzzle_direction_world", Vector3.FORWARD) as Vector3).normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	_velocity = direction * maxf(float(_firing_solution.get("muzzle_velocity_mps", 0.0)), 0.0)
	_distance_travelled_m = 0.0
	_flight_time_sec = 0.0
	_lifetime_sec = 0.0
	_exploded = false
	_explosion_elapsed_sec = 0.0
	_last_explosion_result.clear()
	_sync_flight_visual(_velocity, true)

func get_debug_state() -> Dictionary:
	return {
		"exploded": _exploded,
		"velocity": _velocity,
		"speed_mps": _velocity.length(),
		"distance_travelled_m": _distance_travelled_m,
		"flight_time_sec": _flight_time_sec,
		"simulation_time_scale": ballistic_time_scale,
		"firing_solution": _firing_solution.duplicate(true),
		"last_explosion_result": get_last_explosion_result(),
	}

func get_last_explosion_result() -> Dictionary:
	return _last_explosion_result.duplicate(true)

func _physics_process(delta: float) -> void:
	if _exploded:
		_update_explosion_fx(delta)
		return
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return

	_lifetime_sec += maxf(delta, 0.0)
	_flight_time_sec += maxf(delta, 0.0) * maxf(ballistic_time_scale, 0.001)
	if _lifetime_sec >= max_lifetime_sec:
		_explode("max_lifetime")
		return

	var simulated_delta := maxf(delta, 0.0) * maxf(ballistic_time_scale, 0.001)
	var speed_mps := maxf(_velocity.length(), 0.0)
	var substep_count := clampi(int(ceil((speed_mps * maxf(simulated_delta, 0.001)) / 120.0)), 1, 8)
	var substep_delta := simulated_delta / float(substep_count)
	for _substep_index in range(substep_count):
		if _step_ballistic_flight(substep_delta):
			return

func _step_ballistic_flight(simulated_delta: float) -> bool:
	var start_position := global_position
	var next_velocity := _velocity + Vector3.DOWN * gravity_mps2 * simulated_delta
	var end_position := start_position + (_velocity + next_velocity) * 0.5 * simulated_delta
	var query := PhysicsRayQueryParameters3D.create(start_position, end_position)
	query.collide_with_areas = false
	query.exclude = _build_query_exclusions()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.get("position", end_position)
		_distance_travelled_m += start_position.distance_to(global_position)
		_velocity = next_velocity
		_sync_flight_visual(global_position - start_position, true)
		_explode("impact")
		return true
	global_position = end_position
	_distance_travelled_m += start_position.distance_to(end_position)
	_velocity = next_velocity
	_sync_flight_visual(end_position - start_position, true)
	return false

func _build_query_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if _owner_node is CollisionObject3D:
		exclusions.append((_owner_node as CollisionObject3D).get_rid())
	if _player_target is CollisionObject3D:
		exclusions.append((_player_target as CollisionObject3D).get_rid())
	return exclusions

func _explode(trigger_kind: String) -> void:
	if _exploded:
		return
	_exploded = true
	var explosion_result := _apply_explosion_damage()
	_trigger_camera_shake()
	_ensure_visuals()
	if _visual_root != null:
		_visual_root.visible = false
	if _explosion_ring != null:
		_explosion_ring.visible = true
		_explosion_ring.scale = Vector3(0.42, 1.0, 0.42)
	if _explosion_sphere != null:
		_explosion_sphere.visible = true
		_explosion_sphere.scale = Vector3.ONE * 0.5
	_last_explosion_result = {
		"trigger_kind": trigger_kind,
		"world_position": global_position,
		"radius_m": explosion_radius_m,
		"distance_travelled_m": _distance_travelled_m,
		"flight_time_sec": _flight_time_sec,
		"firing_solution": _firing_solution.duplicate(true),
		"pedestrian_result": (explosion_result.get("pedestrian_result", {}) as Dictionary).duplicate(true),
		"vehicle_result": (explosion_result.get("vehicle_result", {}) as Dictionary).duplicate(true),
		"enemy_hit_count": int(explosion_result.get("enemy_hit_count", 0)),
		"building_hit_count": int(explosion_result.get("building_hit_count", 0)),
	}
	exploded.emit(get_last_explosion_result())

func _apply_explosion_damage() -> Dictionary:
	var enemy_hit_count := 0
	var building_hit_count := 0
	if get_tree() != null:
		for enemy_node in get_tree().get_nodes_in_group("city_enemy"):
			var enemy := enemy_node as Node3D
			if enemy == null or not is_instance_valid(enemy):
				continue
			if enemy.global_position.distance_to(global_position) > explosion_radius_m:
				continue
			if enemy.has_method("apply_projectile_hit"):
				var impulse_direction := enemy.global_position - global_position
				if impulse_direction.length_squared() <= 0.0001:
					impulse_direction = Vector3.UP
				enemy.apply_projectile_hit(explosion_damage, global_position, impulse_direction.normalized() * 26.0)
				enemy_hit_count += 1
		for building_node in get_tree().get_nodes_in_group("city_destructible_building"):
			if building_node == null or not is_instance_valid(building_node):
				continue
			if not building_node.has_method("apply_explosion_damage"):
				continue
			var building_result := building_node.apply_explosion_damage(global_position, explosion_damage, explosion_radius_m) as Dictionary
			if bool(building_result.get("accepted", false)):
				building_hit_count += 1
	var pedestrian_result: Dictionary = {}
	var vehicle_result: Dictionary = {}
	var resolved_world_runtime := _resolve_world_runtime()
	if resolved_world_runtime != null:
		if resolved_world_runtime.has_method("resolve_pedestrian_explosion"):
			pedestrian_result = resolved_world_runtime.resolve_pedestrian_explosion(global_position, maxf(explosion_radius_m * 0.45, 6.0), explosion_radius_m)
		if resolved_world_runtime.has_method("resolve_vehicle_explosion"):
			vehicle_result = resolved_world_runtime.resolve_vehicle_explosion(global_position, explosion_radius_m)
	return {
		"enemy_hit_count": enemy_hit_count,
		"building_hit_count": building_hit_count,
		"pedestrian_result": pedestrian_result.duplicate(true),
		"vehicle_result": vehicle_result.duplicate(true),
	}

func _trigger_camera_shake() -> void:
	if _player_target == null or not is_instance_valid(_player_target):
		return
	if not _player_target.has_method("trigger_camera_shake"):
		return
	var distance_to_player := 0.0
	if _player_target is Node3D:
		distance_to_player = (_player_target as Node3D).global_position.distance_to(global_position)
	var falloff := clampf(1.0 - distance_to_player / 86.0, 0.25, 1.0)
	_player_target.trigger_camera_shake(
		explosion_camera_shake_duration_sec,
		explosion_camera_shake_amplitude_m * falloff
	)

func _resolve_world_runtime() -> Node:
	if _world_runtime != null and is_instance_valid(_world_runtime):
		return _world_runtime
	var current: Node = get_parent()
	while current != null:
		if current.has_method("resolve_pedestrian_explosion") or current.has_method("resolve_vehicle_explosion"):
			return current
		current = current.get_parent()
	return null

func _update_explosion_fx(delta: float) -> void:
	_explosion_elapsed_sec += maxf(delta, 0.0)
	var duration_sec := maxf(explosion_effect_duration_sec, 0.001)
	var progress := clampf(_explosion_elapsed_sec / duration_sec, 0.0, 1.0)
	if _explosion_ring != null:
		var ring_scale := lerpf(0.42, explosion_radius_m * 0.68, progress)
		_explosion_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		var ring_material := _explosion_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color.a = lerpf(0.82, 0.0, progress)
			ring_material.emission_energy_multiplier = lerpf(2.4, 0.0, progress)
	if _explosion_sphere != null:
		var sphere_scale := lerpf(0.5, explosion_radius_m * 0.28, progress)
		_explosion_sphere.scale = Vector3.ONE * sphere_scale
		var sphere_material := _explosion_sphere.material_override as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = lerpf(0.48, 0.0, progress)
			sphere_material.emission_energy_multiplier = lerpf(2.8, 0.0, progress)
	if progress >= 1.0:
		queue_free()

func _sync_flight_visual(frame_delta: Vector3, active: bool) -> void:
	_ensure_visuals()
	if _visual_root == null or not is_instance_valid(_visual_root):
		return
	_visual_root.visible = active
	_visual_root.global_position = global_position
	var direction := frame_delta.normalized() if frame_delta.length_squared() > 0.0001 else _velocity.normalized()
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	var up_axis := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.96 else Vector3.FORWARD
	_visual_root.look_at(global_position + direction, up_axis, true)
	if _tail_mesh != null:
		_tail_mesh.position = Vector3(0.0, 0.0, tail_length_m * 0.5)

func _ensure_visuals() -> void:
	if _visual_root == null or not is_instance_valid(_visual_root):
		_visual_root = get_node_or_null("VisualRoot") as Node3D
	if _visual_root == null:
		_visual_root = Node3D.new()
		_visual_root.name = "VisualRoot"
		add_child(_visual_root)
	if _shell_body == null or not is_instance_valid(_shell_body):
		_shell_body = _visual_root.get_node_or_null("ShellBody") as MeshInstance3D
	if _shell_body == null:
		_shell_body = MeshInstance3D.new()
		_shell_body.name = "ShellBody"
		var body_mesh := SphereMesh.new()
		body_mesh.radius = 0.16
		body_mesh.height = 0.32
		_shell_body.mesh = body_mesh
		var body_material := StandardMaterial3D.new()
		body_material.albedo_color = Color(0.27451, 0.294118, 0.321569, 1.0)
		body_material.emission_enabled = true
		body_material.emission = Color(1.0, 0.721569, 0.282353, 1.0)
		body_material.emission_energy_multiplier = 0.42
		_shell_body.material_override = body_material
		_visual_root.add_child(_shell_body)
	if _tail_mesh == null or not is_instance_valid(_tail_mesh):
		_tail_mesh = _visual_root.get_node_or_null("TailMesh") as MeshInstance3D
	if _tail_mesh == null:
		_tail_mesh = MeshInstance3D.new()
		_tail_mesh.name = "TailMesh"
		var tail_mesh := BoxMesh.new()
		tail_mesh.size = Vector3(0.18, 0.18, tail_length_m)
		_tail_mesh.mesh = tail_mesh
		var tail_material := StandardMaterial3D.new()
		tail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tail_material.albedo_color = Color(0.972549, 0.792157, 0.407843, 0.32)
		tail_material.emission_enabled = true
		tail_material.emission = Color(1.0, 0.768627, 0.290196, 1.0)
		tail_material.emission_energy_multiplier = 1.4
		_tail_mesh.material_override = tail_material
		_visual_root.add_child(_tail_mesh)
	if _explosion_ring == null or not is_instance_valid(_explosion_ring):
		_explosion_ring = get_node_or_null("ExplosionRing") as MeshInstance3D
	if _explosion_ring == null:
		_explosion_ring = MeshInstance3D.new()
		_explosion_ring.name = "ExplosionRing"
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.0
		ring_mesh.bottom_radius = 1.0
		ring_mesh.height = 0.14
		ring_mesh.radial_segments = 28
		_explosion_ring.mesh = ring_mesh
		_explosion_ring.position = Vector3(0.0, 0.06, 0.0)
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(1.0, 0.690196, 0.254902, 0.82)
		ring_material.emission_enabled = true
		ring_material.emission = Color(1.0, 0.580392, 0.219608, 1.0)
		ring_material.emission_energy_multiplier = 2.4
		_explosion_ring.material_override = ring_material
		_explosion_ring.visible = false
		add_child(_explosion_ring)
	if _explosion_sphere == null or not is_instance_valid(_explosion_sphere):
		_explosion_sphere = get_node_or_null("ExplosionSphere") as MeshInstance3D
	if _explosion_sphere == null:
		_explosion_sphere = MeshInstance3D.new()
		_explosion_sphere.name = "ExplosionSphere"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = 1.0
		sphere_mesh.height = 2.0
		_explosion_sphere.mesh = sphere_mesh
		var sphere_material := StandardMaterial3D.new()
		sphere_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sphere_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere_material.albedo_color = Color(1.0, 0.501961, 0.188235, 0.48)
		sphere_material.emission_enabled = true
		sphere_material.emission = Color(1.0, 0.752941, 0.298039, 1.0)
		sphere_material.emission_energy_multiplier = 2.8
		_explosion_sphere.material_override = sphere_material
		_explosion_sphere.visible = false
		add_child(_explosion_sphere)
