extends RefCounted

# Merged triangle-surface accumulator for the v62 procedural building kit.
#
# Emits facade-side quads with UVs authored in facade-module units (one unit
# == one window bay horizontally and one floor vertically) plus a baked
# vertical ambient-occlusion gradient in the vertex color.

var vertices := PackedVector3Array()
var normals := PackedVector3Array()
var colors := PackedColorArray()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()

var bay_x := 3.2
var bay_z := 3.2
var floor_height := 3.6
var origin_x := 0.0
var origin_z := 0.0
var ground_y := 0.0

func configure(p_bay_x: float, p_bay_z: float, p_floor_height: float, p_origin_x: float, p_origin_z: float, p_ground_y: float) -> void:
	bay_x = maxf(p_bay_x, 0.5)
	bay_z = maxf(p_bay_z, 0.5)
	floor_height = maxf(p_floor_height, 0.5)
	origin_x = p_origin_x
	origin_z = p_origin_z
	ground_y = p_ground_y

func is_empty() -> bool:
	return indices.is_empty()

func triangle_count() -> int:
	return int(indices.size() / 3)

func vertex_count() -> int:
	return vertices.size()

# Four wall faces only (top/bottom are handled by roof caps in the detail batch).
func add_box_sides(center: Vector3, size: Vector3, ao_bottom: float, ao_top: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var x0 := center.x - hx
	var x1 := center.x + hx
	var y0 := center.y - hy
	var y1 := center.y + hy
	var z0 := center.z - hz
	var z1 := center.z + hz
	var u_z0 := (z0 - origin_z) / bay_z
	var u_z1 := (z1 - origin_z) / bay_z
	var u_x0 := (x0 - origin_x) / bay_x
	var u_x1 := (x1 - origin_x) / bay_x
	var v0 := (y0 - ground_y) / floor_height
	var v1 := (y1 - ground_y) / floor_height
	var c0 := Color(ao_bottom, ao_bottom, ao_bottom, 1.0)
	var c1 := Color(ao_top, ao_top, ao_top, 1.0)
	# +X
	_add_quad(
		Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1),
		Vector3(1.0, 0.0, 0.0),
		Vector2(u_z0, v0), Vector2(u_z0, v1), Vector2(u_z1, v1), Vector2(u_z1, v0),
		c0, c1, c1, c0
	)
	# -X
	_add_quad(
		Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0),
		Vector3(-1.0, 0.0, 0.0),
		Vector2(u_z1, v0), Vector2(u_z1, v1), Vector2(u_z0, v1), Vector2(u_z0, v0),
		c0, c1, c1, c0
	)
	# +Z
	_add_quad(
		Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1),
		Vector3(0.0, 0.0, 1.0),
		Vector2(u_x1, v0), Vector2(u_x1, v1), Vector2(u_x0, v1), Vector2(u_x0, v0),
		c0, c1, c1, c0
	)
	# -Z
	_add_quad(
		Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0),
		Vector3(0.0, 0.0, -1.0),
		Vector2(u_x0, v0), Vector2(u_x0, v1), Vector2(u_x1, v1), Vector2(u_x1, v0),
		c0, c1, c1, c0
	)

# Closed box used for glazing / lobby volumes.
func add_box(center: Vector3, size: Vector3, color: Color) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var hz := size.z * 0.5
	var x0 := center.x - hx
	var x1 := center.x + hx
	var y0 := center.y - hy
	var y1 := center.y + hy
	var z0 := center.z - hz
	var z1 := center.z + hz
	var uv_zero := Vector2.ZERO
	# +X
	_add_quad(
		Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1),
		Vector3(1.0, 0.0, 0.0), uv_zero, uv_zero, uv_zero, uv_zero, color, color, color, color
	)
	# -X
	_add_quad(
		Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0),
		Vector3(-1.0, 0.0, 0.0), uv_zero, uv_zero, uv_zero, uv_zero, color, color, color, color
	)
	# +Z
	_add_quad(
		Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1),
		Vector3(0.0, 0.0, 1.0), uv_zero, uv_zero, uv_zero, uv_zero, color, color, color, color
	)
	# -Z
	_add_quad(
		Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0),
		Vector3(0.0, 0.0, -1.0), uv_zero, uv_zero, uv_zero, uv_zero, color, color, color, color
	)
	# +Y
	_add_quad(
		Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3(x0, y1, z0),
		Vector3(0.0, 1.0, 0.0), uv_zero, uv_zero, uv_zero, uv_zero, color, color, color, color
	)
	# -Y
	_add_quad(
		Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1),
		Vector3(0.0, -1.0, 0.0), uv_zero, uv_zero, uv_zero, uv_zero, color, color, color, color
	)

func commit(material: Material) -> ArrayMesh:
	if is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh

func _add_quad(
	a: Vector3, b: Vector3, c: Vector3, d: Vector3,
	normal: Vector3,
	uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2,
	col_a: Color, col_b: Color, col_c: Color, col_d: Color
) -> void:
	var base := vertices.size()
	vertices.resize(base + 4)
	normals.resize(base + 4)
	colors.resize(base + 4)
	uvs.resize(base + 4)
	vertices[base] = a
	vertices[base + 1] = b
	vertices[base + 2] = c
	vertices[base + 3] = d
	normals[base] = normal
	normals[base + 1] = normal
	normals[base + 2] = normal
	normals[base + 3] = normal
	colors[base] = col_a
	colors[base + 1] = col_b
	colors[base + 2] = col_c
	colors[base + 3] = col_d
	uvs[base] = uv_a
	uvs[base + 1] = uv_b
	uvs[base + 2] = uv_c
	uvs[base + 3] = uv_d
	var index_base := indices.size()
	indices.resize(index_base + 6)
	# Godot treats clockwise winding as the front face. The quad corners are
	# authored counter-clockwise as seen from outside, so emit the reversed
	# triangle order to make the facade face outward.
	indices[index_base] = base
	indices[index_base + 1] = base + 2
	indices[index_base + 2] = base + 1
	indices[index_base + 3] = base
	indices[index_base + 4] = base + 3
	indices[index_base + 5] = base + 2
