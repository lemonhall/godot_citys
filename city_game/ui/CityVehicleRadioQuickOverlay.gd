extends Control
class_name CityVehicleRadioQuickOverlay

signal prev_requested
signal next_requested
signal confirm_requested
signal power_toggle_requested
signal browser_requested
signal close_requested
signal slot_pressed(slot_index: int)

var _state := {
	"visible": false,
	"slots": [],
	"selected_slot_index": -1,
	"power_action_available": false,
	"browser_action_available": false,
	"power_state": "off",
	"playback_state": "stopped",
	"current_station_name": "",
	"current_station_id": "",
	"selected_station_name": "",
	"selected_station_id": "",
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
		"playback_state": str(state.get("playback_state", "stopped")),
		"current_station_name": str(state.get("current_station_name", "")),
		"current_station_id": str(state.get("current_station_id", "")),
		"selected_station_name": str(state.get("selected_station_name", "")),
		"selected_station_id": str(state.get("selected_station_id", "")),
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
	panel.offset_left = -392.0
	panel.offset_top = -184.0
	panel.offset_right = 392.0
	panel.offset_bottom = 184.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.04, 0.05, 0.06, 0.94)
	stylebox.border_width_left = 2
	stylebox.border_width_top = 2
	stylebox.border_width_right = 2
	stylebox.border_width_bottom = 2
	stylebox.border_color = Color(0.23, 0.76, 0.68, 0.95)
	stylebox.corner_radius_top_left = 18
	stylebox.corner_radius_top_right = 18
	stylebox.corner_radius_bottom_left = 18
	stylebox.corner_radius_bottom_right = 18
	stylebox.content_margin_left = 18.0
	stylebox.content_margin_top = 16.0
	stylebox.content_margin_right = 18.0
	stylebox.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", stylebox)

	var chrome := VBoxContainer.new()
	chrome.name = "Chrome"
	chrome.set_anchors_preset(Control.PRESET_FULL_RECT)
	chrome.offset_left = 0.0
	chrome.offset_top = 0.0
	chrome.offset_right = 0.0
	chrome.offset_bottom = 0.0
	chrome.mouse_filter = Control.MOUSE_FILTER_STOP

	var header := HBoxContainer.new()
	header.name = "Header"
	var title := Label.new()
	title.name = "Title"
	title.text = "Vehicle Radio"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "[ / ] Preset   鼠标可点   Play 即播"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(title)
	header.add_child(hint)
	chrome.add_child(header)

	var display_frame := PanelContainer.new()
	display_frame.name = "DisplayFrame"
	var display_style := StyleBoxFlat.new()
	display_style.bg_color = Color(0.08, 0.12, 0.09, 0.95)
	display_style.border_width_left = 1
	display_style.border_width_top = 1
	display_style.border_width_right = 1
	display_style.border_width_bottom = 1
	display_style.border_color = Color(0.5, 0.88, 0.75, 0.78)
	display_style.corner_radius_top_left = 10
	display_style.corner_radius_top_right = 10
	display_style.corner_radius_bottom_left = 10
	display_style.corner_radius_bottom_right = 10
	display_style.content_margin_left = 12.0
	display_style.content_margin_top = 10.0
	display_style.content_margin_right = 12.0
	display_style.content_margin_bottom = 10.0
	display_frame.add_theme_stylebox_override("panel", display_style)
	var display_label := RichTextLabel.new()
	display_label.name = "DisplayLabel"
	display_label.bbcode_enabled = true
	display_label.fit_content = true
	display_label.scroll_active = false
	display_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	display_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display_frame.add_child(display_label)
	chrome.add_child(display_frame)

	var preset_grid := GridContainer.new()
	preset_grid.name = "PresetGrid"
	preset_grid.columns = 4
	preset_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chrome.add_child(preset_grid)
	for slot_index in range(8):
		var preset_button := Button.new()
		preset_button.name = "PresetButton%d" % slot_index
		preset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preset_button.custom_minimum_size = Vector2(0.0, 44.0)
		preset_button.pressed.connect(func() -> void:
			slot_pressed.emit(slot_index)
		)
		preset_grid.add_child(preset_button)

	var control_row := HBoxContainer.new()
	control_row.name = "ControlRow"
	var prev_button := Button.new()
	prev_button.name = "PrevButton"
	prev_button.text = "Prev ["
	prev_button.pressed.connect(func() -> void:
		prev_requested.emit()
	)
	var next_button := Button.new()
	next_button.name = "NextButton"
	next_button.text = "Next ]"
	next_button.pressed.connect(func() -> void:
		next_requested.emit()
	)
	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = "Play"
	confirm_button.pressed.connect(func() -> void:
		confirm_requested.emit()
	)
	var power_button := Button.new()
	power_button.name = "PowerButton"
	power_button.text = "Power"
	power_button.pressed.connect(func() -> void:
		power_toggle_requested.emit()
	)
	var browser_button := Button.new()
	browser_button.name = "BrowserButton"
	browser_button.text = "Browser"
	browser_button.pressed.connect(func() -> void:
		browser_requested.emit()
	)
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.pressed.connect(func() -> void:
		close_requested.emit()
	)
	for button in [prev_button, next_button, confirm_button, power_button, browser_button, close_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control_row.add_child(button)
	chrome.add_child(control_row)

	panel.add_child(chrome)
	add_child(panel)

func _apply_state() -> void:
	var panel := get_node_or_null("Panel") as PanelContainer
	var display_label := get_node_or_null("Panel/Chrome/DisplayFrame/DisplayLabel") as RichTextLabel
	var prev_button := get_node_or_null("Panel/Chrome/ControlRow/PrevButton") as Button
	var next_button := get_node_or_null("Panel/Chrome/ControlRow/NextButton") as Button
	var confirm_button := get_node_or_null("Panel/Chrome/ControlRow/ConfirmButton") as Button
	var power_button := get_node_or_null("Panel/Chrome/ControlRow/PowerButton") as Button
	var browser_button := get_node_or_null("Panel/Chrome/ControlRow/BrowserButton") as Button
	visible = bool(_state.get("visible", false))
	if panel != null:
		panel.visible = visible
	if display_label != null:
		display_label.text = _build_display_text()
	if prev_button != null:
		prev_button.disabled = _count_filled_slots() <= 0
	if next_button != null:
		next_button.disabled = _count_filled_slots() <= 0
	if confirm_button != null:
		confirm_button.disabled = int(_state.get("selected_slot_index", -1)) < 0 or str(_state.get("selected_station_id", "")).strip_edges() == ""
	if power_button != null:
		power_button.text = "Power %s" % str(_state.get("power_state", "off")).to_upper()
	if browser_button != null:
		browser_button.disabled = not bool(_state.get("browser_action_available", false))
	_apply_preset_buttons()

func _apply_preset_buttons() -> void:
	var slots: Array = _state.get("slots", []) as Array
	var selected_slot_index := int(_state.get("selected_slot_index", -1))
	var current_station_id := str(_state.get("current_station_id", ""))
	var preset_grid := get_node_or_null("Panel/Chrome/PresetGrid") as GridContainer
	if preset_grid == null:
		return
	for slot_index in range(preset_grid.get_child_count()):
		var button := preset_grid.get_child(slot_index) as Button
		if button == null:
			continue
		if slot_index >= slots.size():
			button.visible = false
			continue
		button.visible = true
		var slot := slots[slot_index] as Dictionary
		var station_name := str(slot.get("station_name", "")).strip_edges()
		var slot_station_id := str(slot.get("station_id", ""))
		var prefix := "P%d" % (slot_index + 1)
		if slot_index == selected_slot_index:
			prefix = "> %s" % prefix
		var suffix := station_name if station_name != "" else "Empty"
		if slot_station_id != "" and slot_station_id == current_station_id:
			suffix = "ON AIR  %s" % suffix
		button.text = "%s\n%s" % [prefix, suffix]
		button.disabled = slot_station_id == ""
		button.modulate = Color(0.92, 0.98, 0.95, 1.0) if slot_index == selected_slot_index else Color(0.8, 0.87, 0.83, 1.0)

func _build_display_text() -> String:
	var selected_slot_index := int(_state.get("selected_slot_index", -1))
	var selected_slot_label := "未选预设"
	if selected_slot_index >= 0:
		selected_slot_label = "P%d" % (selected_slot_index + 1)
	var lines := PackedStringArray([
		"[b]NOW[/b] %s" % _resolve_display_station_name(str(_state.get("current_station_name", ""))),
		"状态：power=%s  playback=%s" % [
			str(_state.get("power_state", "off")),
			str(_state.get("playback_state", "stopped")),
		],
		"[b]PRESET[/b] %s  %s" % [selected_slot_label, _resolve_display_station_name(str(_state.get("selected_station_name", "")))],
	])
	if bool(_state.get("browser_action_available", false)):
		lines.append("按 Browser 可切到完整目录，按 Close 仅关闭面板。")
	return "\n".join(lines)

func _resolve_display_station_name(station_name: String) -> String:
	var trimmed := station_name.strip_edges()
	return trimmed if trimmed != "" else "未选台"

func _count_filled_slots() -> int:
	var filled_count := 0
	for slot_variant in _state.get("slots", []):
		if not (slot_variant is Dictionary):
			continue
		if str((slot_variant as Dictionary).get("station_id", "")).strip_edges() != "":
			filled_count += 1
	return filled_count
