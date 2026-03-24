extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/M777HowitzerLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "M777 lab compass contract requires a dedicated lab scene"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "M777 lab compass contract must load the lab scene as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	if not T.require_true(self, lab != null, "M777 lab compass contract must instantiate as Node3D"):
		return
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("get_orientation_contract"), "M777 lab must expose get_orientation_contract() to keep parity with the main-world orientation system"):
		return
	if not T.require_true(self, lab.has_method("get_compass_state"), "M777 lab must expose get_compass_state() once compass HUD is added"):
		return
	if not T.require_true(self, lab.get_node_or_null("Hud/Root/Compass") != null, "M777 lab HUD must mount a formal Compass control instead of only using text labels"):
		return

	var orientation_contract: Dictionary = lab.get_orientation_contract()
	if not T.require_true(self, bool(orientation_contract.get("north_up", false)), "M777 lab orientation contract must keep map north aligned with world north"):
		return

	var compass_state: Dictionary = lab.get_compass_state()
	if not T.require_true(self, bool(compass_state.get("visible", false)), "M777 lab compass state must stay visible while the lab is active"):
		return
	if not T.require_true(self, str(compass_state.get("cardinal_text", "")) != "", "M777 lab compass state must expose a cardinal cue"):
		return

	var player := lab.get_node_or_null("Player") as Node3D
	if not T.require_true(self, player != null, "M777 lab compass contract requires the formal player node"):
		return
	player.rotation.y = -PI * 0.5
	lab.call("_refresh_hud")
	await process_frame

	compass_state = lab.get_compass_state()
	if not T.require_true(self, absf(float(compass_state.get("bearing_deg", -999.0)) - 90.0) <= 0.5, "Turning the lab player to face east must report 90 degrees on the shared compass contract"):
		return
	if not T.require_true(self, str(compass_state.get("cardinal_text", "")) == "E", "Turning the lab player to face east must report E on the shared compass contract"):
		return

	lab.reset_lab_state()
	lab.call("_refresh_hud")
	await process_frame

	compass_state = lab.get_compass_state()
	if not T.require_true(self, absf(float(compass_state.get("bearing_deg", -999.0))) <= 0.5, "Resetting the M777 lab must restore the player-facing compass to the default north-facing zero bearing"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)
