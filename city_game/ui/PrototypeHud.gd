extends CanvasLayer

const CityCrosshairViewScript := preload("res://city_game/ui/CityCrosshairView.gd")
const CityControlsHelpOverlayScript := preload("res://city_game/ui/CityControlsHelpOverlay.gd")
const CityDialoguePanelScript := preload("res://city_game/ui/CityDialoguePanel.gd")
const CityVehicleRadioBrowserScript := preload("res://city_game/ui/CityVehicleRadioBrowser.gd")
const CityVehicleRadioQuickOverlayScript := preload("res://city_game/ui/CityVehicleRadioQuickOverlay.gd")

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
var _focus_message_state: Dictionary = {
	"visible": false,
	"text": "",
	"remaining_sec": 0.0,
	"duration_sec": 0.0,
}
var _interaction_prompt_state: Dictionary = {
	"visible": false,
	"actor_id": "",
	"prompt_text": "",
	"distance_m": 0.0,
}
var _dialogue_panel_state: Dictionary = {
	"visible": false,
	"speaker_name": "",
	"body_text": "",
	"dialogue_id": "",
	"owner_actor_id": "",
	"close_hint_text": "按 E 关闭",
}
var _crosshair_state: Dictionary = {
	"visible": false,
	"screen_position": Vector2.ZERO,
	"viewport_size": Vector2.ZERO,
	"world_target": Vector3.ZERO,
	"aim_down_sights_active": false,
}
var _vehicle_radio_quick_overlay_state: Dictionary = {
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
var _vehicle_radio_browser_state: Dictionary = {
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
var _controls_help_state: Dictionary = {
	"visible": false,
	"title": "键位说明",
	"subtitle": "",
	"close_hint": "按 F1 关闭",
	"sections": [],
}

func _ready() -> void:
	_ensure_mouse_passthrough()
	_ensure_crosshair_view()
	_ensure_fps_label()
	_ensure_focus_message_view()
	_ensure_interaction_prompt_view()
	_ensure_dialogue_panel_view()
	_ensure_vehicle_radio_browser_view()
	_ensure_vehicle_radio_quick_overlay_view()
	_ensure_controls_help_view()
	var toggle_button := get_node_or_null("Root/ToggleButton") as Button
	if toggle_button != null and not toggle_button.pressed.is_connected(_on_toggle_pressed):
		toggle_button.pressed.connect(_on_toggle_pressed)
	_apply_state()

func _process(delta: float) -> void:
	if not bool(_focus_message_state.get("visible", false)):
		return
	var remaining_sec := maxf(float(_focus_message_state.get("remaining_sec", 0.0)) - maxf(delta, 0.0), 0.0)
	_focus_message_state["remaining_sec"] = remaining_sec
	if remaining_sec <= 0.0:
		clear_focus_message()
		return
	_apply_focus_message_state()

func set_status(text: String) -> void:
	_status_text = text
	_apply_status_state()

func set_debug_text(text: String) -> void:
	_debug_text = text
	_apply_debug_text_state()

func set_minimap_snapshot(snapshot: Dictionary) -> void:
	_minimap_snapshot = snapshot.duplicate(false)
	_apply_minimap_state()

func set_navigation_state(_state: Dictionary) -> void:
	pass

func set_focus_message(text: String, duration_sec: float = 10.0) -> void:
	var trimmed := text.strip_edges()
	if trimmed == "":
		clear_focus_message()
		return
	var resolved_duration_sec := maxf(duration_sec, 0.001)
	_focus_message_state = {
		"visible": true,
		"text": trimmed,
		"remaining_sec": resolved_duration_sec,
		"duration_sec": resolved_duration_sec,
	}
	_apply_focus_message_state()

func clear_focus_message() -> void:
	_focus_message_state = {
		"visible": false,
		"text": "",
		"remaining_sec": 0.0,
		"duration_sec": 0.0,
	}
	_apply_focus_message_state()

func set_interaction_prompt_state(state: Dictionary) -> void:
	_interaction_prompt_state = {
		"visible": bool(state.get("visible", false)),
		"actor_id": str(state.get("actor_id", "")),
		"prompt_text": str(state.get("prompt_text", "")),
		"distance_m": float(state.get("distance_m", 0.0)),
	}
	_apply_interaction_prompt_state()

func get_interaction_prompt_state() -> Dictionary:
	return _interaction_prompt_state.duplicate(true)

func set_dialogue_panel_state(state: Dictionary) -> void:
	_dialogue_panel_state = {
		"visible": bool(state.get("visible", false)),
		"speaker_name": str(state.get("speaker_name", "")),
		"body_text": str(state.get("body_text", "")),
		"dialogue_id": str(state.get("dialogue_id", "")),
		"owner_actor_id": str(state.get("owner_actor_id", "")),
		"close_hint_text": str(state.get("close_hint_text", "按 E 关闭")),
	}
	_apply_dialogue_panel_state()

func get_dialogue_panel_state() -> Dictionary:
	return _dialogue_panel_state.duplicate(true)

func set_crosshair_state(state: Dictionary) -> void:
	_crosshair_state = state.duplicate(true)
	_apply_crosshair_state()

func get_minimap_state() -> Dictionary:
	return {
		"expanded": _debug_expanded,
		"snapshot": _minimap_snapshot.duplicate(true),
	}

func get_navigation_state() -> Dictionary:
	return {}

func set_fps_overlay_visible(should_be_visible: bool) -> void:
	_fps_overlay_state["visible"] = should_be_visible
	_apply_fps_overlay_state()

func set_fps_overlay_sample(fps: float) -> void:
	_fps_overlay_state["fps"] = maxf(fps, 0.0)
	var color_state := _resolve_fps_color_state(float(_fps_overlay_state.get("fps", 0.0)))
	_fps_overlay_state["color"] = color_state.get("color", Color(0.4, 0.92, 0.5, 1.0))
	_fps_overlay_state["color_name"] = str(color_state.get("color_name", "green"))
	_apply_fps_overlay_state()

func get_fps_overlay_state() -> Dictionary:
	return _fps_overlay_state.duplicate(true)

func get_focus_message_state() -> Dictionary:
	return _focus_message_state.duplicate(true)

func get_crosshair_state() -> Dictionary:
	return _crosshair_state.duplicate(true)

func set_vehicle_radio_browser_state(state: Dictionary) -> void:
	_vehicle_radio_browser_state = {
		"visible": bool(state.get("visible", false)),
		"selected_tab_id": str(state.get("selected_tab_id", "browse")),
		"tabs": (state.get("tabs", []) as Array).duplicate(true),
		"current_playing": (state.get("current_playing", {}) as Dictionary).duplicate(true),
		"presets": (state.get("presets", []) as Array).duplicate(true),
		"favorites": (state.get("favorites", []) as Array).duplicate(true),
		"recents": (state.get("recents", []) as Array).duplicate(true),
		"browse": (state.get("browse", {}) as Dictionary).duplicate(true),
	}
	_apply_vehicle_radio_browser_state()

func get_vehicle_radio_browser_state() -> Dictionary:
	return _vehicle_radio_browser_state.duplicate(true)

func set_vehicle_radio_quick_overlay_state(state: Dictionary) -> void:
	_vehicle_radio_quick_overlay_state = {
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
	_apply_vehicle_radio_quick_overlay_state()

func get_vehicle_radio_quick_overlay_state() -> Dictionary:
	return _vehicle_radio_quick_overlay_state.duplicate(true)

func set_controls_help_state(state: Dictionary) -> void:
	_controls_help_state = {
		"visible": bool(state.get("visible", false)),
		"title": str(state.get("title", "键位说明")),
		"subtitle": str(state.get("subtitle", "")),
		"close_hint": str(state.get("close_hint", "按 F1 关闭")),
		"sections": (state.get("sections", []) as Array).duplicate(true),
	}
	_apply_controls_help_state()

func get_controls_help_state() -> Dictionary:
	return _controls_help_state.duplicate(true)

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
	_apply_focus_message_state()
	_apply_interaction_prompt_state()
	_apply_dialogue_panel_state()
	_apply_vehicle_radio_browser_state()
	_apply_vehicle_radio_quick_overlay_state()
	_apply_controls_help_state()

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

func _apply_focus_message_state() -> void:
	var panel := get_node_or_null("Root/FocusMessage") as PanelContainer
	var label := get_node_or_null("Root/FocusMessage/Label") as Label
	if panel != null:
		panel.visible = bool(_focus_message_state.get("visible", false))
	if label != null:
		label.text = str(_focus_message_state.get("text", ""))

func _apply_interaction_prompt_state() -> void:
	var panel := get_node_or_null("Root/InteractionPrompt") as PanelContainer
	var label := get_node_or_null("Root/InteractionPrompt/Label") as Label
	if panel != null:
		panel.visible = bool(_interaction_prompt_state.get("visible", false))
	if label == null:
		return
	var prompt_text := str(_interaction_prompt_state.get("prompt_text", ""))
	var distance_m := float(_interaction_prompt_state.get("distance_m", 0.0))
	if prompt_text == "":
		label.text = ""
		return
	label.text = "%s  %.1fm" % [prompt_text, distance_m]

func _apply_dialogue_panel_state() -> void:
	var panel := get_node_or_null("Root/DialoguePanel")
	if panel != null and panel.has_method("set_state"):
		panel.set_state(_dialogue_panel_state)

func _apply_vehicle_radio_browser_state() -> void:
	var browser := get_node_or_null("Root/VehicleRadioBrowser")
	if browser != null and browser.has_method("set_state"):
		browser.set_state(_vehicle_radio_browser_state)

func _apply_vehicle_radio_quick_overlay_state() -> void:
	var overlay := get_node_or_null("Root/VehicleRadioQuickOverlay")
	if overlay != null and overlay.has_method("set_state"):
		overlay.set_state(_vehicle_radio_quick_overlay_state)

func _apply_controls_help_state() -> void:
	var overlay := get_node_or_null("Root/ControlsHelp")
	if overlay != null and overlay.has_method("set_state"):
		overlay.set_state(_controls_help_state)

func _ensure_mouse_passthrough() -> void:
	var root := get_node_or_null("Root") as Control
	if root != null:
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := get_node_or_null("Root/Panel") as Control
	if panel != null:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var minimap_frame := get_node_or_null("Root/MinimapFrame") as Control
	if minimap_frame != null:
		minimap_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var minimap_view := get_node_or_null("Root/MinimapFrame/MinimapView") as Control
	if minimap_view != null:
		minimap_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var interaction_prompt := get_node_or_null("Root/InteractionPrompt") as Control
	if interaction_prompt != null:
		interaction_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dialogue_panel := get_node_or_null("Root/DialoguePanel") as Control
	if dialogue_panel != null:
		dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var radio_overlay := get_node_or_null("Root/VehicleRadioQuickOverlay") as Control
	if radio_overlay != null:
		radio_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fps_label)

func _ensure_focus_message_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("FocusMessage") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "FocusMessage"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -320.0
	panel.offset_top = -144.0
	panel.offset_right = 320.0
	panel.offset_bottom = -92.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.04, 0.08, 0.06, 0.82)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.content_margin_left = 14.0
	stylebox.content_margin_top = 10.0
	stylebox.content_margin_right = 14.0
	stylebox.content_margin_bottom = 10.0
	panel.add_theme_stylebox_override("panel", stylebox)
	var label := Label.new()
	label.name = "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.78, 1.0, 0.84, 1.0))
	panel.add_child(label)
	root.add_child(panel)

func _ensure_interaction_prompt_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("InteractionPrompt") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "InteractionPrompt"
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -220.0
	panel.offset_top = -204.0
	panel.offset_right = 220.0
	panel.offset_bottom = -162.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.05, 0.1, 0.08, 0.82)
	stylebox.corner_radius_top_left = 8
	stylebox.corner_radius_top_right = 8
	stylebox.corner_radius_bottom_left = 8
	stylebox.corner_radius_bottom_right = 8
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.2, 0.72, 0.44, 0.95)
	stylebox.content_margin_left = 14.0
	stylebox.content_margin_top = 8.0
	stylebox.content_margin_right = 14.0
	stylebox.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", stylebox)
	var label := Label.new()
	label.name = "Label"
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.86, 1.0))
	panel.add_child(label)
	root.add_child(panel)

func _ensure_dialogue_panel_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("DialoguePanel") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.set_script(CityDialoguePanelScript)
	root.add_child(panel)

func _ensure_vehicle_radio_browser_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("VehicleRadioBrowser") != null:
		return
	var browser := Control.new()
	browser.name = "VehicleRadioBrowser"
	browser.set_script(CityVehicleRadioBrowserScript)
	root.add_child(browser)

func _ensure_vehicle_radio_quick_overlay_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("VehicleRadioQuickOverlay") != null:
		return
	var overlay := Control.new()
	overlay.name = "VehicleRadioQuickOverlay"
	overlay.set_script(CityVehicleRadioQuickOverlayScript)
	root.add_child(overlay)

func _ensure_controls_help_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("ControlsHelp") != null:
		return
	var overlay := Control.new()
	overlay.name = "ControlsHelp"
	overlay.set_script(CityControlsHelpOverlayScript)
	root.add_child(overlay)

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
