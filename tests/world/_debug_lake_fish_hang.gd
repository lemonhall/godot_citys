extends SceneTree

const LAKE_RUNTIME_PATH := "res://city_game/world/features/lake/CityLakeRegionRuntime.gd"
const FISH_RUNTIME_PATH := "res://city_game/world/features/lake/CityLakeFishSchoolRuntime.gd"
const MANIFEST_PATH := "res://city_game/serviceability/terrain_regions/generated/region_v38_fishing_lake_chunk_147_181/terrain_region_manifest.json"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("debug:load_scripts")
	var lake_runtime_script := load(LAKE_RUNTIME_PATH)
	var fish_runtime_script := load(FISH_RUNTIME_PATH)
	print("debug:scripts_loaded", lake_runtime_script != null, fish_runtime_script != null)
	var lake_runtime = lake_runtime_script.new()
	print("debug:lake_new")
	var load_ok := lake_runtime.load_from_manifest(MANIFEST_PATH)
	print("debug:lake_loaded", load_ok)
	var fish_runtime = fish_runtime_script.new()
	print("debug:fish_new")
	fish_runtime.configure([lake_runtime])
	print("debug:fish_configured")
	var schools: Array = fish_runtime.get_school_summaries_for_region("region:v38:fishing_lake:chunk_147_181")
	print("debug:schools", schools.size())
	quit(0)
