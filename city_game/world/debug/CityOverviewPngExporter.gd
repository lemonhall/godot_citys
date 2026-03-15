extends RefCounted

const CityChunkProfileBuilder := preload("res://city_game/world/rendering/CityChunkProfileBuilder.gd")

const DEFAULT_IMAGE_SIZE := Vector2i(2048, 2048)
const ACTIVE_BOUNDS_MARGIN_M := 1024.0

const BACKGROUND_COLOR := Color(0.933333, 0.92549, 0.890196, 1.0)
const ROAD_COLOR := Color(0.168627, 0.172549, 0.180392, 1.0)
const BUILDING_COLOR := Color(0.666667, 0.54902, 0.439216, 1.0)

const ROAD_BRUSH_RADIUS_BY_CLASS := {
	"expressway_elevated": 4,
	"arterial": 3,
	"local": 2,
	"service": 1,
}

func export_world_overview(config, world_data: Dictionary, output_basename: String) -> Dictionary:
	var road_graph = world_data.get("road_graph")
	if road_graph == null:
		return _build_failure_result("Missing road_graph in world_data")

	var active_bounds := _resolve_active_bounds(config, road_graph)
	var image := Image.create(DEFAULT_IMAGE_SIZE.x, DEFAULT_IMAGE_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(BACKGROUND_COLOR)

	var road_draw_stats := _draw_roads(image, road_graph.edges, active_bounds)
	var building_draw_stats := _draw_buildings(image, config, world_data, active_bounds)

	var resolved_output_basename := _resolve_output_basename(output_basename)
	var output_dir := resolved_output_basename.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		return _build_failure_result("Failed to create overview output directory: %s" % output_dir)

	var png_path := "%s.png" % resolved_output_basename
	var metadata_path := "%s.json" % resolved_output_basename
	var save_error := image.save_png(png_path)
	if save_error != OK:
		return _build_failure_result("Failed to save overview PNG: %s" % png_path)

	var growth_stats: Dictionary = road_graph.get_growth_stats() if road_graph.has_method("get_growth_stats") else {}
	var metadata := {
		"png_path": png_path,
		"metadata_path": metadata_path,
		"image_width_px": image.get_width(),
		"image_height_px": image.get_height(),
		"road_edge_count": int(road_draw_stats.get("road_edge_count", 0)),
		"population_center_count": int(growth_stats.get("population_center_count", 0)),
		"corridor_count": int(growth_stats.get("corridor_count", 0)),
		"road_pixel_count": int(road_draw_stats.get("road_pixel_count", 0)),
		"building_pixel_count": int(building_draw_stats.get("building_pixel_count", 0)),
		"building_footprint_count": int(building_draw_stats.get("building_footprint_count", 0)),
		"building_chunk_count": int(building_draw_stats.get("building_chunk_count", 0)),
		"active_bounds": _rect_to_dict(active_bounds),
	}

	var metadata_file := FileAccess.open(metadata_path, FileAccess.WRITE)
	if metadata_file == null:
		return _build_failure_result("Failed to write overview metadata: %s" % metadata_path, png_path)
	metadata_file.store_string(JSON.stringify(metadata, "\t"))
	metadata_file.close()

	return {
		"success": true,
		"png_path": png_path,
		"metadata_path": metadata_path,
		"metadata": metadata,
	}

func _resolve_output_basename(output_basename: String) -> String:
	var normalized := output_basename.replace("\\", "/").strip_edges()
	if normalized.begins_with("res://"):
		return ProjectSettings.globalize_path(normalized)
	if normalized.begins_with("user://"):
		var project_local := "res://%s" % normalized.trim_prefix("user://").trim_prefix("/")
		return ProjectSettings.globalize_path(project_local)
	if _is_absolute_path(normalized):
		return normalized.replace("/", "\\")
	return ProjectSettings.globalize_path("res://%s" % normalized.trim_prefix("/"))

func _is_absolute_path(path: String) -> bool:
	if path.begins_with("/"):
		return true
	return path.length() >= 3 and path.substr(1, 2) == ":/"

func _build_failure_result(message: String, png_path: String = "", metadata_path: String = "") -> Dictionary:
	return {
		"success": false,
		"error": message,
		"png_path": png_path,
		"metadata_path": metadata_path,
		"metadata": {},
	}

func _resolve_active_bounds(config, road_graph) -> Rect2:
	var has_bounds := false
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for edge_variant in road_graph.edges:
		var edge: Dictionary = edge_variant
		var edge_bounds: Rect2 = edge.get("bounds", Rect2())
		if not edge_bounds.has_area():
			edge_bounds = _build_bounds_from_points(edge.get("points", []))
		if not edge_bounds.has_area():
			continue
		has_bounds = true
		min_x = minf(min_x, edge_bounds.position.x)
		min_y = minf(min_y, edge_bounds.position.y)
		max_x = maxf(max_x, edge_bounds.end.x)
		max_y = maxf(max_y, edge_bounds.end.y)

	var growth_stats: Dictionary = road_graph.get_growth_stats() if road_graph.has_method("get_growth_stats") else {}
	for center_variant in growth_stats.get("population_centers", []):
		var center: Dictionary = center_variant
		var position: Vector2 = center.get("position", Vector2.ZERO)
		var radius_m := maxf(float(center.get("radius_m", 0.0)), 1200.0)
		has_bounds = true
		min_x = minf(min_x, position.x - radius_m)
		min_y = minf(min_y, position.y - radius_m)
		max_x = maxf(max_x, position.x + radius_m)
		max_y = maxf(max_y, position.y + radius_m)

	if not has_bounds:
		return config.get_world_bounds()

	var active_bounds := Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y)).grow(ACTIVE_BOUNDS_MARGIN_M)
	var world_bounds: Rect2 = config.get_world_bounds()
	var clipped := active_bounds.intersection(world_bounds)
	if clipped.has_area():
		return clipped
	return world_bounds

