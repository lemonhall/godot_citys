extends Control
class_name CityVehicleRadioBrowser

signal close_requested
signal tab_selected(tab_id: String)
signal browse_country_selected(country_code: String)
signal browse_root_requested
signal catalog_refresh_requested
signal filter_text_changed(filter_text: String)
signal proxy_mode_selected(proxy_mode: String)
signal station_selected(station_id: String)
signal current_station_favorite_toggled(station_id: String)
signal preset_assign_requested(slot_index: int, station_id: String)
signal play_requested
signal stop_requested
signal volume_linear_changed(volume_linear: float)

const COUNTRY_FLAG_ICON_DIRECTORY := "res://city_game/assets/ui/flags/4x3"
const COUNTRY_FLAG_ICON_FALLBACK_PATH := COUNTRY_FLAG_ICON_DIRECTORY + "/_unknown.svg"
const COUNTRY_FLAG_ICON_WIDTH := 30
const COUNTRY_FLAG_ICON_HEIGHT := 22

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
	"network": {
		"proxy_mode": "direct",
	},
}
var _suppress_filter_signal := false
var _suppress_volume_signal := false
var _country_flag_texture_cache := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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
		"network": (state.get("network", {}) as Dictionary).duplicate(true),
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
	backdrop.color = Color(0.03, 0.05, 0.06, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 56.0
	panel.offset_top = 40.0
	panel.offset_right = -56.0
	panel.offset_bottom = -40.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
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

	var shell := VBoxContainer.new()
	shell.name = "Shell"
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.offset_left = 0.0
	shell.offset_top = 0.0
	shell.offset_right = 0.0
	shell.offset_bottom = 0.0

	var header := HBoxContainer.new()
	header.name = "Header"
	var title := Label.new()
	title.name = "Title"
	title.text = "Vehicle Radio"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "B / Esc 关闭"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var close_button := Button.new()
	close_button.name = "CloseButton"
	close_button.text = "关闭"
	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)
	header.add_child(title)
	header.add_child(hint)
	header.add_child(close_button)
	shell.add_child(header)

	var tab_bar := HBoxContainer.new()
	tab_bar.name = "TabBar"
	shell.add_child(tab_bar)

	var body := HSplitContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.split_offset = 540

	var left_panel := PanelContainer.new()
	left_panel.name = "LeftPanel"
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.05, 0.08, 0.1, 0.92)
	left_style.corner_radius_top_left = 10
	left_style.corner_radius_top_right = 10
	left_style.corner_radius_bottom_left = 10
	left_style.corner_radius_bottom_right = 10
	left_style.content_margin_left = 14.0
	left_style.content_margin_top = 12.0
	left_style.content_margin_right = 14.0
	left_style.content_margin_bottom = 12.0
	left_panel.add_theme_stylebox_override("panel", left_style)

	var left_vbox := VBoxContainer.new()
	left_vbox.name = "LeftVBox"
	left_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	left_vbox.offset_left = 0.0
	left_vbox.offset_top = 0.0
	left_vbox.offset_right = 0.0
	left_vbox.offset_bottom = 0.0

	var toolbar := HBoxContainer.new()
	toolbar.name = "Toolbar"
	var back_button := Button.new()
	back_button.name = "BackButton"
	back_button.text = "返回国家列表"
	if not back_button.pressed.is_connected(_on_back_button_pressed):
		back_button.pressed.connect(_on_back_button_pressed)
	var country_label := Label.new()
	country_label.name = "CountryLabel"
	country_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var filter_edit := LineEdit.new()
	filter_edit.name = "FilterEdit"
	filter_edit.placeholder_text = "筛选台名 / 语言 / 编码"
	filter_edit.custom_minimum_size = Vector2(260.0, 0.0)
	if not filter_edit.text_changed.is_connected(_on_filter_text_changed):
		filter_edit.text_changed.connect(_on_filter_text_changed)
	var refresh_button := Button.new()
	refresh_button.name = "RefreshButton"
	refresh_button.text = "Refresh"
	if not refresh_button.pressed.is_connected(_on_refresh_button_pressed):
		refresh_button.pressed.connect(_on_refresh_button_pressed)
	toolbar.add_child(back_button)
	toolbar.add_child(country_label)
	toolbar.add_child(filter_edit)
	toolbar.add_child(refresh_button)
	left_vbox.add_child(toolbar)

	var list_scroll := ScrollContainer.new()
	list_scroll.name = "ListScroll"
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list_vbox := VBoxContainer.new()
	list_vbox.name = "List"
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list_vbox)
	left_vbox.add_child(list_scroll)
	left_panel.add_child(left_vbox)

	var right_panel := PanelContainer.new()
	right_panel.name = "RightPanel"
	right_panel.add_theme_stylebox_override("panel", left_style.duplicate())

	var right_vbox := VBoxContainer.new()
	right_vbox.name = "RightVBox"
	right_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	right_vbox.offset_left = 0.0
	right_vbox.offset_top = 0.0
	right_vbox.offset_right = 0.0
	right_vbox.offset_bottom = 0.0

	var detail_title := Label.new()
	detail_title.name = "DetailTitle"
	detail_title.text = "播放控制"
	right_vbox.add_child(detail_title)

	var transport_row := HBoxContainer.new()
	transport_row.name = "TransportRow"
	var play_button := Button.new()
	play_button.name = "PlayButton"
	play_button.text = "Play"
	if not play_button.pressed.is_connected(_on_play_button_pressed):
		play_button.pressed.connect(_on_play_button_pressed)
	var stop_button := Button.new()
	stop_button.name = "StopButton"
	stop_button.text = "Stop"
	if not stop_button.pressed.is_connected(_on_stop_button_pressed):
		stop_button.pressed.connect(_on_stop_button_pressed)
	var volume_label := Label.new()
	volume_label.name = "VolumeLabel"
	volume_label.text = "音量"
	var volume_slider := HSlider.new()
	volume_slider.name = "VolumeSlider"
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	if not volume_slider.value_changed.is_connected(_on_volume_slider_changed):
		volume_slider.value_changed.connect(_on_volume_slider_changed)
	transport_row.add_child(play_button)
	transport_row.add_child(stop_button)
	transport_row.add_child(volume_label)
	transport_row.add_child(volume_slider)
	right_vbox.add_child(transport_row)

	var proxy_mode_row := HBoxContainer.new()
	proxy_mode_row.name = "ProxyModeRow"
	var use_direct_proxy_button := Button.new()
	use_direct_proxy_button.name = "UseDirectProxyButton"
	use_direct_proxy_button.text = "直连"
	use_direct_proxy_button.toggle_mode = true
	if not use_direct_proxy_button.pressed.is_connected(_on_use_direct_proxy_button_pressed):
		use_direct_proxy_button.pressed.connect(_on_use_direct_proxy_button_pressed)
	var use_system_proxy_button := Button.new()
	use_system_proxy_button.name = "UseSystemProxyButton"
	use_system_proxy_button.text = "系统代理"
	use_system_proxy_button.toggle_mode = true
	if not use_system_proxy_button.pressed.is_connected(_on_use_system_proxy_button_pressed):
		use_system_proxy_button.pressed.connect(_on_use_system_proxy_button_pressed)
	var use_local_proxy_button := Button.new()
	use_local_proxy_button.name = "UseLocalProxyButton"
	use_local_proxy_button.text = "本机 127.0.0.1:7897"
	use_local_proxy_button.toggle_mode = true
	use_local_proxy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not use_local_proxy_button.pressed.is_connected(_on_use_local_proxy_button_pressed):
		use_local_proxy_button.pressed.connect(_on_use_local_proxy_button_pressed)
	proxy_mode_row.add_child(use_direct_proxy_button)
	proxy_mode_row.add_child(use_system_proxy_button)
	proxy_mode_row.add_child(use_local_proxy_button)
	right_vbox.add_child(proxy_mode_row)

	var proxy_action_row := HBoxContainer.new()
	proxy_action_row.name = "ProxyActionRow"
	var proxy_refresh_button := Button.new()
	proxy_refresh_button.name = "ProxyRefreshButton"
	proxy_refresh_button.text = "刷新目录"
	if not proxy_refresh_button.pressed.is_connected(_on_proxy_refresh_button_pressed):
		proxy_refresh_button.pressed.connect(_on_proxy_refresh_button_pressed)
	proxy_action_row.add_child(proxy_refresh_button)
	right_vbox.add_child(proxy_action_row)

	var detail_text := RichTextLabel.new()
	detail_text.name = "DetailText"
	detail_text.bbcode_enabled = true
	detail_text.fit_content = false
	detail_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_text.scroll_active = true
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(detail_text)

	var favorite_button := Button.new()
	favorite_button.name = "FavoriteButton"
	favorite_button.text = "收藏当前台"
	if not favorite_button.pressed.is_connected(_on_favorite_button_pressed):
		favorite_button.pressed.connect(_on_favorite_button_pressed)
	right_vbox.add_child(favorite_button)

	var preset_label := Label.new()
	preset_label.name = "PresetLabel"
	preset_label.text = "写入 Quick Preset"
	right_vbox.add_child(preset_label)

	var preset_grid := GridContainer.new()
	preset_grid.name = "PresetGrid"
	preset_grid.columns = 4
	right_vbox.add_child(preset_grid)

	right_panel.add_child(right_vbox)
	body.add_child(left_panel)
	body.add_child(right_panel)
	shell.add_child(body)
	panel.add_child(shell)
	add_child(panel)

	for slot_index in range(8):
		var preset_button := Button.new()
		preset_button.name = "PresetButton%d" % slot_index
		preset_button.text = "P%d" % (slot_index + 1)
		preset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		preset_button.pressed.connect(func() -> void:
			_on_preset_button_pressed(slot_index)
		)
		preset_grid.add_child(preset_button)

