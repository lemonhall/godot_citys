extends Control

signal map_world_point_selected(world_position: Vector3)

var _world_bounds := Rect2()
var _pins: Array[Dictionary] = []
var _route_result: Dictionary = {}
var _last_selection_contract: Dictionary = {}
var _map_open := false
var _world_paused := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

func setup(world_bounds: Rect2) -> void:
	_world_bounds = world_bounds
	queue_redraw()

func set_map_open(is_open: bool) -> void:
	_map_open = is_open
	visible = is_open
	queue_redraw()

func is_map_open() -> bool:
	return _map_open

func set_world_paused(paused: bool) -> void:
	_world_paused = paused
	queue_redraw()

func set_pins(pins: Array) -> void:
	_pins.clear()
	for pin_variant in pins:
		_pins.append((pin_variant as Dictionary).duplicate(true))
	queue_redraw()

func set_route_result(route_result: Dictionary) -> void:
	_route_result = route_result.duplicate(true)
	queue_redraw()

func set_last_selection_contract(selection_contract: Dictionary) -> void:
	_last_selection_contract = selection_contract.duplicate(true)
	queue_redraw()

func select_world_point(world_position: Vector3) -> void:
	map_world_point_selected.emit(world_position)

func world_to_map(world_position: Vector3) -> Vector2:
	if _world_bounds.size.x <= 0.001 or _world_bounds.size.y <= 0.001:
		return Vector2.ZERO
	var normalized := Vector2(
		clampf((world_position.x - _world_bounds.position.x) / _world_bounds.size.x, 0.0, 1.0),
		clampf((world_position.z - _world_bounds.position.y) / _world_bounds.size.y, 0.0, 1.0)
	)
	return Vector2(normalized.x * size.x, normalized.y * size.y)

func map_to_world(map_position: Vector2) -> Vector3:
	if size.x <= 0.001 or size.y <= 0.001:
		return Vector3.ZERO
	var normalized := Vector2(
		clampf(map_position.x / size.x, 0.0, 1.0),
		clampf(map_position.y / size.y, 0.0, 1.0)
	)
	return Vector3(
		_world_bounds.position.x + _world_bounds.size.x * normalized.x,
		0.0,
		_world_bounds.position.y + _world_bounds.size.y * normalized.y
	)

func get_render_state() -> Dictionary:
	var pin_types: Array[String] = []
	var pin_type_seen: Dictionary = {}
	for pin_variant in _pins:
		var pin: Dictionary = pin_variant
		var pin_type := str(pin.get("pin_type", ""))
		if pin_type == "" or pin_type_seen.has(pin_type):
			continue
		pin_type_seen[pin_type] = true
		pin_types.append(pin_type)
	return {
		"visible": visible,
		"map_open": _map_open,
		"world_paused": _world_paused,
		"world_bounds": _world_bounds,
		"pin_count": _pins.size(),
		"pin_types": pin_types,
		"route_point_count": (_route_result.get("polyline", []) as Array).size(),
		"last_selection_contract": _last_selection_contract.duplicate(true),
	}

func _gui_input(event: InputEvent) -> void:
	if not _map_open:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			select_world_point(map_to_world(button.position))
			accept_event()

func _draw() -> void:
	if not _map_open:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.08, 0.1, 0.94), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.84, 0.88, 0.91, 0.22), false, 2.0)
	_draw_route()
	_draw_pins()
	_draw_selection_marker()

func _draw_route() -> void:
	var route_points: PackedVector2Array = PackedVector2Array()
	for point_variant in _route_result.get("polyline", []):
		var point: Vector3 = point_variant
		route_points.append(world_to_map(point))
	if route_points.size() >= 2:
		draw_polyline(route_points, Color(1.0, 0.72, 0.18, 0.92), 4.0, true)

func _draw_pins() -> void:
	for pin_variant in _pins:
		var pin: Dictionary = pin_variant
		var world_position: Vector3 = pin.get("world_position", Vector3.ZERO)
		var pin_position := world_to_map(world_position)
		var pin_color := _resolve_pin_color(str(pin.get("pin_type", "")))
		draw_circle(pin_position, 5.0, pin_color)

func _draw_selection_marker() -> void:
	var selection_target: Dictionary = _last_selection_contract.get("resolved_target", {})
	if selection_target.is_empty():
		return
	var world_position: Vector3 = selection_target.get("world_anchor", Vector3.ZERO)
	var marker_position := world_to_map(world_position)
	draw_arc(marker_position, 12.0, 0.0, TAU, 24, Color(0.92, 0.98, 0.98, 0.95), 2.0)

func _resolve_pin_color(pin_type: String) -> Color:
	match pin_type:
		"landmark":
			return Color(0.38, 0.82, 0.98, 1.0)
		"task":
			return Color(0.96, 0.44, 0.3, 1.0)
		"debug":
			return Color(0.96, 0.82, 0.32, 1.0)
		"destination":
			return Color(0.48, 0.96, 0.54, 1.0)
	return Color(0.92, 0.92, 0.92, 1.0)
