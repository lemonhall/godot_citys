extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FOUNTAIN_CHUNK_ID := "chunk_129_142"
const FOUNTAIN_LANDMARK_ID := "landmark:v21:fountain:chunk_129_142"
const FOUNTAIN_WORLD_POSITION := Vector3(-1848.0, 14.545391, 1480.0)
const LOBSTER_PROP_ID := "prop:v27:fountain_lobster:chunk_129_142"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for fountain lobster interaction flow")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player = world.get_node_or_null("Player")
	var hud = world.get_node_or_null("Hud")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Fountain lobster interaction flow requires Player teleport API"):
		return
	if not T.require_true(self, world.has_method("get_chunk_renderer"), "Fountain lobster interaction flow requires chunk renderer introspection"):
		return
	if not T.require_true(self, world.has_method("handle_primary_interaction"), "Fountain lobster interaction flow requires the formal primary interaction entrypoint"):
		return
	if not T.require_true(self, world.has_method("get_interactive_prop_interaction_state"), "Fountain lobster interaction flow requires interactive prop state introspection"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_interaction_prompt_state"), "Fountain lobster interaction flow requires HUD prompt introspection"):
		return

	var chunk_renderer = world.get_chunk_renderer()
	player.teleport_to_world_position(FOUNTAIN_WORLD_POSITION + Vector3(0.0, 8.0, 12.0))
	var mounted_landmark: Node3D = await _wait_for_landmark_mount(chunk_renderer)
	if not T.require_true(self, mounted_landmark != null, "Fountain lobster interaction flow must mount the fountain landmark when chunk_129_142 enters near range"):
		return

	var lobster := mounted_landmark.get_node_or_null("Lobster") as Node3D
	if not T.require_true(self, lobster != null and lobster.has_method("get_debug_state"), "Fountain lobster interaction flow requires the mounted Lobster node with debug state access"):
		return

	player.teleport_to_world_position(lobster.global_position + Vector3(-0.9, 0.95, 0.0))
	await _settle_frames(10)

	var prop_state: Dictionary = world.get_interactive_prop_interaction_state()
	if not T.require_true(self, bool(prop_state.get("visible", false)), "Fountain lobster interaction flow must surface an active prop interaction when the player approaches the lobster"):
		return
	if not T.require_true(self, str(prop_state.get("prop_id", "")) == LOBSTER_PROP_ID, "Fountain lobster interaction flow must preserve the lobster prop_id in runtime state"):
		return
	var prompt_state: Dictionary = hud.get_interaction_prompt_state()
	if not T.require_true(self, bool(prompt_state.get("visible", false)), "Fountain lobster interaction flow must surface the shared HUD prompt near the lobster"):
		return
	if not T.require_true(self, str(prompt_state.get("prompt_text", "")).find("E") >= 0, "Fountain lobster interaction flow prompt must describe the E key"):
		return

	var before_debug: Dictionary = lobster.get_debug_state()
	var interaction_result: Dictionary = world.handle_primary_interaction()
	if not T.require_true(self, bool(interaction_result.get("success", false)), "Fountain lobster interaction flow must allow the player to interact with the lobster"):
		return
	if not T.require_true(self, str(interaction_result.get("interaction_kind", "")) == "wave", "Fountain lobster interaction flow must resolve the interaction kind to wave"):
		return
	if not T.require_true(self, str(interaction_result.get("prop_id", "")) == LOBSTER_PROP_ID, "Fountain lobster interaction flow must preserve the lobster prop_id through the interaction result"):
		return

	await _settle_frames(2)
	var after_debug: Dictionary = lobster.get_debug_state()
	if not T.require_true(self, int(after_debug.get("wave_play_count", 0)) == int(before_debug.get("wave_play_count", 0)) + 1, "Fountain lobster interaction flow must record one more wave interaction after E is pressed"):
		return
	if not T.require_true(self, bool(after_debug.get("is_playing", false)), "Fountain lobster interaction flow must start playing the wave clip after interaction"):
		return
	if not T.require_true(self, str(after_debug.get("current_animation", "")) == "wave", "Fountain lobster interaction flow must actively play the wave animation after interaction"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _wait_for_landmark_mount(chunk_renderer) -> Variant:
	if chunk_renderer == null or not chunk_renderer.has_method("get_chunk_scene"):
		return null
	for _frame in range(180):
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(FOUNTAIN_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_landmark_node"):
			continue
		var mounted_landmark = chunk_scene.find_scene_landmark_node(FOUNTAIN_LANDMARK_ID) as Node3D
		if mounted_landmark != null:
			return mounted_landmark
	return null

func _settle_frames(frame_count: int = 4) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
