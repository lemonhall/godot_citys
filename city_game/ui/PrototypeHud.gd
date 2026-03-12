extends CanvasLayer

const CityCrosshairViewScript := preload("res://city_game/ui/CityCrosshairView.gd")

var _status_text := "Booting city skeleton..."
var _debug_text := ""
var _debug_expanded := false
var _minimap_snapshot: Dictionary = {}
var _crosshair_state: Dictionary = {
	"visible": false,
	"screen_position": Vector2.ZERO,
	"viewport_size": Vector2.ZERO,
	"world_target": Vector3.ZERO,
	"aim_down_sights_active": false,
}

func _ready() -> void:
	_ensure_crosshair_view()
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

func set_minimap_snapshot(snapshot: Dictionary) -> void:
	_minimap_snapshot = snapshot.duplicate(true)
	_apply_state()

func set_crosshair_state(state: Dictionary) -> void:
	_crosshair_state = state.duplicate(true)
	_apply_state()

func get_minimap_state() -> Dictionary:
	return {
		"expanded": _debug_expanded,
		"snapshot": _minimap_snapshot.duplicate(true),
	}

func get_crosshair_state() -> Dictionary:
	return _crosshair_state.duplicate(true)

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
	var minimap_view := get_node_or_null("Root/MinimapFrame/MinimapView")
	var crosshair_view := get_node_or_null("Root/Crosshair")
	if panel != null:
		panel.visible = _debug_expanded
	if toggle_button != null:
		toggle_button.text = "Hide HUD" if _debug_expanded else "Inspect HUD"
	if status_label != null:
		status_label.text = _status_text
	if debug_label != null:
		debug_label.text = _debug_text
	if minimap_view != null and minimap_view.has_method("set_snapshot"):
		minimap_view.set_snapshot(_minimap_snapshot)
	if crosshair_view != null and crosshair_view.has_method("set_state"):
		crosshair_view.set_state(_crosshair_state)

func _ensure_crosshair_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("Crosshair") != null:
		return
	var crosshair_view := Control.new()
	crosshair_view.name = "Crosshair"
	crosshair_view.set_script(CityCrosshairViewScript)
	root.add_child(crosshair_view)
