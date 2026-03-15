extends Control

var _snapshot: Dictionary = {}

func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(false)
	queue_redraw()

func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func _draw() -> void:
	var map_size := float(_snapshot.get("map_size_px", size.x))
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_size, map_size)), Color(0.05, 0.07, 0.09, 0.86), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(map_size, map_size)), Color(0.68, 0.73, 0.78, 0.35), false, 2.0)

	for polyline in _snapshot.get("road_polylines", []):
		var points: PackedVector2Array = polyline
		if points.size() >= 2:
			draw_polyline(points, Color(0.78, 0.82, 0.88, 0.8), 2.0, true)

	var route_overlay: Dictionary = _snapshot.get("route_overlay", {})
	if not route_overlay.is_empty():
		var route_points: PackedVector2Array = route_overlay.get("polyline", PackedVector2Array())
		if route_points.size() >= 2:
			draw_polyline(route_points, Color(1.0, 0.72, 0.18, 0.95), 3.0, true)
		_draw_marker(route_overlay.get("start_marker", {}).get("position", Vector2.ZERO), Color(0.25, 0.9, 0.4, 1.0), 4.0)
		_draw_marker(route_overlay.get("goal_marker", {}).get("position", Vector2.ZERO), Color(1.0, 0.35, 0.35, 1.0), 4.0)

	var crowd_debug_layer: Dictionary = _snapshot.get("crowd_debug_layer", {})
	if bool(crowd_debug_layer.get("visible", false)):
		_draw_crowd_debug_layer(crowd_debug_layer)

	var pin_overlay: Dictionary = _snapshot.get("pin_overlay", {})
	if not pin_overlay.is_empty():
		_draw_pin_overlay(pin_overlay)

	var player_marker: Dictionary = _snapshot.get("player_marker", {})
	var player_position: Vector2 = player_marker.get("position", Vector2(map_size * 0.5, map_size * 0.5))
	_draw_player_marker(player_position, float(player_marker.get("heading_rad", 0.0)))

func build_player_marker_polygon(marker_position: Vector2, heading_rad: float) -> PackedVector2Array:
	var forward := Vector2(sin(heading_rad), -cos(heading_rad))
	var right := Vector2(-forward.y, forward.x)
	return PackedVector2Array([
		marker_position + forward * 9.0,
		marker_position - forward * 6.0 + right * 5.0,
		marker_position - forward * 6.0 - right * 5.0,
	])

func _draw_marker(marker_position: Vector2, color: Color, radius: float) -> void:
	draw_circle(marker_position, radius, color)

func _draw_player_marker(marker_position: Vector2, heading_rad: float) -> void:
	var points := build_player_marker_polygon(marker_position, heading_rad)
	draw_colored_polygon(points, Color(0.3, 0.88, 1.0, 1.0))

func _draw_pin_overlay(pin_overlay: Dictionary) -> void:
	for marker_variant in pin_overlay.get("markers", []):
		var marker: Dictionary = marker_variant
		_draw_marker(marker.get("position", Vector2.ZERO), _resolve_pin_color(str(marker.get("pin_type", ""))), 3.2)

func _draw_crowd_debug_layer(layer: Dictionary) -> void:
	for polyline_variant in layer.get("sidewalk_polylines", []):
		var sidewalk_points: PackedVector2Array = polyline_variant
		if sidewalk_points.size() >= 2:
			draw_polyline(sidewalk_points, Color(0.36, 0.95, 0.88, 0.8), 1.5, true)
	for polyline_variant in layer.get("crossing_polylines", []):
		var crossing_points: PackedVector2Array = polyline_variant
		if crossing_points.size() >= 2:
			draw_polyline(crossing_points, Color(1.0, 0.7, 0.28, 0.85), 2.0, true)
	for marker_variant in layer.get("spawn_markers", []):
		var marker: Dictionary = marker_variant
		_draw_marker(marker.get("position", Vector2.ZERO), Color(1.0, 0.48, 0.48, 0.92), 2.4)

func _resolve_pin_color(pin_type: String) -> Color:
	match pin_type:
		"landmark":
			return Color(0.38, 0.82, 0.98, 1.0)
		"task":
			return Color(0.96, 0.44, 0.3, 1.0)
		"destination":
			return Color(0.48, 0.96, 0.54, 1.0)
	return Color(0.92, 0.92, 0.92, 1.0)