func _draw_roads(image: Image, edges: Array, active_bounds: Rect2) -> Dictionary:
	var road_pixels: Dictionary = {}
	var drawn_edge_count := 0
	for edge_variant in edges:
		var edge: Dictionary = edge_variant
		var points: Array = edge.get("points", [])
		if points.size() < 2:
			continue
		drawn_edge_count += 1
		var road_class := str(edge.get("class", "local"))
		var brush_radius := int(ROAD_BRUSH_RADIUS_BY_CLASS.get(road_class, 2))
		for point_index in range(points.size() - 1):
			var a: Vector2 = points[point_index]
			var b: Vector2 = points[point_index + 1]
			_paint_segment(
				image,
				road_pixels,
				_world_to_image(a, active_bounds, DEFAULT_IMAGE_SIZE),
				_world_to_image(b, active_bounds, DEFAULT_IMAGE_SIZE),
				brush_radius,
				ROAD_COLOR
			)
	return {
		"road_edge_count": drawn_edge_count,
		"road_pixel_count": road_pixels.size(),
	}

func _draw_buildings(image: Image, config, world_data: Dictionary, active_bounds: Rect2) -> Dictionary:
	var road_graph = world_data.get("road_graph")
	if road_graph == null:
		return {
			"building_pixel_count": 0,
			"building_footprint_count": 0,
			"building_chunk_count": 0,
		}

	var building_pixels: Dictionary = {}
	var building_footprint_count := 0
	var chunk_keys := _collect_building_chunk_keys(config, road_graph, active_bounds)
	for chunk_key_variant in chunk_keys:
		var chunk_key: Vector2i = chunk_key_variant
		var chunk_rect := _chunk_rect_from_key(config, chunk_key)
		if road_graph.get_edges_intersecting_rect(chunk_rect.grow(float(config.chunk_size_m) * 0.35)).is_empty():
			continue
		var chunk_center := _chunk_center_from_key(config, chunk_key)
		var chunk_payload := {
			"chunk_id": config.format_chunk_id(chunk_key),
			"chunk_key": chunk_key,
			"chunk_center": chunk_center,
			"chunk_size_m": float(config.chunk_size_m),
			"chunk_seed": config.derive_seed("render_chunk", chunk_key),
			"world_seed": config.base_seed,
			"road_graph": road_graph,
		}
		var profile: Dictionary = CityChunkProfileBuilder.build_profile(chunk_payload)
		for building_variant in profile.get("buildings", []):
			var building: Dictionary = building_variant
			var building_corners := _resolve_building_corners_world(building, chunk_center)
			if building_corners.size() < 3:
				continue
			_paint_polygon(image, building_pixels, building_corners, active_bounds, BUILDING_COLOR)
			building_footprint_count += 1

	return {
		"building_pixel_count": building_pixels.size(),
		"building_footprint_count": building_footprint_count,
		"building_chunk_count": chunk_keys.size(),
	}

