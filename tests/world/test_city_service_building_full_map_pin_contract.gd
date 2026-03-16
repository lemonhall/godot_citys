extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for service building full-map pin contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	if not T.require_true(self, world.has_method("get_service_building_map_pin_state"), "Service building full-map pin contract requires runtime state introspection"):
		return
	if not T.require_true(self, world.has_method("get_pin_registry_state"), "Service building full-map pin contract requires pin registry introspection"):
		return
	if not T.require_true(self, world.has_method("set_full_map_open"), "Service building full-map pin contract requires full-map open control"):
		return
	if not T.require_true(self, world.has_method("get_map_screen_state"), "Service building full-map pin contract requires full-map render state introspection"):
		return
	if not T.require_true(self, world.has_method("build_minimap_snapshot"), "Service building full-map pin contract requires minimap snapshot introspection"):
		return

	var pin_runtime_state := await _wait_for_service_building_pin_cache(world)
	if not T.require_true(self, int(pin_runtime_state.get("pin_count", 0)) >= 2, "Service building full-map pin runtime must eventually cache both cafe and gun shop custom-building pins"):
		return
	if not T.require_true(self, int(pin_runtime_state.get("manifest_read_count", 0)) >= 3, "Service building full-map pin runtime must actually read the generated building manifests instead of synthesizing pins out of thin air"):
		return

	var registry_state: Dictionary = world.get_pin_registry_state()
	if not T.require_true(self, (registry_state.get("pin_types", []) as Array).has("service_building"), "Shared pin registry must surface the new service_building pin family once lazy loading completes"):
		return

	world.set_full_map_open(true)
	await process_frame

	var map_state: Dictionary = world.get_map_screen_state()
	if not T.require_true(self, (map_state.get("pin_types", []) as Array).has("service_building"), "Full map must render service_building pins from the shared pin pipeline"):
		return
	var cafe_marker := _find_marker_by_icon_id(map_state.get("pin_markers", []), "cafe")
	if not T.require_true(self, not cafe_marker.is_empty(), "Full map render state must expose a cafe marker projected from the custom building manifest"):
		return
	if not T.require_true(self, str(cafe_marker.get("pin_type", "")) == "service_building", "Cafe marker must keep the formal service_building pin_type in the full-map render state"):
		return
	if not T.require_true(self, str(cafe_marker.get("visibility_scope", "")) == "full_map", "Cafe marker must remain full_map only in the render state contract"):
		return
	if not T.require_true(self, str(cafe_marker.get("icon_glyph", "")) == "☕", "Cafe marker must resolve the coffee emoji/text glyph from icon_id in the UI layer"):
		return
	var gun_shop_marker := _find_marker_by_icon_id(map_state.get("pin_markers", []), "gun_shop")
	if not T.require_true(self, not gun_shop_marker.is_empty(), "Full map render state must expose a gun shop marker projected from the custom building manifest"):
		return
	if not T.require_true(self, str(gun_shop_marker.get("pin_type", "")) == "service_building", "Gun shop marker must keep the formal service_building pin_type in the full-map render state"):
		return
	if not T.require_true(self, str(gun_shop_marker.get("visibility_scope", "")) == "full_map", "Gun shop marker must remain full_map only in the render state contract"):
		return
	if not T.require_true(self, str(gun_shop_marker.get("icon_glyph", "")) == "🔫", "Gun shop marker must resolve the gun glyph from icon_id in the UI layer"):
		return

	var minimap_snapshot: Dictionary = world.build_minimap_snapshot()
	var pin_overlay: Dictionary = minimap_snapshot.get("pin_overlay", {})
	if not T.require_true(self, not (pin_overlay.get("pin_types", []) as Array).has("service_building"), "Custom building full-map pins must not leak into minimap overlay scope"):
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
