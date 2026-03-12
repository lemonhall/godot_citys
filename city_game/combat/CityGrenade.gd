extends Node3D

signal exploded(world_position: Vector3, radius_m: float)

@export var max_lifetime_sec := 2.4
@export var gravity_mps2 := 24.0
@export var explosion_radius_m := 8.0
@export var explosion_damage := 5.0
@export var explosion_effect_duration_sec := 0.42
@export var explosion_camera_shake_duration_sec := 0.32
@export var explosion_camera_shake_amplitude_m := 0.22

var _velocity := Vector3.ZERO
var _owner_node: Node = null
var _player_target: Node = null
var _lifetime_sec := 0.0
var _exploded := false
var _explosion_elapsed_sec := 0.0
var _grenade_mesh: MeshInstance3D = null
var _explosion_ring: MeshInstance3D = null
var _explosion_sphere: MeshInstance3D = null

func _ready() -> void:
	add_to_group("city_grenade")
	_ensure_visuals()

func configure(origin: Vector3, initial_velocity: Vector3, owner_node: Node = null, player_target: Node = null) -> void:
	position = origin
	_velocity = initial_velocity
	_owner_node = owner_node
	_player_target = player_target

func get_velocity() -> Vector3:
	return _velocity

func has_exploded() -> bool:
	return _exploded

func _physics_process(delta: float) -> void:
	if _exploded:
		_update_explosion_fx(delta)
		return
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return

	_lifetime_sec += delta
	if _lifetime_sec >= max_lifetime_sec:
		_explode()
		return

	var start_position := global_position
	_velocity.y -= gravity_mps2 * delta
	var end_position := start_position + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(start_position, end_position)
	query.collide_with_areas = false
	query.exclude = _build_query_exclusions()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit.get("position", end_position)
		_explode()
		return

	global_position = end_position

func _build_query_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if _owner_node is CollisionObject3D:
		exclusions.append((_owner_node as CollisionObject3D).get_rid())
	return exclusions

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	_velocity = Vector3.ZERO
	_apply_explosion_damage()
	_trigger_camera_shake()
	_ensure_visuals()
	if _grenade_mesh != null:
		_grenade_mesh.visible = false
	if _explosion_ring != null:
		_explosion_ring.visible = true
		_explosion_ring.scale = Vector3(0.3, 1.0, 0.3)
	if _explosion_sphere != null:
		_explosion_sphere.visible = true
		_explosion_sphere.scale = Vector3.ONE * 0.35
	exploded.emit(global_position, explosion_radius_m)

func _apply_explosion_damage() -> void:
	if get_tree() == null:
		return
	for enemy_node in get_tree().get_nodes_in_group("city_enemy"):
		var enemy := enemy_node as Node3D
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > explosion_radius_m:
			continue
		if enemy.has_method("apply_projectile_hit"):
			var impulse := (enemy.global_position - global_position).normalized() * 18.0
			enemy.apply_projectile_hit(explosion_damage, global_position, impulse)

func _trigger_camera_shake() -> void:
	if _player_target == null or not is_instance_valid(_player_target):
		return
	if not _player_target.has_method("trigger_camera_shake"):
		return
	var distance_to_player := 0.0
	if _player_target is Node3D:
		distance_to_player = (_player_target as Node3D).global_position.distance_to(global_position)
	var falloff := clampf(1.0 - distance_to_player / 24.0, 0.25, 1.0)
	_player_target.trigger_camera_shake(
		explosion_camera_shake_duration_sec,
		explosion_camera_shake_amplitude_m * falloff
	)

func _update_explosion_fx(delta: float) -> void:
	_explosion_elapsed_sec += delta
	var duration_sec := maxf(explosion_effect_duration_sec, 0.001)
	var progress := clampf(_explosion_elapsed_sec / duration_sec, 0.0, 1.0)
	if _explosion_ring != null:
		var ring_scale := lerpf(0.3, explosion_radius_m * 0.55, progress)
		_explosion_ring.scale = Vector3(ring_scale, 1.0, ring_scale)
		var ring_material := _explosion_ring.material_override as StandardMaterial3D
		if ring_material != null:
			ring_material.albedo_color.a = lerpf(0.72, 0.0, progress)
			ring_material.emission_energy_multiplier = lerpf(1.6, 0.0, progress)
	if _explosion_sphere != null:
		var sphere_scale := lerpf(0.35, explosion_radius_m * 0.2, progress)
		_explosion_sphere.scale = Vector3.ONE * sphere_scale
		var sphere_material := _explosion_sphere.material_override as StandardMaterial3D
		if sphere_material != null:
			sphere_material.albedo_color.a = lerpf(0.44, 0.0, progress)
			sphere_material.emission_energy_multiplier = lerpf(2.2, 0.0, progress)
	if progress >= 1.0:
		queue_free()

func _ensure_visuals() -> void:
	if _grenade_mesh == null or not is_instance_valid(_grenade_mesh):
		_grenade_mesh = get_node_or_null("GrenadeMesh") as MeshInstance3D
	if _grenade_mesh == null:
		_grenade_mesh = MeshInstance3D.new()
		_grenade_mesh.name = "GrenadeMesh"
		var grenade_mesh := SphereMesh.new()
		grenade_mesh.radius = 0.14
		grenade_mesh.height = 0.28
		_grenade_mesh.mesh = grenade_mesh
		var grenade_material := StandardMaterial3D.new()
		grenade_material.albedo_color = Color(0.196078, 0.215686, 0.25098, 1.0)
		grenade_material.roughness = 0.75
		grenade_material.emission_enabled = true
		grenade_material.emission = Color(0.227451, 0.909804, 0.65098, 1.0)
		grenade_material.emission_energy_multiplier = 0.14
		_grenade_mesh.material_override = grenade_material
		add_child(_grenade_mesh)
	if _explosion_ring == null or not is_instance_valid(_explosion_ring):
		_explosion_ring = get_node_or_null("ExplosionRing") as MeshInstance3D
	if _explosion_ring == null:
		_explosion_ring = MeshInstance3D.new()
		_explosion_ring.name = "ExplosionRing"
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 1.0
		ring_mesh.bottom_radius = 1.0
		ring_mesh.height = 0.12
		ring_mesh.radial_segments = 24
		_explosion_ring.mesh = ring_mesh
		_explosion_ring.position = Vector3(0.0, 0.04, 0.0)
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.albedo_color = Color(1.0, 0.690196, 0.227451, 0.72)
		ring_material.emission_enabled = true
		ring_material.emission = Color(1.0, 0.572549, 0.164706, 1.0)
		ring_material.emission_energy_multiplier = 1.6
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
		sphere_material.albedo_color = Color(1.0, 0.454902, 0.176471, 0.44)
		sphere_material.emission_enabled = true
		sphere_material.emission = Color(1.0, 0.686275, 0.258824, 1.0)
		sphere_material.emission_energy_multiplier = 2.2
		_explosion_sphere.material_override = sphere_material
		_explosion_sphere.visible = false
		add_child(_explosion_sphere)
