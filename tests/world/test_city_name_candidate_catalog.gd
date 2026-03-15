extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var catalog_script := load("res://city_game/world/generation/CityNameCandidateCatalog.gd")
	if catalog_script == null:
		T.fail_and_quit(self, "Name candidate catalog test requires CityNameCandidateCatalog.gd")
		return

	var catalog = catalog_script.new()
	if not T.require_true(self, catalog.has_method("build_catalog"), "CityNameCandidateCatalog must expose build_catalog()"):
		return

	var built_a: Dictionary = catalog.build_catalog(424242)
	var built_b: Dictionary = catalog.build_catalog(424242)
	var road_pool: Array = built_a.get("road_name_root_pool", [])
	var landmark_pool: Array = built_a.get("landmark_proper_name_pool", [])

	if not T.require_true(self, road_pool.size() >= 11000 and road_pool.size() <= 13000, "Road name root pool must freeze into the 11000-13000 band"):
		return
	if not T.require_true(self, landmark_pool.size() >= 3000 and landmark_pool.size() <= 5000, "Landmark proper-name pool must freeze into the 3000-5000 band"):
		return
	if not T.require_true(self, built_a == built_b, "Name candidate catalog must stay deterministic for the same seed"):
		return
	if not T.require_true(self, not str(road_pool[0]).begins_with("Reference "), "Road name candidate pool must not include technical placeholders"):
		return
	if not T.require_true(self, not str(road_pool[0]).contains("district_"), "Road name candidate pool must not include district connector placeholders"):
		return

	T.pass_and_quit(self)
