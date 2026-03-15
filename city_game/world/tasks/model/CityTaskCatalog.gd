extends RefCounted

const CityTaskDefinition := preload("res://city_game/world/tasks/model/CityTaskDefinition.gd")

var _definitions_by_id: Dictionary = {}
var _sorted_task_ids: Array[String] = []

func setup(definitions: Array) -> void:
	_definitions_by_id.clear()
	_sorted_task_ids.clear()
	for definition_variant in definitions:
		if not (definition_variant is Dictionary):
			continue
		var definition := CityTaskDefinition.new()
		definition.setup(definition_variant as Dictionary)
		if not definition.is_valid():
			continue
		var task_id := definition.get_task_id()
		_definitions_by_id[task_id] = definition
		_sorted_task_ids.append(task_id)
	_sorted_task_ids.sort()

func has_task(task_id: String) -> bool:
	return _definitions_by_id.has(task_id)

func get_task_count() -> int:
	return _sorted_task_ids.size()

func get_task_ids() -> Array[String]:
	return _sorted_task_ids.duplicate()

func get_task_definition(task_id: String) -> Dictionary:
	if not _definitions_by_id.has(task_id):
		return {}
	return (_definitions_by_id[task_id] as CityTaskDefinition).to_dict()

func get_task_definitions() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for task_id in _sorted_task_ids:
		results.append((_definitions_by_id[task_id] as CityTaskDefinition).to_dict())
	return results
