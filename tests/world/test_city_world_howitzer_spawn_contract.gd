extends SceneTree

const T := preload("res://tests/_test_util.gd")
const OrientationScript := preload("res://city_game/world/navigation/CityWorldOrientation.gd")

const CITY_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"
const HOWITZER_SCENE_PATH := "res://city_game/combat/artillery/CityM777Howitzer.tscn"
const HOWITZER_SCRIPT_PATH := "res://city_game/combat/artillery/CityM777Howitzer.gd"
const APPROACH_OFFSET := Vector3(0.0, 0.0, 4.2)
const MAX_BARREL_TO_PLAYER_FORWARD_BEARING_DELTA_DEG := 10.0

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
	if not T.require_true(self, world.has_method("get_world_howitzer_operation_state"), "World howitzer spawn contract requires operation-state introspection so KP_8 retract can prove it exits操炮态 cleanly"):
		return

	var player := world.get_node_or_null("Player") as Node3D
	var orientation := OrientationScript.new()
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "World howitzer spawn contract requires the main world player node with teleport support"):
		return
	var authored_vertical_offset_m := _resolve_howitzer_authored_vertical_offset_m()
	if not T.require_true(self, world.get_active_world_howitzer() == null, "Before pressing KP_8, the main world must not already hold a summoned howitzer instance"):
		return

	var spawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, spawned, "KP_8 must be wired as the main-world howitzer summon shortcut"):
		return
	await _settle_frames()

	var howitzer := world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_fire_state"), "KP_8 summon must instantiate the formal CityM777Howitzer runtime in the main world"):
		return
	if not _require_visible_barrel_faces_player_forward(orientation, player, howitzer, "Fresh summon"):
		return

	var spawned_howitzers := _collect_howitzer_nodes(world)
	if not T.require_true(self, spawned_howitzers.size() == 1, "Summoning the main-world howitzer must create exactly one formal howitzer instance instead of leaving the scene empty or duplicating multiple copies"):
		return

	var horizontal_distance_m := _horizontal_distance(player.global_position, howitzer.global_position)
	if not T.require_true(self, horizontal_distance_m >= 4.0 and horizontal_distance_m <= 18.0, "Summoned howitzer must appear in front of the player at a usable standoff distance instead of underfoot or far away"):
		return
	var raw_spawn_position := world.call("_resolve_world_howitzer_spawn_position") as Vector3
	var expected_spawn_y := raw_spawn_position.y + authored_vertical_offset_m
	if not T.require_true(self, is_equal_approx(howitzer.global_position.y, expected_spawn_y), "Summoned howitzer must preserve the authored root vertical offset instead of snapping the whole asset to the raw surface sample and floating above ground"):
		return
	var yaw_anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var anchor_world := yaw_anchor.global_position if yaw_anchor != null else howitzer.global_position
	player.teleport_to_world_position(anchor_world + APPROACH_OFFSET)
	await _settle_frames()
	_press_key(world, KEY_E)
	await _settle_frames()
	var operation_state := world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, bool(operation_state.get("active", false)), "Approaching the summoned howitzer and pressing E must enter操炮态 before the retract safety path can be verified"):
		return
	if not T.require_true(self, howitzer.has_method("get_debug_state"), "World howitzer spawn contract requires debug_state introspection so the操炮 lanyard binding can be regression tested"):
		return
	var operated_debug_state := howitzer.get_debug_state() as Dictionary
	if not T.require_true(self, bool(operated_debug_state.get("operator_lanyard_target_active", false)), "Entering操炮态 must bind the operator lanyard target onto the active howitzer instead of leaving the fire-control rope detached"):
		return
	var retract_while_operating: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, retract_while_operating, "Pressing KP_8 while the main-world howitzer is still in操炮态 must remain accepted as the retract shortcut"):
		return
	var retracting_debug_state := howitzer.get_debug_state() as Dictionary
	if not T.require_true(self, not bool(retracting_debug_state.get("operator_lanyard_target_active", true)), "Pressing KP_8 while operating the howitzer must first release the operator lanyard target instead of queue_free-ing the gun while the操炮 binding still thinks it owns the player"):
		return
	await _settle_frames()
	if not T.require_true(self, world.get_active_world_howitzer() == null, "Pressing KP_8 while operating the howitzer must retract it instead of leaving the operated gun stranded in the world"):
		return
	operation_state = world.get_world_howitzer_operation_state() as Dictionary
	if not T.require_true(self, not bool(operation_state.get("active", false)), "Retracting with KP_8 while operating the howitzer must also exit操炮态 instead of leaving stale operation ownership behind"):
		return
	spawned_howitzers = _collect_howitzer_nodes(world)
	if not T.require_true(self, spawned_howitzers.is_empty(), "Retracting the currently operated howitzer must remove the runtime instance instead of leaving hidden duplicates behind"):
		return

	var respawn_after_operating_retract: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, respawn_after_operating_retract, "After retracting from操炮态, pressing KP_8 again must still summon the howitzer back normally"):
		return
	await _settle_frames()

	player.global_position += Vector3(36.0, 0.0, -18.0)
	player.rotation.y = deg_to_rad(90.0)
	await _settle_frames()

	var recalled: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, recalled, "Pressing KP_8 again must still be accepted as the world howitzer toggle shortcut"):
		return
	await _settle_frames()
	if not T.require_true(self, world.get_active_world_howitzer() == null, "Pressing KP_8 a second time must retract the currently summoned howitzer instead of silently respawning or leaving it in place"):
		return
	spawned_howitzers = _collect_howitzer_nodes(world)
	if not T.require_true(self, spawned_howitzers.is_empty(), "Retracting the world howitzer must remove the active howitzer instance instead of leaving hidden duplicates in the scene tree"):
		return

	var respawned: bool = world.handle_debug_keypress(KEY_KP_8, KEY_KP_8)
	if not T.require_true(self, respawned, "After retracting, pressing KP_8 again must summon the world howitzer back"):
		return
	await _settle_frames()

	howitzer = world.get_active_world_howitzer() as Node3D
	if not T.require_true(self, howitzer != null, "After re-summoning, CityPrototype must still expose the currently active howitzer instance"):
		return
	if not _require_visible_barrel_faces_player_forward(orientation, player, howitzer, "Re-summon"):
		return
	spawned_howitzers = _collect_howitzer_nodes(world)
	if not T.require_true(self, spawned_howitzers.size() == 1, "Re-summoning must replace or reposition the current howitzer instead of accumulating multiple world instances"):
		return
	horizontal_distance_m = _horizontal_distance(player.global_position, howitzer.global_position)
	if not T.require_true(self, horizontal_distance_m >= 4.0 and horizontal_distance_m <= 18.0, "Re-summoned howitzer must follow the player's new position/orientation instead of staying at the old summon point"):
		return
	raw_spawn_position = world.call("_resolve_world_howitzer_spawn_position") as Vector3
	expected_spawn_y = raw_spawn_position.y + authored_vertical_offset_m
	if not T.require_true(self, is_equal_approx(howitzer.global_position.y, expected_spawn_y), "Re-summoned howitzer must keep the authored vertical offset at the new summon point instead of floating after repositioning"):
		return

	world.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _resolve_howitzer_authored_vertical_offset_m() -> float:
	var howitzer_scene := load(HOWITZER_SCENE_PATH)
	if howitzer_scene == null or not (howitzer_scene is PackedScene):
		return 0.0
	var reference_howitzer := (howitzer_scene as PackedScene).instantiate() as Node3D
	if reference_howitzer == null:
		return 0.0
	var authored_vertical_offset_m := reference_howitzer.position.y
	reference_howitzer.queue_free()
	return authored_vertical_offset_m

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

