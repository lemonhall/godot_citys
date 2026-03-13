extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianReactiveAgent := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactiveAgent.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var agent := CityPedestrianReactiveAgent.new()
	root.add_child(agent)
	await process_frame

	agent.apply_state(_build_state(Vector3(2.0, 0.0, -3.0), 23, "flee", "alive"), Vector3.ZERO)
	await process_frame

	if not T.require_true(self, agent.has_method("get_current_animation_name"), "Tier3 reactive visual must expose get_current_animation_name() for animation routing validation"):
		agent.queue_free()
		return
	if not T.require_true(self, agent.has_method("uses_placeholder_box_mesh"), "Tier3 reactive visual must expose uses_placeholder_box_mesh() for anti-placeholder validation"):
		agent.queue_free()
		return
	if not T.require_true(self, not bool(agent.call("uses_placeholder_box_mesh")), "Tier3 reactive visual must stop using BoxMesh placeholders in M8"):
		agent.queue_free()
		return

	var run_animation := str(agent.call("get_current_animation_name"))
	if not T.require_true(self, _has_any_token(run_animation, ["run"]), "Panic/flee Tier3 pedestrian must route into a run clip instead of static box translation"):
		agent.queue_free()
		return

	agent.apply_state(_build_state(Vector3(2.0, 0.0, -3.0), 23, "none", "dead"), Vector3.ZERO)
	await process_frame

	var death_animation := str(agent.call("get_current_animation_name"))
	if not T.require_true(self, _has_any_token(death_animation, ["death", "dead"]), "Dead Tier3 pedestrian must route into a death clip when the model provides one"):
		agent.queue_free()
		return

	agent.queue_free()
	T.pass_and_quit(self)

func _build_state(world_position: Vector3, seed_value: int, reaction_state: String, life_state: String) -> Dictionary:
	return {
		"pedestrian_id": "ped:tier3",
		"world_position": world_position,
		"heading": Vector3.RIGHT,
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
