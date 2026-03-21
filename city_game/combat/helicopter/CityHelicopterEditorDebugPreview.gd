@tool
extends MeshInstance3D


func _ready() -> void:
	if Engine.is_editor_hint():
		visible = true
		return
	queue_free()
