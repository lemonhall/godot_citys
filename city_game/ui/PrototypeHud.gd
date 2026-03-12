extends CanvasLayer

const CityCrosshairViewScript := preload("res://city_game/ui/CityCrosshairView.gd")

var _status_text := "Booting city skeleton..."
var _debug_text := ""
var _debug_expanded := false
var _minimap_snapshot: Dictionary = {}
var _fps_overlay_state := {
	"visible": false,
	"fps": 0.0,
	"color": Color(0.4, 0.92, 0.5, 1.0),
	"color_name": "green",
}
var _crosshair_state: Dictionary = {
	"visible": false,
	"screen_position": Vector2.ZERO,
	"viewport_size": Vector2.ZERO,
	"world_target": Vector3.ZERO,
	"aim_down_sights_active": false,
}

func _ready() -> void:
	_ensure_crosshair_view()
	_ensure_fps_label()
	var toggle_button := get_node_or_null("Root/ToggleButton") as Button
	if toggle_button != null and not toggle_button.pressed.is_connected(_on_toggle_pressed):
		toggle_button.pressed.connect(_on_toggle_pressed)
	_apply_state()

func set_status(text: String) -> void:
	_status_text = text
	_apply_status_state()

func set_debug_text(text: String) -> void:
	_debug_text = text
	_apply_debug_text_state()

func set_minimap_snapshot(snapshot: Dictionary) -> void:
	_minimap_snapshot = snapshot.duplicate(false)
	_apply_minimap_state()

func set_crosshair_state(state: Dictionary) -> void:
	_crosshair_state = state.duplicate(true)
	_apply_crosshair_state()

func get_minimap_state() -> Dictionary:
	return {
		"expanded": _debug_expanded,
		"snapshot": _minimap_snapshot.duplicate(true),
	}

func set_fps_overlay_visible(visible: bool) -> void:
	_fps_overlay_state["visible"] = visible
	_apply_fps_overlay_state()

func set_fps_overlay_sample(fps: float) -> void:
	_fps_overlay_state["fps"] = maxf(fps, 0.0)
	var color_state := _resolve_fps_color_state(float(_fps_overlay_state.get("fps", 0.0)))
	_fps_overlay_state["color"] = color_state.get("color", Color(0.4, 0.92, 0.5, 1.0))
	_fps_overlay_state["color_name"] = str(color_state.get("color_name", "green"))
	_apply_fps_overlay_state()

func get_fps_overlay_state() -> Dictionary:
	return _fps_overlay_state.duplicate(true)

func get_crosshair_state() -> Dictionary:
	return _crosshair_state.duplicate(true)

func toggle_debug_expanded() -> void:
	_debug_expanded = not _debug_expanded
	_apply_panel_state()

func is_debug_expanded() -> bool:
	return _debug_expanded

func _on_toggle_pressed() -> void:
	toggle_debug_expanded()

func _apply_state() -> void:
	_apply_panel_state()
	_apply_status_state()
	_apply_debug_text_state()
	_apply_minimap_state()
	_apply_crosshair_state()
	_apply_fps_overlay_state()

func _apply_panel_state() -> void:
	var panel := get_node_or_null("Root/Panel") as PanelContainer
	var toggle_button := get_node_or_null("Root/ToggleButton") as Button
	if panel != null:
		panel.visible = _debug_expanded
	if toggle_button != null:
		toggle_button.text = "Hide HUD" if _debug_expanded else "Inspect HUD"

func _apply_status_state() -> void:
	var status_label := get_node_or_null("Root/Panel/VBox/Status") as Label
	if status_label != null:
		status_label.text = _status_text

func _apply_debug_text_state() -> void:
	var debug_label := get_node_or_null("Root/Panel/VBox/DebugText") as Label
	if debug_label != null:
		debug_label.text = _debug_text

func _apply_minimap_state() -> void:
	var minimap_view := get_node_or_null("Root/MinimapFrame/MinimapView")
	if minimap_view != null and minimap_view.has_method("set_snapshot"):
		minimap_view.set_snapshot(_minimap_snapshot)

func _apply_crosshair_state() -> void:
	var crosshair_view := get_node_or_null("Root/Crosshair")
	if crosshair_view != null and crosshair_view.has_method("set_state"):
		crosshair_view.set_state(_crosshair_state)

func _apply_fps_overlay_state() -> void:
	var fps_label := get_node_or_null("Root/FpsLabel") as Label
	if fps_label != null:
		fps_label.visible = bool(_fps_overlay_state.get("visible", false))
		fps_label.text = "FPS %.1f" % float(_fps_overlay_state.get("fps", 0.0))
		fps_label.modulate = _fps_overlay_state.get("color", Color(0.4, 0.92, 0.5, 1.0))

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

func _ensure_fps_label() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("FpsLabel") != null:
		return
	var fps_label := Label.new()
	fps_label.name = "FpsLabel"
	fps_label.anchor_left = 1.0
	fps_label.anchor_right = 1.0
	fps_label.offset_left = -140.0
	fps_label.offset_top = 16.0
	fps_label.offset_right = -16.0
	fps_label.offset_bottom = 40.0
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.visible = false
	root.add_child(fps_label)

func _resolve_fps_color_state(fps: float) -> Dictionary:
	if fps < 30.0:
		return {
			"color": Color(0.94, 0.3, 0.3, 1.0),
			"color_name": "red",
		}
	if fps <= 50.0:
		return {
			"color": Color(0.95, 0.82, 0.28, 1.0),
			"color_name": "yellow",
		}
	return {
		"color": Color(0.4, 0.92, 0.5, 1.0),
		"color_name": "green",
	}
