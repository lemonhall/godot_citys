extends CanvasLayer

const CityCrosshairViewScript := preload("res://city_game/ui/CityCrosshairView.gd")
const CityControlsHelpOverlayScript := preload("res://city_game/ui/CityControlsHelpOverlay.gd")
const CityDialoguePanelScript := preload("res://city_game/ui/CityDialoguePanel.gd")
const CityVehicleRadioBrowserScript := preload("res://city_game/ui/CityVehicleRadioBrowser.gd")
const CityVehicleRadioQuickOverlayScript := preload("res://city_game/ui/CityVehicleRadioQuickOverlay.gd")
const AUDIO_SAMPLE_RATE := 22050

static var _tennis_feedback_audio_stream_cache: Dictionary = {}

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
	"owner_kind": "",
	"actor_id": "",
	"prop_id": "",
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
var _soccer_match_hud_state: Dictionary = {
	"visible": false,
	"match_state": "idle",
	"home_score": 0,
	"away_score": 0,
	"home_team_color_id": "red",
	"away_team_color_id": "blue",
	"clock_text": "05:00",
	"winner_side": "",
}
var _tennis_match_hud_state: Dictionary = {
	"visible": false,
	"match_state": "idle",
	"home_games": 0,
	"away_games": 0,
	"home_point_label": "0",
	"away_point_label": "0",
	"server_side": "home",
	"winner_side": "",
	"point_end_reason": "",
	"landing_marker_visible": false,
	"landing_marker_world_position": Vector3.ZERO,
	"auto_footwork_assist_state": "idle",
	"strike_window_state": "idle",
	"strike_quality_feedback": "",
	"expected_service_box_id": "",
	"state_text": "",
	"coach_text": "",
	"coach_tone": "neutral",
	"feedback_event_token": 0,
	"feedback_event_kind": "",
	"feedback_event_text": "",
	"feedback_event_tone": "neutral",
}
var _missile_command_hud_state: Dictionary = {
	"visible": false,
	"wave_index": 0,
	"wave_total": 3,
	"wave_state": "idle",
	"selected_silo_id": "",
	"cities_alive_count": 0,
	"enemy_remaining_count": 0,
	"zoom_active": false,
	"feedback_event_token": 0,
	"feedback_event_text": "",
	"feedback_event_tone": "neutral",
}
var _fishing_hud_state: Dictionary = {
	"visible": false,
	"fishing_mode_active": false,
	"pole_equipped": false,
	"cast_state": "idle",
	"target_school_id": "",
	"last_catch_result": {},
	"display_name": "Lakeside Fishing",
	"state_text": "按 E 拿起鱼竿",
	"result_text": "",
	"feedback_event_token": 0,
	"feedback_event_text": "",
	"feedback_event_tone": "neutral",
}
var _tennis_feedback_audio_player: AudioStreamPlayer = null
var _tennis_feedback_audio_state: Dictionary = {
	"play_count": 0,
	"last_event_kind": "",
	"last_event_token": 0,
}
var _last_tennis_feedback_event_token := 0

func _ready() -> void:
	_ensure_mouse_passthrough()
	_ensure_crosshair_view()
	_ensure_fps_label()
	_ensure_soccer_match_hud_view()
	_ensure_tennis_match_hud_view()
	_ensure_missile_command_hud_view()
	_ensure_fishing_hud_view()
	_ensure_tennis_feedback_audio_player()
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
		"owner_kind": str(state.get("owner_kind", "")),
		"actor_id": str(state.get("actor_id", "")),
		"prop_id": str(state.get("prop_id", "")),
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

func set_soccer_match_hud_state(state: Dictionary) -> void:
	_soccer_match_hud_state = {
		"visible": bool(state.get("visible", false)),
		"match_state": str(state.get("match_state", "idle")),
		"home_score": int(state.get("home_score", 0)),
		"away_score": int(state.get("away_score", 0)),
		"home_team_color_id": str(state.get("home_team_color_id", "red")),
		"away_team_color_id": str(state.get("away_team_color_id", "blue")),
		"clock_text": str(state.get("clock_text", "05:00")),
		"winner_side": str(state.get("winner_side", "")),
	}
	_apply_soccer_match_hud_state()

func get_soccer_match_hud_state() -> Dictionary:
	return _soccer_match_hud_state.duplicate(true)

