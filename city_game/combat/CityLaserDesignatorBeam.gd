extends Node3D

@export var beam_thickness_m := 0.08
@export var max_lifetime_sec := 0.18

var _remaining_sec := 0.0
var _origin := Vector3.ZERO
var _hit_position := Vector3.ZERO
var _beam_material: StandardMaterial3D = null
var _impact_material: StandardMaterial3D = null

func _ready() -> void:
	_remaining_sec = maxf(_remaining_sec, max_lifetime_sec)
	_ensure_visuals()
	_apply_geometry()

func configure(origin: Vector3, hit_position: Vector3) -> void:
	_origin = origin
	_hit_position = hit_position
	_remaining_sec = max_lifetime_sec
	if is_inside_tree():
		_ensure_visuals()
		_apply_geometry()

func _process(delta: float) -> void:
	_remaining_sec = maxf(_remaining_sec - maxf(delta, 0.0), 0.0)
	_apply_fade()
	if _remaining_sec <= 0.0:
		queue_free()

func _ensure_visuals() -> void:
	var beam_mesh := get_node_or_null("Beam") as MeshInstance3D
	if beam_mesh == null:
		beam_mesh = MeshInstance3D.new()
		beam_mesh.name = "Beam"
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(beam_thickness_m, beam_thickness_m, 0.5)
		beam_mesh.mesh = box_mesh
		_beam_material = _build_material(Color(0.24, 1.0, 0.48, 0.72), 2.4)
		beam_mesh.material_override = _beam_material
		add_child(beam_mesh)
	else:
		_beam_material = beam_mesh.material_override as StandardMaterial3D
	var impact := get_node_or_null("Impact") as MeshInstance3D
	if impact == null:
		impact = MeshInstance3D.new()
		impact.name = "Impact"
		var sphere_mesh := SphereMesh.new()
		sphere_mesh.radius = beam_thickness_m * 1.25
		sphere_mesh.height = beam_thickness_m * 2.5
		impact.mesh = sphere_mesh
		_impact_material = _build_material(Color(0.62, 1.0, 0.74, 0.9), 2.8)
		impact.material_override = _impact_material
		add_child(impact)
	else:
		_impact_material = impact.material_override as StandardMaterial3D

func _apply_geometry() -> void:
	var beam_mesh := get_node_or_null("Beam") as MeshInstance3D
	var impact := get_node_or_null("Impact") as MeshInstance3D
	if beam_mesh == null or impact == null:
		return
	var delta := _hit_position - _origin
	var distance_m := maxf(delta.length(), 0.05)
	var direction := delta.normalized() if delta.length_squared() > 0.0001 else Vector3.FORWARD
	global_position = _origin
	var up_vector := Vector3.UP
	if absf(direction.dot(up_vector)) >= 0.98:
		up_vector = Vector3.FORWARD
	look_at(_origin + direction, up_vector, true)
	var box_mesh := beam_mesh.mesh as BoxMesh
	if box_mesh != null:
		box_mesh.size = Vector3(beam_thickness_m, beam_thickness_m, distance_m)
	beam_mesh.position = Vector3(0.0, 0.0, -distance_m * 0.5)
	impact.global_position = _hit_position

func _apply_fade() -> void:
	var fade := clampf(_remaining_sec / maxf(max_lifetime_sec, 0.001), 0.0, 1.0)
	if _beam_material != null:
		_beam_material.albedo_color.a = 0.72 * fade
		_beam_material.emission_energy_multiplier = 2.4 * fade
	if _impact_material != null:
		_impact_material.albedo_color.a = 0.9 * fade
		_impact_material.emission_energy_multiplier = 2.8 * fade

func _build_material(base_color: Color, emission_energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = base_color
	material.emission_enabled = true
	material.emission = Color(base_color.r, base_color.g, base_color.b, 1.0)
	material.emission_energy_multiplier = emission_energy
	return material
