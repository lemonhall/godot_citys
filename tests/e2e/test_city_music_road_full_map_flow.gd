extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for music road full-map flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Music road full-map flow requires full-map open control"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Music road full-map flow requires map render state introspection"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "Music road full-map flow requires minimap snapshot introspection"):
		return

	world.set_full_map_open(true)
	var map_state: Dictionary = {}
	var music_road_marker: Dictionary = {}
	for _frame in range(90):
		await process_frame
		map_state = world.get_map_screen_state()
		music_road_marker = _find_marker_by_icon_id(map_state.get("pin_markers", []), "music_road")
		if not music_road_marker.is_empty():
			break
	if not T.require_true(self, not music_road_marker.is_empty(), "Music road full-map flow must surface the music_road marker after opening the map"):
		return
	if not T.require_true(self, str(music_road_marker.get("pin_type", "")) == "landmark", "Music road full-map flow must reuse the landmark pin family"):
		return
	if not T.require_true(self, str(music_road_marker.get("visibility_scope", "")) == "full_map", "Music road full-map flow must stay full_map only"):
		return
	if not T.require_true(self, str(music_road_marker.get("icon_glyph", "")) == "🎵", "Music road full-map flow must render the music glyph in UI state"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	for pin_variant in pin_overlay.get("pins", []):
		var pin: Dictionary = pin_variant
		if not T.require_true(self, str(pin.get("icon_id", "")) != "music_road", "Music road full-map flow must keep the music road marker out of minimap overlay"):
			return

	world.queue_free()
	T.pass_and_quit(self)

func _find_marker_by_icon_id(markers: Array, icon_id: String) -> Dictionary:
	for marker_variant in markers:
		var marker: Dictionary = marker_variant
		if str(marker.get("icon_id", "")) == icon_id:
			return marker
	return {}