func _apply_state() -> void:
	var panel := get_node_or_null("Panel") as PanelContainer
	var title := get_node_or_null("Panel/Shell/Header/Title") as Label
	var hint := get_node_or_null("Panel/Shell/Header/Hint") as Label
	if panel != null:
		panel.visible = bool(_state.get("visible", false))
	visible = bool(_state.get("visible", false))
	if title != null:
		title.text = "Vehicle Radio"
	if hint != null:
		hint.text = "B / Esc 关闭"
	_rebuild_tab_bar()
	_apply_toolbar_state()
	_rebuild_list_content()
	_apply_detail_panel()

func _rebuild_tab_bar() -> void:
	var tab_bar := get_node_or_null("Panel/Shell/TabBar") as HBoxContainer
	if tab_bar == null:
		return
	for child in tab_bar.get_children():
		child.queue_free()
	var selected_tab_id := str(_state.get("selected_tab_id", "browse"))
	for tab_variant in _state.get("tabs", []):
		var tab: Dictionary = tab_variant as Dictionary
		var tab_id := str(tab.get("tab_id", ""))
		var button := Button.new()
		button.text = str(tab.get("label", tab_id))
		button.toggle_mode = true
		button.button_pressed = tab_id == selected_tab_id
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			tab_selected.emit(tab_id)
		)
		tab_bar.add_child(button)

