extends SceneTree

# v63 M2: history core / axes / ring railway.
# REQ-0034-003.

const T := preload("res://tests/_test_util.gd")
const GENERATOR_PATH := "res://city_game/world/generation/plan/CityPlanGenerator.gd"
const CityTerrainPlan := preload("res://city_game/world/generation/plan/CityTerrainPlan.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generator_script = load(GENERATOR_PATH)
	if not T.require_true(self, generator_script != null, "CityPlanGenerator must exist"):
		return
	var plan: Dictionary = generator_script.new().generate(12345)
	var history: Dictionary = plan.get("history", {})
	if not T.require_true(self, not history.is_empty(), "plan must carry a history layer"):
		return
	var core: Vector2 = history.get("core", Vector2.ZERO)
	var terrain: Dictionary = plan.get("terrain", {})
	var river_distance := CityTerrainPlan.river_distance(terrain, core.x, core.y)
	if not T.require_true(self, river_distance <= 800.0, "old-town core must sit within 800m of water"):
		return
	if not T.require_true(self, (history.get("axes", []) as Array).size() >= 2, "history must expose at least two growth axes"):
		return
	var rail: Dictionary = history.get("rail", {})
	var rail_points: Array = rail.get("points", [])
	if not T.require_true(self, rail_points.size() >= 24, "rail must be a closed polyline with at least 24 points"):
		return
	var first: Vector3 = rail_points[0]
	var last: Vector3 = rail_points[rail_points.size() - 1]
	if not T.require_true(self, first.distance_to(last) < 1.0, "rail polyline must be closed"):
		return
	if not T.require_true(self, (history.get("stations", []) as Array).size() >= 3, "history must expose at least three stations"):
		return
	T.pass_and_quit(self)
