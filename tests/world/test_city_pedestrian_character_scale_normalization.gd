extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CityPedestrianVisualInstance := preload("res://city_game/world/pedestrians/rendering/CityPedestrianVisualInstance.gd")

const MANIFEST_PATH := "res://city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json"
const SAMPLE_HEIGHT_M := 1.75
const SCALE_EPSILON := 0.001
const HEIGHT_EPSILON := 0.02
const GROUND_EPSILON := 0.01
const ANIMATION_SETTLE_FRAMES := 4

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Pedestrian character manifest must parse as a Dictionary for scale normalization"):
		return
	var manifest: Dictionary = manifest_variant
	var models: Array = manifest.get("models", [])
	if not T.require_true(self, not models.is_empty(), "Pedestrian character manifest must contain model entries for scale normalization"):
		return
	var raw_profile_by_model_id: Dictionary = {}

	for model_index in range(models.size()):
		var model: Dictionary = models[model_index]
		var model_id := str(model.get("model_id", ""))
		var file_path := str(model.get("file", ""))
		var walk_animation := str(model.get("walk_animation", ""))
		var packed_scene := load(file_path) as PackedScene
		if not T.require_true(self, packed_scene != null, "Model %s must load for scale normalization inspection" % model_id):
			return

		var raw_instance := packed_scene.instantiate() as Node3D
		if not T.require_true(self, raw_instance != null, "Model %s must instantiate as Node3D for scale normalization inspection" % model_id):
			return
		root.add_child(raw_instance)
		var animation_player := _find_animation_player(raw_instance)
		if animation_player != null and walk_animation != "" and animation_player.has_animation(walk_animation):
			animation_player.play(walk_animation)
		for _frame_index in range(ANIMATION_SETTLE_FRAMES):
			await process_frame
		var raw_mesh_bounds := _measure_world_bounds(raw_instance)
		var raw_live_height_m := _measure_live_skeleton_height_m(raw_instance)
		print("CITY_PEDESTRIAN_MODEL_RAW_PROFILE %s" % JSON.stringify({
			"model_id": model_id,
			"raw_mesh_height_m": raw_mesh_bounds.get("height_m", 0.0),
			"raw_mesh_min_y_m": raw_mesh_bounds.get("min_y_m", 0.0),
			"raw_mesh_max_y_m": raw_mesh_bounds.get("max_y_m", 0.0),
			"raw_live_skeleton_height_m": raw_live_height_m,
		}))
		raw_profile_by_model_id[model_id] = {
			"mesh_bounds": raw_mesh_bounds.duplicate(true),
			"live_height_m": raw_live_height_m,
		}
		raw_instance.queue_free()
		await process_frame
	for model_index in range(models.size()):
		var model: Dictionary = models[model_index]
		var model_id := str(model.get("model_id", ""))
		var raw_profile: Dictionary = raw_profile_by_model_id.get(model_id, {})
		var raw_mesh_bounds: Dictionary = raw_profile.get("mesh_bounds", {})
		var raw_live_height_m := float(raw_profile.get("live_height_m", 0.0))

		if not T.require_true(self, model.has("source_height_m"), "Manifest entry %s must declare source_height_m for per-model normalization" % model_id):
			return
		if not T.require_true(self, model.has("visual_target_height_m"), "Manifest entry %s must declare visual_target_height_m for player-relative M9 size calibration" % model_id):
			return
		if not T.require_true(self, model.has("source_ground_offset_m"), "Manifest entry %s must declare source_ground_offset_m so scaled models keep feet on the ground" % model_id):
			return

		var source_height_m := float(model.get("source_height_m", 0.0))
		var visual_target_height_m := float(model.get("visual_target_height_m", 0.0))
		var source_ground_offset_m := float(model.get("source_ground_offset_m", 0.0))
		if not T.require_true(self, absf(source_height_m - raw_live_height_m) <= HEIGHT_EPSILON, "Manifest source_height_m for %s must match the raw live skeleton height, not the static mesh AABB" % model_id):
			return
		if not T.require_true(self, absf(source_ground_offset_m - (-float(raw_mesh_bounds.get("min_y_m", 0.0)))) <= GROUND_EPSILON, "Manifest source_ground_offset_m for %s must match the raw imported foot offset" % model_id):
			return

		var visual := CityPedestrianVisualInstance.new()
		root.add_child(visual)
		visual.apply_state(_build_state(model_index), Vector3.ZERO)
		for _frame_index in range(ANIMATION_SETTLE_FRAMES):
			await process_frame

		var model_root := visual.get_node_or_null("Model") as Node3D
		if not T.require_true(self, model_root != null, "Visual instance must mount a Model child for %s" % model_id):
			visual.queue_free()
			return
		var expected_uniform_scale := visual_target_height_m / source_height_m
		if not T.require_true(self, absf(model_root.scale.y - expected_uniform_scale) <= SCALE_EPSILON, "Visual instance must scale %s from manifest visual_target_height_m" % model_id):
			visual.queue_free()
			return
		if not T.require_true(self, absf(model_root.position.y - source_ground_offset_m * expected_uniform_scale) <= GROUND_EPSILON, "Visual instance must raise %s by the scaled source_ground_offset_m" % model_id):
			visual.queue_free()
			return
		var normalized_live_height_m := _measure_live_skeleton_height_m(visual)
		if not T.require_true(self, absf(normalized_live_height_m - visual_target_height_m) <= HEIGHT_EPSILON, "Visual instance must render %s at manifest visual_target_height_m after live skeleton normalization" % model_id):
			visual.queue_free()
			return

		visual.queue_free()
		await process_frame

	T.pass_and_quit(self)