func _collect_building_chunk_keys(config, road_graph, active_bounds: Rect2) -> Array:
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var chunk_key_map: Dictionary = {}
	for edge_variant in road_graph.edges:
		var edge: Dictionary = edge_variant
		var edge_bounds: Rect2 = edge.get("bounds", Rect2())
		if not edge_bounds.has_area():
			edge_bounds = _build_bounds_from_points(edge.get("points", []))
		if not edge_bounds.has_area() or not edge_bounds.intersects(active_bounds):
			continue
		var expanded := edge_bounds.grow(float(config.chunk_size_m) * 0.35)
		var min_key := _world_to_chunk_key(config, expanded.position)
		var max_key := _world_to_chunk_key(config, expanded.end - Vector2.ONE * 0.001)
		for chunk_x in range(maxi(min_key.x, 0), mini(max_key.x, chunk_grid.x - 1) + 1):
			for chunk_y in range(maxi(min_key.y, 0), mini(max_key.y, chunk_grid.y - 1) + 1):
				var chunk_key := Vector2i(chunk_x, chunk_y)
				chunk_key_map["%d:%d" % [chunk_x, chunk_y]] = chunk_key
	var chunk_keys: Array = []
	for chunk_key_variant in chunk_key_map.values():
		chunk_keys.append(chunk_key_variant)
	chunk_keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.x == b.x:
			return a.y < b.y
		return a.x < b.x
	)
	return chunk_keys

func _resolve_building_corners_world(building: Dictionary, chunk_center: Vector3) -> PackedVector2Array:
	var local_center: Vector3 = building.get("center", Vector3.ZERO)
	var footprint_size: Vector3 = building.get("collision_size", building.get("size", Vector3(12.0, 12.0, 12.0)))
	var yaw_rad := float(building.get("yaw_rad", 0.0))
	var cos_yaw := cos(yaw_rad)
	var sin_yaw := sin(yaw_rad)
	var half_footprint := Vector2(footprint_size.x * 0.5, footprint_size.z * 0.5)
	var world_center := Vector2(chunk_center.x + local_center.x, chunk_center.z + local_center.z)
	var corners := PackedVector2Array()
	for corner_variant in [
		Vector2(-half_footprint.x, -half_footprint.y),
		Vector2(half_footprint.x, -half_footprint.y),
		Vector2(half_footprint.x, half_footprint.y),
		Vector2(-half_footprint.x, half_footprint.y),
	]:
		var corner: Vector2 = corner_variant
		var rotated := Vector2(
			corner.x * cos_yaw - corner.y * sin_yaw,
			corner.x * sin_yaw + corner.y * cos_yaw
		)
		corners.append(world_center + rotated)
	return corners

func _paint_polygon(image: Image, pixel_map: Dictionary, polygon_world: PackedVector2Array, active_bounds: Rect2, color: Color) -> void:
	if polygon_world.size() < 3:
		return
	var polygon_px := PackedVector2Array()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point_world in polygon_world:
		var point_px := _world_to_image(point_world, active_bounds, DEFAULT_IMAGE_SIZE)
		polygon_px.append(point_px)
		min_x = minf(min_x, point_px.x)
		min_y = minf(min_y, point_px.y)
		max_x = maxf(max_x, point_px.x)
		max_y = maxf(max_y, point_px.y)
	var left := maxi(int(floor(min_x)), 0)
	var top := maxi(int(floor(min_y)), 0)
	var right := mini(int(ceil(max_x)), image.get_width() - 1)
	var bottom := mini(int(ceil(max_y)), image.get_height() - 1)
	for pixel_y in range(top, bottom + 1):
		for pixel_x in range(left, right + 1):
			if not Geometry2D.is_point_in_polygon(Vector2(float(pixel_x) + 0.5, float(pixel_y) + 0.5), polygon_px):
				continue
			var pixel_key := pixel_y * image.get_width() + pixel_x
			pixel_map[pixel_key] = true
			image.set_pixel(pixel_x, pixel_y, color)

