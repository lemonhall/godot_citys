extends RefCounted

# Persist the world plan under user://cache/world so a restart reuses the same
# plan_hash instead of regenerating a different city.

const CACHE_DIR := "user://cache/world"

var _last_path := ""
var _last_seed := -1

func store(plan: Dictionary) -> bool:
	var seed_value := int(plan.get("seed", 0))
	DirAccess.make_dir_recursive_absolute(CACHE_DIR)
	var path := _path_for_seed(seed_value)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(var_to_str(plan))
	file.close()
	_last_path = path
	_last_seed = seed_value
	return true

func load_plan(seed_value: int = -2147483648) -> Dictionary:
	var path := _last_path
	if seed_value != -2147483648:
		path = _path_for_seed(seed_value)
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var value = str_to_var(file.get_as_text())
	file.close()
	if not (value is Dictionary):
		return {}
	return value as Dictionary

func _path_for_seed(seed_value: int) -> String:
	return "%s/city_plan_%d.plan" % [CACHE_DIR, seed_value]
