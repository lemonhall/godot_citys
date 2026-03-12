extends Node3D

@export var speed_mps := 180.0
@export var max_distance_m := 420.0
@export var max_lifetime_sec := 3.5
@export var damage := 1.0

var _direction := Vector3.FORWARD
var _owner: Node = null
var _distance_travelled_m := 0.0
var _lifetime_sec := 0.0
var _group_name := "city_projectile"
var _target_group_name := "city_enemy"
var _tint := Color(0.65098, 0.85098, 1.0, 1.0)
var _emission_tint := Color(0.360784, 0.713725, 1.0, 1.0)
var _pedestrian_hit_resolver: Object = null

func _ready() -> void:
	add_to_group(_group_name)
	_ensure_visual()

func configure(
	origin: Vector3,
	direction: Vector3,
	owner_node: Node = null,
	projectile_damage: float = 1.0,
	group_name: String = "city_projectile",
	target_group_name: String = "city_enemy",
	tint: Color = Color(0.65098, 0.85098, 1.0, 1.0),
	emission_tint: Color = Color(0.360784, 0.713725, 1.0, 1.0),
	pedestrian_hit_resolver: Object = null
) -> void:
	position = origin
	_direction = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	_owner = owner_node
	damage = projectile_damage
	_group_name = group_name
	_target_group_name = target_group_name
	_tint = tint
	_emission_tint = emission_tint
	_pedestrian_hit_resolver = pedestrian_hit_resolver

func get_direction() -> Vector3:
	return _direction

func get_velocity() -> Vector3:
	return _direction * speed_mps

func _physics_process(delta: float) -> void:
	if get_world_3d() == null or get_world_3d().direct_space_state == null:
		return
	_lifetime_sec += delta
	if _lifetime_sec >= max_lifetime_sec:
		queue_free()
		return
	var start_position := global_position
	var end_position := start_position + get_velocity() * delta
	var query := PhysicsRayQueryParameters3D.create(start_position, end_position)
	query.collide_with_areas = false
	query.exclude = _build_query_exclusions()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider", null)
		if collider != null and collider.is_in_group(_target_group_name) and collider.has_method("apply_projectile_hit"):
			collider.apply_projectile_hit(damage, hit.get("position", end_position), get_velocity())
		queue_free()
		return
	if _pedestrian_hit_resolver != null and _pedestrian_hit_resolver.has_method("resolve_projectile_hit"):
		var pedestrian_hit: Dictionary = _pedestrian_hit_resolver.resolve_projectile_hit(start_position, end_position, damage, get_velocity())
		if not pedestrian_hit.is_empty():
			global_position = pedestrian_hit.get("hit_position", end_position)
			queue_free()
			return
	global_position = end_position
	_distance_travelled_m += start_position.distance_to(end_position)
	if _distance_travelled_m >= max_distance_m:
		queue_free()

func _build_query_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if _owner is CollisionObject3D:
		exclusions.append((_owner as CollisionObject3D).get_rid())
	return exclusions

func _ensure_visual() -> void:
	if get_node_or_null("MeshInstance3D") != null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = _tint
	material.emission_enabled = true
	material.emission = _emission_tint
	material.emission_energy_multiplier = 1.2
	mesh_instance.material_override = material
	add_child(mesh_instance)
