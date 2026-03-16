extends "res://city_game/world/interactions/CityInteractableNpc.gd"

@export var model_root_path: NodePath = ^"Model"
@export var idle_animation_name := "CharacterArmature|Idle"
@export var source_height_m := 1.531864
@export var target_visual_height_m := 3.1
@export var source_ground_offset_m := 0.001869

func _ready() -> void:
	super()
	var model_root := _resolve_model_root()
	if model_root == null:
		return
	var height_scale := maxf(target_visual_height_m / maxf(source_height_m, 0.001), 0.01)
	model_root.scale = Vector3.ONE * height_scale
	model_root.position = Vector3(0.0, source_ground_offset_m * height_scale, 0.0)
	var animation_player := _find_animation_player(model_root)
	if animation_player == null:
		return
	if idle_animation_name != "" and animation_player.has_animation(idle_animation_name):
		animation_player.play(idle_animation_name)

func _resolve_model_root() -> Node3D:
	var explicit_root := get_node_or_null(model_root_path) as Node3D
	if explicit_root != null:
		return explicit_root
	for child in get_children():
		var child_node := child as Node3D
		if child_node != null:
			return child_node
	return null

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node == null:
		return null
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var found := _find_animation_player(child_node)
		if found != null:
			return found
	return null
