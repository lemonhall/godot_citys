extends SceneTree

const T := preload("res://tests/_test_util.gd")
const BARISTA_BUILDING_ID := "bld:v15-building-id-1:seed424242:chunk_137_136:003"
const BARISTA_BUILDING_CENTER := Vector3(-38.6843566894531, 18.9783496856689, -83.3768157958984)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for cafe barista dialogue flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Cafe barista dialogue flow requires Player teleport API"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state"), "Cafe barista dialogue flow requires HUD interaction prompt introspection"):
		return
	if not T.require_true(self, hud.has_method("get_dialogue_panel_state"), "Cafe barista dialogue flow requires HUD dialogue panel introspection"):
		return
	if not T.require_true(self, world.has_method("find_building_override_node"), "Cafe barista dialogue flow requires CityPrototype.find_building_override_node()"):
		return
	if not T.require_true(self, world.has_method("get_npc_interaction_state"), "Cafe barista dialogue flow requires NPC interaction runtime introspection"):
		return
	if not T.require_true(self, world.has_method("get_dialogue_runtime_state"), "Cafe barista dialogue flow requires dialogue runtime introspection"):
		return

	var barista := await _wait_for_barista(world, player)
	if not T.require_true(self, barista != null, "Cafe barista dialogue flow requires the service override scene to mount the barista actor"):
		return

	player.teleport_to_world_position(barista.global_position + Vector3(0.0, 0.0, 4.2))
	await _refresh_streaming(world, player.global_position)

	var prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(prompt_state.get("visible", false)), "Approaching the barista inside the frozen 5m range must surface the persistent E interaction prompt"):
		return
	if not T.require_true(self, str(prompt_state.get("actor_id", "")) == "barista_01", "The barista must own the interaction prompt when the player is the closest customer candidate"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	var dialogue_state: Dictionary = world.get_dialogue_runtime_state()
	if not T.require_true(self, str(dialogue_state.get("status", "")) == "active", "Pressing E near the barista must enter dialogue active state"):
		return
	if not T.require_true(self, str(dialogue_state.get("owner_actor_id", "")) == "barista_01", "Barista dialogue flow must preserve the barista actor_id as dialogue owner"):
		return
	if not T.require_true(self, str(dialogue_state.get("body_text", "")).find("你想喝点什么") >= 0, "Barista dialogue flow must surface the frozen opening line text"):
		return
	if not T.require_true(self, not bool(hud.get_interaction_prompt_state().get("visible", false)), "Dialogue flow must hide the prompt while the dialogue panel is active"):
		return
	var dialogue_panel_state: Dictionary = hud.get_dialogue_panel_state()
	if not T.require_true(self, bool(dialogue_panel_state.get("visible", false)), "Dialogue flow must surface the HUD dialogue panel"):
		return
	if not T.require_true(self, str(dialogue_panel_state.get("body_text", "")).find("你想喝点什么") >= 0, "Dialogue panel must render the barista opening line body text"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	dialogue_state = world.get_dialogue_runtime_state()
	if not T.require_true(self, str(dialogue_state.get("status", "")) == "idle", "Pressing E again must close the single-line barista dialogue runtime"):
		return
	if not T.require_true(self, bool(hud.get_interaction_prompt_state().get("visible", false)), "Closing the barista dialogue must return the HUD to prompt state while the player remains nearby"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_barista(world: Node, player) -> Node3D:
	var staging_position := BARISTA_BUILDING_CENTER + Vector3(0.0, 2.0, 18.0)
	player.teleport_to_world_position(staging_position)
	await _refresh_streaming(world, staging_position, 8)
	for _frame_index in range(48):
		var override_root: Node = world.find_building_override_node(BARISTA_BUILDING_ID)
		var barista := _find_barista_node(override_root if override_root != null else world)
		if barista != null:
			return barista
		world.update_streaming_for_position(staging_position, 0.25)
		await process_frame
	return _find_barista_node(world)

func _find_barista_node(root_node: Node) -> Node3D:
	if root_node == null:
		return null
	var root_3d := root_node as Node3D
	if root_3d != null and str(root_3d.get_meta("city_service_actor_role", "")) == "barista":
		return root_3d
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var found := _find_barista_node(child_node)
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
