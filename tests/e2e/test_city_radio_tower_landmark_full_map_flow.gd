extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for radio tower landmark full-map flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Radio tower landmark full-map flow requires full-map open control"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Radio tower landmark full-map flow requires map render state introspection"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "Radio tower landmark full-map flow requires minimap snapshot introspection"):
		return

	world.set_full_map_open(true)
	var map_state: Dictionary = {}
	var radio_tower_marker: Dictionary = {}
	for _frame in range(90):
		await process_frame
		map_state = world.get_map_screen_state()
		radio_tower_marker = _find_marker_by_icon_id(map_state.get("pin_markers", []), "radio_tower")
		if not radio_tower_marker.is_empty():
			break
	if not T.require_true(self, not radio_tower_marker.is_empty(), "Radio tower landmark full-map flow must surface the radio tower marker after opening the map"):
		return
	if not T.require_true(self, str(radio_tower_marker.get("icon_glyph", "")) == "📡", "Radio tower landmark full-map flow must render the radio tower glyph in UI state"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	for pin_variant in pin_overlay.get("pins", []):
		var pin: Dictionary = pin_variant
		if not T.require_true(self, str(pin.get("icon_id", "")) != "radio_tower", "Radio tower landmark full-map flow must keep the radio tower out of minimap overlay"):
			return

	world.queue_free()
	T.pass_and_quit(self)

func _find_marker_by_icon_id(markers: Array, icon_id: String) -> Dictionary:
	for marker_variant in markers:
		var marker: Dictionary = marker_variant
		if str(marker.get("icon_id", "")) == icon_id:
			return marker
	return {}
