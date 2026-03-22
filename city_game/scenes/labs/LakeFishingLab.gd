extends Node3D

const CityLakeRegionRuntime := preload("res://city_game/world/features/lake/CityLakeRegionRuntime.gd")
const CityLakeFishSchoolRuntime := preload("res://city_game/world/features/lake/CityLakeFishSchoolRuntime.gd")
const CityFishingVenueRuntime := preload("res://city_game/world/minigames/CityFishingVenueRuntime.gd")

const REGION_MANIFEST_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/terrain_region_manifest.json"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"

@onready var player := $Player
@onready var hud := $Hud
@onready var water_surface_root := $LakeRoot/WaterSurface
@onready var fish_schools_root := $LakeRoot/FishSchools
@onready var venue_root := $VenueRoot

var _lake_runtime = null
var _fish_school_runtime = null
var _fishing_runtime = null
var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _water_state: Dictionary = {}
var _fish_school_summaries: Array = []

func _ready() -> void:
	_capture_initial_state()
	_setup_runtimes()
	_rebuild_lake_visuals()
	_apply_hud_state()

func _process(delta: float) -> void:
	_update_lake_player_water_state()
	if _fishing_runtime != null and _fishing_runtime.has_method("update_direct"):
		_fishing_runtime.update_direct(venue_root, player, delta)
	_apply_hud_state()

func get_lake_player_water_state() -> Dictionary:
	return _water_state.duplicate(true)

func get_fish_school_summaries() -> Array:
	var snapshot: Array = []
	for school_variant in _fish_school_summaries:
		snapshot.append((school_variant as Dictionary).duplicate(true))
	return snapshot

func get_fishing_runtime_state() -> Dictionary:
	if _fishing_runtime == null or not _fishing_runtime.has_method("get_state"):
		return {}
	return _fishing_runtime.get_state()

func request_fishing_primary_interaction() -> Dictionary:
	if _fishing_runtime == null or not _fishing_runtime.has_method("handle_primary_interaction_direct"):
		return {"success": false, "error": "runtime_unavailable"}
	return _fishing_runtime.handle_primary_interaction_direct(venue_root, player)

func reset_lab_state() -> void:
	if _fishing_runtime != null and _fishing_runtime.has_method("reset_runtime_state"):
		_fishing_runtime.reset_runtime_state(true)
	if player != null and is_instance_valid(player):
		player.global_position = _initial_player_position
		player.rotation = _initial_player_rotation
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		if player.has_method("set_movement_locked"):
			player.set_movement_locked(false)
	_update_lake_player_water_state()
	_apply_hud_state()

func find_scene_minigame_venue_node(venue_id: String) -> Node3D:
	if venue_root == null or not is_instance_valid(venue_root) or not venue_root.has_method("get_fishing_contract"):
		return null
	var contract: Dictionary = venue_root.get_fishing_contract()
	return venue_root if str(contract.get("venue_id", "")) == venue_id else null

func _setup_runtimes() -> void:
	_lake_runtime = CityLakeRegionRuntime.new()
	_lake_runtime.load_from_manifest(REGION_MANIFEST_PATH)
	_fish_school_runtime = CityLakeFishSchoolRuntime.new()
	_fish_school_runtime.configure([_lake_runtime])
	_fish_school_summaries = _fish_school_runtime.get_school_summaries_for_region(REGION_ID)
	_fishing_runtime = CityFishingVenueRuntime.new()
	if venue_root != null and venue_root.has_method("get_fishing_contract"):
		var venue_contract: Dictionary = venue_root.get_fishing_contract()
		_fishing_runtime.configure({
			str(venue_contract.get("venue_id", VENUE_ID)): venue_contract.duplicate(true),
		})
	_fishing_runtime.set_lake_context(_lake_runtime, _fish_school_runtime)
	_update_lake_player_water_state()

func _capture_initial_state() -> void:
	if player == null:
		return
	_initial_player_position = player.global_position
	_initial_player_rotation = player.rotation

