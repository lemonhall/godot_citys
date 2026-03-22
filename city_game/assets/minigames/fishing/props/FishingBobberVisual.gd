extends Node3D

@onready var _bobber_mesh := $Bobber as MeshInstance3D

var _debug_state: Dictionary = {
	"visible": false,
	"bite_feedback_active": false,
	"world_position": Vector3.ZERO,
}

func set_bobber_state(should_show: bool, world_position: Vector3, bite_feedback_active: bool = false) -> void:
	visible = should_show
	global_position = world_position
	_debug_state = {
		"visible": should_show,
		"bite_feedback_active": bite_feedback_active,
		"world_position": world_position,
	}
	if _bobber_mesh == null:
		return
	var material := _bobber_mesh.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_energy_multiplier = 1.25 if bite_feedback_active else 0.5

func get_debug_state() -> Dictionary:
	return _debug_state.duplicate(true)
