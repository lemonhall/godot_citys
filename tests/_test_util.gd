extends RefCounted

static func require_true(tree: SceneTree, cond: bool, msg: String) -> bool:
	if not cond:
		fail_and_quit(tree, msg)
		return false
	return true

static func pass_and_quit(tree: SceneTree) -> void:
	print("PASS")
	tree.quit(0)

static func fail_and_quit(tree: SceneTree, msg: String) -> void:
	push_error(msg)
	print("FAIL: " + msg)
	tree.quit(1)