func _update_lake_player_water_state() -> void:
	if _lake_runtime == null or player == null:
		_water_state = {
			"in_water": false,
			"underwater": false,
			"region_id": "",
			"world_position": player.global_position if player != null else Vector3.ZERO,
		}
		return
	_water_state = _lake_runtime.query_water_state(player.global_position)
	if player.has_method("set_lake_water_state"):
		player.set_lake_water_state(_water_state)

func _rebuild_lake_visuals() -> void:
	_rebuild_water_surface()
	_rebuild_fish_school_visuals()

func _rebuild_water_surface() -> void:
	if water_surface_root == null or _lake_runtime == null:
		return
	for child in water_surface_root.get_children():
		child.queue_free()
	var runtime_contract: Dictionary = _lake_runtime.get_runtime_contract()
	var polygon_world_points: Array = runtime_contract.get("polygon_world_points", [])
	if polygon_world_points.size() < 3:
		return
	var polygon_local_points := PackedVector2Array()
	var polygon_vertices: Array[Vector3] = []
	var water_level_y_m := float(runtime_contract.get("water_level_y_m", 0.0))
	for point_variant in polygon_world_points:
		if not (point_variant is Vector3):
			continue
		var world_point := point_variant as Vector3
		polygon_local_points.append(Vector2(world_point.x, world_point.z))
		polygon_vertices.append(Vector3(world_point.x, water_level_y_m, world_point.z))
	var indices: PackedInt32Array = Geometry2D.triangulate_polygon(polygon_local_points)
	if indices.size() < 3:
		return
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index_variant in indices:
		var vertex_index := int(index_variant)
		if vertex_index < 0 or vertex_index >= polygon_vertices.size():
			continue
		var vertex := polygon_vertices[vertex_index]
		surface_tool.set_normal(Vector3.UP)
		surface_tool.set_uv(Vector2(vertex.x, vertex.z))
		surface_tool.add_vertex(vertex)
	var mesh := surface_tool.commit()
	if mesh == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "SurfaceMesh"
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.44, 0.68, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.08
	mesh_instance.material_override = material
	water_surface_root.add_child(mesh_instance)

func _rebuild_fish_school_visuals() -> void:
	if fish_schools_root == null:
		return
	for child in fish_schools_root.get_children():
		child.queue_free()
	for school_variant in _fish_school_summaries:
		if not (school_variant is Dictionary):
			continue
		var school: Dictionary = school_variant
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.name = str(school.get("school_id", "FishSchool"))
		var sphere := SphereMesh.new()
		sphere.radius = clampf(float(school.get("swim_radius_m", 6.0)) * 0.05, 0.25, 0.7)
		sphere.height = sphere.radius * 2.0
		mesh_instance.mesh = sphere
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.88, 0.72, 0.34, 0.95)
		material.emission_enabled = true
		material.emission = Color(0.18, 0.44, 0.56, 1.0)
		material.emission_energy_multiplier = 0.15
		mesh_instance.material_override = material
		mesh_instance.position = school.get("world_position", Vector3.ZERO)
		fish_schools_root.add_child(mesh_instance)

func _apply_hud_state() -> void:
	if hud == null:
		return
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(true)
	if hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(Engine.get_frames_per_second())
	if hud.has_method("set_status"):
		var fishing_state := get_fishing_runtime_state()
		hud.set_status(
			"v38 Lake Fishing Lab\nstate=%s  schools=%d  in_water=%s  underwater=%s" % [
				str(fishing_state.get("cast_state", "idle")),
				_fish_school_summaries.size(),
				str(bool(_water_state.get("in_water", false))),
				str(bool(_water_state.get("underwater", false))),
			]
		)
	if hud.has_method("set_fishing_hud_state") and _fishing_runtime != null and _fishing_runtime.has_method("get_match_hud_state"):
		hud.set_fishing_hud_state(_fishing_runtime.get_match_hud_state())
	if hud.has_method("set_interaction_prompt_state") and _fishing_runtime != null and _fishing_runtime.has_method("get_primary_interaction_state"):
		hud.set_interaction_prompt_state(_fishing_runtime.get_primary_interaction_state(player))