func set_tennis_match_hud_state(state: Dictionary) -> void:
	_tennis_match_hud_state = {
		"visible": bool(state.get("visible", false)),
		"match_state": str(state.get("match_state", "idle")),
		"home_games": int(state.get("home_games", 0)),
		"away_games": int(state.get("away_games", 0)),
		"home_point_label": str(state.get("home_point_label", "0")),
		"away_point_label": str(state.get("away_point_label", "0")),
		"server_side": str(state.get("server_side", "home")),
		"winner_side": str(state.get("winner_side", "")),
		"point_end_reason": str(state.get("point_end_reason", "")),
		"landing_marker_visible": bool(state.get("landing_marker_visible", false)),
		"landing_marker_world_position": state.get("landing_marker_world_position", Vector3.ZERO),
		"auto_footwork_assist_state": str(state.get("auto_footwork_assist_state", "idle")),
		"strike_window_state": str(state.get("strike_window_state", "idle")),
		"strike_quality_feedback": str(state.get("strike_quality_feedback", "")),
		"expected_service_box_id": str(state.get("expected_service_box_id", "")),
		"state_text": str(state.get("state_text", "")),
		"coach_text": str(state.get("coach_text", "")),
		"coach_tone": str(state.get("coach_tone", "neutral")),
		"feedback_event_token": int(state.get("feedback_event_token", 0)),
		"feedback_event_kind": str(state.get("feedback_event_kind", "")),
		"feedback_event_text": str(state.get("feedback_event_text", "")),
		"feedback_event_tone": str(state.get("feedback_event_tone", "neutral")),
	}
	_handle_tennis_feedback_event(_tennis_match_hud_state)
	_apply_tennis_match_hud_state()

func get_tennis_match_hud_state() -> Dictionary:
	return _tennis_match_hud_state.duplicate(true)

func set_missile_command_hud_state(state: Dictionary) -> void:
	_missile_command_hud_state = {
		"visible": bool(state.get("visible", false)),
		"wave_index": int(state.get("wave_index", 0)),
		"wave_total": int(state.get("wave_total", 3)),
		"wave_state": str(state.get("wave_state", "idle")),
		"selected_silo_id": str(state.get("selected_silo_id", "")),
		"cities_alive_count": int(state.get("cities_alive_count", 0)),
		"enemy_remaining_count": int(state.get("enemy_remaining_count", 0)),
		"zoom_active": bool(state.get("zoom_active", false)),
		"feedback_event_token": int(state.get("feedback_event_token", 0)),
		"feedback_event_text": str(state.get("feedback_event_text", "")),
		"feedback_event_tone": str(state.get("feedback_event_tone", "neutral")),
	}
	_apply_missile_command_hud_state()

func get_missile_command_hud_state() -> Dictionary:
	return _missile_command_hud_state.duplicate(true)

func set_fishing_hud_state(state: Dictionary) -> void:
	var next_state := {
		"visible": bool(state.get("visible", false)),
		"fishing_mode_active": bool(state.get("fishing_mode_active", false)),
		"pole_equipped": bool(state.get("pole_equipped", false)),
		"cast_state": str(state.get("cast_state", "idle")),
		"target_school_id": str(state.get("target_school_id", "")),
		"last_catch_result": (state.get("last_catch_result", {}) as Dictionary).duplicate(true),
		"display_name": str(state.get("display_name", "Lakeside Fishing")),
		"state_text": str(state.get("state_text", "")),
		"result_text": str(state.get("result_text", "")),
		"feedback_event_token": int(state.get("feedback_event_token", 0)),
		"feedback_event_text": str(state.get("feedback_event_text", "")),
		"feedback_event_tone": str(state.get("feedback_event_tone", "neutral")),
	}
	if next_state == _fishing_hud_state:
		return
	_fishing_hud_state = next_state
	_apply_fishing_hud_state()

func get_fishing_hud_state() -> Dictionary:
	return _fishing_hud_state.duplicate(true)

func get_tennis_feedback_audio_state() -> Dictionary:
	return _tennis_feedback_audio_state.duplicate(true)

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
	_apply_soccer_match_hud_state()
	_apply_tennis_match_hud_state()
	_apply_missile_command_hud_state()
	_apply_fishing_hud_state()

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

