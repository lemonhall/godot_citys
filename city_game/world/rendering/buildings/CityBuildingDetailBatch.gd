extends RefCounted

# Instance accumulator for repeated building detail (cornices, fins, balconies,
# rooftop equipment, signage). Emits one MultiMeshInstance3D per batch, which is
# far cheaper to author in GDScript than merged triangles and still renders in a
# single draw call.
#
# The hot path is deliberately inlined: a tower emits 100+ detail boxes per
# mount, and GDScript call overhead dominated an earlier version.

const MAX_INSTANCES := 512

var transforms: Array[Transform3D] = []
var custom_data: Array[Color] = []

func is_empty() -> bool:
	return transforms.is_empty()

func count() -> int:
	return transforms.size()

func add_box(center: Vector3, size: Vector3, linear_color: Color, emissive: float = 0.0) -> void:
	if transforms.size() >= MAX_INSTANCES:
		return
	var sx := size.x if size.x > 0.02 else 0.02
	var sy := size.y if size.y > 0.02 else 0.02
	var sz := size.z if size.z > 0.02 else 0.02
	transforms.append(Transform3D(Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, sy, 0.0), Vector3(0.0, 0.0, sz)), center))
	custom_data.append(Color(linear_color.r, linear_color.g, linear_color.b, emissive if emissive > 0.0 else 0.0))

func add_oriented_box(center: Vector3, size: Vector3, rotation: Basis, linear_color: Color, emissive: float = 0.0) -> void:
	if transforms.size() >= MAX_INSTANCES:
		return
	var sx := size.x if size.x > 0.02 else 0.02
	var sy := size.y if size.y > 0.02 else 0.02
	var sz := size.z if size.z > 0.02 else 0.02
	transforms.append(Transform3D(rotation * Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, sy, 0.0), Vector3(0.0, 0.0, sz)), center))
	custom_data.append(Color(linear_color.r, linear_color.g, linear_color.b, emissive if emissive > 0.0 else 0.0))

func add_cylinder(center: Vector3, radius: float, height: float, linear_color: Color, emissive: float = 0.0) -> void:
	if transforms.size() >= MAX_INSTANCES:
		return
	var diameter := maxf(radius, 0.02) * 2.0
	var cyl_height := height if height > 0.05 else 0.05
	transforms.append(Transform3D(Basis(Vector3(diameter, 0.0, 0.0), Vector3(0.0, cyl_height, 0.0), Vector3(0.0, 0.0, diameter)), center))
	custom_data.append(Color(linear_color.r, linear_color.g, linear_color.b, emissive if emissive > 0.0 else 0.0))

func build_multimesh(mesh: Mesh) -> MultiMesh:
	if transforms.is_empty():
		return null
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for instance_index in range(transforms.size()):
		multimesh.set_instance_transform(instance_index, transforms[instance_index])
		multimesh.set_instance_custom_data(instance_index, custom_data[instance_index])
	return multimesh

func build(node_name: String, mesh: Mesh, material: Material, cast_shadow: bool = true) -> MultiMeshInstance3D:
	var multimesh := build_multimesh(mesh)
	if multimesh == null:
		return null
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance
