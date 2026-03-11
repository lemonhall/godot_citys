extends Control

var _snapshot: Dictionary = {}

func set_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
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

	var player_marker: Dictionary = _snapshot.get("player_marker", {})
	var player_position: Vector2 = player_marker.get("position", Vector2(map_size * 0.5, map_size * 0.5))
	_draw_player_marker(player_position, float(player_marker.get("heading_rad", 0.0)))

func _draw_marker(position: Vector2, color: Color, radius: float) -> void:
	draw_circle(position, radius, color)

func _draw_player_marker(position: Vector2, heading_rad: float) -> void:
	var forward := Vector2(sin(heading_rad), cos(heading_rad))
	var right := Vector2(forward.y, -forward.x)
	var points := PackedVector2Array([
		position + forward * 9.0,
		position - forward * 6.0 + right * 5.0,
		position - forward * 6.0 - right * 5.0,
	])
	draw_colored_polygon(points, Color(0.3, 0.88, 1.0, 1.0))
