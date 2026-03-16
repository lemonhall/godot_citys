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

	func _init(resolved_actor_id: String, resolved_display_name: String, resolved_position: Vector3, resolved_line: String = "") -> void:
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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for NPC interaction prompt contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "NPC interaction prompt contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("teleport_to_world_position"), "NPC interaction prompt contract requires Player teleport API for isolated setup"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "NPC interaction prompt contract requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("get_interaction_prompt_state"), "PrototypeHud must expose get_interaction_prompt_state() for NPC prompt verification"):
		return
	if not T.require_true(self, world.has_method("get_npc_interaction_state"), "CityPrototype must expose get_npc_interaction_state() for NPC prompt contract"):
		return

	player.teleport_to_world_position(player.global_position + Vector3(320.0, 0.0, 320.0))
	if world.has_method("update_streaming_for_position"):
		world.update_streaming_for_position(player.global_position, 0.25)
	await _settle_frames(4)

	var far_actor := FakeInteractableNpc.new("npc_far", "Far NPC", player.global_position + Vector3(0.0, 0.0, 5.6), "far")
	world.add_child(far_actor)
	await _settle_frames()

	var prompt_state: Dictionary = world.get_npc_interaction_state()
	if not T.require_true(self, not bool(prompt_state.get("visible", false)), "NPC prompt must stay hidden while every candidate remains outside the frozen 5m range"):
		return
	if not T.require_true(self, not bool(hud.get_interaction_prompt_state().get("visible", false)), "HUD interaction prompt must stay hidden while every candidate remains outside range"):
		return

	far_actor.global_position = player.global_position + Vector3(0.0, 0.0, 4.6)
	var near_actor := FakeInteractableNpc.new("npc_near", "Near NPC", player.global_position + Vector3(0.0, 0.0, 1.5), "near")
	world.add_child(near_actor)
	await _settle_frames()

	prompt_state = world.get_npc_interaction_state()
	if not T.require_true(self, bool(prompt_state.get("visible", false)), "NPC prompt must become visible once a candidate enters the frozen 5m range"):
		return
	if not T.require_true(self, str(prompt_state.get("actor_id", "")) == "npc_near", "NPC prompt ownership must still belong to the nearest candidate when two NPCs are both inside the frozen 5m range"):
		return
	var hud_prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(hud_prompt_state.get("visible", false)), "HUD interaction prompt must mirror the active interaction candidate state"):
		return
	if not T.require_true(self, str(hud_prompt_state.get("prompt_text", "")).find("E") >= 0, "HUD interaction prompt must describe the E key contract"):
		return

	near_actor.global_position = player.global_position + Vector3(0.0, 0.0, 6.0)
	far_actor.global_position = player.global_position + Vector3(0.0, 0.0, 6.4)
	await _settle_frames()

	prompt_state = world.get_npc_interaction_state()
	if not T.require_true(self, not bool(prompt_state.get("visible", false)), "NPC prompt must hide again after all candidates leave the frozen interaction radius"):
		return
	if not T.require_true(self, not bool(hud.get_interaction_prompt_state().get("visible", false)), "HUD interaction prompt must clear once no candidate remains in range"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _settle_frames(frame_count: int = 3) -> void:
	for _frame_index in range(frame_count):
		await process_frame
