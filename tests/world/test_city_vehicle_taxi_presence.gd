extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityVehicleVisualCatalog := preload("res://city_game/world/vehicles/rendering/CityVehicleVisualCatalog.gd")

const MANIFEST_PATH := "res://city_game/assets/vehicles/vehicle_model_manifest.json"
const TAXI_MODEL_ID := "taxi_a"
const TAXI_FILE_PATH := "res://city_game/assets/vehicles/civilian/taxi_a.glb"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, FileAccess.file_exists(MANIFEST_PATH), "Vehicle manifest must exist for taxi validation"):
		return

	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Vehicle manifest must parse as Dictionary for taxi validation"):
		return
	var manifest := manifest_variant as Dictionary
	var models: Array = manifest.get("models", [])
	var taxi_entry := _find_model_entry(models, TAXI_MODEL_ID)
	if not T.require_true(self, not taxi_entry.is_empty(), "Vehicle manifest must include taxi_a once Taxi.glb is added to the repository"):
		return
	if not T.require_true(self, str(taxi_entry.get("file", "")) == TAXI_FILE_PATH, "Taxi asset must be archived under the formal civilian vehicle directory"):
		return
	if not T.require_true(self, ResourceLoader.exists(TAXI_FILE_PATH, "PackedScene"), "Taxi asset must load as a PackedScene from the formal civilian vehicle directory"):
		return
	if not T.require_true(self, str(taxi_entry.get("traffic_role", "")) == "civilian", "Taxi must participate in default ambient civilian traffic"):
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var vehicle_query = world_data.get("vehicle_query")
	if not T.require_true(self, vehicle_query != null and vehicle_query.has_method("get_vehicle_query_for_chunk"), "vehicle_query must exist for taxi coverage validation"):
		return
	var visual_catalog := CityVehicleVisualCatalog.new()

	var chunk_grid: Vector2i = config.get_chunk_grid_size()
	var center_chunk := Vector2i(chunk_grid.x / 2, chunk_grid.y / 2)
	var total_slots := 0
	var taxi_count := 0
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
				if str(descriptor.get("model_id", "")) == TAXI_MODEL_ID:
					taxi_count += 1

	print("CITY_VEHICLE_TAXI_PRESENCE %s" % JSON.stringify({
		"total_slots": total_slots,
		"taxi_count": taxi_count,
	}))

	if not T.require_true(self, total_slots > 0, "Taxi coverage validation requires at least one ambient vehicle spawn slot"):
		return
	if not T.require_true(self, taxi_count > 0, "Default ambient traffic must expose taxi_a in the center play corridor"):
		return

	T.pass_and_quit(self)

func _find_model_entry(models: Array, model_id: String) -> Dictionary:
	for model_variant in models:
		if not model_variant is Dictionary:
			continue
		var model := model_variant as Dictionary
		if str(model.get("model_id", "")) == model_id:
			return model
	return {}
