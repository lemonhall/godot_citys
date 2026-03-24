extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb")
	var root_node := packed.instantiate() as Node3D
	for child_name in ["m777_lower_base", "m777_upper_carriage", "m777_gun_assembly"]:
		var mesh_node := root_node.get_node_or_null(child_name) as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var aabb := mesh_node.get_aabb()
		print(child_name, " aabb=", aabb)
	root_node.free()
	quit()
