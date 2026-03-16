extends SceneTree

const T := preload("res://tests/_test_util.gd")

class FakeInteractableNpc:
	extends Node3D

	var actor_id := ""
	var display_name := ""
	var interaction_kind := "dialogue"
	var interaction_radius_m := 5.0
	var dialogue_id := ""
	var opening_line := ""

	func _init(resolved_actor_id: String, resolved_display_name: String, resolved_position: Vector3, resolved_line: String) -> void:
		actor_id = resolved_actor_id
		display_name = resolved_display_name
		dialogue_id = "%s_dialogue" % resolved_actor_id
		opening_line = resolved_line
		position = resolved_position
		name = resolved_actor_id

	func _ready() -> void:
		add_to_group("city_interactable_npc")

	func get_interaction_contract() -> Dictionary:
		return {
			"actor_id": actor_id,
			"display_name": display_name,
			"interaction_kind": interaction_kind,
			"interaction_radius_m": interaction_radius_m,
			"dialogue_id": dialogue_id,
			"opening_line": opening_line,
		}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for dialogue runtime contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "Dialogue runtime contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "Dialogue runtime contract requires Player teleport API for isolated setup"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "Dialogue runtime contract requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("get_interaction_prompt_state"), "PrototypeHud must expose get_interaction_prompt_state() for dialogue ownership verification"):
		return
	if not T.require_true(self, hud.has_method("get_dialogue_panel_state"), "PrototypeHud must expose get_dialogue_panel_state() for dialogue HUD verification"):
		return
	if not T.require_true(self, world.has_method("get_npc_interaction_state"), "CityPrototype must expose get_npc_interaction_state() for dialogue setup"):
		return
	if not T.require_true(self, world.has_method("get_dialogue_runtime_state"), "CityPrototype must expose get_dialogue_runtime_state() for dialogue runtime contract"):
		return

	player.teleport_to_world_position(player.global_position + Vector3(320.0, 0.0, 320.0))
	if world.has_method("update_streaming_for_position"):
		world.update_streaming_for_position(player.global_position, 0.25)
	await _settle_frames(4)

	_press_key(world, KEY_E)
	await _settle_frames()

	var dialogue_state: Dictionary = world.get_dialogue_runtime_state()
	if not T.require_true(self, str(dialogue_state.get("status", "")) == "idle", "Pressing E without an active NPC candidate must not open dialogue"):
		return

	var actor := FakeInteractableNpc.new("npc_dialogue", "Dialog NPC", player.global_position + Vector3(0.0, 0.0, 1.6), "测试开场白")
	world.add_child(actor)
	await _settle_frames()

	var prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(prompt_state.get("visible", false)), "Dialogue runtime contract requires a visible prompt before E ownership transfers"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	dialogue_state = world.get_dialogue_runtime_state()
	if not T.require_true(self, str(dialogue_state.get("status", "")) == "active", "Pressing E with an active NPC candidate must enter active dialogue state"):
		return
	if not T.require_true(self, str(dialogue_state.get("owner_actor_id", "")) == "npc_dialogue", "Dialogue runtime must preserve the owner_actor_id of the active NPC"):
		return
	if not T.require_true(self, str(dialogue_state.get("body_text", "")) == "测试开场白", "Dialogue runtime must surface the opening line from the active NPC contract"):
		return
	if not T.require_true(self, not bool(hud.get_interaction_prompt_state().get("visible", false)), "Opening dialogue must hide the interaction prompt while E ownership belongs to dialogue runtime"):
		return
	var dialogue_panel_state: Dictionary = hud.get_dialogue_panel_state()
	if not T.require_true(self, bool(dialogue_panel_state.get("visible", false)), "Opening dialogue must surface a visible dialogue panel state on the HUD"):
		return
	if not T.require_true(self, str(dialogue_panel_state.get("body_text", "")) == "测试开场白", "Dialogue panel must mirror the dialogue runtime body text"):
		return

	_press_key(world, KEY_E)
	await _settle_frames()

	dialogue_state = world.get_dialogue_runtime_state()
	if not T.require_true(self, str(dialogue_state.get("status", "")) == "idle", "Pressing E again while dialogue is active must close the single-line dialogue runtime"):
		return
	if not T.require_true(self, bool(hud.get_interaction_prompt_state().get("visible", false)), "Closing dialogue must return HUD ownership to the interaction prompt when the NPC is still in range"):
		return
	if not T.require_true(self, not bool(hud.get_dialogue_panel_state().get("visible", false)), "Closing dialogue must hide the dialogue panel state"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _press_key(world: Node, keycode: int) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	world._unhandled_input(key_event)

func _settle_frames(frame_count: int = 3) -> void:
	for _frame_index in range(frame_count):
		await process_frame
