extends "res://city_game/world/radio/backend/CityRadioStreamBackend.gd"
class_name CityRadioMockBackend

func _init() -> void:
	_state["backend_id"] = "mock"
