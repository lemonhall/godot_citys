extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var exporter_script := load("res://city_game/world/debug/CityOverviewPngExporter.gd")
	if exporter_script == null:
		T.fail_and_quit(self, "Missing CityOverviewPngExporter.gd for v13 overview acceptance")
		return

	var config := CityWorldConfig.new()
	var world_data: Dictionary = CityWorldGenerator.new().generate_world(config)
	var exporter = exporter_script.new()
	if exporter == null:
		T.fail_and_quit(self, "CityOverviewPngExporter must instantiate")
		return

	var output_basename := "res://reports/v13/test_city_overview_seed_%d" % int(config.base_seed)
	var result: Dictionary = exporter.export_world_overview(config, world_data, output_basename)
	if not T.require_true(self, bool(result.get("success", false)), "Overview exporter must report success for fixed-seed world data"):
		return
	var png_path := str(result.get("png_path", ""))
	var metadata_path := str(result.get("metadata_path", ""))
	var project_root := ProjectSettings.globalize_path("res://")
	if not T.require_true(self, png_path.begins_with(project_root), "Overview exporter must write PNGs into the project workspace, not Godot user:// storage"):
		return
	if not T.require_true(self, metadata_path.begins_with(project_root), "Overview exporter metadata must also stay inside the project workspace"):
		return
	if not T.require_true(self, png_path != "" and FileAccess.file_exists(png_path), "Overview exporter must write a PNG file to disk"):
		return
	if not T.require_true(self, metadata_path != "" and FileAccess.file_exists(metadata_path), "Overview exporter must write a sidecar metadata file to disk"):
		return

	var metadata: Dictionary = result.get("metadata", {})
	if not T.require_true(self, int(metadata.get("population_center_count", 0)) >= 3, "Overview metadata must report one main center plus satellites"):
		return
	if not T.require_true(self, int(metadata.get("corridor_count", 0)) >= 2, "Overview metadata must report corridor links between centers"):
		return
	if not T.require_true(self, int(metadata.get("road_pixel_count", 0)) > 0, "Overview PNG metadata must report non-zero road pixels"):
		return
	if not T.require_true(self, int(metadata.get("building_pixel_count", 0)) > 0, "Overview PNG metadata must report non-zero building pixels"):
		return
	if not T.require_true(self, int(metadata.get("building_footprint_count", 0)) > 0, "Overview PNG metadata must report exported building footprints"):
		return

	T.pass_and_quit(self)