func _apply_soccer_match_hud_state() -> void:
	var panel := get_node_or_null("Root/SoccerMatchHud") as PanelContainer
	var clock_label := get_node_or_null("Root/SoccerMatchHud/Margin/VBox/Clock") as Label
	var score_label := get_node_or_null("Root/SoccerMatchHud/Margin/VBox/Score") as Label
	var state_label := get_node_or_null("Root/SoccerMatchHud/Margin/VBox/State") as Label
	if panel != null:
		panel.visible = bool(_soccer_match_hud_state.get("visible", false))
	if clock_label != null:
		clock_label.text = str(_soccer_match_hud_state.get("clock_text", "05:00"))
	if score_label != null:
		score_label.text = "RED %d  :  %d BLUE" % [
			int(_soccer_match_hud_state.get("home_score", 0)),
			int(_soccer_match_hud_state.get("away_score", 0))
		]
	if state_label != null:
		var state_text := str(_soccer_match_hud_state.get("match_state", "idle")).to_upper()
		var winner_side := str(_soccer_match_hud_state.get("winner_side", ""))
		if winner_side != "":
			state_text = "%s WINS" % winner_side.to_upper()
		state_label.text = state_text

func _apply_tennis_match_hud_state() -> void:
	var panel := get_node_or_null("Root/TennisMatchHud") as PanelContainer
	var games_label := get_node_or_null("Root/TennisMatchHud/Margin/VBox/Games") as Label
	var points_label := get_node_or_null("Root/TennisMatchHud/Margin/VBox/Points") as Label
	var state_label := get_node_or_null("Root/TennisMatchHud/Margin/VBox/State") as Label
	var assist_label := get_node_or_null("Root/TennisMatchHud/Margin/VBox/Assist") as Label
	var coach_label := get_node_or_null("Root/TennisMatchHud/Margin/VBox/Coach") as Label
	if panel != null:
		panel.visible = bool(_tennis_match_hud_state.get("visible", false))
	if games_label != null:
		var server_side := str(_tennis_match_hud_state.get("server_side", "home")).to_upper()
		games_label.text = "GAMES %d  :  %d    SRV %s" % [
			int(_tennis_match_hud_state.get("home_games", 0)),
			int(_tennis_match_hud_state.get("away_games", 0)),
			server_side
		]
	if points_label != null:
		points_label.text = "%s  :  %s" % [
			str(_tennis_match_hud_state.get("home_point_label", "0")),
			str(_tennis_match_hud_state.get("away_point_label", "0"))
		]
	if state_label != null:
		var state_text := str(_tennis_match_hud_state.get("state_text", ""))
		if state_text == "":
			state_text = str(_tennis_match_hud_state.get("match_state", "idle")).to_upper()
		state_label.text = state_text
	if assist_label != null:
		var assist_text := "等待开赛"
		var expected_service_box_id := str(_tennis_match_hud_state.get("expected_service_box_id", ""))
		var match_state := str(_tennis_match_hud_state.get("match_state", "idle"))
		var strike_window_state := str(_tennis_match_hud_state.get("strike_window_state", "idle"))
		match match_state:
			"pre_serve":
				assist_text = "目标发球区：%s" % expected_service_box_id.to_upper()
			"rally":
				match strike_window_state:
					"ready":
						assist_text = "击球窗口已开，按 E 回球"
					"recover":
						assist_text = "回球已出手，准备下一拍"
					_:
						assist_text = "跟住绿圈，等待击球窗口"
			"serve_in_flight":
				assist_text = "跟住绿圈，提前准备接发"
			"point_result":
				assist_text = "等待下一分开始"
			"game_break":
				assist_text = "换发球，准备下一局"
			"final":
				assist_text = "离开场地可重置比赛"
		assist_label.text = assist_text
		var assist_color := Color(0.72, 0.86, 0.94, 1.0)
		if strike_window_state == "ready":
			assist_color = Color(0.74, 0.98, 0.82, 1.0)
		elif strike_window_state == "recover":
			assist_color = Color(0.98, 0.88, 0.62, 1.0)
		assist_label.add_theme_color_override("font_color", assist_color)
	if coach_label != null:
		coach_label.text = str(_tennis_match_hud_state.get("coach_text", ""))
		var coach_tone := str(_tennis_match_hud_state.get("coach_tone", "neutral"))
		var coach_color := Color(0.86, 0.9, 0.96, 1.0)
		match coach_tone:
			"success":
				coach_color = Color(0.82, 1.0, 0.76, 1.0)
			"warning":
				coach_color = Color(1.0, 0.88, 0.66, 1.0)
			"action":
				coach_color = Color(0.98, 0.98, 0.72, 1.0)
		coach_label.add_theme_color_override("font_color", coach_color)

