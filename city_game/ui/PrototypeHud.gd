extends CanvasLayer

var _status_text := "Booting city skeleton..."
var _debug_text := ""
var _debug_expanded := false

func _ready() -> void:
	var toggle_button := get_node_or_null("Root/ToggleButton") as Button
	if toggle_button != null and not toggle_button.pressed.is_connected(_on_toggle_pressed):
		toggle_button.pressed.connect(_on_toggle_pressed)
	_apply_state()

func set_status(text: String) -> void:
	_status_text = text
	_apply_state()

func set_debug_text(text: String) -> void:
	_debug_text = text
	_apply_state()

func toggle_debug_expanded() -> void:
	_debug_expanded = not _debug_expanded
	_apply_state()

func is_debug_expanded() -> bool:
	return _debug_expanded

func _on_toggle_pressed() -> void:
	toggle_debug_expanded()

func _apply_state() -> void:
	var panel := get_node_or_null("Root/Panel") as PanelContainer
	var toggle_button := get_node_or_null("Root/ToggleButton") as Button
	var status_label := get_node_or_null("Root/Panel/VBox/Status") as Label
	var debug_label := get_node_or_null("Root/Panel/VBox/DebugText") as Label
	if panel != null:
		panel.visible = _debug_expanded
	if toggle_button != null:
		toggle_button.text = "Hide HUD" if _debug_expanded else "Inspect HUD"
	if status_label != null:
		status_label.text = _status_text
	if debug_label != null:
		debug_label.text = _debug_text
