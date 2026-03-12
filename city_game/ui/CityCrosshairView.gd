extends Control

var _state: Dictionary = {
	"visible": false,
	"screen_position": Vector2.ZERO,
	"viewport_size": Vector2.ZERO,
	"world_target": Vector3.ZERO,
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	queue_redraw()

func set_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	queue_redraw()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _draw() -> void:
	if not bool(_state.get("visible", false)):
		return
	var center: Vector2 = _state.get("screen_position", size * 0.5)
	var outer_radius := 9.0
	var gap_radius := 3.0
	var color := Color(0.92, 0.97, 1.0, 0.95)
	var shadow := Color(0.02, 0.04, 0.05, 0.65)
	draw_arc(center, outer_radius + 1.0, 0.0, TAU, 32, shadow, 2.0, true)
	draw_arc(center, outer_radius, 0.0, TAU, 32, color, 1.6, true)
	draw_line(center + Vector2(-outer_radius, 0.0), center + Vector2(-gap_radius, 0.0), color, 1.8, true)
	draw_line(center + Vector2(outer_radius, 0.0), center + Vector2(gap_radius, 0.0), color, 1.8, true)
	draw_line(center + Vector2(0.0, -outer_radius), center + Vector2(0.0, -gap_radius), color, 1.8, true)
	draw_line(center + Vector2(0.0, outer_radius), center + Vector2(0.0, gap_radius), color, 1.8, true)
	draw_circle(center, 1.1, color)
