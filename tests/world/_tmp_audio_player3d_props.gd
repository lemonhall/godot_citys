extends SceneTree
func _initialize() -> void:
	var node := AudioStreamPlayer3D.new()
	for prop in node.get_property_list():
		var name := String(prop.get("name", ""))
		if name.to_lower().contains("loop"):
			print(name)
	quit()
