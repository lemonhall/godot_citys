extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for lake main-world pickup visual contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake main-world pickup visual contract requires Player teleport API"):
		return
	if not T.require_true(self, player.has_method("get_fishing_visual_state"), "Lake main-world pickup visual contract requires fishing visual introspection on Player"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_crosshair_state"), "Lake main-world pickup visual contract requires HUD crosshair introspection"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Lake main-world pickup visual contract requires the shared primary interaction entrypoint"):
		return

	player.teleport_to_world_position(Vector3(2834.0, 1.2, 11546.0))
	var prompt_state: Dictionary = await _wait_for_visible_prompt(world)
	if not T.require_true(self, bool(prompt_state.get("visible", false)), "Lake main-world pickup visual contract requires a visible fishing prompt before pickup"):
		return
	var pickup_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(pickup_result.get("success", false)), "Lake main-world pickup visual contract must allow pole pickup through the shared E interaction entrypoint"):
		return
	await physics_frame
	await process_frame

	var fishing_visual_state: Dictionary = player.get_fishing_visual_state()
	if not T.require_true(self, bool(fishing_visual_state.get("pole_present", false)), "Lake main-world pickup visual contract must keep the held pole scene mounted on the player after pickup"):
		return
	if not T.require_true(self, bool(fishing_visual_state.get("equipped_visible", false)), "Lake main-world pickup visual contract must keep the held pole visibly enabled after pickup instead of making it disappear"):
		return
	var camera := world.get_viewport().get_camera_3d()
	if not T.require_true(self, camera != null, "Lake main-world pickup visual contract requires an active camera to project the held pole tip"):
		return
	var tip_world_position: Vector3 = fishing_visual_state.get("tip_world_position", Vector3.ZERO)
	if not T.require_true(self, tip_world_position != Vector3.ZERO, "Lake main-world pickup visual contract must expose a stable held-pole tip world position after pickup"):
		return
	if not T.require_true(self, not camera.is_position_behind(tip_world_position), "Lake main-world pickup visual contract must keep the held pole tip in front of the main-world camera after pickup"):
		return

	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, not bool(crosshair_state.get("visible", true)), "Lake main-world pickup visual contract must hide the combat crosshair while fishing mode owns the interaction loop"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_visible_prompt(world) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var prompt_state: Dictionary = world.get_fishing_primary_interaction_state() if world.has_method("get_fishing_primary_interaction_state") else {}
		if bool(prompt_state.get("visible", false)):
			return prompt_state
	return world.get_fishing_primary_interaction_state() if world.has_method("get_fishing_primary_interaction_state") else {}
