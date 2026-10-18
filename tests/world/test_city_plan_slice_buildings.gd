extends SceneTree

# v63 M5: inside the slice, buildings come from plan parcels (street walls),
# not from the v62 scatter.
# REQ-0034-006.

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")
const CityChunkScene := preload("res://city_game/world/rendering/CityChunkScene.gd")
const Runtime := preload("res://city_game/world/generation/plan/CityPlanRuntime.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var parcels: Array = Runtime.get_parcels(config.base_seed)
	if not T.require_true(self, parcels.size() >= 12, "plan must expose parcels"):
		return
	var counts := {}
	for parcel_variant in parcels:
		var center: Vector2 = (parcel_variant as Dictionary).get("center", Vector2.ZERO)
		var key := Vector2i(136 + int(floor(center.x / 256.0)), 136 + int(floor(center.y / 256.0)))
		counts[key] = int(counts.get(key, 0)) + 1
	var best_key := Vector2i(136, 136)
	var best_count := 0
	for key_variant in counts.keys():
		var key: Vector2i = key_variant
		if int(counts[key]) > best_count:
			best_count = int(counts[key])
			best_key = key
	if not T.require_true(self, best_count >= 12, "at least one slice chunk must hold 12+ parcels (best=%d)" % best_count):
		return
	var chunk_center := Vector3(float(best_key.x - 136) * 256.0, 0.0, float(best_key.y - 136) * 256.0)
	var chunk_scene = CityChunkScene.new()
	root.add_child(chunk_scene)
	await process_frame
	chunk_scene.setup({
		"chunk_id": config.format_chunk_id(best_key),
		"chunk_key": best_key,
		"chunk_center": chunk_center,
		"chunk_size_m": float(config.chunk_size_m),
		"chunk_seed": config.derive_seed("render_chunk", best_key),
		"road_graph": world_data.get("road_graph"),
		"world_seed": config.base_seed,
	})
	var profile: Dictionary = chunk_scene.get("_profile")
	var buildings: Array = profile.get("buildings", [])
	if not T.require_true(self, buildings.size() >= 12, "slice chunk must build plan parcels (got %d)" % buildings.size()):
		return
	for building_variant in buildings:
		var building: Dictionary = building_variant
		if not T.require_true(self, str(building.get("candidate_kind", "")) == "plan_parcel", "slice buildings must come from plan parcels"):
			return
		if not T.require_true(self, str(building.get("district_kind", "")) != "", "plan parcels must carry their district"):
			return
	T.pass_and_quit(self)
