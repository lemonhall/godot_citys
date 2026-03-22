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
	if not T.require_true(self, venue != null and venue.has_method("get_fishing_contract") and venue.has_method("get_pole_anchor"), "Fishing venue cast loop contract requires the authored fishing venue root with formal pole anchor API"):
		return
	var contract: Dictionary = venue.get_fishing_contract()
	var pole_anchor: Dictionary = venue.get_pole_anchor() if venue.has_method("get_pole_anchor") else {}
	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Fishing venue cast loop contract requires Player teleport API"):
		return
	if not T.require_true(self, lab.has_method("set_fishing_cast_preview_active"), "Fishing venue cast loop contract requires direct cast-preview control in the lab wrapper"):
		return
	if not T.require_true(self, lab.has_method("request_fishing_cast_action"), "Fishing venue cast loop contract requires direct cast-action control in the lab wrapper"):
		return
	if not T.require_true(self, lab.has_method("debug_set_fishing_bite_delay_override"), "Fishing venue cast loop contract requires deterministic bite-delay override for focused regression"):
		return
	player.teleport_to_world_position(pole_anchor.get("world_position", Vector3.ZERO) + Vector3.UP * _estimate_standing_height(player))

	var equip_result: Dictionary = lab.request_fishing_primary_interaction()
	if not T.require_true(self, bool(equip_result.get("success", false)), "Fishing venue cast loop contract must allow the player to equip the authored fishing pole through the shared E interaction entrypoint"):
		return
	var runtime_state: Dictionary = lab.get_fishing_runtime_state()
	if not T.require_true(self, bool(runtime_state.get("fishing_mode_active", false)), "Fishing venue cast loop contract must activate fishing_mode_active after pole pickup"):
		return
	if not T.require_true(self, bool(runtime_state.get("pole_equipped", false)), "Fishing venue cast loop contract must expose pole_equipped = true after pickup"):
		return
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "equipped", "Fishing venue cast loop contract must enter equipped state after the player picks up the authored pole"):
		return
	lab.debug_set_fishing_bite_delay_override(0.05)
	if not T.require_true(self, bool(lab.set_fishing_cast_preview_active(true).get("success", false)), "Fishing venue cast loop contract must allow entering the right-click cast preview state while the pole is equipped"):
		return

	var cast_result: Dictionary = lab.request_fishing_cast_action()
	if not T.require_true(self, bool(cast_result.get("success", false)), "Fishing venue cast loop contract must allow a formal cast through the dedicated cast action entrypoint"):
		return
	runtime_state = lab.get_fishing_runtime_state()
	if not T.require_true(self, bool(runtime_state.get("bobber_visible", false)), "Fishing venue cast loop contract must expose a visible fishing bobber after cast_out"):
		return
	if not T.require_true(self, bool(runtime_state.get("fishing_line_visible", false)), "Fishing venue cast loop contract must expose a visible fishing line after cast_out"):
		return
	runtime_state = await _wait_for_cast_state(lab, "bite_ready")
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "bite_ready", "Fishing venue cast loop contract must expose a bite_ready state after the randomized waiting period resolves"):
		return
	if not T.require_true(self, bool(runtime_state.get("bobber_bite_feedback_active", false)), "Fishing venue cast loop contract must surface bobber bite feedback while a fish is on the line"):
		return

	var reel_result: Dictionary = lab.request_fishing_cast_action()
	if not T.require_true(self, bool(reel_result.get("success", false)), "Fishing venue cast loop contract must allow reel interaction through the dedicated cast action entrypoint when a fish is on the line"):
		return
	runtime_state = lab.get_fishing_runtime_state()
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "equipped", "Fishing venue cast loop contract must return to equipped state after a successful catch so the player can cast again without re-picking the pole"):
		return
	var last_catch_result: Dictionary = runtime_state.get("last_catch_result", {})
	if not T.require_true(self, str(last_catch_result.get("result", "")) == "caught", "Fishing venue cast loop contract must preserve the caught result payload"):
		return
	if not T.require_true(self, str(last_catch_result.get("school_id", "")) != "", "Fishing venue cast loop contract must preserve the targeted school id on catch result"):
		return

	var stow_result: Dictionary = lab.request_fishing_primary_interaction()
	if not T.require_true(self, bool(stow_result.get("success", false)), "Fishing venue cast loop contract must allow the player to put the pole back with E after a catch"):
		return
	runtime_state = lab.get_fishing_runtime_state()
	if not T.require_true(self, str(runtime_state.get("cast_state", "")) == "idle", "Fishing venue cast loop contract must return to idle after the player puts the pole back"):
		return
	if not T.require_true(self, not bool(runtime_state.get("fishing_mode_active", true)), "Fishing venue cast loop contract must release fishing_mode_active after reset"):
		return
	if not T.require_true(self, not bool(runtime_state.get("pole_equipped", true)), "Fishing venue cast loop contract must release pole_equipped after the pole is stowed"):
		return
	if not T.require_true(self, str(contract.get("linked_region_id", "")) == "region:v38:fishing_lake:chunk_147_181", "Fishing venue cast loop contract must stay linked to the canonical lake region"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_cast_state(lab, expected_state: String) -> Dictionary:
	for _frame in range(240):
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