func _apply_missile_command_hud_state() -> void:
	var panel := get_node_or_null("Root/MissileCommandHud") as PanelContainer
	var wave_label := get_node_or_null("Root/MissileCommandHud/Margin/VBox/Wave") as Label
	var targets_label := get_node_or_null("Root/MissileCommandHud/Margin/VBox/Targets") as Label
	var silo_label := get_node_or_null("Root/MissileCommandHud/Margin/VBox/Silo") as Label
	var feedback_label := get_node_or_null("Root/MissileCommandHud/Margin/VBox/Feedback") as Label
	if panel != null:
		panel.visible = bool(_missile_command_hud_state.get("visible", false))
	if wave_label != null:
		wave_label.text = "WAVE %d / %d   %s" % [
			int(_missile_command_hud_state.get("wave_index", 0)),
			int(_missile_command_hud_state.get("wave_total", 3)),
			str(_missile_command_hud_state.get("wave_state", "idle")).to_upper()
		]
	if targets_label != null:
		targets_label.text = "CITIES %d   THREATS %d   ZOOM %s" % [
			int(_missile_command_hud_state.get("cities_alive_count", 0)),
			int(_missile_command_hud_state.get("enemy_remaining_count", 0)),
			"ON" if bool(_missile_command_hud_state.get("zoom_active", false)) else "OFF"
		]
	if silo_label != null:
		var selected_silo_label := str(_missile_command_hud_state.get("selected_silo_id", "")).replace("_", " ").to_upper()
		if selected_silo_label == "":
			selected_silo_label = "BATTERY"
		silo_label.text = "%s  READY" % selected_silo_label
	if feedback_label != null:
		var feedback_text := str(_missile_command_hud_state.get("feedback_event_text", ""))
		feedback_label.text = feedback_text if feedback_text != "" else "左键发射  右键放大  Q 切井  Esc 退出"
		var tone := str(_missile_command_hud_state.get("feedback_event_tone", "neutral"))
		var feedback_color := Color(0.84, 0.9, 0.96, 1.0)
		match tone:
			"success":
				feedback_color = Color(0.8, 1.0, 0.76, 1.0)
			"warning":
				feedback_color = Color(1.0, 0.86, 0.64, 1.0)
			"action":
				feedback_color = Color(0.78, 0.96, 1.0, 1.0)
		feedback_label.add_theme_color_override("font_color", feedback_color)

func _apply_fishing_hud_state() -> void:
	var panel := get_node_or_null("Root/FishingHud") as PanelContainer
	var title_label := get_node_or_null("Root/FishingHud/Margin/VBox/Title") as Label
	var state_label := get_node_or_null("Root/FishingHud/Margin/VBox/State") as Label
	var target_label := get_node_or_null("Root/FishingHud/Margin/VBox/Target") as Label
	var result_label := get_node_or_null("Root/FishingHud/Margin/VBox/Result") as Label
	if panel != null:
		panel.visible = bool(_fishing_hud_state.get("visible", false))
	if title_label != null:
		title_label.text = str(_fishing_hud_state.get("display_name", "Lakeside Fishing")).to_upper()
	if state_label != null:
		var state_text := str(_fishing_hud_state.get("state_text", "")).strip_edges()
		if state_text == "":
			state_text = str(_fishing_hud_state.get("cast_state", "idle")).to_upper()
		state_label.text = state_text
	if target_label != null:
		var school_id := str(_fishing_hud_state.get("target_school_id", ""))
		target_label.text = "TARGET  %s" % school_id if school_id != "" else "TARGET  WAITING"
	if result_label != null:
		var result_text := str(_fishing_hud_state.get("result_text", "")).strip_edges()
		if result_text == "":
			result_text = "左键收杆 / E 放回"
		result_label.text = result_text

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
	var soccer_match_hud := get_node_or_null("Root/SoccerMatchHud") as Control
	if soccer_match_hud != null:
		soccer_match_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tennis_match_hud := get_node_or_null("Root/TennisMatchHud") as Control
	if tennis_match_hud != null:
		tennis_match_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var missile_command_hud := get_node_or_null("Root/MissileCommandHud") as Control
	if missile_command_hud != null:
		missile_command_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE

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

