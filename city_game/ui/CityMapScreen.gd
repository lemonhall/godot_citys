extends Control

signal map_world_point_selected(world_position: Vector3)
signal task_selected(task_id: String)

const DRAG_START_THRESHOLD_PX := 6.0
const ZOOM_STEP_RATIO := 0.82
const MIN_VIEW_HALF_EXTENT_Y_M := 256.0
const TASK_PANEL_WIDTH_PX := 320.0
const TASK_PANEL_MARGIN_PX := 16.0
const PIN_ICON_FONT_NAMES := [
	"Segoe UI Emoji",
	"Segoe UI Symbol",
	"Noto Color Emoji",
	"Noto Emoji",
]
const PIN_ICON_GLYPHS := {
	"burger_shop": "🍔",
	"cafe": "☕",
	"clinic": "⚕",
	"fishing": "🎣",
	"football": "⚽",
	"garage": "🔧",
	"fountain": "⛲",
	"gun_shop": "🔫",
	"helicopter": "🚁",
	"music_road": "🎵",
	"missile_command": "🚀",
	"radio_tower": "📡",
	"shop": "🛍",
	"restaurant": "🍽",
	"tennis": "🎾",
}
const CityTaskBriefPanelScene := preload("res://city_game/ui/CityTaskBriefPanel.tscn")

var _world_bounds := Rect2()
var _pins: Array[Dictionary] = []
var _route_result: Dictionary = {}
var _last_selection_contract: Dictionary = {}
var _player_marker: Dictionary = {}
var _map_open := false
var _world_paused := false
var _task_panel_state: Dictionary = {}
var _road_graph = null
var _task_brief_panel: Control = null
var _road_polylines: Array[Dictionary] = []
var _road_cache_size := Vector2.ZERO
var _road_cache_view_rect := Rect2()
var _road_cache_dirty := true
var _view_center_world := Vector2.ZERO
var _view_half_extent_y_m := 0.0
var _default_view_half_extent_y_m := 0.0
var _drag_candidate_active := false
var _drag_active := false
var _drag_anchor_map_position := Vector2.ZERO
var _drag_anchor_center_world := Vector2.ZERO
var _pin_icon_font: Font = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_task_panel()
	_pin_icon_font = _build_pin_icon_font()
	visible = false

func setup(world_bounds: Rect2) -> void:
	_world_bounds = world_bounds
	_reset_view_state()
	queue_redraw()

func set_map_open(is_open: bool) -> void:
	_map_open = is_open
	visible = is_open
	if _task_brief_panel != null:
		_task_brief_panel.visible = is_open
	if is_open:
		_ensure_road_cache()
	queue_redraw()

func is_map_open() -> bool:
	return _map_open

func set_world_paused(paused: bool) -> void:
	_world_paused = paused
	queue_redraw()

func set_road_graph(road_graph) -> void:
	_road_graph = road_graph
	_invalidate_road_cache()
	queue_redraw()

func set_pins(pins: Array) -> void:
	_pins.clear()
	for pin_variant in pins:
		_pins.append((pin_variant as Dictionary).duplicate(true))
	_pins.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_priority := int(a.get("priority", 0))
		var b_priority := int(b.get("priority", 0))
		if a_priority == b_priority:
			return str(a.get("pin_id", "")) < str(b.get("pin_id", ""))
		return a_priority < b_priority
	)
	queue_redraw()

func set_route_result(route_result: Dictionary) -> void:
	_route_result = route_result.duplicate(true)
	queue_redraw()

func set_last_selection_contract(selection_contract: Dictionary) -> void:
	_last_selection_contract = selection_contract.duplicate(true)
	queue_redraw()

func set_player_marker(player_marker: Dictionary) -> void:
	_player_marker = player_marker.duplicate(true)
	queue_redraw()

func set_task_panel_state(task_panel_state: Dictionary) -> void:
	_task_panel_state = task_panel_state.duplicate(true)
	if _task_brief_panel != null and _task_brief_panel.has_method("set_panel_state"):
		_task_brief_panel.set_panel_state(_task_panel_state)
	queue_redraw()

func select_task(task_id: String) -> void:
	if _task_brief_panel != null and _task_brief_panel.has_method("select_task"):
		_task_brief_panel.select_task(task_id)
		return
	task_selected.emit(task_id)

func select_world_point(world_position: Vector3) -> void:
	map_world_point_selected.emit(world_position)

