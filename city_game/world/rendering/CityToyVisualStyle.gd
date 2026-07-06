extends RefCounted

const LEGO_BUILDING_PALETTE := [
	Color(0.86, 0.04, 0.07, 1.0),
	Color(0.95, 0.74, 0.08, 1.0),
	Color(0.04, 0.26, 0.78, 1.0),
	Color(0.02, 0.48, 0.14, 1.0),
	Color(0.92, 0.92, 0.86, 1.0),
	Color(0.12, 0.52, 0.88, 1.0),
]

const LEGO_GROUND_COLOR := Color(0.25, 0.72, 0.18, 1.0)
const LEGO_ROAD_COLOR := Color(0.08, 0.10, 0.13, 1.0)
const LEGO_STRIPE_COLOR := Color(1.0, 0.84, 0.16, 1.0)
const LEGO_WATER_COLOR := Color(0.05, 0.58, 0.93, 0.72)
const LEGO_SKY_COLOR := Color(0.42, 0.76, 1.0, 1.0)
const LEGO_AMBIENT_COLOR := Color(1.0, 0.98, 0.92, 1.0)
const LEGO_PLASTIC_CLEARCOAT := 0.92
const LEGO_PLASTIC_CLEARCOAT_ROUGHNESS := 0.08
const LEGO_PLASTIC_SPECULAR := 0.95
const LEGO_ROUNDED_BOX_RADIUS_M := 1.15

static var _material_cache: Dictionary = {}
static var _box_mesh_cache: Dictionary = {}

static func get_palette_color(seed_value: int) -> Color:
	return LEGO_BUILDING_PALETTE[int(posmod(seed_value, LEGO_BUILDING_PALETTE.size()))]

