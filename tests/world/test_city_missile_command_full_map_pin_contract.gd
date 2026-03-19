extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for Missile Command full-map pin contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("set_full_map_open"), "Missile Command full-map pin contract requires full-map open control"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Missile Command full-map pin contract requires full-map render state introspection"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "Missile Command full-map pin contract requires minimap snapshot introspection"):
		return

	world.set_full_map_open(true)
	var map_state: Dictionary = {}
	var marker: Dictionary = {}
	for _frame in range(120):
		await process_frame
		map_state = world.get_map_screen_state()
		marker = _find_marker_by_icon_id(map_state.get("pin_markers", []), "missile_command")
		if not marker.is_empty():
			break
	if not T.require_true(self, not marker.is_empty(), "Full map render state must expose a missile_command marker from the scene_minigame_venue manifest pipeline"):
		return
	if not T.require_true(self, str(marker.get("pin_type", "")) == "landmark", "Missile Command marker must reuse the landmark pin family on full map"):
		return
	if not T.require_true(self, str(marker.get("visibility_scope", "")) == "full_map", "Missile Command marker must remain full_map only in render state"):
		return
	if not T.require_true(self, str(marker.get("icon_glyph", "")) == "🚀", "Missile Command marker must resolve the missile_command glyph from icon_id in UI layer"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	for pin_variant in pin_overlay.get("pins", []):
		var pin: Dictionary = pin_variant
		if not T.require_true(self, str(pin.get("icon_id", "")) != "missile_command", "Missile Command full-map marker must not leak into minimap overlay"):
			return

	world.queue_free()
	T.pass_and_quit(self)

func _find_marker_by_icon_id(markers: Array, icon_id: String) -> Dictionary:
	for marker_variant in markers:
		var marker: Dictionary = marker_variant
		if str(marker.get("icon_id", "")) == icon_id:
			return marker
	return {}
