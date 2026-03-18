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
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer ball interaction flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player = world.get_node_or_null("Player")
	var hud = world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer ball interaction flow requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Soccer ball interaction flow requires chunk renderer introspection"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Soccer ball interaction flow requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state"), "Soccer ball interaction flow requires HUD prompt introspection"):
		return

	var chunk_renderer = world.get_chunk_renderer()
	player.teleport_to_world_position(SOCCER_ANCHOR_WORLD_POSITION + Vector3(0.0, 3.0, 4.0))
	var mounted_prop = await _wait_for_prop_mount(chunk_renderer)
	if not T.require_true(self, mounted_prop != null, "Soccer ball interaction flow must mount the soccer prop when chunk_129_139 enters near range"):
		return

	player.teleport_to_world_position(mounted_prop.global_position + Vector3(-0.9, 0.95, 0.0))
	var prompt_visible := false
	for _frame in range(24):
		await physics_frame
		await process_frame
		if bool(hud.get_interaction_prompt_state().get("visible", false)):
			prompt_visible = true
			break
	if not T.require_true(self, prompt_visible, "Soccer ball interaction flow must surface the shared interaction prompt before the kick"):
		return

	var before_position: Vector3 = mounted_prop.global_position
	var interaction_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(interaction_result.get("success", false)), "Soccer ball interaction flow must let the player kick the mounted soccer ball"):
		return

	for _frame in range(30):
		await physics_frame
		await process_frame
	if not T.require_true(self, mounted_prop.global_position.distance_to(before_position) >= 0.45, "Soccer ball interaction flow must move the ball a readable distance after kick"):
		return

	player.teleport_to_world_position(Vector3(0.0, 8.0, 0.0))
	var retired := false
	for _frame in range(180):
		await process_frame
		if chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID) == null:
			retired = true
			break
	if not T.require_true(self, retired, "Soccer ball interaction flow must retire the soccer chunk after the player leaves the area"):
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
