extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_PROP_ID := "prop:v25:soccer_ball:chunk_129_139"
const SOCCER_ANCHOR_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer ball kick contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player = world.get_node_or_null("Player")
	var hud = world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer ball kick contract requires Player teleport API"):
		return
	if not T.require_true(self, player.has_method("enter_vehicle_drive_mode"), "Soccer ball kick contract requires synthetic driving-mode entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Soccer ball kick contract requires chunk renderer introspection"):
		return
	if not T.require_true(self, world.has_method("get_interactive_prop_interaction_state"), "Soccer ball kick contract requires interactive prop state introspection"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Soccer ball kick contract requires a formal primary interaction entrypoint"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state"), "Soccer ball kick contract requires HUD prompt introspection"):
		return

	var chunk_renderer = world.get_chunk_renderer()
	player.teleport_to_world_position(SOCCER_ANCHOR_WORLD_POSITION + Vector3(0.0, 3.0, 4.0))
	var mounted_prop = await _wait_for_prop_mount(chunk_renderer)
	if not T.require_true(self, mounted_prop != null, "Soccer ball kick contract must mount the soccer prop before interaction checks"):
		return

	player.teleport_to_world_position(mounted_prop.global_position + Vector3(-0.95, 0.95, 0.0))
	await _settle_frames(8)

	var prop_state: Dictionary = world.get_interactive_prop_interaction_state()
	if not T.require_true(self, bool(prop_state.get("visible", false)), "Soccer ball kick contract must surface an active prop interaction when the player is nearby"):
		return
	if not T.require_true(self, str(prop_state.get("prop_id", "")) == SOCCER_PROP_ID, "Soccer ball kick contract must preserve the active soccer prop_id in runtime state"):
		return
	var hud_prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(hud_prompt_state.get("visible", false)), "Soccer ball kick contract must surface the shared HUD prompt while the ball is in range"):
		return
	if not T.require_true(self, str(hud_prompt_state.get("prompt_text", "")).find("E") >= 0, "Soccer ball kick contract prompt must describe the E key interaction"):
		return
	if not T.require_true(self, str(hud_prompt_state.get("prompt_text", "")).find("踢") >= 0, "Soccer ball kick contract prompt must describe kicking the ball"):
		return

	var before_position: Vector3 = mounted_prop.global_position
	var before_speed: float = mounted_prop.linear_velocity.length() if mounted_prop is RigidBody3D else 0.0
	var interaction_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(interaction_result.get("success", false)), "Soccer ball kick contract must let primary interaction succeed when the ball owns the prompt"):
		return
	if not T.require_true(self, str(interaction_result.get("interaction_kind", "")) == "kick", "Soccer ball kick contract must resolve the primary interaction kind to kick"):
		return
	if not T.require_true(self, str(interaction_result.get("prop_id", "")) == SOCCER_PROP_ID, "Soccer ball kick contract must preserve the soccer prop_id through the interaction result"):
		return

	for _frame in range(24):
		await physics_frame
		await process_frame
	var after_position: Vector3 = mounted_prop.global_position
	var after_speed: float = mounted_prop.linear_velocity.length() if mounted_prop is RigidBody3D else 0.0
	if not T.require_true(self, after_position.distance_to(before_position) >= 0.35, "Soccer ball kick contract must physically move the ball instead of only toggling a flag"):
		return
	if not T.require_true(self, after_speed >= before_speed + 1.0, "Soccer ball kick contract must leave the ball with a clearly higher linear speed after kick impulse"):
		return

	player.enter_vehicle_drive_mode({
		"vehicle_id": "test_vehicle",
		"model_id": "test_vehicle_model",
		"heading": Vector3.FORWARD,
		"world_position": player.global_position,
	})
	await _settle_frames(6)
	var driving_prop_state: Dictionary = world.get_interactive_prop_interaction_state()
	if not T.require_true(self, not bool(driving_prop_state.get("visible", false)), "Soccer ball kick contract must hide prop interactions while the player is in driving mode"):
		return
	var blocked_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, not bool(blocked_result.get("success", false)), "Soccer ball kick contract must refuse kick interactions while the player is in driving mode"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_prop_mount(chunk_renderer) -> Variant:
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_interactive_prop_node"):
			continue
		var mounted_prop = chunk_scene.find_scene_interactive_prop_node(SOCCER_PROP_ID)
		if mounted_prop != null:
			return mounted_prop
	return null

func _settle_frames(frame_count: int = 4) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