func _require_visible_barrel_faces_player_forward(orientation, player: Node3D, howitzer: Node3D, label: String) -> bool:
	var player_forward := -player.global_transform.basis.z
	player_forward.y = 0.0
	var barrel_probe := _resolve_visible_barrel_probe(howitzer)
	var barrel_direction_world := barrel_probe.get("direction_world", Vector3.ZERO) as Vector3
	barrel_direction_world.y = 0.0
	if not T.require_true(self, player_forward.length_squared() > 0.0001 and barrel_direction_world.length_squared() > 0.0001, "%s world howitzer summon must produce measurable planar forward vectors for both player and barrel" % label):
		return false
	var player_bearing_deg := float(orientation.bearing_deg_from_world_vector(player_forward.normalized()))
	var barrel_bearing_deg := float(orientation.bearing_deg_from_world_vector(barrel_direction_world.normalized()))
	var bearing_delta_deg := absf(float(orientation.shortest_bearing_delta_deg(player_bearing_deg, barrel_bearing_deg)))
	return T.require_true(self, bearing_delta_deg <= MAX_BARREL_TO_PLAYER_FORWARD_BEARING_DELTA_DEG, "%s summoned howitzer barrel must face roughly the same direction as the player's summon forward instead of starting out turned back toward the operator (player=%0.2f barrel=%0.2f delta=%0.2f)" % [label, player_bearing_deg, barrel_bearing_deg, bearing_delta_deg])

func _resolve_visible_barrel_probe(howitzer: Node3D) -> Dictionary:
	var pitch_pivot := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot") as Node3D
	var gun_assembly := howitzer.get_node_or_null("ModelRoot/YawPivot/PitchPivot/m777_gun_assembly") as VisualInstance3D
	if pitch_pivot == null or gun_assembly == null:
		return {}
	var pivot_world_position := pitch_pivot.global_position
	var aabb := gun_assembly.get_aabb()
	var axis_index := _resolve_long_axis_index(aabb.size)
	var local_tip_point := _resolve_forward_face_center_local(aabb, gun_assembly.transform, axis_index)
	var world_tip_point: Vector3 = gun_assembly.global_transform * local_tip_point
	var direction_world := world_tip_point - pivot_world_position
	return {
		"direction_world": direction_world.normalized(),
		"length_m": direction_world.length(),
	}

func _resolve_long_axis_index(size: Vector3) -> int:
	if size.y >= size.x and size.y >= size.z:
		return 1
	if size.z >= size.x and size.z >= size.y:
		return 2
	return 0

func _resolve_forward_face_center_local(aabb: AABB, local_transform: Transform3D, axis_index: int) -> Vector3:
	var local_face_min := aabb.position + aabb.size * 0.5
	var local_face_max := local_face_min
	match axis_index:
		0:
			local_face_min.x = aabb.position.x
			local_face_max.x = aabb.position.x + aabb.size.x
		1:
			local_face_min.y = aabb.position.y
			local_face_max.y = aabb.position.y + aabb.size.y
		2:
			local_face_min.z = aabb.position.z
			local_face_max.z = aabb.position.z + aabb.size.z
	var parent_face_min: Vector3 = local_transform * local_face_min
	var parent_face_max: Vector3 = local_transform * local_face_max
	if parent_face_max.length_squared() >= parent_face_min.length_squared():
		return local_face_max
	return local_face_min

func _build_key_event(keycode: Key, pressed: bool) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.pressed = pressed
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	return key_event

func _press_key(target: Node, keycode: Key) -> void:
	target._unhandled_input(_build_key_event(keycode, true))

func _settle_frames(frame_count: int = 6) -> void:
	for _frame_index in range(frame_count):
		await physics_frame
		await process_frame
