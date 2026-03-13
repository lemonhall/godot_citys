extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianCrowdRenderer := preload("res://city_game/world/pedestrians/rendering/CityPedestrianCrowdRenderer.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var renderer := CityPedestrianCrowdRenderer.new()
	root.add_child(renderer)
	await process_frame
	renderer.setup({"chunk_center": Vector3.ZERO})

	renderer.apply_chunk_snapshot({
		"chunk_id": "chunk_0000_0000",
		"tier0_count": 0,
		"tier1_count": 0,
		"tier2_count": 1,
		"tier3_count": 0,
		"tier1_states": [],
		"tier2_states": [_build_state("ped:tier2", Vector3(4.0, 0.0, 2.0), 17, "none", "alive")],
		"tier3_states": [],
	})
	await process_frame

	var tier2_root := renderer.get_node_or_null("Tier2Agents") as Node3D
	if not T.require_true(self, tier2_root != null, "Crowd renderer must mount a Tier2Agents root for nearfield civilian visuals"):
		renderer.queue_free()
		return
	if not T.require_true(self, tier2_root.get_child_count() == 1, "Tier2 snapshot must materialize exactly one nearfield visual agent"):
		renderer.queue_free()
		return

	var tier2_visual := tier2_root.get_child(0) as Node
	if not T.require_true(self, tier2_visual != null and tier2_visual.has_method("get_current_animation_name"), "Tier2 nearfield visual must expose get_current_animation_name() for animation routing validation"):
		renderer.queue_free()
		return
	if not T.require_true(self, tier2_visual.has_method("uses_placeholder_box_mesh"), "Tier2 nearfield visual must expose uses_placeholder_box_mesh() for anti-placeholder validation"):
		renderer.queue_free()
		return
	if not T.require_true(self, not bool(tier2_visual.call("uses_placeholder_box_mesh")), "Tier2 nearfield visual must not keep using BoxMesh placeholder bodies in M8"):
		renderer.queue_free()
		return

	var walk_animation := str(tier2_visual.call("get_current_animation_name"))
	if not T.require_true(self, _has_any_token(walk_animation, ["walk"]), "Ambient Tier2 pedestrian must play a walk clip instead of standing-box translation"):
		renderer.queue_free()
		return

	renderer.apply_chunk_snapshot({
		"chunk_id": "chunk_0000_0000",
		"tier0_count": 0,
		"tier1_count": 0,
		"tier2_count": 1,
		"tier3_count": 0,
		"tier1_states": [],
		"tier2_states": [_build_state("ped:tier2", Vector3(4.0, 0.0, 2.0), 17, "none", "dead")],
		"tier3_states": [],
	})
	await process_frame

	var death_animation := str(tier2_visual.call("get_current_animation_name"))
	if not T.require_true(self, _has_any_token(death_animation, ["death", "dead"]), "Dead Tier2 pedestrian must route into a death clip when the model provides one"):
		renderer.queue_free()
		return

	renderer.queue_free()
	T.pass_and_quit(self)

func _build_state(pedestrian_id: String, world_position: Vector3, seed_value: int, reaction_state: String, life_state: String) -> Dictionary:
	return {
		"pedestrian_id": pedestrian_id,
		"world_position": world_position,
		"heading": Vector3.FORWARD,
		"height_m": 1.75,
		"radius_m": 0.28,
		"seed": seed_value,
		"archetype_id": "resident",
		"archetype_signature": "resident:v0",
		"reaction_state": reaction_state,
		"life_state": life_state,
	}

func _has_any_token(animation_name: String, tokens: Array[String]) -> bool:
	var normalized_animation := animation_name.to_lower()
	for token in tokens:
		if normalized_animation.find(token) >= 0:
			return true
	return false
