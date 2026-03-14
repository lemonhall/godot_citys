extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var vehicle_query = world_data.get("vehicle_query")
	if not T.require_true(self, vehicle_query != null and vehicle_query.has_method("get_vehicle_query_for_chunk"), "vehicle_query must exist for service vehicle coverage validation"):
		return

	var visual_catalog := CityVehicleVisualCatalog.new()
	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var center_chunk := Vector2i(chunk_grid.x / 2, chunk_grid.y / 2)
	var total_slots := 0
	var service_count := 0
	var police_count := 0
	for offset_y in range(-2, 3):
		for offset_x in range(-2, 3):
			var chunk_key := center_chunk + Vector2i(offset_x, offset_y)
			if chunk_key.x < 0 or chunk_key.y < 0 or chunk_key.x >= chunk_grid.x or chunk_key.y >= chunk_grid.y:
				continue
			var chunk_query: Dictionary = vehicle_query.get_vehicle_query_for_chunk(chunk_key)
			for slot_variant in chunk_query.get("spawn_slots", []):
				var slot: Dictionary = slot_variant
				var descriptor: Dictionary = visual_catalog.build_descriptor(slot)
				total_slots += 1
				if str(descriptor.get("traffic_role", "")) == "service":
					service_count += 1
				if str(descriptor.get("model_id", "")) == "police_car_a":
					police_count += 1

	print("CITY_VEHICLE_SERVICE_PRESENCE %s" % JSON.stringify({
		"total_slots": total_slots,
		"service_count": service_count,
		"police_count": police_count,
	}))

	if not T.require_true(self, total_slots > 0, "Service vehicle coverage validation requires at least one ambient vehicle spawn slot"):
		return
	if not T.require_true(self, service_count > 0, "Default ambient traffic must expose at least one service-role vehicle in the center play corridor"):
		return
	if not T.require_true(self, police_count > 0, "Default ambient traffic must allow police_car_a to appear in the center play corridor"):
		return
	if not T.require_true(self, service_count < total_slots, "Default ambient traffic must not collapse into all-service traffic"):
		return

	T.pass_and_quit(self)