static func get_material(color: Color, surface_kind: String = "building") -> StandardMaterial3D:
	var key := "%s|%s" % [_color_cache_key(color), surface_kind]
	if _material_cache.has(key):
		return _material_cache[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.02
	material.metallic_specular = LEGO_PLASTIC_SPECULAR
	material.roughness = _roughness_for_kind(surface_kind)
	material.clearcoat_enabled = true
	material.clearcoat = LEGO_PLASTIC_CLEARCOAT
	material.clearcoat_roughness = LEGO_PLASTIC_CLEARCOAT_ROUGHNESS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if color.a < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[key] = material
	return material

static func get_vertex_color_material(surface_kind: String = "vehicle") -> StandardMaterial3D:
	var key := "vertex|%s" % surface_kind
	if _material_cache.has(key):
		return _material_cache[key]
	var material := get_material(Color.WHITE, surface_kind).duplicate()
	material.vertex_color_use_as_albedo = true
	_material_cache[key] = material
	return material

static func get_rounded_box_mesh(size: Vector3) -> ArrayMesh:
	var key := _vector3_cache_key(size)
	if _box_mesh_cache.has(key):
		return _box_mesh_cache[key]
	var mesh := _build_beveled_box_mesh(size, _resolve_bevel_radius(size))
	_box_mesh_cache[key] = mesh
	return mesh

static func configure_environment(environment: Environment) -> void:
	if environment == null:
		return
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = LEGO_SKY_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = LEGO_AMBIENT_COLOR
	environment.ambient_light_energy = 0.82
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.08
	environment.ssao_enabled = false
	environment.glow_enabled = false
	environment.fog_enabled = false

static func _roughness_for_kind(surface_kind: String) -> float:
	match surface_kind:
		"water":
			return 0.08
		"road":
			return 0.48
		"ground":
			return 0.58
		"vehicle":
			return 0.16
		"pedestrian":
			return 0.46
		"hlod":
			return 0.54
	return 0.14

static func _resolve_bevel_radius(size: Vector3) -> float:
	var shortest_axis := minf(size.x, minf(size.y, size.z))
	return clampf(LEGO_ROUNDED_BOX_RADIUS_M, 0.08, shortest_axis * 0.22)

static func _build_beveled_box_mesh(size: Vector3, bevel_radius: float) -> ArrayMesh:
	var half := size * 0.5
	var radius := minf(bevel_radius, minf(half.x, minf(half.y, half.z)) * 0.85)
	var inset := Vector3(
		maxf(half.x - radius, half.x * 0.18),
		maxf(half.y - radius, half.y * 0.18),
		maxf(half.z - radius, half.z * 0.18)
	)
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_axis_faces(surface_tool, half, inset)
	_append_edge_faces(surface_tool, half, inset)
	_append_corner_faces(surface_tool, half, inset)
	surface_tool.generate_normals()
	return surface_tool.commit()

static func _append_axis_faces(surface_tool: SurfaceTool, half: Vector3, inset: Vector3) -> void:
	for sign_value in [-1.0, 1.0]:
		var sx := float(sign_value)
		_add_oriented_quad(
			surface_tool,
			Vector3(sx * half.x, -inset.y, -inset.z),
			Vector3(sx * half.x, -inset.y, inset.z),
			Vector3(sx * half.x, inset.y, inset.z),
			Vector3(sx * half.x, inset.y, -inset.z)
		)
		var sy := float(sign_value)
		_add_oriented_quad(
			surface_tool,
			Vector3(-inset.x, sy * half.y, -inset.z),
			Vector3(inset.x, sy * half.y, -inset.z),
			Vector3(inset.x, sy * half.y, inset.z),
			Vector3(-inset.x, sy * half.y, inset.z)
		)
		var sz := float(sign_value)
		_add_oriented_quad(
			surface_tool,
			Vector3(-inset.x, -inset.y, sz * half.z),
			Vector3(-inset.x, inset.y, sz * half.z),
			Vector3(inset.x, inset.y, sz * half.z),
			Vector3(inset.x, -inset.y, sz * half.z)
		)

static func _append_edge_faces(surface_tool: SurfaceTool, half: Vector3, inset: Vector3) -> void:
	for sy_value in [-1.0, 1.0]:
		for sz_value in [-1.0, 1.0]:
			var sy := float(sy_value)
			var sz := float(sz_value)
			_add_oriented_quad(
				surface_tool,
				Vector3(-inset.x, sy * half.y, sz * inset.z),
				Vector3(inset.x, sy * half.y, sz * inset.z),
				Vector3(inset.x, sy * inset.y, sz * half.z),
				Vector3(-inset.x, sy * inset.y, sz * half.z)
			)
	for sx_value in [-1.0, 1.0]:
		for sz_value in [-1.0, 1.0]:
			var sx := float(sx_value)
			var sz := float(sz_value)
			_add_oriented_quad(
				surface_tool,
				Vector3(sx * half.x, -inset.y, sz * inset.z),
				Vector3(sx * half.x, inset.y, sz * inset.z),
				Vector3(sx * inset.x, inset.y, sz * half.z),
				Vector3(sx * inset.x, -inset.y, sz * half.z)
			)
	for sx_value in [-1.0, 1.0]:
		for sy_value in [-1.0, 1.0]:
			var sx := float(sx_value)
			var sy := float(sy_value)
			_add_oriented_quad(
				surface_tool,
				Vector3(sx * half.x, sy * inset.y, -inset.z),
				Vector3(sx * half.x, sy * inset.y, inset.z),
				Vector3(sx * inset.x, sy * half.y, inset.z),
				Vector3(sx * inset.x, sy * half.y, -inset.z)
			)

static func _append_corner_faces(surface_tool: SurfaceTool, half: Vector3, inset: Vector3) -> void:
	for sx_value in [-1.0, 1.0]:
		for sy_value in [-1.0, 1.0]:
			for sz_value in [-1.0, 1.0]:
				var sx := float(sx_value)
				var sy := float(sy_value)
				var sz := float(sz_value)
				_add_oriented_triangle(
					surface_tool,
					Vector3(sx * inset.x, sy * half.y, sz * half.z),
					Vector3(sx * half.x, sy * inset.y, sz * half.z),
					Vector3(sx * half.x, sy * half.y, sz * inset.z)
				)

static func _add_oriented_quad(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	if _face_points_inward(a, b, c, [a, b, c, d]):
		_add_triangle(surface_tool, a, c, b)
		_add_triangle(surface_tool, a, d, c)
	else:
		_add_triangle(surface_tool, a, b, c)
		_add_triangle(surface_tool, a, c, d)

static func _add_oriented_triangle(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if _face_points_inward(a, b, c, [a, b, c]):
		_add_triangle(surface_tool, a, c, b)
	else:
		_add_triangle(surface_tool, a, b, c)

static func _face_points_inward(a: Vector3, b: Vector3, c: Vector3, points: Array) -> bool:
	var normal := (b - a).cross(c - a).normalized()
	var center := Vector3.ZERO
	for point_variant in points:
		center += point_variant as Vector3
	center /= float(points.size())
	return normal.dot(center) < 0.0

static func _add_triangle(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface_tool.add_vertex(a)
	surface_tool.add_vertex(b)
	surface_tool.add_vertex(c)

static func _vector3_cache_key(value: Vector3) -> String:
	return "%.3f|%.3f|%.3f" % [value.x, value.y, value.z]

static func _color_cache_key(value: Color) -> String:
	return "%.4f|%.4f|%.4f|%.4f" % [value.r, value.g, value.b, value.a]
