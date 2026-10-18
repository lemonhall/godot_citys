extends RefCounted

# Builds the v63 vertical-slice content for one chunk: the river surface and
# the three plan landmarks. Outside the slice this returns null so the world
# keeps the v62 path unchanged.

const Runtime := preload("res://city_game/world/generation/plan/CityPlanRuntime.gd")
const SceneBuilder := preload("res://city_game/world/serviceability/CityBuildingSceneBuilder.gd")
const RoofAccess := preload("res://city_game/world/generation/plan/CityPlanRoofAccess.gd")

const WATER_LEVEL_Y := 0.06
const WATER_SAMPLE_STEP_M := 24.0

static func build(chunk_data: Dictionary) -> Node3D:
	var chunk_center: Vector3 = chunk_data.get("chunk_center", Vector3.ZERO)
	var chunk_size := float(chunk_data.get("chunk_size_m", 256.0))
	if not Runtime.chunk_overlaps_slice(chunk_center, chunk_size):
		return null
	var world_seed := int(chunk_data.get("world_seed", 12345))
	var sampler = Runtime.get_sampler(world_seed)
	var root := Node3D.new()
	root.name = "CityPlanSlice"
	var bed := _build_ribbon(sampler, chunk_center, chunk_size, 1.35, 0.02, "CityPlanRiverBed", _bed_material())
	if bed != null:
		root.add_child(bed)
	var water := _build_ribbon(sampler, chunk_center, chunk_size, 1.0, WATER_LEVEL_Y, "CityPlanWater", _water_material())
	if water != null:
		root.add_child(water)
	var landmarks := _build_landmarks(sampler, chunk_center, chunk_size)
	if landmarks.get_child_count() > 0:
		root.add_child(landmarks)
	return root if root.get_child_count() > 0 else null

static func _build_ribbon(sampler, chunk_center: Vector3, chunk_size: float, width_scale: float, y_level: float, node_name: String, material: StandardMaterial3D) -> MeshInstance3D:
	var river: Dictionary = sampler.terrain().get("river", {})
	var points: Array = river.get("points", [])
	var width := float(river.get("width_m", 60.0)) * width_scale
	if points.size() < 2:
		return null
	var half := chunk_size * 0.5 + width * 2.0
	var runs: Array = []
	var current: Array = []
	for index in range(points.size() - 1):
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var segment_length := a.distance_to(b)
		var steps := maxi(int(ceil(segment_length / WATER_SAMPLE_STEP_M)), 1)
		for step in range(steps):
			var t := float(step) / float(steps)
			var world := a.lerp(b, t)
			var local := Vector2(world.x - chunk_center.x, world.z - chunk_center.z)
			if absf(local.x) <= half and absf(local.y) <= half:
				current.append(local)
			elif current.size() >= 2:
				runs.append(current)
				current = []
			else:
				current = []
	if current.size() >= 2:
		runs.append(current)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_count := 0
	for run in runs:
		for index in range(run.size() - 1):
			var p0: Vector2 = run[index]
			var p1: Vector2 = run[index + 1]
			var tangent := (p1 - p0).normalized()
			if tangent.length_squared() < 0.0001:
				continue
			var normal := Vector2(-tangent.y, tangent.x) * (width * 0.5)
			var y := y_level
			var a0 := Vector3(p0.x - normal.x, y, p0.y - normal.y)
			var a1 := Vector3(p0.x + normal.x, y, p0.y + normal.y)
			var b0 := Vector3(p1.x - normal.x, y, p1.y - normal.y)
			var b1 := Vector3(p1.x + normal.x, y, p1.y + normal.y)
			_add_quad(surface, a0, a1, b1, b0)
			vertex_count += 6
	if vertex_count == 0:
		return null
	var mesh := surface.commit()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return instance

static func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)

static func _bed_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.11, 0.10, 0.085)
	material.roughness = 0.96
	return material

static func _water_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.05, 0.17, 0.22, 0.88)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.10
	material.metallic = 0.25
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	return material

static func _build_landmarks(sampler, chunk_center: Vector3, chunk_size: float) -> Node3D:
	var root := Node3D.new()
	root.name = "CityPlanLandmarks"
	var half := chunk_size * 0.5 + 40.0
	for landmark_variant in sampler.landmarks():
		var landmark: Dictionary = landmark_variant
		var position: Vector2 = landmark.get("position", Vector2.ZERO)
		var local := Vector3(position.x - chunk_center.x, 0.0, position.y - chunk_center.z)
		if absf(local.x) > half or absf(local.z) > half:
			continue
		var height := float(landmark.get("height_m", 120.0))
		var kind := str(landmark.get("kind", "spire"))
		var footprint := 40.0 if kind == "spire" else 30.0
		var archetype := "needle" if kind == "spire" else "hotel_tower"
		var building := {
			"name": "CityLandmark_%s" % str(landmark.get("id", "")),
			"building_id": str(landmark.get("id", "")),
			"archetype_id": archetype,
			"center": Vector3(local.x, height * 0.5, local.z),
			"size": Vector3(footprint, height, footprint),
			"collision_size": Vector3(footprint, height, footprint),
			"yaw_rad": 0.35,
			"road_angle_rad": 0.0,
			"footprint_radius_m": footprint * 0.5,
			"visual_footprint_radius_m": footprint * 0.5,
			"road_clearance_m": 40.0,
			"visual_road_clearance_m": 40.0,
			"candidate_kind": "landmark",
			"road_alignment_delta_deg": 0.0,
			"detail_seed": int(str(landmark.get("id", "")).hash()),
			"district_kind": "downtown",
			"main_color": Color(0.40, 0.43, 0.46),
			"accent_color": Color(0.62, 0.58, 0.50),
			"roof_color": Color(0.20, 0.22, 0.24),
			"glass_color": Color(0.04, 0.08, 0.11),
			"detail_level": "compact",
		}
		var node := SceneBuilder.build_runtime_building(building)
		if node == null:
			continue
		node.name = "CityLandmark_%s" % str(landmark.get("id", ""))
		node.set_meta("city_landmark_id", str(landmark.get("id", "")))
		node.set_meta("city_landmark_height_m", height)
		var access := _build_roof_access(local, height)
		node.add_child(access)
		root.add_child(node)
	return root

static func _build_roof_access(local: Vector3, height: float) -> Node3D:
	var access := Node3D.new()
	access.name = "RoofAccess"
	access.position = Vector3(0.0, -height * 0.5, 0.0)
	access.set_meta("roof_local", Vector3(0.0, height, 0.0))
	access.set_meta("city_landmark_height_m", height)
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 2.2
	pad_mesh.bottom_radius = 2.2
	pad_mesh.height = 0.12
	var pad := MeshInstance3D.new()
	pad.name = "Pad"
	pad.mesh = pad_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.9, 0.75, 0.3)
	material.emission_enabled = true
	material.emission = Color(0.95, 0.75, 0.25)
	material.emission_energy_multiplier = 2.0
	pad.material_override = material
	access.add_child(pad)
	return access