func _ensure_soccer_match_hud_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("SoccerMatchHud") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "SoccerMatchHud"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -150.0
	panel.offset_top = 18.0
	panel.offset_right = 150.0
	panel.offset_bottom = 108.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.03, 0.05, 0.06, 0.88)
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.86, 0.9, 0.94, 0.16)
	panel.add_theme_stylebox_override("panel", stylebox)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)
	var clock_label := Label.new()
	clock_label.name = "Clock"
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.add_theme_font_size_override("font_size", 28)
	clock_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92, 1.0))
	vbox.add_child(clock_label)
	var score_label := Label.new()
	score_label.name = "Score"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 18)
	score_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 1.0))
	vbox.add_child(score_label)
	var state_label := Label.new()
	state_label.name = "State"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.92, 1.0))
	vbox.add_child(state_label)
	var assist_label := Label.new()
	assist_label.name = "Assist"
	assist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assist_label.add_theme_font_size_override("font_size", 12)
	assist_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.86, 1.0))
	vbox.add_child(assist_label)
	root.add_child(panel)

func _ensure_tennis_match_hud_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("TennisMatchHud") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "TennisMatchHud"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -168.0
	panel.offset_top = 124.0
	panel.offset_right = 168.0
	panel.offset_bottom = 254.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.05, 0.08, 0.13, 0.88)
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.9, 0.96, 1.0, 0.16)
	panel.add_theme_stylebox_override("panel", stylebox)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	var games_label := Label.new()
	games_label.name = "Games"
	games_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	games_label.add_theme_font_size_override("font_size", 15)
	games_label.add_theme_color_override("font_color", Color(0.84, 0.94, 1.0, 1.0))
	vbox.add_child(games_label)
	var points_label := Label.new()
	points_label.name = "Points"
	points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	points_label.add_theme_font_size_override("font_size", 28)
	points_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.88, 1.0))
	vbox.add_child(points_label)
	var state_label := Label.new()
	state_label.name = "State"
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.add_theme_font_size_override("font_size", 13)
	state_label.add_theme_color_override("font_color", Color(0.74, 0.84, 0.92, 1.0))
	vbox.add_child(state_label)
	var assist_label := Label.new()
	assist_label.name = "Assist"
	assist_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	assist_label.add_theme_font_size_override("font_size", 12)
	assist_label.add_theme_color_override("font_color", Color(0.78, 0.92, 0.86, 1.0))
	vbox.add_child(assist_label)
	var coach_label := Label.new()
	coach_label.name = "Coach"
	coach_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coach_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coach_label.add_theme_font_size_override("font_size", 13)
	coach_label.add_theme_color_override("font_color", Color(0.86, 0.9, 0.96, 1.0))
	vbox.add_child(coach_label)
	root.add_child(panel)

func _ensure_tennis_feedback_audio_player() -> void:
	if _tennis_feedback_audio_player != null and is_instance_valid(_tennis_feedback_audio_player):
		return
	_tennis_feedback_audio_player = get_node_or_null("Root/TennisFeedbackAudio") as AudioStreamPlayer
	if _tennis_feedback_audio_player == null:
		var root := get_node_or_null("Root") as Control
		if root == null:
			return
		_tennis_feedback_audio_player = AudioStreamPlayer.new()
		_tennis_feedback_audio_player.name = "TennisFeedbackAudio"
		_tennis_feedback_audio_player.volume_db = -11.0
		root.add_child(_tennis_feedback_audio_player)

