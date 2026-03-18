
extends SceneTree
func _init() -> void:
    call_deferred("_run")
func _run() -> void:
    var packed := load("res://city_game/assets/minigames/soccer/players/animated_human.glb")
    if packed == null:
        push_error("LOAD_FAILED")
        quit(1)
        return
    var root = packed.instantiate()
    get_root().add_child(root)
    _dump(root, "")
    quit()
func _dump(node: Node, indent: String) -> void:
    print("NODE %s%s [%s]" % [indent, node.name, node.get_class()])
    if node is AnimationPlayer:
        var player := node as AnimationPlayer
        for name_variant in player.get_animation_list():
            print("ANIM %s" % str(name_variant))
    for child in node.get_children():
        _dump(child, indent + "  ")
