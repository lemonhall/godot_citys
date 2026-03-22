extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Fishing venue cast loop contract requires LakeFishingLab.tscn"):
		return
	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var venue := lab.get_node_or_null("VenueRoot") as Node3D
	if not T.require_true(self, venue != null and venue.has_method("get_fishing_contract"), "Fishing venue cast loop contract requires the authored fishing venue root"):
		return
	var contract: Dictionary = venue.get_fishing_contract()
	var seat_anchor: Dictionary = venue.get_seat_anchor("seat_main") if venue.has_method("get_seat_anchor") else {}
	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Fishing venue cast loop contract requires Player teleport API"):
		return
	player.teleport_to_world_position(seat_anchor.get("world_position", Vector3.ZERO) + Vector3.UP * _estimate_standing_height(player))

	var seat_result: Dictionary = lab.request_fishing_primary_interaction()
	if not T.require_true(self, bool(seat_result.get("success", false)), "Fishing venue cast loop contract must allow the player to enter the seat flow"):
		return
	var runtime_state: Dictionary = lab.get_fishing_runtime_state()
	if not T.require_true(self, bool(runtime_state.get("fishing_mode_active", false)), "Fishing venue cast loop contract must activate fishing_mode_active after seating"):
		return
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "seated", "Fishing venue cast loop contract must enter seated state before casting"):
		return

	var cast_result: Dictionary = lab.request_fishing_primary_interaction()
	if not T.require_true(self, bool(cast_result.get("success", false)), "Fishing venue cast loop contract must allow a formal cast from seated state"):
		return
	runtime_state = await _wait_for_cast_state(lab, "bite_window")
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "bite_window", "Fishing venue cast loop contract must expose a bite_window state after cast_out"):
		return
	if not T.require_true(self, bool(runtime_state.get("bite_window_active", false)), "Fishing venue cast loop contract must surface bite_window_active while the fish is on the line"):
		return

	var reel_result: Dictionary = lab.request_fishing_primary_interaction()
	if not T.require_true(self, bool(reel_result.get("success", false)), "Fishing venue cast loop contract must allow reel interaction inside the bite window"):
		return
	runtime_state = lab.get_fishing_runtime_state()
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "catch_resolved", "Fishing venue cast loop contract must resolve into catch_resolved after a valid reel"):
		return
	var last_catch_result: Dictionary = runtime_state.get("last_catch_result", {})
	if not T.require_true(self, str(last_catch_result.get("result", "")) == "caught", "Fishing venue cast loop contract must preserve the caught result payload"):
		return
	if not T.require_true(self, str(last_catch_result.get("school_id", "")) != "", "Fishing venue cast loop contract must preserve the targeted school id on catch result"):
		return

	var reset_result: Dictionary = lab.request_fishing_primary_interaction()
	if not T.require_true(self, bool(reset_result.get("success", false)), "Fishing venue cast loop contract must allow the player to reset after catch resolution"):
		return
	runtime_state = lab.get_fishing_runtime_state()
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "idle", "Fishing venue cast loop contract must return to idle after reset"):
		return
	if not T.require_true(self, not bool(runtime_state.get("fishing_mode_active", true)), "Fishing venue cast loop contract must release fishing_mode_active after reset"):
		return
	if not T.require_true(self, str(contract.get("linked_region_id", "")) == "region:v38:fishing_lake:chunk_147_181", "Fishing venue cast loop contract must stay linked to the canonical lake region"):
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

func _estimate_standing_height(player) -> float:
	var collision_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return capsule.radius + capsule.height * 0.5
	if collision_shape.shape is BoxShape3D:
		var box := collision_shape.shape as BoxShape3D
		return box.size.y * 0.5
	return 1.0