func world_to_map(world_position: Vector3) -> Vector2:
	var view_rect := _get_view_rect_world()
	var map_rect := _get_map_canvas_rect()
	if view_rect.size.x <= 0.001 or view_rect.size.y <= 0.001 or map_rect.size.x <= 0.001 or map_rect.size.y <= 0.001:
		return Vector2.ZERO
	var normalized := Vector2(
		(world_position.x - view_rect.position.x) / view_rect.size.x,
		(world_position.z - view_rect.position.y) / view_rect.size.y
	)
	return map_rect.position + Vector2(normalized.x * map_rect.size.x, normalized.y * map_rect.size.y)

func map_to_world(map_position: Vector2) -> Vector3:
	var view_rect := _get_view_rect_world()
	var map_rect := _get_map_canvas_rect()
	if map_rect.size.x <= 0.001 or map_rect.size.y <= 0.001 or view_rect.size.x <= 0.001 or view_rect.size.y <= 0.001:
		return Vector3.ZERO
	var local_position := map_position - map_rect.position
	var normalized := Vector2(
		clampf(local_position.x / map_rect.size.x, 0.0, 1.0),
		clampf(local_position.y / map_rect.size.y, 0.0, 1.0)
	)
	return Vector3(
		view_rect.position.x + view_rect.size.x * normalized.x,
		0.0,
		view_rect.position.y + view_rect.size.y * normalized.y
	)

func get_render_state() -> Dictionary:
	_ensure_road_cache()
	var view_half_extents := _get_view_half_extents_world()
	var pin_types: Array[String] = []
	var pin_type_seen: Dictionary = {}
	for pin_variant in _pins:
		var pin: Dictionary = pin_variant
		var pin_type := str(pin.get("pin_type", ""))
		if pin_type == "" or pin_type_seen.has(pin_type):
			continue
		pin_type_seen[pin_type] = true
		pin_types.append(pin_type)
	var player_marker := _build_player_marker_render_state()
	return {
		"visible": visible,
		"map_open": _map_open,
		"world_paused": _world_paused,
		"size": size,
		"world_bounds": _world_bounds,
		"view_center_world": _view_center_world,
		"view_half_extent_x_m": view_half_extents.x,
		"view_half_extent_y_m": view_half_extents.y,
		"map_canvas_rect": _get_map_canvas_rect(),
		"road_polyline_count": _road_polylines.size(),
		"pin_count": _pins.size(),
		"pin_types": pin_types,
		"pin_markers": _build_pin_markers_render_state(),
		"route_point_count": (_route_result.get("polyline", []) as Array).size(),
		"route_style_id": str(_route_result.get("route_style_id", "destination")),
		"last_selection_contract": _last_selection_contract.duplicate(true),
		"player_marker": player_marker,
		"task_panel": _task_panel_state.duplicate(true),
	}

func _gui_input(event: InputEvent) -> void:
	if not _map_open:
		return
	var map_rect := _get_map_canvas_rect()
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if not map_rect.has_point(button.position):
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_apply_zoom_at(button.position, ZOOM_STEP_RATIO)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_apply_zoom_at(button.position, 1.0 / ZOOM_STEP_RATIO)
			accept_event()
			return
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_drag_candidate_active = true
				_drag_active = false
				_drag_anchor_map_position = button.position
				_drag_anchor_center_world = _view_center_world
			elif _drag_candidate_active or _drag_active:
				if not _drag_active:
					select_world_point(map_to_world(button.position))
				_drag_candidate_active = false
				_drag_active = false
			accept_event()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if not map_rect.has_point(motion.position) and not _drag_active:
			return
		if _drag_candidate_active or _drag_active:
			var drag_delta := motion.position - _drag_anchor_map_position
			if not _drag_active and drag_delta.length() >= DRAG_START_THRESHOLD_PX:
				_drag_active = true
			if _drag_active:
				var view_half_extents := _get_view_half_extents_world()
				if size.x > 0.001 and size.y > 0.001:
					var world_delta := Vector2(
						drag_delta.x * (view_half_extents.x * 2.0 / size.x),
						drag_delta.y * (view_half_extents.y * 2.0 / size.y)
					)
					_view_center_world = _clamp_view_center_world(_drag_anchor_center_world - world_delta)
					_invalidate_road_cache()
					queue_redraw()
			accept_event()