func _ensure_missile_command_hud_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("MissileCommandHud") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "MissileCommandHud"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -220.0
	panel.offset_top = 18.0
	panel.offset_right = 220.0
	panel.offset_bottom = 124.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.04, 0.08, 0.11, 0.9)
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.76, 0.9, 0.98, 0.18)
	panel.add_theme_stylebox_override("panel", stylebox)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	for label_spec in [
		{"name": "Wave", "font_size": 24, "color": Color(0.97, 0.94, 0.86, 1.0)},
		{"name": "Targets", "font_size": 15, "color": Color(0.82, 0.9, 0.98, 1.0)},
		{"name": "Silo", "font_size": 16, "color": Color(0.82, 1.0, 0.84, 1.0)},
		{"name": "Feedback", "font_size": 13, "color": Color(0.84, 0.9, 0.96, 1.0)},
	]:
		var label := Label.new()
		label.name = str(label_spec.get("name", "Label"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(label_spec.get("font_size", 14)))
		label.add_theme_color_override("font_color", label_spec.get("color", Color.WHITE))
		vbox.add_child(label)
	root.add_child(panel)

func _ensure_fishing_hud_view() -> void:
	var root := get_node_or_null("Root") as Control
	if root == null:
		return
	if root.get_node_or_null("FishingHud") != null:
		return
	var panel := PanelContainer.new()
	panel.name = "FishingHud"
	panel.anchor_left = 0.5
	panel.anchor_top = 0.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.0
	panel.offset_left = -220.0
	panel.offset_top = 136.0
	panel.offset_right = 220.0
	panel.offset_bottom = 236.0
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.05, 0.1, 0.08, 0.9)
	stylebox.corner_radius_top_left = 12
	stylebox.corner_radius_top_right = 12
	stylebox.corner_radius_bottom_left = 12
	stylebox.corner_radius_bottom_right = 12
	stylebox.border_width_left = 1
	stylebox.border_width_top = 1
	stylebox.border_width_right = 1
	stylebox.border_width_bottom = 1
	stylebox.border_color = Color(0.64, 0.88, 0.82, 0.18)
	panel.add_theme_stylebox_override("panel", stylebox)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)
	for label_spec in [
		{"name": "Title", "font_size": 18, "color": Color(0.94, 0.98, 0.88, 1.0)},
		{"name": "State", "font_size": 16, "color": Color(0.82, 0.96, 0.88, 1.0)},
		{"name": "Target", "font_size": 14, "color": Color(0.78, 0.92, 0.98, 1.0)},
		{"name": "Result", "font_size": 13, "color": Color(0.84, 0.9, 0.96, 1.0)},
	]:
		var label := Label.new()
		label.name = str(label_spec.get("name", "Label"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", int(label_spec.get("font_size", 14)))
		label.add_theme_color_override("font_color", label_spec.get("color", Color.WHITE))
		vbox.add_child(label)
	root.add_child(panel)

func _handle_tennis_feedback_event(state: Dictionary) -> void:
	var event_token := int(state.get("feedback_event_token", 0))
	if event_token <= 0 or event_token <= _last_tennis_feedback_event_token:
		return
	_last_tennis_feedback_event_token = event_token
	var event_kind := str(state.get("feedback_event_kind", ""))
	var event_text := str(state.get("feedback_event_text", "")).strip_edges()
	var event_tone := str(state.get("feedback_event_tone", "neutral"))
	if event_text != "":
		set_focus_message(event_text, _resolve_tennis_feedback_duration_sec(event_kind))
	_play_tennis_feedback_audio(event_kind, event_tone, event_token)

func _resolve_tennis_feedback_duration_sec(event_kind: String) -> float:
	match event_kind:
		"ready":
			return 1.35
		"serve_ready":
			return 1.25
		"point_result":
			return 1.8
		"game_break":
			return 1.8
		"final":
			return 2.4
		_:
			return 1.4

func _play_tennis_feedback_audio(event_kind: String, event_tone: String, event_token: int) -> void:
	_ensure_tennis_feedback_audio_player()
	_tennis_feedback_audio_state["play_count"] = int(_tennis_feedback_audio_state.get("play_count", 0)) + 1
	_tennis_feedback_audio_state["last_event_kind"] = event_kind
	_tennis_feedback_audio_state["last_event_token"] = event_token
	if _tennis_feedback_audio_player == null or not is_instance_valid(_tennis_feedback_audio_player):
		return
	_tennis_feedback_audio_player.stream = _resolve_tennis_feedback_audio_stream(event_kind, event_tone)
	_tennis_feedback_audio_player.play()

func _resolve_tennis_feedback_audio_stream(event_kind: String, event_tone: String) -> AudioStreamWAV:
	var cache_key := "%s|%s" % [event_kind, event_tone]
	if _tennis_feedback_audio_stream_cache.has(cache_key):
		return _tennis_feedback_audio_stream_cache.get(cache_key) as AudioStreamWAV
	var stream := _build_tennis_feedback_audio_stream(event_kind, event_tone)
	_tennis_feedback_audio_stream_cache[cache_key] = stream
	return stream

func _build_tennis_feedback_audio_stream(event_kind: String, event_tone: String) -> AudioStreamWAV:
	var pattern := _resolve_tennis_feedback_pattern(event_kind, event_tone)
	var data := PackedByteArray()
	for segment_variant in pattern:
		var segment: Dictionary = segment_variant
		data.append_array(_build_tennis_feedback_segment(
			float(segment.get("freq_hz", 660.0)),
			float(segment.get("duration_sec", 0.08)),
			float(segment.get("gain", 0.42))
		))
		var gap_sec := maxf(float(segment.get("gap_sec", 0.0)), 0.0)
		if gap_sec <= 0.0:
			continue
		var gap_sample_count := maxi(int(round(gap_sec * AUDIO_SAMPLE_RATE)), 1)
		var gap_bytes := PackedByteArray()
		gap_bytes.resize(gap_sample_count * 2)
		data.append_array(gap_bytes)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream

func _resolve_tennis_feedback_pattern(event_kind: String, event_tone: String) -> Array:
	match event_kind:
		"ready":
			return [
				{"freq_hz": 900.0, "duration_sec": 0.085, "gain": 0.48},
			]
		"serve_ready":
			return [
				{"freq_hz": 620.0, "duration_sec": 0.075, "gain": 0.42},
			]
		"point_result":
			if event_tone == "success":
				return [
					{"freq_hz": 620.0, "duration_sec": 0.06, "gain": 0.34, "gap_sec": 0.025},
					{"freq_hz": 880.0, "duration_sec": 0.11, "gain": 0.46},
				]
			return [
				{"freq_hz": 520.0, "duration_sec": 0.075, "gain": 0.34, "gap_sec": 0.025},
				{"freq_hz": 340.0, "duration_sec": 0.13, "gain": 0.44},
			]
		"game_break":
			return [
				{"freq_hz": 540.0, "duration_sec": 0.07, "gain": 0.34, "gap_sec": 0.025},
				{"freq_hz": 700.0, "duration_sec": 0.09, "gain": 0.38},
			]
		"final":
			if event_tone == "success":
				return [
					{"freq_hz": 520.0, "duration_sec": 0.07, "gain": 0.34, "gap_sec": 0.02},
					{"freq_hz": 660.0, "duration_sec": 0.08, "gain": 0.38, "gap_sec": 0.02},
					{"freq_hz": 880.0, "duration_sec": 0.16, "gain": 0.48},
				]
			return [
				{"freq_hz": 520.0, "duration_sec": 0.08, "gain": 0.34, "gap_sec": 0.02},
				{"freq_hz": 420.0, "duration_sec": 0.09, "gain": 0.38, "gap_sec": 0.02},
				{"freq_hz": 300.0, "duration_sec": 0.16, "gain": 0.46},
			]
		_:
			if event_tone == "action":
				return [
					{"freq_hz": 700.0, "duration_sec": 0.08, "gain": 0.4},
				]
			if event_tone == "warning":
				return [
					{"freq_hz": 420.0, "duration_sec": 0.09, "gain": 0.42},
				]
			return [
				{"freq_hz": 760.0, "duration_sec": 0.08, "gain": 0.42},
			]

func _build_tennis_feedback_segment(freq_hz: float, duration_sec: float, gain: float) -> PackedByteArray:
	var sample_count := maxi(int(round(maxf(duration_sec, 0.02) * AUDIO_SAMPLE_RATE)), 1)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for sample_index in range(sample_count):
		var progress := float(sample_index) / float(maxi(sample_count - 1, 1))
		var time_sec := float(sample_index) / float(AUDIO_SAMPLE_RATE)
		var envelope := sin(progress * PI)
		var vibrato := sin(TAU * 7.0 * time_sec) * 0.018
		var sample := sin(TAU * (freq_hz * (1.0 + vibrato)) * time_sec) * envelope * gain
		var pcm_value := int(round(clampf(sample, -1.0, 1.0) * 32767.0))
		if pcm_value < 0:
			pcm_value += 65536
		data[sample_index * 2] = pcm_value & 0xFF
		data[sample_index * 2 + 1] = (pcm_value >> 8) & 0xFF
	return data

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
