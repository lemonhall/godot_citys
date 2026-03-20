@tool
extends RefCounted

func evaluate_scene_root(scene_root: Node) -> Dictionary:
	if scene_root == null:
		return {
			"eligible": false,
			"reason": "No edited scene root is open.",
			"reason_id": "missing_scene_root",
		}
	if not (scene_root is Node3D):
		return {
			"eligible": false,
			"reason": "Only Node3D scene roots can use Scene Preview.",
			"reason_id": "scene_root_not_node3d",
		}
	return {
		"eligible": true,
		"reason": "",
		"reason_id": "eligible",
		"scene_root_name": scene_root.name,
	}