func _apply_toolbar_state() -> void:
	var browse_state: Dictionary = _state.get("browse", {}) as Dictionary
	var selected_tab_id := str(_state.get("selected_tab_id", "browse"))
	var is_browse := selected_tab_id == "browse"
	var is_station_browse := is_browse and str(browse_state.get("root_kind", "countries")) == "stations"
	var toolbar := get_node_or_null("Panel/Shell/Body/LeftPanel/LeftVBox/Toolbar") as HBoxContainer
	var back_button := get_node_or_null("Panel/Shell/Body/LeftPanel/LeftVBox/Toolbar/BackButton") as Button
	var country_label := get_node_or_null("Panel/Shell/Body/LeftPanel/LeftVBox/Toolbar/CountryLabel") as Label
	var filter_edit := get_node_or_null("Panel/Shell/Body/LeftPanel/LeftVBox/Toolbar/FilterEdit") as LineEdit
	var refresh_button := get_node_or_null("Panel/Shell/Body/LeftPanel/LeftVBox/Toolbar/RefreshButton") as Button
	if toolbar != null:
		toolbar.visible = is_browse
	if back_button != null:
		back_button.visible = is_station_browse
	if country_label != null:
		country_label.text = "国家：%s" % str(browse_state.get("selected_country_code", "全部"))
		country_label.visible = is_station_browse
	if filter_edit != null:
		filter_edit.visible = is_station_browse
		_suppress_filter_signal = true
		filter_edit.text = str(browse_state.get("filter_text", ""))
		_suppress_filter_signal = false
	if refresh_button != null:
		refresh_button.visible = is_browse

