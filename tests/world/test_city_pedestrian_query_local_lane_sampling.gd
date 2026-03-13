extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianQuery := preload("res://city_game/world/pedestrians/model/CityPedestrianQuery.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var query := CityPedestrianQuery.new()
	var lane_points: Array = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(10000.0, 0.0, 0.0),
	]
	var spawn_rect := Rect2(Vector2(5000.0, -10.0), Vector2(100.0, 20.0))
	var local_length := query._measure_lane_length_in_rect(lane_points, spawn_rect)
	if not T.require_true(self, absf(local_length - 100.0) <= 0.001, "Chunk-local lane sampling test requires clipped lane length to match rect overlap"):
		return

	var sampled_positions: Array[Vector3] = query._sample_lane_positions_in_rect(lane_points, 2, spawn_rect)
	if not T.require_true(self, sampled_positions.size() == 2, "Chunk-local lane sampling must fill the full local slot budget for a long lane crossing a small rect"):
		return

	for position in sampled_positions:
		if not T.require_true(self, spawn_rect.has_point(Vector2(position.x, position.z)), "Chunk-local lane sampling must keep sampled positions inside the spawn rect"):
			return

	if not T.require_true(self, sampled_positions[0].x < sampled_positions[1].x, "Chunk-local lane sampling must preserve forward ordering inside the clipped rect"):
		return

	T.pass_and_quit(self)
