extends SceneTree

const T := preload("res://tests/_test_util.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const HOWITZER_SCRIPT_PATH := "res://city_game/combat/artillery/CityM777Howitzer.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CITY_SCENE_PATH)
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "World howitzer spawn contract requires CityPrototype.tscn")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	await process_frame

	if not T.require_true(self, world.has_method("get_active_world_howitzer"), "CityPrototype must expose get_active_world_howitzer() once howitzer summon is added to the main world"):
		return
	if not T.require_true(self, world.has_method("get_active_artillery_shell_count"), "CityPrototype must expose get_active_artillery_shell_count() once world artillery shells exist"):
		return
	if not T.require_true(self, world.has_method("get_last_artillery_shell_explosion_result"), "CityPrototype must expose get_last_artillery_shell_explosion_result() once world artillery shells exist"):
		return

	var player := world.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "World howitzer spawn contract requires the main world player node"):
		return
	if not T.require_true(self, world.get_active_world_howitzer() == null, "Before pressing KP_8, the main world must not already hold a summoned howitzer instance"):
		return

	var spawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, spawned, "KP_8 must be wired as the main-world howitzer summon shortcut"):
		return
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_fire_state"), "KP_8 summon must instantiate the formal CityM777Howitzer runtime in the main world"):
		return

	var spawned_howitzers := _collect_howitzer_nodes(world)
	if not T.require_true(self, spawned_howitzers.size() == 1, "Summoning the main-world howitzer must create exactly one formal howitzer instance instead of leaving the scene empty or duplicating multiple copies"):
		return

	var horizontal_distance_m := _horizontal_distance(player.global_position, howitzer.global_position)
	if not T.require_true(self, horizontal_distance_m >= 4.0 and horizontal_distance_m <= 18.0, "Summoned howitzer must appear in front of the player at a usable standoff distance instead of underfoot or far away"):
		return

	player.global_position += Vector3(36.0, 0.0, -18.0)
	player.rotation.y = deg_to_rad(90.0)
	await _settle_frames()

	var respawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, respawned, "Pressing KP_8 again must still be accepted as the howitzer summon shortcut"):
		return
	await _settle_frames()

	howitzer = world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null, "After re-summoning, CityPrototype must still expose the currently active howitzer instance"):
		return
	spawned_howitzers = _collect_howitzer_nodes(world)
	if not T.require_true(self, spawned_howitzers.size() == 1, "Re-summoning must replace or reposition the current howitzer instead of accumulating multiple world instances"):
		return
	horizontal_distance_m = _horizontal_distance(player.global_position, howitzer.global_position)
	if not T.require_true(self, horizontal_distance_m >= 4.0 and horizontal_distance_m <= 18.0, "Re-summoned howitzer must follow the player's new position/orientation instead of staying at the old summon point"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _collect_howitzer_nodes(root_node: Node) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node_variant: Variant in root_node.find_children("*", "Node3D", true, false):
		var node := node_variant as Node3D
		if node == null:
			continue
		var script: Variant = node.get_script()
		if script == null:
			continue
		if str(script.resource_path) != HOWITZER_SCRIPT_PATH:
			continue
		result.append(node)
	return result

func _horizontal_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