func _paint_segment(image: Image, pixel_map: Dictionary, start_px: Vector2, end_px: Vector2, brush_radius: int, color: Color) -> void:
	var step_count := maxi(int(ceil(start_px.distance_to(end_px))), 1)
	for step_index in range(step_count + 1):
		var ratio := float(step_index) / float(step_count)
		_paint_disc(image, pixel_map, start_px.lerp(end_px, ratio), brush_radius, color)

func _paint_disc(image: Image, pixel_map: Dictionary, center_px: Vector2, radius_px: int, color: Color) -> void:
	var center_x := int(round(center_px.x))
	var center_y := int(round(center_px.y))
	var min_x := maxi(center_x - radius_px, 0)
	var min_y := maxi(center_y - radius_px, 0)
	var max_x := mini(center_x + radius_px, image.get_width() - 1)
	var max_y := mini(center_y + radius_px, image.get_height() - 1)
	var radius_squared := float(radius_px * radius_px) + 0.25
	for pixel_y in range(min_y, max_y + 1):
		for pixel_x in range(min_x, max_x + 1):
			var delta_x := float(pixel_x - center_x)
			var delta_y := float(pixel_y - center_y)
			if delta_x * delta_x + delta_y * delta_y > radius_squared:
				continue
			var pixel_key := pixel_y * image.get_width() + pixel_x
			pixel_map[pixel_key] = true
			image.set_pixel(pixel_x, pixel_y, color)

func _world_to_image(world_point: Vector2, active_bounds: Rect2, image_size: Vector2i) -> Vector2:
	var safe_width := maxf(active_bounds.size.x, 1.0)
	var safe_height := maxf(active_bounds.size.y, 1.0)
	var x_ratio := clampf((world_point.x - active_bounds.position.x) / safe_width, 0.0, 1.0)
	var y_ratio := clampf((world_point.y - active_bounds.position.y) / safe_height, 0.0, 1.0)
	return Vector2(
		x_ratio * float(image_size.x - 1),
		(1.0 - y_ratio) * float(image_size.y - 1)
	)

func _world_to_chunk_key(config, world_point: Vector2) -> Vector2i:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var chunk_size := float(config.chunk_size_m)
	return Vector2i(
		clampi(int(floor((world_point.x - bounds.position.x) / chunk_size)), 0, chunk_grid.x - 1),
		clampi(int(floor((world_point.y - bounds.position.y) / chunk_size)), 0, chunk_grid.y - 1)
	)

func _chunk_rect_from_key(config, chunk_key: Vector2i) -> Rect2:
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_size := float(config.chunk_size_m)
	return Rect2(
		Vector2(
			bounds.position.x + float(chunk_key.x) * chunk_size,
			bounds.position.y + float(chunk_key.y) * chunk_size
		),
		Vector2.ONE * chunk_size
	)

func _chunk_center_from_key(config, chunk_key: Vector2i) -> Vector3:
	var bounds: Rect2 = config.get_world_bounds()
	return Vector3(
		bounds.position.x + (float(chunk_key.x) + 0.5) * float(config.chunk_size_m),
		0.0,
		bounds.position.y + (float(chunk_key.y) + 0.5) * float(config.chunk_size_m)
	)

func _build_bounds_from_points(points: Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := INF
	var min_y := INF
	var max_x := -INF
	var max_y := -INF
	for point_variant in points:
		var point: Vector2 = point_variant
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _rect_to_dict(rect: Rect2) -> Dictionary:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
	}
