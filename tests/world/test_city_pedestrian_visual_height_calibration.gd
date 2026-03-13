extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianVisualInstance := preload("res://city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd")

const MANIFEST_PATH := "res://city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json"
const SAMPLE_STATE_HEIGHT_M := 1.56
const MIN_VISUAL_HEIGHT_M := 3.0
const MAX_VISUAL_HEIGHT_M := 3.2
const MAX_HEIGHT_SPREAD_RATIO := 1.10
const ANIMATION_SETTLE_FRAMES := 4

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for pedestrian visual height calibration")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player_half_height_m := float(world.call("_estimate_player_standing_height"))
	if not T.require_true(self, player_half_height_m > 0.0, "CityPrototype must expose a positive player standing half-height for pedestrian visual calibration"):
		return
	var player_total_height_m := player_half_height_m * 2.0

	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Pedestrian visual calibration requires a valid civilian manifest"):
		return
	var manifest: Dictionary = manifest_variant
	var models: Array = manifest.get("models", [])
	if not T.require_true(self, not models.is_empty(), "Pedestrian visual calibration requires at least one civilian model"):
		return

	var measured_heights: Dictionary = {}
	var min_height_m := INF
	var max_height_m := 0.0
	for model_index in range(models.size()):
		var model: Dictionary = models[model_index]
		var model_id := str(model.get("model_id", ""))
		var visual := CityPedestrianVisualInstance.new()
		root.add_child(visual)
		visual.apply_state(_build_state(model_index), Vector3.ZERO)
		for _frame_index in range(ANIMATION_SETTLE_FRAMES):
			await process_frame
		var rendered_height_m := _measure_live_skeleton_height_m(visual)
		measured_heights[model_id] = rendered_height_m
		min_height_m = minf(min_height_m, rendered_height_m)
		max_height_m = maxf(max_height_m, rendered_height_m)
		if not T.require_true(self, rendered_height_m >= MIN_VISUAL_HEIGHT_M, "Model %s must not render shorter than %.2fm in live visual height" % [model_id, MIN_VISUAL_HEIGHT_M]):
			return
		if not T.require_true(self, rendered_height_m <= MAX_VISUAL_HEIGHT_M, "Model %s must not render taller than %.2fm in live visual height" % [model_id, MAX_VISUAL_HEIGHT_M]):
			return
		visual.queue_free()
		await process_frame

	print("CITY_PEDESTRIAN_VISUAL_HEIGHTS %s" % JSON.stringify({
		"player_total_height_m": player_total_height_m,
		"measured_heights_m": measured_heights,
		"spread_ratio": max_height_m / maxf(min_height_m, 0.001),
	}))

	if not T.require_true(self, (max_height_m / maxf(min_height_m, 0.001)) <= MAX_HEIGHT_SPREAD_RATIO, "Civilian visual height spread must stay within %.2f and not create giant outliers" % MAX_HEIGHT_SPREAD_RATIO):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _build_state(model_index: int) -> Dictionary:
	return {
		"pedestrian_id": "ped:calibration:%d" % model_index,
		"world_position": Vector3.ZERO,
		"heading": Vector3.FORWARD,
		"height_m": SAMPLE_STATE_HEIGHT_M,
		"radius_m": 0.28,
		"seed": model_index,
		"archetype_id": "walker",
		"archetype_signature": "walker:v0",
		"reaction_state": "none",
		"life_state": "alive",
	}

func _measure_live_skeleton_height_m(root_node: Node) -> float:
	var bounds := _collect_live_skeleton_bounds(root_node)
	if not bool(bounds.get("has_bounds", false)):
		return 0.0
	var min_corner: Vector3 = bounds.get("min_corner", Vector3.ZERO)
	var max_corner: Vector3 = bounds.get("max_corner", Vector3.ZERO)
	return max_corner.y - min_corner.y

func _collect_live_skeleton_bounds(node: Node) -> Dictionary:
	var has_bounds := false
	var min_corner := Vector3.ZERO
	var max_corner := Vector3.ZERO
	if node is Skeleton3D:
		var skeleton := node as Skeleton3D
		for bone_index in range(skeleton.get_bone_count()):
			var world_position := skeleton.global_transform * skeleton.get_bone_global_pose(bone_index).origin
			if not has_bounds:
				min_corner = world_position
				max_corner = world_position
				has_bounds = true
			else:
				min_corner = min_corner.min(world_position)
				max_corner = max_corner.max(world_position)
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var child_bounds := _collect_live_skeleton_bounds(child_node)
		if not bool(child_bounds.get("has_bounds", false)):
			continue
		var child_min: Vector3 = child_bounds.get("min_corner", Vector3.ZERO)
		var child_max: Vector3 = child_bounds.get("max_corner", Vector3.ZERO)
		if not has_bounds:
			min_corner = child_min
			max_corner = child_max
			has_bounds = true
		else:
			min_corner = min_corner.min(child_min)
			max_corner = max_corner.max(child_max)
	return {
		"has_bounds": has_bounds,
		"min_corner": min_corner,
		"max_corner": max_corner,
	}
