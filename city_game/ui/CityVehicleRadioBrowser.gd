extends Control
class_name CityVehicleRadioBrowser

var _state := {
	"visible": false,
	"selected_tab_id": "browse",
	"tabs": [],
	"current_playing": {},
	"presets": [],
	"favorites": [],
	"recents": [],
	"browse": {
		"root_kind": "countries",
		"countries": [],
		"stations": [],
	},
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ensure_layout()
	_apply_state()

func set_state(state: Dictionary) -> void:
	_state = {
		"visible": bool(state.get("visible", false)),
		"selected_tab_id": str(state.get("selected_tab_id", "browse")),
		"tabs": (state.get("tabs", []) as Array).duplicate(true),
		"current_playing": (state.get("current_playing", {}) as Dictionary).duplicate(true),
		"presets": (state.get("presets", []) as Array).duplicate(true),
		"favorites": (state.get("favorites", []) as Array).duplicate(true),
		"recents": (state.get("recents", []) as Array).duplicate(true),
		"browse": (state.get("browse", {}) as Dictionary).duplicate(true),
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
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -420.0
	panel.offset_top = -260.0
	panel.offset_right = 420.0
	panel.offset_bottom = 260.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.03, 0.05, 0.06, 0.94)
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.28, 0.74, 0.66, 0.95)
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	stylebox.content_margin_left = 18.0
	stylebox.content_margin_top = 16.0
	stylebox.content_margin_right = 18.0
	stylebox.content_margin_bottom = 16.0
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
		"[b]Vehicle Radio Browser[/b]",
		"Selected tab=%s" % str(_state.get("selected_tab_id", "browse")),
		"Tabs=%s" % _build_tab_summary(),
	])
	var browse_state: Dictionary = _state.get("browse", {}) as Dictionary
	lines.append("Browse root=%s  countries=%d  stations=%d" % [
		str(browse_state.get("root_kind", "countries")),
		int((browse_state.get("countries", []) as Array).size()),
		int((browse_state.get("stations", []) as Array).size()),
	])
	return "\n".join(lines)

func _build_tab_summary() -> String:
	var labels := PackedStringArray()
	for tab_variant in _state.get("tabs", []):
		var tab: Dictionary = tab_variant as Dictionary
		labels.append(str(tab.get("tab_id", "")))
	return ", ".join(labels)