func _draw() -> void:
	if not _map_open:
		return
	_ensure_road_cache()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.1, 0.94), true)
	var map_rect := _get_map_canvas_rect()
	draw_rect(map_rect, Color(0.09, 0.12, 0.16, 0.96), true)
	draw_rect(map_rect, Color(0.84, 0.88, 0.91, 0.22), false, 2.0)
	_draw_road_network()
	_draw_route()
	_draw_pins()
	_draw_selection_marker()
	_draw_player_marker()
	draw_line(Vector2(map_rect.end.x + TASK_PANEL_MARGIN_PX * 0.5, 0.0), Vector2(map_rect.end.x + TASK_PANEL_MARGIN_PX * 0.5, size.y), Color(0.84, 0.88, 0.91, 0.15), 1.0)

func _draw_road_network() -> void:
	for polyline_variant in _road_polylines:
		var road_polyline: Dictionary = polyline_variant
		var points: PackedVector2Array = road_polyline.get("points", PackedVector2Array())
		if points.size() < 2:
			continue
		var road_style := _resolve_road_style(str(road_polyline.get("road_class", "")))
		draw_polyline(points, road_style.get("color", Color(0.76, 0.8, 0.86, 0.45)), float(road_style.get("width", 1.0)), true)

func _draw_route() -> void:
	var route_points: PackedVector2Array = PackedVector2Array()
	for point_variant in _route_result.get("polyline", []):
		var point: Vector3 = point_variant
		route_points.append(world_to_map(point))
	if route_points.size() >= 2:
		var route_style := _resolve_route_style(str(_route_result.get("route_style_id", "destination")))
		draw_polyline(route_points, route_style.get("line", Color(1.0, 0.72, 0.18, 0.92)), 4.0, true)

func _draw_pins() -> void:
	for pin_variant in _pins:
		var pin: Dictionary = pin_variant
		var world_position: Vector3 = pin.get("world_position", Vector3.ZERO)
		var pin_position := world_to_map(world_position)
		var pin_color := _resolve_pin_color(str(pin.get("pin_type", "")))
		var icon_glyph := _resolve_pin_icon_glyph(str(pin.get("icon_id", "")))
		if icon_glyph == "":
			draw_circle(pin_position, 5.0, pin_color)
			continue
		draw_circle(pin_position, 10.0, Color(0.08, 0.1, 0.12, 0.96))
		draw_circle(pin_position, 8.4, pin_color)
		_draw_pin_icon_glyph(pin_position, icon_glyph)

func _draw_selection_marker() -> void:
	var selection_target: Dictionary = _last_selection_contract.get("resolved_target", {})
	if selection_target.is_empty():
		return
	var world_position: Vector3 = selection_target.get("world_anchor", Vector3.ZERO)
	var marker_position := world_to_map(world_position)
	draw_arc(marker_position, 12.0, 0.0, TAU, 24, Color(0.92, 0.98, 0.98, 0.95), 2.0)

func build_player_marker_polygon(marker_position: Vector2, heading_rad: float) -> PackedVector2Array:
	var forward := Vector2(sin(heading_rad), -cos(heading_rad))
	var right := Vector2(-forward.y, forward.x)
	return PackedVector2Array([
		marker_position + forward * 9.0,
		marker_position - forward * 6.0 + right * 5.0,
		marker_position - forward * 6.0 - right * 5.0,
	])