func _rebuild_list_content() -> void:
	var list_vbox := get_node_or_null("Panel/Shell/Body/LeftPanel/LeftVBox/ListScroll/List") as VBoxContainer
	if list_vbox == null:
		return
	for child in list_vbox.get_children():
		child.queue_free()
	var selected_tab_id := str(_state.get("selected_tab_id", "browse"))
	match selected_tab_id:
		"browse":
			_rebuild_browse_content(list_vbox)
		"proxy":
			_add_placeholder_label(list_vbox, "网络访问与代理设置在右侧面板。切换代理模式后，可直接点击刷新目录重新同步国家列表。")
		"presets":
			_rebuild_station_collection(list_vbox, _state.get("presets", []) as Array, "当前还没有 preset")
		"favorites":
			_rebuild_station_collection(list_vbox, _state.get("favorites", []) as Array, "当前还没有 favorites")
		"recents":
			_rebuild_station_collection(list_vbox, _state.get("recents", []) as Array, "当前还没有 recents")
		_:
			_add_placeholder_label(list_vbox, "电台详情与播放控制在右侧面板。")

func _rebuild_browse_content(list_vbox: VBoxContainer) -> void:
	var browse_state: Dictionary = _state.get("browse", {}) as Dictionary
	var root_kind := str(browse_state.get("root_kind", "countries"))
	var loading := bool(browse_state.get("loading", false))
	var load_error := str(browse_state.get("load_error", "")).strip_edges()
	if root_kind == "countries":
		var countries := browse_state.get("countries", []) as Array
		if countries.is_empty():
			if loading:
				_add_placeholder_label(list_vbox, "国家目录同步中...")
			elif load_error != "":
				_add_placeholder_label(list_vbox, "国家目录加载失败：%s" % load_error)
			else:
				_add_placeholder_label(list_vbox, "没有可浏览的国家索引。")
			return
		var last_section := ""
		for country_variant in countries:
			var country: Dictionary = country_variant as Dictionary
			var section := str(country.get("list_section", "general"))
			if last_section != "" and section != last_section:
				list_vbox.add_child(HSeparator.new())
			last_section = section
			var country_code := str(country.get("country_code", ""))
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0.0, 34.0)
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = str(country.get("display_label", "%s  (%d 台)" % [
				str(country.get("display_name", country.get("country_code", ""))),
				int(country.get("station_count", 0)),
			]))
			_apply_country_flag_icon(button, country_code)
			button.pressed.connect(func() -> void:
				browse_country_selected.emit(country_code)
			)
			list_vbox.add_child(button)
		return
	var stations := browse_state.get("stations", []) as Array
	if stations.is_empty():
		if loading:
			_add_placeholder_label(list_vbox, "电台目录同步中...")
		elif load_error != "":
			_add_placeholder_label(list_vbox, "电台目录加载失败：%s" % load_error)
		else:
			_add_placeholder_label(list_vbox, "当前筛选条件下没有可用电台。")
		return
	_rebuild_station_collection(list_vbox, stations, "当前筛选条件下没有可用电台。")

func _rebuild_station_collection(list_vbox: VBoxContainer, stations: Array, empty_text: String) -> void:
	if stations.is_empty():
		_add_placeholder_label(list_vbox, empty_text)
		return
	for station_variant in stations:
		var station: Dictionary = _normalize_station_snapshot(station_variant)
		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = _build_station_button_text(station)
		var station_id := str(station.get("station_id", ""))
		button.pressed.connect(func() -> void:
			station_selected.emit(station_id)
		)
		list_vbox.add_child(button)