func _build_state(model_index: int) -> Dictionary:
	return {
		"pedestrian_id": "ped:%d" % model_index,
		"world_position": Vector3.ZERO,
		"heading": Vector3.FORWARD,
		"height_m": SAMPLE_HEIGHT_M,
		"radius_m": 0.28,
		"seed": model_index,
		"archetype_id": "resident",
		"archetype_signature": "resident:v0",
		"reaction_state": "none",
		"life_state": "alive",
	}

func _measure_world_bounds(root_node: Node3D) -> Dictionary:
	var bounds := _collect_world_bounds(root_node)
	if not bool(bounds.get("has_bounds", false)):
		return {
			"has_bounds": false,
			"min_y_m": 0.0,
			"max_y_m": 0.0,
			"height_m": 0.0,
		}
	return {
		"has_bounds": true,
		"min_y_m": float(bounds.get("min_corner", Vector3.ZERO).y),
		"max_y_m": float(bounds.get("max_corner", Vector3.ZERO).y),
		"height_m": float(bounds.get("max_corner", Vector3.ZERO).y) - float(bounds.get("min_corner", Vector3.ZERO).y),
	}

func _measure_live_skeleton_height_m(root_node: Node) -> float:
	var bounds := _collect_live_skeleton_bounds(root_node)
	if not bool(bounds.get("has_bounds", false)):
		return 0.0
	var min_corner: Vector3 = bounds.get("min_corner", Vector3.ZERO)
	var max_corner: Vector3 = bounds.get("max_corner", Vector3.ZERO)
	return max_corner.y - min_corner.y

func _collect_world_bounds(node: Node) -> Dictionary:
	var has_bounds := false
	var min_corner := Vector3.ZERO
	var max_corner := Vector3.ZERO
	if node is VisualInstance3D and node.has_method("get_aabb"):
		var visual := node as VisualInstance3D
		var local_aabb: AABB = visual.get_aabb()
		if local_aabb.size.length_squared() > 0.0:
			for corner in _aabb_corners(local_aabb):
				var world_corner := visual.global_transform * corner
				if not has_bounds:
					min_corner = world_corner
					max_corner = world_corner
					has_bounds = true
				else:
					min_corner = min_corner.min(world_corner)
					max_corner = max_corner.max(world_corner)
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var child_bounds := _collect_world_bounds(child_node)
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

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var animation_player := _find_animation_player(child_node)
		if animation_player != null:
			return animation_player
	return null

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var corners: Array[Vector3] = []
	for x_bit in [0.0, 1.0]:
		for y_bit in [0.0, 1.0]:
			for z_bit in [0.0, 1.0]:
				corners.append(aabb.position + Vector3(aabb.size.x * x_bit, aabb.size.y * y_bit, aabb.size.z * z_bit))
	return corners
