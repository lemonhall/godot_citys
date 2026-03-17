extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LANDMARK_SCENE_PATH := "res://city_game/serviceability/landmarks/generated/landmark_v23_music_road_chunk_136_136/music_road_landmark.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LANDMARK_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Music road collision contract requires the authored landmark scene"):
		return

	var landmark := (scene as PackedScene).instantiate()
	root.add_child(landmark)
	await process_frame

	var collision_body := landmark.get_node_or_null("RoadCollisionBody") as StaticBody3D
	if not T.require_true(self, collision_body != null, "Music road landmark must expose a static collision body for drivable vehicle contact"):
		return
	var collision_shape := collision_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not T.require_true(self, collision_shape != null and collision_shape.shape is BoxShape3D, "Music road collision body must use a box collision shape"):
		return
	var box := collision_shape.shape as BoxShape3D
	if not T.require_true(self, box.size.x >= 17.5, "Music road collision width must cover the drivable deck"):
		return
	if not T.require_true(self, box.size.z >= 1200.0, "Music road collision length must cover the authored full song corridor"):
		return

	landmark.queue_free()
	T.pass_and_quit(self)