func _apply_detail_panel() -> void:
	var selected_tab_id := str(_state.get("selected_tab_id", "browse"))
	var detail_title := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/DetailTitle") as Label
	var transport_row := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/TransportRow") as HBoxContainer
	var play_button := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/TransportRow/PlayButton") as Button
	var stop_button := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/TransportRow/StopButton") as Button
	var volume_slider := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/TransportRow/VolumeSlider") as HSlider
	var proxy_mode_row := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/ProxyModeRow") as HBoxContainer
	var use_direct_proxy_button := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/ProxyModeRow/UseDirectProxyButton") as Button
	var use_system_proxy_button := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/ProxyModeRow/UseSystemProxyButton") as Button
	var use_local_proxy_button := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/ProxyModeRow/UseLocalProxyButton") as Button
	var proxy_action_row := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/ProxyActionRow") as HBoxContainer
	var detail_text := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/DetailText") as RichTextLabel
	var favorite_button := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/FavoriteButton") as Button
	var preset_label := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/PresetLabel") as Label
	var preset_grid := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/PresetGrid") as GridContainer
	var network_state := _state.get("network", {}) as Dictionary
	var is_proxy_tab := selected_tab_id == "proxy"
	var runtime_state := _state.get("current_playing", {}) as Dictionary
	var current_station := _normalize_station_snapshot(runtime_state.get("selected_station_snapshot", {}))
	var current_station_id := str(current_station.get("station_id", ""))
	var has_station := current_station_id != ""
	var playback_state := str(runtime_state.get("playback_state", "stopped"))
	var volume_linear := clampf(float(runtime_state.get("volume_linear", 1.0)), 0.0, 1.0)
	if detail_title != null:
		detail_title.text = "Proxy / Network" if is_proxy_tab else ("播放控制" if has_station else "未选择电台")
	if transport_row != null:
		transport_row.visible = not is_proxy_tab
	if proxy_mode_row != null:
		proxy_mode_row.visible = is_proxy_tab
	if use_direct_proxy_button != null:
		use_direct_proxy_button.button_pressed = str(network_state.get("proxy_mode", "direct")) == "direct"
	if use_system_proxy_button != null:
		use_system_proxy_button.button_pressed = str(network_state.get("proxy_mode", "")) == "system_proxy"
	if use_local_proxy_button != null:
		use_local_proxy_button.button_pressed = str(network_state.get("proxy_mode", "")) == "local_proxy"
	if proxy_action_row != null:
		proxy_action_row.visible = is_proxy_tab
	if play_button != null:
		play_button.disabled = not has_station or playback_state == "playing"
	if stop_button != null:
		stop_button.disabled = not has_station or playback_state == "stopped"
	if volume_slider != null:
		volume_slider.editable = has_station
		_suppress_volume_signal = true
		volume_slider.value = round(volume_linear * 100.0)
		_suppress_volume_signal = false
	if detail_text != null:
		detail_text.text = _build_proxy_detail_text(network_state) if is_proxy_tab else _build_detail_text(current_station)
	if favorite_button != null:
		favorite_button.visible = has_station and not is_proxy_tab
		favorite_button.disabled = not has_station
		favorite_button.text = "取消收藏当前台" if _is_station_favorited(current_station_id) else "收藏当前台"
	if preset_label != null:
		preset_label.visible = has_station and not is_proxy_tab
	if preset_grid != null:
		preset_grid.visible = has_station and not is_proxy_tab
		for child in preset_grid.get_children():
			var button := child as Button
			if button == null:
				continue
			var slot_index := int(button.name.trim_prefix("PresetButton"))
			button.disabled = not has_station
			button.text = _build_preset_button_text(slot_index, current_station_id)

