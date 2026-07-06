extends MeshInstance3D

func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 16384.0
	_update_viewport_size()
	get_viewport().size_changed.connect(_update_viewport_size)

func _process(_delta: float) -> void:
	_update_viewport_size()

func _update_viewport_size() -> void:
	var shader_material := material_override as ShaderMaterial
	if shader_material == null:
		return
	var viewport_rect := get_viewport().get_visible_rect()
	shader_material.set_shader_parameter("viewport_size", viewport_rect.size)
