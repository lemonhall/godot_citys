extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CONFIG_PATH := "res://city_game/world/model/CityWorldConfig.gd"
const REGISTRY_PATH := "res://city_game/serviceability/buildings/generated/building_override_registry.json"

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
	if not T.require_true(self, int(pin_runtime_state.get("pin_count", 0)) >= 3, "Service building full-map pin runtime must eventually cache cafe, burger shop, and gun shop custom-building pins"):
		return
	if not T.require_true(self, int(pin_runtime_state.get("manifest_read_count", 0)) >= 4, "Service building full-map pin runtime must actually read the generated building manifests instead of synthesizing pins out of thin air"):
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
	var burger_shop_marker := _find_marker_by_icon_id(map_state.get("pin_markers", []), "burger_shop")
	if not T.require_true(self, not burger_shop_marker.is_empty(), "Full map render state must expose a burger shop marker projected from the custom building manifest"):
		return
	if not T.require_true(self, str(burger_shop_marker.get("pin_type", "")) == "service_building", "Burger shop marker must keep the formal service_building pin_type in the full-map render state"):
		return
	if not T.require_true(self, str(burger_shop_marker.get("visibility_scope", "")) == "full_map", "Burger shop marker must remain full_map only in the render state contract"):
		return
	if not T.require_true(self, str(burger_shop_marker.get("icon_glyph", "")) == "🍔", "Burger shop marker must resolve the burger glyph from icon_id in the UI layer"):
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

	var config_script := load(CONFIG_PATH)
	if not T.require_true(self, config_script != null, "Service building full-map pin contract requires CityWorldConfig.gd for absolute-position regression coverage"):
		return
	var config = config_script.new()
	if not T.require_true(self, config != null, "Service building full-map pin contract must instantiate CityWorldConfig"):
		return
	var registry := _load_registry()
	if not T.require_true(self, not registry.is_empty(), "Service building full-map pin contract requires generated building registry fixtures"):
		return
	var registry_entries: Dictionary = registry.get("entries", {})
	var cafe_manifest := _load_manifest(registry_entries.get("bld:v15-building-id-1:seed424242:chunk_137_136:003", {}))
	if not T.require_true(self, not cafe_manifest.is_empty(), "Service building full-map pin contract requires the cafe manifest fixture"):
		return
	var expected_cafe_position: Variant = _resolve_expected_absolute_world_position(config, cafe_manifest)
	if not T.require_true(self, expected_cafe_position is Vector3, "Service building full-map pin contract must derive an absolute cafe world position"):
		return
	if not T.require_true(self, _vector3_near(cafe_marker.get("world_position", Vector3.ZERO), expected_cafe_position as Vector3), "Cafe full-map marker must keep the absolute building world position through the UI render state"):
		return
	var burger_shop_manifest := _load_manifest(registry_entries.get("bld:v15-building-id-1:seed424242:chunk_131_143:003", {}))
	if not T.require_true(self, not burger_shop_manifest.is_empty(), "Service building full-map pin contract requires the burger shop manifest fixture"):
		return
	var expected_burger_shop_position: Variant = _resolve_expected_absolute_world_position(config, burger_shop_manifest)
	if not T.require_true(self, expected_burger_shop_position is Vector3, "Service building full-map pin contract must derive an absolute burger shop world position"):
		return
	if not T.require_true(self, _vector3_near(burger_shop_marker.get("world_position", Vector3.ZERO), expected_burger_shop_position as Vector3), "Burger shop full-map marker must keep the absolute building world position through the UI render state"):
		return
	var gun_shop_manifest := _load_manifest(registry_entries.get("bld:v15-building-id-1:seed424242:chunk_134_130:014", {}))
	if not T.require_true(self, not gun_shop_manifest.is_empty(), "Service building full-map pin contract requires the gun shop manifest fixture"):
		return
	var expected_gun_shop_position: Variant = _resolve_expected_absolute_world_position(config, gun_shop_manifest)
	if not T.require_true(self, expected_gun_shop_position is Vector3, "Service building full-map pin contract must derive an absolute gun shop world position"):
		return
	if not T.require_true(self, _vector3_near(gun_shop_marker.get("world_position", Vector3.ZERO), expected_gun_shop_position as Vector3), "Gun shop full-map marker must keep the absolute building world position through the UI render state"):
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

func _load_registry() -> Dictionary:
	var registry_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(REGISTRY_PATH))
	var registry_variant = JSON.parse_string(registry_text)
	if not (registry_variant is Dictionary):
		return {}
	return (registry_variant as Dictionary).duplicate(true)

func _load_manifest(entry_variant: Variant) -> Dictionary:
	if not (entry_variant is Dictionary):
		return {}
	var entry: Dictionary = entry_variant
	var manifest_path := str(entry.get("manifest_path", "")).strip_edges()
	if manifest_path == "":
		return {}
	var manifest_variant = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path(manifest_path)))
	if not (manifest_variant is Dictionary):
		return {}
	return (manifest_variant as Dictionary).duplicate(true)

func _resolve_expected_absolute_world_position(config, manifest: Dictionary) -> Variant:
	var source_contract_variant = manifest.get("source_building_contract", {})
	if not (source_contract_variant is Dictionary):
		return null
	var source_contract: Dictionary = source_contract_variant
	var local_center: Variant = _decode_vector3(source_contract.get("center", null))
	if local_center == null:
		return null
	var generation_locator_variant = source_contract.get("generation_locator", manifest.get("generation_locator", {}))
	if not (generation_locator_variant is Dictionary):
		return null
	var generation_locator: Dictionary = generation_locator_variant
	var chunk_key: Variant = _decode_vector2i(generation_locator.get("chunk_key", null))
	if chunk_key == null:
		return null
	var bounds: Rect2 = config.get_world_bounds()
	var chunk_size_m := float(config.chunk_size_m)
	var resolved_chunk_key := chunk_key as Vector2i
	var chunk_center := Vector3(
		bounds.position.x + (float(resolved_chunk_key.x) + 0.5) * chunk_size_m,
		0.0,
		bounds.position.y + (float(resolved_chunk_key.y) + 0.5) * chunk_size_m
	)
	var local_center_vector := local_center as Vector3
	return Vector3(
		chunk_center.x + local_center_vector.x,
		local_center_vector.y,
		chunk_center.z + local_center_vector.z
	)

func _decode_vector3(value: Variant) -> Variant:
	if value is Vector3:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector3":
		return null
	return Vector3(
		float(payload.get("x", 0.0)),
		float(payload.get("y", 0.0)),
		float(payload.get("z", 0.0))
	)

func _decode_vector2i(value: Variant) -> Variant:
	if value is Vector2i:
		return value
	if not (value is Dictionary):
		return null
	var payload: Dictionary = value
	if str(payload.get("@type", "")) != "Vector2i":
		return null
	return Vector2i(
		int(payload.get("x", 0)),
		int(payload.get("y", 0))
	)

func _vector3_near(actual: Variant, expected: Vector3, epsilon: float = 0.01) -> bool:
	if not (actual is Vector3):
		return false
	var actual_vector := actual as Vector3
	return actual_vector.distance_to(expected) <= epsilon
