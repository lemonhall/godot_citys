extends SceneTree
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkKey := preload("res://city_game/world/streaming/CityChunkKey.gd")
const ROUTES := {
	"inspection": [
		Vector3(-600.0, 1.1, 26.0),
		Vector3(0.0, 1.1, 26.0),
		Vector3(768.0, 1.1, 26.0),
		Vector3(1536.0, 1.1, 26.0),
	],
	"first_visit": [
		Vector3(0.0, 1.1, 0.0),
		Vector3(512.0, 1.1, 192.0),
		Vector3(1024.0, 1.1, 384.0),
		Vector3(1536.0, 1.1, 576.0),
		Vector3(2048.0, 1.1, 768.0),
	],
}
func _init() -> void:
	call_deferred("_run")
func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var query = world_data.get("pedestrian_query")
	for route_name in ROUTES.keys():
		var seen := {}
		var zero_capacity_count := 0
		var low_capacity_count := 0
		var total_capacity := 0
		var road_class_totals := {}
		var sampled_chunk_ids: Array[String] = []
		for waypoint in ROUTES[route_name]:
			var chunk_key: Vector2i = CityChunkKey.world_to_chunk_key(config, waypoint)
			for dx in range(-2, 3):
				for dy in range(-2, 3):
					var sample_key := Vector2i(chunk_key.x + dx, chunk_key.y + dy)
					var chunk_id := config.format_chunk_id(sample_key)
					if seen.has(chunk_id):
						continue
					seen[chunk_id] = true
					sampled_chunk_ids.append(chunk_id)
					var chunk_query: Dictionary = query.get_pedestrian_query_for_chunk(sample_key)
					var spawn_capacity := int(chunk_query.get("spawn_capacity", 0))
					total_capacity += spawn_capacity
					if spawn_capacity <= 0:
						zero_capacity_count += 1
					elif spawn_capacity <= 3:
						low_capacity_count += 1
					var road_class_counts: Dictionary = chunk_query.get("road_class_counts", {})
					for road_class_variant in road_class_counts.keys():
						var road_class := str(road_class_variant)
						road_class_totals[road_class] = int(road_class_totals.get(road_class, 0)) + int(road_class_counts.get(road_class, 0))
		print(JSON.stringify({
			"route": route_name,
			"sampled_chunk_count": sampled_chunk_ids.size(),
			"zero_capacity_count": zero_capacity_count,
			"low_capacity_count": low_capacity_count,
			"total_capacity": total_capacity,
			"average_capacity": float(total_capacity) / float(maxi(sampled_chunk_ids.size(), 1)),
			"road_class_totals": road_class_totals,
		}))
	quit()
