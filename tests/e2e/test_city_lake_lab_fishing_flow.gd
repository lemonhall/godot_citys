extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lake lab fishing flow requires LakeFishingLab.tscn"):
		return
	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player")
	var venue := lab.get_node_or_null("VenueRoot") as Node3D
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake lab fishing flow requires Player teleport API"):
		return
	if not T.require_true(self, venue != null and venue.has_method("get_seat_anchor"), "Lake lab fishing flow requires the authored seat anchor contract"):
		return
	var seat_anchor: Dictionary = venue.get_seat_anchor("seat_main")
	player.teleport_to_world_position(seat_anchor.get("world_position", Vector3.ZERO) + Vector3.UP * 1.2)

	if not T.require_true(self, bool(lab.request_fishing_primary_interaction().get("success", false)), "Lake lab fishing flow must seat the player first"):
		return
	if not T.require_true(self, bool(lab.request_fishing_primary_interaction().get("success", false)), "Lake lab fishing flow must allow a cast after seating"):
		return
	var runtime_state: Dictionary = await _wait_for_cast_state(lab, "bite_window")
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "bite_window", "Lake lab fishing flow must reach bite_window before reeling"):
		return
	if not T.require_true(self, bool(lab.request_fishing_primary_interaction().get("success", false)), "Lake lab fishing flow must resolve the catch from the bite window"):
		return
	runtime_state = lab.get_fishing_runtime_state()
	if not T.require_true(self, str(runtime_state.get("last_catch_result", {}).get("result", "")) == "caught", "Lake lab fishing flow must finish with a caught result"):
		return
	if not T.require_true(self, bool(lab.request_fishing_primary_interaction().get("success", false)), "Lake lab fishing flow must allow reset after catch resolution"):
		return
	runtime_state = lab.get_fishing_runtime_state()
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "idle", "Lake lab fishing flow must return to idle after reset"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_cast_state(lab, expected_state: String) -> Dictionary:
	for _frame in range(180):
		await physics_frame
		await process_frame
		var runtime_state: Dictionary = lab.get_fishing_runtime_state()
		if str(runtime_state.get("cast_state", "")) == expected_state:
			return runtime_state
	return lab.get_fishing_runtime_state()
