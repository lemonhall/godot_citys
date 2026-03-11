extends Node3D

const CityWorldConfig := preload("res://city_game/world/model/CityWorldConfig.gd")
const CityWorldGenerator := preload("res://city_game/world/generation/CityWorldGenerator.gd")

@onready var generated_city: Node = $GeneratedCity
@onready var hud: CanvasLayer = $Hud

var _world_config
var _world_data: Dictionary = {}

func _ready() -> void:
	_world_config = CityWorldConfig.new()
	_world_data = CityWorldGenerator.new().generate_world(_world_config)

	if not generated_city.has_method("get_city_summary"):
		return
	if not hud.has_method("set_status"):
		return

	var world_summary := str(_world_data.get("summary", "World data unavailable"))
	var lines := PackedStringArray([
		"City sandbox skeleton",
		"WASD / arrows move",
		"Shift sprint  Space jump",
		"Mouse rotates camera  Esc releases cursor",
		generated_city.get_city_summary(),
		world_summary
	])
	hud.set_status("\n".join(lines))

func get_world_config():
	return _world_config

func get_world_data() -> Dictionary:
	return _world_data
