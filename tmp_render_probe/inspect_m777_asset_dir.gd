extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://city_game/assets/environment/source/artillery/m777/m777_3_parts.glb")
	if packed == null:
		push_error("load failed")
		quit(1)
		return
	var inst: Node = packed.instantiate()
	_print_tree(inst, 0)
	inst.free()
	quit()

func _print_tree(node: Node, depth: int) -> void:
	var indent := "  ".repeat(depth)
	print(indent, node.name, " :: ", node.get_class())
	for child: Node in node.get_children():
		_print_tree(child, depth + 1)
