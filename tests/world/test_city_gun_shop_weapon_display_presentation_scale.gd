extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GUN_SHOP_SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/枪店_A.tscn"
const MIN_PRESENTATION_SCALE_MULTIPLIER := 3.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(GUN_SHOP_SCENE_PATH)
	if not T.require_true(self, scene is PackedScene, "Gun shop presentation scale test requires the generated gun shop PackedScene"):
		return
	var scene_root := (scene as PackedScene).instantiate()
	if not T.require_true(self, scene_root is Node3D, "Gun shop presentation scale test must instantiate as Node3D"):
		return
	root.add_child(scene_root)
	await process_frame

	var weapon_displays := scene_root.get_node_or_null("GeneratedBuilding/Interior/WeaponDisplays")
	if not T.require_true(self, weapon_displays is Node3D, "Gun shop presentation scale test requires Interior/WeaponDisplays root"):
		return

	var display_nodes := _collect_display_nodes(weapon_displays)
	if not T.require_true(self, not display_nodes.is_empty(), "Gun shop presentation scale test requires mounted weapon display nodes"):
		return

	for display_node in display_nodes:
		var contract: Dictionary = display_node.get_weapon_display_contract()
		var weapon_class := str(contract.get("weapon_class", ""))
		var target_length_m := float(contract.get("target_length_m", 0.0))
		if not T.require_true(self, target_length_m > 0.05, "Gun shop presentation scale test requires a positive target_length_m for %s" % weapon_class):
			return
		var presented_length_m := _measure_presented_length_m(display_node)
		if not T.require_true(
			self,
			presented_length_m >= target_length_m * MIN_PRESENTATION_SCALE_MULTIPLIER,
			"Gun shop display %s must present larger-than-real showroom weapons so they read clearly against the oversized interior (target=%.3fm presented=%.3fm min_multiplier=%.2f)" % [
				weapon_class,
				target_length_m,
				presented_length_m,
				MIN_PRESENTATION_SCALE_MULTIPLIER,
			]
		):
			return

	scene_root.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _collect_display_nodes(root_node: Node) -> Array:
	var result: Array = []
	for child in root_node.get_children():
		if child != null and child.has_method("get_weapon_display_contract"):
			result.append(child)
	return result

func _measure_presented_length_m(root_node: Node) -> float:
	var visuals: Array = []
	_collect_visuals(root_node, visuals)
	var has_any := false
	var merged := AABB()
	for visual_variant in visuals:
		var visual := visual_variant as VisualInstance3D
		if visual == null:
			continue
		var visual_aabb := visual.get_aabb()
		if visual_aabb.size == Vector3.ZERO:
			continue
		var world_aabb := _transform_aabb(visual.global_transform, visual_aabb)
		if not has_any:
			merged = world_aabb
			has_any = true
		else:
			merged = merged.merge(world_aabb)
	if not has_any:
		return 0.0
	return maxf(merged.size.x, maxf(merged.size.y, merged.size.z))

func _collect_visuals(node: Node, visuals: Array) -> void:
	if node is VisualInstance3D:
		visuals.append(node)
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_collect_visuals(child_node, visuals)

func _transform_aabb(transform: Transform3D, aabb: AABB) -> AABB:
	var corners := [
		aabb.position,
		aabb.position + Vector3(aabb.size.x, 0.0, 0.0),
		aabb.position + Vector3(0.0, aabb.size.y, 0.0),
		aabb.position + Vector3(0.0, 0.0, aabb.size.z),
		aabb.position + Vector3(aabb.size.x, aabb.size.y, 0.0),
		aabb.position + Vector3(aabb.size.x, 0.0, aabb.size.z),
		aabb.position + Vector3(0.0, aabb.size.y, aabb.size.z),
		aabb.position + aabb.size,
	]
	var first_corner: Vector3 = transform * corners[0]
	var min_corner := first_corner
	var max_corner := first_corner
	for corner in corners:
		var transformed_corner: Vector3 = transform * corner
		min_corner = Vector3(
			minf(min_corner.x, transformed_corner.x),
			minf(min_corner.y, transformed_corner.y),
			minf(min_corner.z, transformed_corner.z)
		)
		max_corner = Vector3(
			maxf(max_corner.x, transformed_corner.x),
			maxf(max_corner.y, transformed_corner.y),
			maxf(max_corner.z, transformed_corner.z)
		)
	return AABB(min_corner, max_corner - min_corner)