func _build_detail_text(current_station: Dictionary) -> String:
	if current_station.is_empty():
		return "[color=#B9D8D2]从左侧列表选择电台后，这里会显示播放详情，并可直接 Play / Stop、调节音量、收藏或写入 preset。[/color]"
	var runtime_state := _state.get("current_playing", {}) as Dictionary
	var metadata: Dictionary = runtime_state.get("metadata", {}) as Dictionary
	var lines := PackedStringArray([
		"[b]%s[/b]" % str(current_station.get("station_name", "")),
		"状态：power=%s  playback=%s  buffer=%s" % [
			str(runtime_state.get("power_state", "off")),
			str(runtime_state.get("playback_state", "stopped")),
			str(runtime_state.get("buffer_state", "idle")),
		],
		"后端：%s  延迟：%d ms  欠载：%d" % [
			str(runtime_state.get("backend_id", "")),
			int(runtime_state.get("latency_ms", 0)),
			int(runtime_state.get("underflow_count", 0)),
		],
		"国家：%s" % str(current_station.get("country", "")),
		"语言：%s" % str(current_station.get("language", "")),
		"编码：%s" % str(current_station.get("codec", "")),
	])
	var stream_title := str(metadata.get("stream_title", ""))
	if stream_title != "":
		lines.append("流标题：%s" % stream_title)
	var preset_slot := _find_station_preset_slot(str(current_station.get("station_id", "")))
	if preset_slot >= 0:
		lines.append("当前 preset：P%d" % (preset_slot + 1))
	var resolved_url := str(runtime_state.get("resolved_url", ""))
	if resolved_url != "":
		lines.append("流地址：%s" % resolved_url)
	var error_message := str(runtime_state.get("error_message", "")).strip_edges()
	if error_message != "":
		lines.append("错误：%s" % error_message)
	return "\n".join(lines)

func _build_proxy_detail_text(network_state: Dictionary) -> String:
	var lines := PackedStringArray([
		"[b]目录网络访问[/b]",
		"当前模式：%s" % str(network_state.get("proxy_mode_label", network_state.get("proxy_mode", "direct"))),
		"有效代理：%s" % (
			"%s:%d" % [str(network_state.get("proxy_host", "")), int(network_state.get("proxy_port", 0))]
			if bool(network_state.get("proxy_enabled", false))
			else "未启用"
		),
	])
	var proxy_error := str(network_state.get("proxy_error", "")).strip_edges()
	if proxy_error != "":
		lines.append("代理状态：%s" % proxy_error)
	var env_https_proxy := str(network_state.get("env_https_proxy", "")).strip_edges()
	var env_http_proxy := str(network_state.get("env_http_proxy", "")).strip_edges()
	if env_https_proxy != "":
		lines.append("HTTPS_PROXY：%s" % env_https_proxy)
	if env_http_proxy != "":
		lines.append("HTTP_PROXY：%s" % env_http_proxy)
	var countries_error := str(network_state.get("countries_error", "")).strip_edges()
	if countries_error != "":
		lines.append("国家目录错误：%s" % countries_error)
	var stations_error := str(network_state.get("stations_error", "")).strip_edges()
	if stations_error != "":
		lines.append("电台目录错误：%s" % stations_error)
	lines.append("说明：Radio Browser 目录请求在当前网络环境下更适合走代理。切换代理模式后，点击“刷新目录”即可重新拉取国家列表或当前国家电台。")
	return "\n".join(lines)

func _build_station_button_text(station: Dictionary) -> String:
	var labels := PackedStringArray()
	if bool(station.get("favorite_state", false)):
		labels.append("★")
	var preset_slot := int(station.get("preset_slot", -1))
	if preset_slot >= 0:
		labels.append("P%d" % (preset_slot + 1))
	labels.append(str(station.get("station_name", "")))
	var tail := " · ".join([
		str(station.get("country", "")),
		str(station.get("language", "")),
		str(station.get("codec", "")),
	]).strip_edges()
	if tail != "":
		labels.append("(%s)" % tail)
	return " ".join(labels)

func _build_preset_button_text(slot_index: int, station_id: String) -> String:
	var preset_station_id := _find_preset_station_id(slot_index)
	if preset_station_id == station_id and station_id != "":
		return "P%d 已绑定" % (slot_index + 1)
	return "写入 P%d" % (slot_index + 1)

func _find_preset_station_id(slot_index: int) -> String:
	for preset_variant in _state.get("presets", []):
		if not (preset_variant is Dictionary):
			continue
		var preset := preset_variant as Dictionary
		if int(preset.get("slot_index", -1)) != slot_index:
			continue
		var station_snapshot := _normalize_station_snapshot(preset.get("station_snapshot", {}))
		return str(station_snapshot.get("station_id", ""))
	return ""

func _find_station_preset_slot(station_id: String) -> int:
	if station_id == "":
		return -1
	for preset_variant in _state.get("presets", []):
		if not (preset_variant is Dictionary):
			continue
		var preset := preset_variant as Dictionary
		var station_snapshot := _normalize_station_snapshot(preset.get("station_snapshot", {}))
		if str(station_snapshot.get("station_id", "")) == station_id:
			return int(preset.get("slot_index", -1))
	return -1

