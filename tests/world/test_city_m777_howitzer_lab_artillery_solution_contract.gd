extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/M777HowitzerLab.tscn"
const INSIDE_INTERACTION_OFFSET := Vector3(0.0, 0.0, 6.8)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 lab artillery solution contract requires the dedicated lab PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	if not T.require_true(self, lab != null, "M777 lab artillery solution contract must instantiate as Node3D"):
		return

	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player") as CharacterBody3D
	var howitzer := lab.get_node_or_null("ArtilleryRoot/Howitzer") as Node3D
	var hud := lab.get_node_or_null("Hud")
	var fire_audio := lab.get_node_or_null("ArtilleryRoot/Howitzer/ModelRoot/YawPivot/PitchPivot/FirePresentationRoot/FireAudio") as AudioStreamPlayer3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "M777 lab artillery solution contract requires the formal player teleport API"):
		return
	if not T.require_true(self, howitzer != null and howitzer.has_method("get_firing_solution_snapshot"), "M777 lab artillery solution contract requires the formal howitzer firing solution API in the lab hierarchy"):
		return
	if not T.require_true(self, hud != null and hud.has_method("get_artillery_solution_state"), "M777 lab artillery solution contract requires PrototypeHud artillery solution introspection"):
		return
	if not T.require_true(self, fire_audio != null, "M777 lab artillery solution contract requires the formal howitzer fire audio node so post-shot cleanup can release playback resources cleanly"):
		return
	if not T.require_true(self, hud.get_node_or_null("Root/ArtillerySolutionHud") != null, "M777 lab artillery solution contract requires the formal ArtillerySolutionHud view in the shared HUD root"):
		return

	var initial_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, not bool(initial_state.get("visible", false)), "Outside operation mode, artillery solution HUD must stay hidden so J/L/I/K ownership remains contextual"):
		return

	var anchor := howitzer.get_node_or_null("Anchors/YawPivotAnchor") as Node3D
	var interaction_anchor := anchor.global_position if anchor != null else howitzer.global_position
	player.teleport_to_world_position(interaction_anchor + INSIDE_INTERACTION_OFFSET)
	await _settle_frames()

	var nearby_hidden_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, not bool(nearby_hidden_state.get("visible", false)), "Entering the 7m interaction radius alone must not reveal artillery solution HUD before the player actually presses E to operate the gun"):
		return

	_press_key(lab, KEY_E)
	await _settle_frames()

	var active_operation_state := lab.get_operation_state() as Dictionary
	if not T.require_true(self, bool(active_operation_state.get("active", false)), "Pressing E in range must enter howitzer operation mode before artillery solution HUD becomes visible"):
		return

	var active_hud_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, bool(active_hud_state.get("visible", false)), "Entering howitzer operation mode must surface the artillery solution HUD"):
		return

	var expected_solution := howitzer.get_firing_solution_snapshot() as Dictionary
	if not T.require_true(self, absf(float(active_hud_state.get("yaw_bearing_deg", -999.0)) - float(expected_solution.get("world_bearing_deg", 0.0))) <= 0.05, "Lab artillery solution HUD must show the howitzer muzzle's formal world bearing instead of a separate lab-only yaw estimate"):
		return
	if not T.require_true(self, absf(float(active_hud_state.get("pitch_deg", -999.0)) - float(expected_solution.get("pitch_deg", 0.0))) <= 0.05, "Lab artillery solution HUD must show the same calibrated pitch value exposed by the formal howitzer firing solution snapshot"):
		return

	lab.adjust_yaw_degrees(21.0)
	lab.adjust_pitch_degrees(12.0)
	await _settle_frames()

	var adjusted_hud_state := hud.get_artillery_solution_state() as Dictionary
	expected_solution = howitzer.get_firing_solution_snapshot() as Dictionary
	if not T.require_true(self, absf(float(adjusted_hud_state.get("yaw_bearing_deg", -999.0)) - float(expected_solution.get("world_bearing_deg", 0.0))) <= 0.05, "After操炮调向, the lab HUD must keep following the formal world-bearing firing solution state"):
		return
	if not T.require_true(self, absf(float(adjusted_hud_state.get("pitch_deg", -999.0)) - float(expected_solution.get("pitch_deg", 0.0))) <= 0.05, "After操炮调高低, the lab HUD must keep following the formal pitch firing solution state"):
		return

	var fire_result := lab.request_fire() as Dictionary
	if not T.require_true(self, bool(fire_result.get("accepted", false)), "Lab artillery solution contract requires an accepted shot so the persisted firing solution payload can be verified through the real operation path"):
		return
	if not T.require_true(self, fire_result.get("firing_solution", null) is Dictionary, "Lab request_fire() must return the howitzer's formal firing_solution payload once the operation path is active"):
		return
	var last_fired_solution := howitzer.get_last_fired_solution() as Dictionary
	if not T.require_true(self, absf(float(last_fired_solution.get("world_bearing_deg", -999.0)) - float((fire_result.get("firing_solution", {}) as Dictionary).get("world_bearing_deg", 0.0))) <= 0.01, "The lab operation path must preserve the same firing solution payload that the underlying howitzer runtime stores as last_fired_solution"):
		return

	_press_key(lab, KEY_E)
	await _settle_frames()

	var exit_state := hud.get_artillery_solution_state() as Dictionary
	if not T.require_true(self, not bool(exit_state.get("visible", false)), "Exiting howitzer operation mode must hide the artillery solution HUD again instead of leaving stale firing readouts on screen"):
		return

	if fire_audio.playing:
		fire_audio.stop()
		await process_frame
	lab.queue_free()
	await physics_frame
	await process_frame
	await process_frame
	T.pass_and_quit(self)

func _press_key(target: Node, keycode: Key) -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.echo = false
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	target._unhandled_input(key_event)

func _settle_frames(frame_count: int = 4) -> void:
	for _frame_index in range(frame_count):
		await process_frame
