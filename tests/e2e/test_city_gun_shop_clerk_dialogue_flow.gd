extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GUN_SHOP_BUILDING_ID := "bld:v15-building-id-1:seed424242:chunk_134_130:014"
const GUN_SHOP_MANIFEST_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/building_manifest.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for gun shop clerk dialogue flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Gun shop clerk dialogue flow requires Player teleport API"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state"), "Gun shop clerk dialogue flow requires HUD interaction prompt introspection"):
		return
	if not T.require_true(self, hud.has_method("get_dialogue_panel_state"), "Gun shop clerk dialogue flow requires HUD dialogue panel introspection"):
		return
	if not T.require_true(self, world.has_method("find_building_override_node"), "Gun shop clerk dialogue flow requires CityPrototype.find_building_override_node()"):
		return
	if not T.require_true(self, world.has_method("get_npc_interaction_state"), "Gun shop clerk dialogue flow requires NPC interaction runtime introspection"):
		return
	if not T.require_true(self, world.has_method("get_dialogue_runtime_state"), "Gun shop clerk dialogue flow requires dialogue runtime introspection"):
		return

	var gunsmith := await _wait_for_gunsmith(world, player)
	if not T.require_true(self, gunsmith != null, "Gun shop clerk dialogue flow requires the service override scene to mount the gunsmith actor"):
		return

	player.teleport_to_world_position(gunsmith.global_position + Vector3(0.0, 0.0, 4.2))
	await _refresh_streaming(world, player.global_position)

	var prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(prompt_state.get("visible", false)), "Approaching the gunsmith inside the frozen 5m range must surface the persistent E interaction prompt"):
		return
	if not T.require_true(self, str(prompt_state.get("actor_id", "")) == "gunsmith_01", "The gunsmith must own the interaction prompt when the player is the closest customer candidate"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	var dialogue_state: Dictionary = world.get_dialogue_runtime_state()
	if not T.require_true(self, str(dialogue_state.get("status", "")) == "active", "Pressing E near the gunsmith must enter dialogue active state"):
		return
	if not T.require_true(self, str(dialogue_state.get("owner_actor_id", "")) == "gunsmith_01", "Gun shop clerk dialogue flow must preserve the gunsmith actor_id as dialogue owner"):
		return
	if not T.require_true(self, str(dialogue_state.get("body_text", "")).find("都很致命，想要哪一把") >= 0, "Gun shop clerk dialogue flow must surface the frozen opening line text"):
		return
	if not T.require_true(self, not bool(hud.get_interaction_prompt_state().get("visible", false)), "Dialogue flow must hide the prompt while the dialogue panel is active"):
		return
	var dialogue_panel_state: Dictionary = hud.get_dialogue_panel_state()
	if not T.require_true(self, bool(dialogue_panel_state.get("visible", false)), "Dialogue flow must surface the HUD dialogue panel"):
		return
	if not T.require_true(self, str(dialogue_panel_state.get("body_text", "")).find("都很致命，想要哪一把") >= 0, "Dialogue panel must render the gunsmith opening line body text"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	dialogue_state = world.get_dialogue_runtime_state()
	if not T.require_true(self, str(dialogue_state.get("status", "")) == "idle", "Pressing E again must close the single-line gunsmith dialogue runtime"):
		return
	if not T.require_true(self, bool(hud.get_interaction_prompt_state().get("visible", false)), "Closing the gunsmith dialogue must return the HUD to prompt state while the player remains nearby"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_gunsmith(world: Node, player) -> Node3D:
	var staging_position := _resolve_gun_shop_world_position() + Vector3(0.0, 2.0, 8.0)
	player.teleport_to_world_position(staging_position)
	await _refresh_streaming(world, staging_position, 8)
	for _frame_index in range(48):
		var override_root: Node = world.find_building_override_node(GUN_SHOP_BUILDING_ID)
		var gunsmith := _find_gunsmith_node(override_root if override_root != null else world)
		if gunsmith != null:
			return gunsmith
		world.update_streaming_for_position(staging_position, 0.25)
		await process_frame
	return _find_gunsmith_node(world)

func _find_gunsmith_node(root_node: Node) -> Node3D:
	if root_node == null:
		return null
	var root_3d := root_node as Node3D
	if root_3d != null and str(root_3d.get_meta("city_service_actor_role", "")) == "gunsmith":
		return root_3d
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var found := _find_gunsmith_node(child_node)
		if found != null:
			return found
	return null

func _press_key(world: Node, keycode: int) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	world._unhandled_input(key_event)

func _refresh_streaming(world: Node, anchor_world_position: Vector3, steps: int = 4) -> void:
	for _step_index in range(steps):
		world.update_streaming_for_position(anchor_world_position, 0.25)
		await process_frame

func _settle_frames(frame_count: int = 3) -> void:
	for _frame_index in range(frame_count):
		await process_frame

func _resolve_gun_shop_world_position() -> Vector3:
	var config_script: Variant = load("res://city_game/world/model/CityWorldConfig.gd")
	if config_script == null:
		return Vector3.ZERO
	var config: Variant = config_script.new()
	if config == null:
		return Vector3.ZERO
	var manifest: Dictionary = _load_manifest(GUN_SHOP_MANIFEST_PATH)
	var resolved_position: Variant = _resolve_expected_absolute_world_position(config, manifest)
	return resolved_position if resolved_position is Vector3 else Vector3.ZERO

func _load_manifest(manifest_path: String) -> Dictionary:
	var global_manifest_path := ProjectSettings.globalize_path(manifest_path)
	if manifest_path == "" or not FileAccess.file_exists(global_manifest_path):
		return {}
	var manifest_variant = JSON.parse_string(FileAccess.get_file_as_string(global_manifest_path))
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
