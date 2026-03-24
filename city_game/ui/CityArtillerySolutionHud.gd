extends Control

const CityCompassStripScript := preload("res://city_game/ui/CityCompassStrip.gd")
const CityWorldOrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")

const DEFAULT_TITLE := "射击诸元"
const DEFAULT_YAW_LABEL_TEXT := "方位"
const DEFAULT_PITCH_LABEL_TEXT := "高低"

const PITCH_HALF_SPAN_DEG := 18.0
const PITCH_MINOR_TICK_STEP_DEG := 2.0
const PITCH_MAJOR_TICK_STEP_DEG := 5.0
const PITCH_LABEL_STEP_DEG := 10.0

var _world_orientation = CityWorldOrientationScript.new()
var _state: Dictionary = _build_hidden_state()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_view()
	_apply_state()

func set_state(state: Dictionary) -> void:
	var resolved_pitch_min_deg := float(state.get("pitch_min_deg", 0.0))
	var resolved_pitch_max_deg := float(state.get("pitch_max_deg", 71.0))
	if resolved_pitch_max_deg < resolved_pitch_min_deg:
		var swap_value := resolved_pitch_min_deg
		resolved_pitch_min_deg = resolved_pitch_max_deg
		resolved_pitch_max_deg = swap_value
	_state = {
		"visible": bool(state.get("visible", false)),
		"title": str(state.get("title", DEFAULT_TITLE)),
		"yaw_label_text": str(state.get("yaw_label_text", DEFAULT_YAW_LABEL_TEXT)),
		"pitch_label_text": str(state.get("pitch_label_text", DEFAULT_PITCH_LABEL_TEXT)),
		"yaw_bearing_deg": float(state.get("yaw_bearing_deg", 0.0)),
		"pitch_deg": float(state.get("pitch_deg", 0.0)),
		"pitch_min_deg": resolved_pitch_min_deg,
		"pitch_max_deg": resolved_pitch_max_deg,
	}
	_apply_state()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _build_hidden_state() -> Dictionary:
	return {
		"visible": false,
		"title": DEFAULT_TITLE,
		"yaw_label_text": DEFAULT_YAW_LABEL_TEXT,
		"pitch_label_text": DEFAULT_PITCH_LABEL_TEXT,
		"yaw_bearing_deg": 0.0,
		"pitch_deg": 0.0,
		"pitch_min_deg": 0.0,
		"pitch_max_deg": 71.0,
	}

func _ensure_view() -> void:
	if get_node_or_null("Panel") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.03, 0.06, 0.05, 0.84)
	stylebox.corner_radius_top_left = 10
	stylebox.corner_radius_top_right = 10
	stylebox.corner_radius_bottom_left = 10
	stylebox.corner_radius_bottom_right = 10
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.72, 0.88, 0.82, 0.18)
	panel.add_theme_stylebox_override("panel", stylebox)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.97, 0.98, 0.94, 1.0))
	vbox.add_child(title)

	var yaw_label := Label.new()
	yaw_label.name = "YawLabel"
	yaw_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	yaw_label.add_theme_font_size_override("font_size", 12)
	yaw_label.add_theme_color_override("font_color", Color(0.74, 0.94, 0.84, 1.0))
	vbox.add_child(yaw_label)

	var yaw_strip := Control.new()
	yaw_strip.name = "YawStrip"
	yaw_strip.set_script(CityCompassStripScript)
	yaw_strip.custom_minimum_size = Vector2(0.0, 70.0)
	yaw_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(yaw_strip)

	var pitch_label := Label.new()
	pitch_label.name = "PitchLabel"
	pitch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pitch_label.add_theme_font_size_override("font_size", 12)
	pitch_label.add_theme_color_override("font_color", Color(0.74, 0.94, 0.84, 1.0))
	vbox.add_child(pitch_label)

	var pitch_strip := Control.new()
	pitch_strip.name = "PitchStrip"
	pitch_strip.set_script(CityCompassStripScript)
	pitch_strip.custom_minimum_size = Vector2(0.0, 70.0)
	pitch_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(pitch_strip)