func _is_station_favorited(station_id: String) -> bool:
	if station_id == "":
		return false
	for favorite_variant in _state.get("favorites", []):
		var favorite := _normalize_station_snapshot(favorite_variant)
		if str(favorite.get("station_id", "")) == station_id:
			return true
	return false

func _normalize_station_snapshot(station_variant: Variant) -> Dictionary:
	if not (station_variant is Dictionary):
		return {}
	var station: Dictionary = station_variant as Dictionary
	if station.has("station_snapshot") and station.get("station_snapshot") is Dictionary:
		return (station.get("station_snapshot", {}) as Dictionary).duplicate(true)
	return station.duplicate(true)

func _add_placeholder_label(list_vbox: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list_vbox.add_child(label)

func _apply_country_flag_icon(button: Button, country_code: String) -> void:
	if button == null:
		return
	button.icon = _resolve_country_flag_texture(country_code)

func _resolve_country_flag_texture(country_code: String) -> Texture2D:
	var cache_key := country_code.strip_edges().to_lower()
	if cache_key == "":
		cache_key = "_unknown"
	if _country_flag_texture_cache.has(cache_key):
		return _country_flag_texture_cache.get(cache_key) as Texture2D
	var texture := _load_country_flag_texture_from_svg(_build_country_flag_icon_path(cache_key))
	if texture == null:
		texture = _load_country_flag_texture_from_svg(COUNTRY_FLAG_ICON_FALLBACK_PATH)
	_country_flag_texture_cache[cache_key] = texture
	return texture

func _build_country_flag_icon_path(country_code: String) -> String:
	var normalized_country_code := country_code.strip_edges().to_lower()
	if normalized_country_code.length() != 2:
		return COUNTRY_FLAG_ICON_FALLBACK_PATH
	return "%s/%s.svg" % [COUNTRY_FLAG_ICON_DIRECTORY, normalized_country_code]

func _load_country_flag_texture_from_svg(path: String) -> Texture2D:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var svg_bytes := FileAccess.get_file_as_bytes(path)
	if svg_bytes.is_empty():
		return null
	var image := Image.new()
	var load_error := image.load_svg_from_buffer(svg_bytes)
	if load_error != OK:
		return null
	image.resize(COUNTRY_FLAG_ICON_WIDTH, COUNTRY_FLAG_ICON_HEIGHT, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _on_close_button_pressed() -> void:
	close_requested.emit()

func _on_back_button_pressed() -> void:
	browse_root_requested.emit()

func _on_refresh_button_pressed() -> void:
	catalog_refresh_requested.emit()

func _on_filter_text_changed(new_text: String) -> void:
	if _suppress_filter_signal:
		return
	filter_text_changed.emit(new_text)

func _on_use_direct_proxy_button_pressed() -> void:
	proxy_mode_selected.emit("direct")

func _on_use_system_proxy_button_pressed() -> void:
	proxy_mode_selected.emit("system_proxy")

func _on_use_local_proxy_button_pressed() -> void:
	proxy_mode_selected.emit("local_proxy")

func _on_proxy_refresh_button_pressed() -> void:
	catalog_refresh_requested.emit()

func _on_favorite_button_pressed() -> void:
	var current_station := _normalize_station_snapshot((_state.get("current_playing", {}) as Dictionary).get("selected_station_snapshot", {}))
	var station_id := str(current_station.get("station_id", ""))
	if station_id == "":
		return
	current_station_favorite_toggled.emit(station_id)

func _on_preset_button_pressed(slot_index: int) -> void:
	var current_station := _normalize_station_snapshot((_state.get("current_playing", {}) as Dictionary).get("selected_station_snapshot", {}))
	var station_id := str(current_station.get("station_id", ""))
	if station_id == "":
		return
	preset_assign_requested.emit(slot_index, station_id)

func _on_play_button_pressed() -> void:
	play_requested.emit()

func _on_stop_button_pressed() -> void:
	stop_requested.emit()

func _on_volume_slider_changed(value: float) -> void:
	if _suppress_volume_signal:
		return
	volume_linear_changed.emit(clampf(value / 100.0, 0.0, 1.0))
