extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for service building full-map icon flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Service building full-map icon flow requires set_full_map_open()"):
		return
	if not T.require_true(self, world.has_method("is_full_map_open"), "Service building full-map icon flow requires is_full_map_open()"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Service building full-map icon flow requires full-map render state introspection"):
		return
	if not T.require_true(self, world.has_method("get_service_building_map_pin_state"), "Service building full-map icon flow requires custom building pin runtime introspection"):
		return

	var runtime_state := await _wait_for_service_building_pin_cache(world)
	if not T.require_true(self, int(runtime_state.get("pin_count", 0)) >= 3, "Service building full-map icon flow requires all custom-building map pins to finish lazy loading before opening the map"):
		return

	world.set_full_map_open(true)
	await process_frame
	if not T.require_true(self, world.is_full_map_open(), "Service building full-map icon flow must open the full map before checking custom-building icons"):
		return

	var map_state: Dictionary = world.get_map_screen_state()
	var cafe_marker := _find_marker_by_icon_id(map_state.get("pin_markers", []), "cafe")
	if not T.require_true(self, not cafe_marker.is_empty(), "Opening the full map must reveal the cafe custom-building icon marker"):
		return
	if not T.require_true(self, str(cafe_marker.get("icon_glyph", "")) == "☕", "Cafe custom-building marker must render the coffee glyph in the full-map user flow"):
		return
	var burger_shop_marker := _find_marker_by_icon_id(map_state.get("pin_markers", []), "burger_shop")
	if not T.require_true(self, not burger_shop_marker.is_empty(), "Opening the full map must reveal the burger shop custom-building icon marker"):
		return
	if not T.require_true(self, str(burger_shop_marker.get("icon_glyph", "")) == "🍔", "Burger shop custom-building marker must render the burger glyph in the full-map user flow"):
		return

	world.set_full_map_open(false)
	await process_frame
	if not T.require_true(self, not world.is_full_map_open(), "Service building full-map icon flow must close the full map cleanly after inspection"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_service_building_pin_cache(world) -> Dictionary:
	for _frame in range(180):
		await process_frame
		var state: Dictionary = world.get_service_building_map_pin_state()
		if not bool(state.get("loading", false)):
			return state
	return world.get_service_building_map_pin_state()

func _find_marker_by_icon_id(markers: Array, icon_id: String) -> Dictionary:
	for marker_variant in markers:
		var marker: Dictionary = marker_variant
		if str(marker.get("icon_id", "")) == icon_id:
			return marker
	return {}
