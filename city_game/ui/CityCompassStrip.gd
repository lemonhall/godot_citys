extends Control

var _state: Dictionary = {
	"visible": false,
	"bearing_deg": 0.0,
	"bearing_text": "000°",
	"cardinal_text": "N",
	"tick_entries": [],
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	visible = bool(_state.get("visible", false))
	queue_redraw()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _draw() -> void:
	if not bool(_state.get("visible", false)):
		return
	if size.x <= 0.001 or size.y <= 0.001:
		return
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.03, 0.06, 0.05, 0.78), true)
	draw_rect(rect, Color(0.72, 0.88, 0.82, 0.18), false, 1.0)
	_draw_ticks(rect)
	_draw_center_indicator(rect)
	_draw_center_labels(rect)

func _draw_ticks(rect: Rect2) -> void:
	var font := _resolve_font()
	var label_font_size: int = maxi(_resolve_font_size(13) - 1, 11)
	for tick_variant in _state.get("tick_entries", []):
		var tick: Dictionary = tick_variant
		var offset_ratio := clampf(float(tick.get("offset_ratio", 0.0)), -1.0, 1.0)
		var x := rect.size.x * 0.5 + offset_ratio * rect.size.x * 0.46
		var tick_top := rect.size.y * (0.52 if bool(tick.get("is_major", false)) else 0.62)
		var tick_bottom := rect.size.y * 0.86
		var tick_color := Color(0.84, 0.96, 0.9, 0.95) if bool(tick.get("is_cardinal", false)) else Color(0.72, 0.86, 0.8, 0.82)
		draw_line(Vector2(x, tick_top), Vector2(x, tick_bottom), tick_color, 1.6 if bool(tick.get("is_major", false)) else 1.0)
		var label := str(tick.get("label", ""))
		if label == "" or font == null:
			continue
		var label_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size)
		var label_position := Vector2(x - label_size.x * 0.5, rect.size.y * 0.48)
		draw_string(font, label_position, label, HORIZONTAL_ALIGNMENT_LEFT, -1, label_font_size, tick_color)

func _draw_center_indicator(rect: Rect2) -> void:
	var center_x := rect.size.x * 0.5
	var caret_top := rect.size.y * 0.12
	var caret_mid := rect.size.y * 0.34
	var caret_half_width := 7.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(center_x, caret_top),
		Vector2(center_x - caret_half_width, caret_mid),
		Vector2(center_x + caret_half_width, caret_mid),
	]), Color(1.0, 0.84, 0.34, 1.0))
	draw_line(Vector2(center_x, caret_mid), Vector2(center_x, rect.size.y * 0.92), Color(1.0, 0.84, 0.34, 0.72), 1.2)

func _draw_center_labels(rect: Rect2) -> void:
	var font := _resolve_font()
	if font == null:
		return
	var bearing_text := str(_state.get("bearing_text", "000°"))
	var cardinal_text := str(_state.get("cardinal_text", "N"))
	var bearing_font_size: int = maxi(_resolve_font_size(16), 16)
	var cardinal_font_size: int = maxi(_resolve_font_size(12), 12)
	var center_x := rect.size.x * 0.5
	var bearing_size := font.get_string_size(bearing_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bearing_font_size)
	var bearing_position := Vector2(center_x - bearing_size.x * 0.5, rect.size.y * 0.24)
	draw_string(font, bearing_position, bearing_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bearing_font_size, Color(0.97, 0.98, 0.94, 1.0))
	var cardinal_size := font.get_string_size(cardinal_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cardinal_font_size)
	var cardinal_position := Vector2(center_x - cardinal_size.x * 0.5, rect.size.y * 0.39)
	draw_string(font, cardinal_position, cardinal_text, HORIZONTAL_ALIGNMENT_LEFT, -1, cardinal_font_size, Color(0.74, 0.94, 0.84, 1.0))

func _resolve_font() -> Font:
	var font := get_theme_default_font()
	if font != null:
		return font
	return ThemeDB.fallback_font

func _resolve_font_size(default_size: int) -> int:
	var font_size := get_theme_default_font_size()
	if font_size > 0:
		return font_size
	if ThemeDB.fallback_font_size > 0:
		return ThemeDB.fallback_font_size
	return default_size
