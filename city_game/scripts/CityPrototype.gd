extends Node3D

@onready var generated_city: Node = $GeneratedCity
@onready var hud: CanvasLayer = $Hud

func _ready() -> void:
	if not generated_city.has_method("get_city_summary"):
		return
	if not hud.has_method("set_status"):
		return

	var lines := PackedStringArray([
		"City sandbox skeleton",
		"WASD / arrows move",
		"Shift sprint  Space jump",
		"Mouse rotates camera  Esc releases cursor",
		generated_city.get_city_summary()
	])
	hud.set_status("\n".join(lines))
