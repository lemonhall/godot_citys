extends SceneTree

const T := preload("res://tests/_test_util.gd")

const MANIFEST_PATH := "res://city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json"
const EXPECTED_MODEL_COUNT := 7

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, FileAccess.file_exists(MANIFEST_PATH), "Pedestrian character manifest must exist at the formal civilian asset path"):
		return
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Pedestrian character manifest must parse as a Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	var models: Array = manifest.get("models", [])
	if not T.require_true(self, models.size() == EXPECTED_MODEL_COUNT, "Pedestrian character manifest must cover exactly 7 civilian models for M8"):
		return

	for model_variant in models:
		var model: Dictionary = model_variant
		var file_path := str(model.get("file", ""))
		if not T.require_true(self, file_path.begins_with("res://city_game/assets/pedestrians/civilians/"), "Civilian character assets must be archived inside the formal pedestrian asset directory"):
			return
		if not T.require_true(self, ResourceLoader.exists(file_path, "PackedScene"), "Civilian model %s must load as a PackedScene" % str(model.get("model_id", ""))):
			return
		var walk_animation := str(model.get("walk_animation", ""))
		var run_animation := str(model.get("run_animation", ""))
		var death_animation := str(model.get("death_animation", ""))
		var source_height_m := float(model.get("source_height_m", 0.0))
		var visual_target_height_m := float(model.get("visual_target_height_m", 0.0))
		if not T.require_true(self, walk_animation != "", "Manifest entry %s must declare walk_animation explicitly" % str(model.get("model_id", ""))):
			return
		if not T.require_true(self, run_animation != "", "Manifest entry %s must declare run_animation explicitly" % str(model.get("model_id", ""))):
			return
		if not T.require_true(self, death_animation != "", "Manifest entry %s must declare death_animation explicitly" % str(model.get("model_id", ""))):
			return
		if not T.require_true(self, source_height_m > 0.0, "Manifest entry %s must declare source_height_m for per-model normalization" % str(model.get("model_id", ""))):
			return
		if not T.require_true(self, visual_target_height_m > 0.0, "Manifest entry %s must declare visual_target_height_m for player-relative M9 size calibration" % str(model.get("model_id", ""))):
			return
		if not T.require_true(self, model.has("source_ground_offset_m"), "Manifest entry %s must declare source_ground_offset_m so scaled models keep feet on ground" % str(model.get("model_id", ""))):
			return

		var scene_resource := load(file_path)
		var packed_scene := scene_resource as PackedScene
		if not T.require_true(self, packed_scene != null, "Civilian model %s must instantiate as PackedScene" % str(model.get("model_id", ""))):
			return
		var instance := packed_scene.instantiate()
		var animation_player := _find_animation_player(instance)
		if not T.require_true(self, animation_player != null, "Civilian model %s must expose an AnimationPlayer" % str(model.get("model_id", ""))):
			instance.free()
			return
		if not T.require_true(self, animation_player.has_animation(walk_animation), "Civilian model %s must contain the manifest walk_animation clip" % str(model.get("model_id", ""))):
			instance.free()
			return
		if not T.require_true(self, animation_player.has_animation(run_animation), "Civilian model %s must contain the manifest run_animation clip" % str(model.get("model_id", ""))):
			instance.free()
			return
		if not T.require_true(self, animation_player.has_animation(death_animation), "Civilian model %s must contain the manifest death_animation clip" % str(model.get("model_id", ""))):
			instance.free()
			return
		instance.free()

	T.pass_and_quit(self)

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
