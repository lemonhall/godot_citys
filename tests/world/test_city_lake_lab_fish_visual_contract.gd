extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FISH_ASSET_PATH := "res://city_game/assets/environment/source/creatures/fish/Fish.glb"
const FISH_ACTOR_SCENE_PATH := "res://city_game/world/features/lake/LakeFishActor.tscn"
const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"
const EXPECTED_SWIM_ANIMATION := "Armature|Swim"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(FISH_ASSET_PATH, "PackedScene"), "Lake fish visual contract requires Fish.glb to be curated under the formal fish asset directory"):
		return
	if not T.require_true(self, ResourceLoader.exists(FISH_ACTOR_SCENE_PATH, "PackedScene"), "Lake fish visual contract requires a dedicated LakeFishActor.tscn scene wrapper"):
		return
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Lake fish visual contract requires LakeFishingLab.tscn"):
		return

	var fish_scene := load(FISH_ACTOR_SCENE_PATH) as PackedScene
	if not T.require_true(self, fish_scene != null, "Lake fish visual contract must load LakeFishActor.tscn as PackedScene"):
		return
	var fish_actor := fish_scene.instantiate() as Node3D
	root.add_child(fish_actor)
	await process_frame

	if not T.require_true(self, fish_actor.has_method("get_debug_state"), "Lake fish actor scene must expose get_debug_state() for regression coverage"):
		return
	var fish_model := fish_actor.get_node_or_null("MotionRoot/Model") as Node3D
	if not T.require_true(self, fish_model != null, "Lake fish actor scene must mount the imported fish model under MotionRoot/Model"):
		return
	if not T.require_true(self, str(fish_model.scene_file_path) == FISH_ASSET_PATH, "Lake fish actor scene must source the curated Fish.glb asset from the formal fish asset directory"):
		return
	var fish_animation_player := _find_animation_player(fish_actor)
	if not T.require_true(self, fish_animation_player != null, "Lake fish actor scene must contain an AnimationPlayer"):
		return
	if not T.require_true(self, fish_animation_player.current_animation == EXPECTED_SWIM_ANIMATION, "Lake fish actor scene must autoplay the Swim clip by default"):
		return
	if not T.require_true(self, fish_animation_player.is_playing(), "Lake fish actor scene must keep the Swim clip playing at runtime"):
		return

	var lab_scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, lab_scene != null, "Lake fish visual contract must load LakeFishingLab.tscn as PackedScene"):
		return
	var lab := lab_scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var fish_schools_root := lab.get_node_or_null("LakeRoot/FishSchools") as Node3D
	if not T.require_true(self, fish_schools_root != null, "Lake fish visual contract requires the authored FishSchools runtime root in LakeFishingLab"):
		return
	if not T.require_true(self, fish_schools_root.get_child_count() >= 2, "Lake fish visual contract requires the lab to materialize animated fish actors for the shared fish schools"):
		return
	var fish_school_actor := fish_schools_root.get_child(0) as Node3D
	if not T.require_true(self, fish_school_actor != null and fish_school_actor.has_method("get_debug_state"), "Lake fish visual contract requires each school visual to expose the fish actor debug API"):
		return
	var school_debug_state: Dictionary = fish_school_actor.get_debug_state()
	if not T.require_true(self, str(school_debug_state.get("current_animation", "")) == EXPECTED_SWIM_ANIMATION, "Lake fish visual contract requires runtime fish actors to keep the Swim clip active inside the lake"):
		return
	if not T.require_true(self, bool(school_debug_state.get("is_playing", false)), "Lake fish visual contract requires runtime fish actors to actively play Swim instead of staying static"):
		return

	lab.queue_free()
	fish_actor.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	if root_node == null:
		return null
	for child in root_node.get_children():
		var match_player := _find_animation_player(child)
		if match_player != null:
			return match_player
	return null
