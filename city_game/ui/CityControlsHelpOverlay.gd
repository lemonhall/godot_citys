extends Control
class_name CityControlsHelpOverlay

var _state: Dictionary = {
	"visible": false,
	"title": "键位说明",
	"subtitle": "",
	"close_hint": "按 F1 关闭",
	"sections": [],
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_ensure_layout()
	_apply_state()

func set_state(state: Dictionary) -> void:
	_state = {
		"visible": bool(state.get("visible", false)),
		"title": str(state.get("title", "键位说明")),
		"subtitle": str(state.get("subtitle", "")),
		"close_hint": str(state.get("close_hint", "按 F1 关闭")),
		"sections": (state.get("sections", []) as Array).duplicate(true),
	}
	_ensure_layout()
	_apply_state()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _ensure_layout() -> void:
	if get_node_or_null("Backdrop") != null:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.offset_left = 0.0
	backdrop.offset_top = 0.0
	backdrop.offset_right = 0.0
	backdrop.offset_bottom = 0.0
	backdrop.color = Color(0.02, 0.04, 0.05, 0.9)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -560.0
	panel.offset_top = -320.0
	panel.offset_right = 560.0
	panel.offset_bottom = 320.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.05, 0.08, 0.1, 0.96)
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.32, 0.82, 0.76, 0.96)
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	stylebox.content_margin_left = 20.0
	stylebox.content_margin_top = 18.0
	stylebox.content_margin_right = 20.0
	stylebox.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", stylebox)

	var label := RichTextLabel.new()
	label.name = "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(label)
	add_child(panel)

func _apply_state() -> void:
	visible = bool(_state.get("visible", false))
	var panel := get_node_or_null("Panel") as PanelContainer
	var label := get_node_or_null("Panel/Label") as RichTextLabel
	if panel != null:
		panel.visible = visible
	if label != null:
		label.text = _build_text()

func _build_text() -> String:
	var lines := PackedStringArray()
	lines.append("[b][font_size=28]%s[/font_size][/b]" % str(_state.get("title", "键位说明")))
	var subtitle := str(_state.get("subtitle", ""))
	if subtitle != "":
		lines.append("[color=#B9D8D2]%s[/color]" % subtitle)
	lines.append("[color=#7FE6D4]%s[/color]" % str(_state.get("close_hint", "按 F1 关闭")))
	lines.append("")
	for section_variant in _state.get("sections", []):
		var section: Dictionary = section_variant as Dictionary
		lines.append("[color=#7FE6D4][b]%s[/b][/color]" % str(section.get("title", "")))
		for entry_variant in section.get("entries", []):
			var entry: Dictionary = entry_variant as Dictionary
			lines.append("[code]%s[/code]  %s" % [
				str(entry.get("binding", "")),
				str(entry.get("description", "")),
			])
		lines.append("")
	return "\n".join(lines)
