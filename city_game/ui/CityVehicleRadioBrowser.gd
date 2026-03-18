extends Control
class_name CityVehicleRadioBrowser

signal close_requested
signal tab_selected(tab_id: String)
signal browse_country_selected(country_code: String)
signal browse_root_requested
signal filter_text_changed(filter_text: String)
signal station_selected(station_id: String)
signal current_station_favorite_toggled(station_id: String)
signal preset_assign_requested(slot_index: int, station_id: String)

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
var _suppress_filter_signal := false

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
	toolbar.add_child(back_button)
	toolbar.add_child(country_label)
	toolbar.add_child(filter_edit)
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
	detail_title.text = "当前播放"
	right_vbox.add_child(detail_title)

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
		"presets":
			_rebuild_station_collection(list_vbox, _state.get("presets", []) as Array, "当前还没有 preset")
		"favorites":
			_rebuild_station_collection(list_vbox, _state.get("favorites", []) as Array, "当前还没有 favorites")
		"recents":
			_rebuild_station_collection(list_vbox, _state.get("recents", []) as Array, "当前还没有 recents")
		_:
			_add_placeholder_label(list_vbox, "当前播放信息与操作在右侧面板。")

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
		for country_variant in countries:
			var country: Dictionary = country_variant as Dictionary
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.text = "%s  (%d 台)" % [
				str(country.get("display_name", country.get("country_code", ""))),
				int(country.get("station_count", 0)),
			]
			var country_code := str(country.get("country_code", ""))
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
	var detail_title := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/DetailTitle") as Label
	var detail_text := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/DetailText") as RichTextLabel
	var favorite_button := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/FavoriteButton") as Button
	var preset_label := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/PresetLabel") as Label
	var preset_grid := get_node_or_null("Panel/Shell/Body/RightPanel/RightVBox/PresetGrid") as GridContainer
	var current_station := _normalize_station_snapshot((_state.get("current_playing", {}) as Dictionary).get("selected_station_snapshot", {}))
	var current_station_id := str(current_station.get("station_id", ""))
	var has_station := current_station_id != ""
	if detail_title != null:
		detail_title.text = "当前播放" if has_station else "未选择电台"
	if detail_text != null:
		detail_text.text = _build_detail_text(current_station)
	if favorite_button != null:
		favorite_button.visible = has_station
		favorite_button.disabled = not has_station
		favorite_button.text = "取消收藏当前台" if _is_station_favorited(current_station_id) else "收藏当前台"
	if preset_label != null:
		preset_label.visible = has_station
	if preset_grid != null:
		preset_grid.visible = has_station
		for child in preset_grid.get_children():
			var button := child as Button
			if button == null:
				continue
			var slot_index := int(button.name.trim_prefix("PresetButton"))
			button.disabled = not has_station
			button.text = _build_preset_button_text(slot_index, current_station_id)

func _build_detail_text(current_station: Dictionary) -> String:
	if current_station.is_empty():
		return "[color=#B9D8D2]从左侧列表选择电台后，这里会显示当前播放详情，并可直接收藏或写入 preset。[/color]"
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

func _on_close_button_pressed() -> void:
	close_requested.emit()

func _on_back_button_pressed() -> void:
	browse_root_requested.emit()

func _on_filter_text_changed(new_text: String) -> void:
	if _suppress_filter_signal:
		return
	filter_text_changed.emit(new_text)

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
