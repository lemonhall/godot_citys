extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianReactionModel := preload("res://city_game/world/pedestrians/simulation/CityPedestrianReactionModel.gd")

const SHOT_RANGE_M := 36.0
const SHOT_ORIGINS := [
	Vector3.ZERO,
	Vector3(0.18, 0.0, 0.06),
	Vector3(-0.12, 0.0, -0.08),
	Vector3(0.09, 0.0, 0.04),
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var reaction_model := CityPedestrianReactionModel.new()
	reaction_model.set_player_context(Vector3.ZERO, Vector3.ZERO)

	for shot_origin in SHOT_ORIGINS:
		reaction_model.notify_projectile_event(shot_origin, Vector3.RIGHT, SHOT_RANGE_M)

	var threat_regions: Array[Dictionary] = reaction_model.get_active_threat_regions(_build_budget_contract())
	var projectile_region_count := 0
	var gunshot_region_count := 0
	for region_variant in threat_regions:
		var region: Dictionary = region_variant
		match str(region.get("type", "")):
			"projectile":
				projectile_region_count += 1
			"gunshot":
				gunshot_region_count += 1

	print("CITY_PEDESTRIAN_PROJECTILE_EVENT_COALESCING %s" % JSON.stringify({
		"shot_count": SHOT_ORIGINS.size(),
		"event_count": reaction_model.get_event_count(),
		"projectile_region_count": projectile_region_count,
		"gunshot_region_count": gunshot_region_count,
	}))

	if not T.require_true(self, reaction_model.get_event_count() <= 2, "Repeated rifle shots should coalesce into one projectile threat and one gunshot threat instead of appending duplicates"):
		return
	if not T.require_true(self, projectile_region_count == 1, "Repeated rifle shots should expose a single coalesced projectile threat region"):
		return
	if not T.require_true(self, gunshot_region_count == 1, "Repeated rifle shots should expose a single coalesced gunshot threat region"):
		return

	T.pass_and_quit(self)

func _build_budget_contract() -> Dictionary:
	return {
		"violent_witness_core_radius_m": 200.0,
		"violent_witness_outer_response_ratio": 0.4,
		"gunshot_radius_m": 400.0,
		"projectile_reaction_radius_m": 4.5,
	}
