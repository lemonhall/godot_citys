extends PanelContainer

var _state := {
	"visible": false,
	"speaker_name": "",
	"body_text": "",
	"dialogue_id": "",
	"owner_actor_id": "",
	"close_hint_text": "按 E 关闭",
}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_top = 1.0
	anchor_right = 0.5
	anchor_bottom = 1.0
	offset_left = -280.0
	offset_top = -280.0
	offset_right = 280.0
	offset_bottom = -112.0
	_ensure_children()
	_apply_style()
	_apply_state()

func set_state(state: Dictionary) -> void:
	_state = {
		"visible": bool(state.get("visible", false)),
		"speaker_name": str(state.get("speaker_name", "")),
		"body_text": str(state.get("body_text", "")),
		"dialogue_id": str(state.get("dialogue_id", "")),
		"owner_actor_id": str(state.get("owner_actor_id", "")),
		"close_hint_text": str(state.get("close_hint_text", "按 E 关闭")),
	}
	_apply_state()

func get_state() -> Dictionary:
	return _state.duplicate(true)

func _ensure_children() -> void:
	if get_node_or_null("VBox") != null:
		return
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 0.0
	vbox.offset_top = 0.0
	vbox.offset_right = 0.0
	vbox.offset_bottom = 0.0
	add_child(vbox)

	var speaker_label := Label.new()
	speaker_label.name = "Speaker"
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	speaker_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.8, 1.0))
	vbox.add_child(speaker_label)

	var body_label := Label.new()
	body_label.name = "Body"
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	vbox.add_child(body_label)

	var hint_label := Label.new()
	hint_label.name = "Hint"
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_color_override("font_color", Color(0.72, 0.94, 0.78, 1.0))
	vbox.add_child(hint_label)

func _apply_style() -> void:
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.04, 0.06, 0.08, 0.88)
	stylebox.border_color = Color(0.2, 0.7, 0.45, 0.95)
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.corner_radius_top_left = 10
	stylebox.corner_radius_top_right = 10
	stylebox.corner_radius_bottom_left = 10
	stylebox.corner_radius_bottom_right = 10
	stylebox.content_margin_left = 16.0
	stylebox.content_margin_top = 14.0
	stylebox.content_margin_right = 16.0
	stylebox.content_margin_bottom = 14.0
	add_theme_stylebox_override("panel", stylebox)

func _apply_state() -> void:
	visible = bool(_state.get("visible", false))
	var speaker_label := get_node_or_null("VBox/Speaker") as Label
	if speaker_label != null:
		speaker_label.text = str(_state.get("speaker_name", ""))
	var body_label := get_node_or_null("VBox/Body") as Label
	if body_label != null:
		body_label.text = str(_state.get("body_text", ""))
	var hint_label := get_node_or_null("VBox/Hint") as Label
	if hint_label != null:
		hint_label.text = str(_state.get("close_hint_text", "按 E 关闭"))
