extends Control
class_name CityVehicleRadioQuickOverlay

var _state := {
	"visible": false,
	"slots": [],
	"selected_slot_index": -1,
	"power_action_available": false,
	"browser_action_available": false,
	"power_state": "off",
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_layout()
	_apply_state()

func set_state(state: Dictionary) -> void:
	_state = {
		"visible": bool(state.get("visible", false)),
		"slots": (state.get("slots", []) as Array).duplicate(true),
		"selected_slot_index": int(state.get("selected_slot_index", -1)),
		"power_action_available": bool(state.get("power_action_available", false)),
		"browser_action_available": bool(state.get("browser_action_available", false)),
		"power_state": str(state.get("power_state", "off")),
	}
	_ensure_layout()
	_apply_state()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _ensure_layout() -> void:
	if get_node_or_null("Panel") != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -360.0
	panel.offset_top = -188.0
	panel.offset_right = 360.0
	panel.offset_bottom = -84.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.04, 0.07, 0.06, 0.9)
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.36, 0.7, 0.56, 0.95)
	stylebox.corner_radius_top_left = 10
	stylebox.corner_radius_top_right = 10
	stylebox.corner_radius_bottom_left = 10
	stylebox.corner_radius_bottom_right = 10
	stylebox.content_margin_left = 16.0
	stylebox.content_margin_top = 12.0
	stylebox.content_margin_right = 16.0
	stylebox.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", stylebox)
	var label := RichTextLabel.new()
	label.name = "Label"
	label.fit_content = true
	label.bbcode_enabled = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	add_child(panel)

func _apply_state() -> void:
	var panel := get_node_or_null("Panel") as PanelContainer
	var label := get_node_or_null("Panel/Label") as RichTextLabel
	if panel != null:
		panel.visible = bool(_state.get("visible", false))
	if label == null:
		return
	label.text = _build_text()

func _build_text() -> String:
	var lines := PackedStringArray([
		"[b]Vehicle Radio[/b]  power=%s" % str(_state.get("power_state", "off")),
		"Power action=%s  Browser action=%s" % [
			str(bool(_state.get("power_action_available", false))),
			str(bool(_state.get("browser_action_available", false))),
		],
	])
	var slots: Array = _state.get("slots", []) as Array
	var selected_slot_index := int(_state.get("selected_slot_index", -1))
	for slot_index in range(slots.size()):
		var slot: Dictionary = slots[slot_index] as Dictionary
		var marker := ">" if slot_index == selected_slot_index else " "
		lines.append("%s [%d] %s" % [marker, slot_index + 1, str(slot.get("station_name", ""))])
	return "\n".join(lines)
