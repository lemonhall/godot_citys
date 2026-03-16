extends SceneTree

const T := preload("res://tests/_test_util.gd")
const SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/枪店_A.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(SCENE_PATH)
	if not T.require_true(self, scene is PackedScene, "Gun shop orientation test requires the generated gun shop scene fixture"):
		return

	var root := (scene as PackedScene).instantiate()
	if not T.require_true(self, root != null, "Gun shop orientation test must instantiate the gun shop scene"):
		return
	root.name = "GunShopSceneRoot"
	self.root.add_child(root)
	await process_frame

	var generated_building := root.get_node_or_null("GeneratedBuilding") as Node3D
	if not T.require_true(self, generated_building != null, "Gun shop orientation test requires GeneratedBuilding root"):
		return
	var entry_anchor := root.get_node_or_null("GeneratedBuilding/ServiceAnchors/DoorEntryAnchor") as Node3D
	if not T.require_true(self, entry_anchor != null, "Gun shop orientation test requires a door_entry anchor"):
		return
	var sign_mesh := root.get_node_or_null("GeneratedBuilding/Shell/ShopSign") as MeshInstance3D
	if not T.require_true(self, sign_mesh != null, "Gun shop orientation test requires the storefront sign mesh"):
		return

	if not T.require_true(self, entry_anchor.global_position.z < generated_building.global_position.z, "Gun shop door entry anchor must sit on the flipped storefront side so the entrance faces the street approach"):
		return
	if not T.require_true(self, sign_mesh.global_position.z < generated_building.global_position.z, "Gun shop sign mesh must sit on the same flipped storefront side as the entrance"):
		return

	root.queue_free()
	await process_frame
	T.pass_and_quit(self)