func _draw_player_marker() -> void:
	var player_marker := _build_player_marker_render_state()
	if player_marker.is_empty():
		return
	var marker_position: Vector2 = player_marker.get("position", Vector2.ZERO)
	var points := build_player_marker_polygon(marker_position, float(player_marker.get("heading_rad", 0.0)))
	draw_colored_polygon(points, Color(0.3, 0.88, 1.0, 1.0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_task_panel()
		_invalidate_road_cache()
		queue_redraw()

func _resolve_pin_color(pin_type: String) -> Color:
	match pin_type:
		"landmark":
			return Color(0.38, 0.82, 0.98, 1.0)
		"service_building":
			return Color(0.81, 0.53, 0.28, 1.0)
		"task_available":
			return Color(0.34, 0.92, 0.48, 1.0)
		"task_active":
			return Color(0.34, 0.58, 1.0, 1.0)
		"task_completed":
			return Color(0.78, 0.82, 0.86, 1.0)
		"task":
			return Color(0.96, 0.44, 0.3, 1.0)
		"debug":
			return Color(0.96, 0.82, 0.32, 1.0)
		"destination":
			return Color(0.48, 0.96, 0.54, 1.0)
	return Color(0.92, 0.92, 0.92, 1.0)

func _resolve_road_style(road_class: String) -> Dictionary:
	match road_class:
		"arterial", "secondary", "expressway_elevated":
			return {
				"width": 2.4,
				"color": Color(0.86, 0.9, 0.96, 0.78),
			}
		"collector":
			return {
				"width": 1.8,
				"color": Color(0.72, 0.78, 0.85, 0.62),
			}
		"service":
			return {
				"width": 1.2,
				"color": Color(0.54, 0.6, 0.68, 0.44),
			}
	return {
		"width": 1.4,
		"color": Color(0.62, 0.68, 0.76, 0.5),
	}

func _resolve_route_style(route_style_id: String) -> Dictionary:
	match route_style_id:
		"task_available":
			return {
				"line": Color(0.28, 0.9, 0.44, 0.92),
			}
		"task_active":
			return {
				"line": Color(0.3, 0.58, 1.0, 0.94),
			}
	return {
		"line": Color(1.0, 0.72, 0.18, 0.92),
	}

func _build_pin_markers_render_state() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for pin_variant in _pins:
		var pin: Dictionary = pin_variant
		var marker := pin.duplicate(true)
		marker["position"] = world_to_map(pin.get("world_position", Vector3.ZERO))
		marker["icon_glyph"] = _resolve_pin_icon_glyph(str(pin.get("icon_id", "")))
		markers.append(marker)
	return markers

func _resolve_pin_icon_glyph(icon_id: String) -> String:
	return str(PIN_ICON_GLYPHS.get(icon_id, ""))

func _build_pin_icon_font() -> Font:
	var system_font := SystemFont.new()
	system_font.font_names = PIN_ICON_FONT_NAMES
	system_font.allow_system_fallback = true
	return system_font

func _draw_pin_icon_glyph(pin_position: Vector2, icon_glyph: String) -> void:
	if _pin_icon_font == null or icon_glyph == "":
		return
	var font_size := 16
	var glyph_size := _pin_icon_font.get_string_size(icon_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := pin_position + Vector2(-glyph_size.x * 0.5, glyph_size.y * 0.38)
	draw_string(_pin_icon_font, baseline, icon_glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.13, 0.08, 0.03, 1.0))

func _ensure_road_cache() -> void:
	if not _map_open or not _road_cache_dirty:
		return
	var view_rect := _get_view_rect_world()
	if size.x <= 0.001 or size.y <= 0.001 or view_rect.size.x <= 0.001 or view_rect.size.y <= 0.001:
		return
	_road_polylines.clear()
	if _road_graph != null and _road_graph.has_method("get_edges_intersecting_rect"):
		for edge_variant in _road_graph.get_edges_intersecting_rect(view_rect):
			var edge: Dictionary = edge_variant
			var projected_points := PackedVector2Array()
			for point_variant in edge.get("points", []):
				var world_point: Vector2 = point_variant
				projected_points.append(world_to_map(Vector3(world_point.x, 0.0, world_point.y)))
			if projected_points.size() < 2:
				continue
			_road_polylines.append({
				"road_class": str(edge.get("class", "")),
				"points": projected_points,
				"edge_id": str(edge.get("edge_id", "")),
			})
	_road_polylines.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_order := _resolve_road_draw_order(str(a.get("road_class", "")))
		var b_order := _resolve_road_draw_order(str(b.get("road_class", "")))
		if a_order == b_order:
			return str(a.get("edge_id", "")) < str(b.get("edge_id", ""))
		return a_order < b_order
	)
	_road_cache_size = size
	_road_cache_view_rect = view_rect
	_road_cache_dirty = false

func _invalidate_road_cache() -> void:
	_road_cache_dirty = true

func _resolve_road_draw_order(road_class: String) -> int:
	match road_class:
		"service":
			return 0
		"local":
			return 1
		"collector":
			return 2
		"arterial", "secondary":
			return 3
		"expressway_elevated":
			return 4
	return 1

func _reset_view_state() -> void:
	if _world_bounds.size.x <= 0.001 or _world_bounds.size.y <= 0.001:
		_view_center_world = Vector2.ZERO
		_view_half_extent_y_m = 0.0
		_default_view_half_extent_y_m = 0.0
		return
	_view_center_world = _world_bounds.get_center()
	_default_view_half_extent_y_m = _world_bounds.size.y * 0.5
	_view_half_extent_y_m = _default_view_half_extent_y_m
	_invalidate_road_cache()

func _get_view_half_extents_world() -> Vector2:
	if _world_bounds.size.x <= 0.001 or _world_bounds.size.y <= 0.001:
		return Vector2.ZERO
	var aspect_ratio := 1.0
	var map_rect := _get_map_canvas_rect()
	if map_rect.size.y > 0.001:
		aspect_ratio = maxf(map_rect.size.x / map_rect.size.y, 1.0)
	return Vector2(_view_half_extent_y_m * aspect_ratio, _view_half_extent_y_m)

func _get_view_rect_world() -> Rect2:
	var half_extents := _get_view_half_extents_world()
	return Rect2(_view_center_world - half_extents, half_extents * 2.0)

func _clamp_view_center_world(center_world: Vector2) -> Vector2:
	if _world_bounds.size.x <= 0.001 or _world_bounds.size.y <= 0.001:
		return center_world
	var half_extents := _get_view_half_extents_world()
	var clamped := center_world
	var world_center := _world_bounds.get_center()
	var x_margin := minf(half_extents.x, _world_bounds.size.x * 0.5)
	var y_margin := minf(half_extents.y, _world_bounds.size.y * 0.5)
	var min_x := _world_bounds.position.x + x_margin
	var max_x := _world_bounds.end.x - x_margin
	var min_y := _world_bounds.position.y + y_margin
	var max_y := _world_bounds.end.y - y_margin
	clamped.x = world_center.x if min_x > max_x else clampf(clamped.x, min_x, max_x)
	clamped.y = world_center.y if min_y > max_y else clampf(clamped.y, min_y, max_y)
	return clamped

func _apply_zoom_at(map_position: Vector2, zoom_ratio: float) -> void:
	if size.x <= 0.001 or size.y <= 0.001 or _world_bounds.size.x <= 0.001 or _world_bounds.size.y <= 0.001:
		return
	var world_before := map_to_world(map_position)
	var minimum_half_extent := minf(MIN_VIEW_HALF_EXTENT_Y_M, _default_view_half_extent_y_m)
	_view_half_extent_y_m = clampf(_view_half_extent_y_m * zoom_ratio, minimum_half_extent, _default_view_half_extent_y_m)
	var world_after := map_to_world(map_position)
	var world_delta := Vector2(world_before.x - world_after.x, world_before.z - world_after.z)
	_view_center_world = _clamp_view_center_world(_view_center_world + world_delta)
	_invalidate_road_cache()
	queue_redraw()

func _build_player_marker_render_state() -> Dictionary:
	if _player_marker.is_empty():
		return {}
	var world_position: Vector3 = _player_marker.get("world_position", Vector3.ZERO)
	var render_state := _player_marker.duplicate(true)
	render_state["position"] = world_to_map(world_position)
	return render_state

func _ensure_task_panel() -> void:
	if _task_brief_panel != null:
		return
	var task_panel := CityTaskBriefPanelScene.instantiate() as Control
	if task_panel == null:
		return
	task_panel.name = "TaskBriefPanel"
	add_child(task_panel)
	_task_brief_panel = task_panel
	if _task_brief_panel.has_signal("task_selected") and not _task_brief_panel.is_connected("task_selected", Callable(self, "_on_task_panel_selected")):
		_task_brief_panel.connect("task_selected", Callable(self, "_on_task_panel_selected"))
	_layout_task_panel()
	if _task_brief_panel.has_method("set_panel_state"):
		_task_brief_panel.set_panel_state(_task_panel_state)
	_task_brief_panel.visible = _map_open

func _layout_task_panel() -> void:
	if _task_brief_panel == null:
		return
	_task_brief_panel.anchor_left = 1.0
	_task_brief_panel.anchor_right = 1.0
	_task_brief_panel.anchor_top = 0.0
	_task_brief_panel.anchor_bottom = 1.0
	_task_brief_panel.offset_left = -TASK_PANEL_WIDTH_PX
	_task_brief_panel.offset_right = 0.0
	_task_brief_panel.offset_top = TASK_PANEL_MARGIN_PX
	_task_brief_panel.offset_bottom = -TASK_PANEL_MARGIN_PX

func _get_map_canvas_rect() -> Rect2:
	var panel_width := minf(TASK_PANEL_WIDTH_PX + TASK_PANEL_MARGIN_PX, maxf(size.x * 0.42, 0.0))
	var map_width := maxf(size.x - panel_width, 220.0)
	return Rect2(Vector2.ZERO, Vector2(map_width, size.y))

func _on_task_panel_selected(task_id: String) -> void:
	task_selected.emit(task_id)