func _apply_state() -> void:
	visible = bool(_state.get("visible", false))
	var title := get_node_or_null("Panel/Margin/VBox/Title") as Label
	if title != null:
		title.text = str(_state.get("title", DEFAULT_TITLE))
	var yaw_label := get_node_or_null("Panel/Margin/VBox/YawLabel") as Label
	if yaw_label != null:
		yaw_label.text = str(_state.get("yaw_label_text", DEFAULT_YAW_LABEL_TEXT))
	var pitch_label := get_node_or_null("Panel/Margin/VBox/PitchLabel") as Label
	if pitch_label != null:
		pitch_label.text = str(_state.get("pitch_label_text", DEFAULT_PITCH_LABEL_TEXT))
	var yaw_strip := get_node_or_null("Panel/Margin/VBox/YawStrip")
	if yaw_strip != null and yaw_strip.has_method("set_state"):
		yaw_strip.set_state(_build_yaw_strip_state())
	var pitch_strip := get_node_or_null("Panel/Margin/VBox/PitchStrip")
	if pitch_strip != null and pitch_strip.has_method("set_state"):
		pitch_strip.set_state(_build_pitch_strip_state())

func _build_yaw_strip_state() -> Dictionary:
	if _world_orientation == null:
		return {"visible": false}
	return _world_orientation.build_compass_state_from_bearing_deg(
		float(_state.get("yaw_bearing_deg", 0.0)),
		bool(_state.get("visible", false))
	)

func _build_pitch_strip_state() -> Dictionary:
	var resolved_visible := bool(_state.get("visible", false))
	var resolved_pitch_min_deg := float(_state.get("pitch_min_deg", 0.0))
	var resolved_pitch_max_deg := float(_state.get("pitch_max_deg", 71.0))
	var resolved_pitch_deg := clampf(float(_state.get("pitch_deg", 0.0)), resolved_pitch_min_deg, resolved_pitch_max_deg)
	var tick_entries: Array[Dictionary] = []
	var min_tick_index := int(floor((resolved_pitch_deg - PITCH_HALF_SPAN_DEG) / PITCH_MINOR_TICK_STEP_DEG))
	var max_tick_index := int(ceil((resolved_pitch_deg + PITCH_HALF_SPAN_DEG) / PITCH_MINOR_TICK_STEP_DEG))
	for tick_index in range(min_tick_index, max_tick_index + 1):
		var tick_value := float(tick_index) * PITCH_MINOR_TICK_STEP_DEG
		if tick_value < resolved_pitch_min_deg - 0.001 or tick_value > resolved_pitch_max_deg + 0.001:
			continue
		var delta_deg := tick_value - resolved_pitch_deg
		if absf(delta_deg) > PITCH_HALF_SPAN_DEG + 0.001:
			continue
		var rounded_tick := int(round(tick_value))
		var label := ""
		if rounded_tick == int(round(resolved_pitch_min_deg)) or rounded_tick == int(round(resolved_pitch_max_deg)) or rounded_tick % int(PITCH_LABEL_STEP_DEG) == 0:
			label = str(rounded_tick)
		tick_entries.append({
			"bearing_deg": float(rounded_tick),
			"offset_ratio": clampf(delta_deg / maxf(PITCH_HALF_SPAN_DEG, 0.001), -1.0, 1.0),
			"is_major": rounded_tick % int(PITCH_MAJOR_TICK_STEP_DEG) == 0 or label != "",
			"is_cardinal": label != "",
			"label": label,
		})
	return {
		"visible": resolved_visible,
		"bearing_deg": resolved_pitch_deg,
		"bearing_text": "%.1f°" % resolved_pitch_deg,
		"cardinal_text": "%.0f-%.0f°" % [resolved_pitch_min_deg, resolved_pitch_max_deg],
		"tick_entries": tick_entries,
	}
