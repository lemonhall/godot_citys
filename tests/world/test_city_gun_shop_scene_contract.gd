extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GUN_SHOP_SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/枪店_A.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(GUN_SHOP_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Gun shop service scene must load as PackedScene"):
		return
	var scene_root := (scene as PackedScene).instantiate()
	if not T.require_true(self, scene_root is Node3D, "Gun shop service scene must instantiate as Node3D"):
		return
	root.add_child(scene_root)
	await process_frame

	if not T.require_true(self, bool(scene_root.get_meta("city_service_scene_root", false)), "Gun shop service scene root must advertise city_service_scene_root metadata"):
		return

	var generated_building := scene_root.get_node_or_null("GeneratedBuilding")
	if not T.require_true(self, generated_building is StaticBody3D, "Gun shop service scene must keep GeneratedBuilding StaticBody3D root"):
		return
	if not T.require_true(self, str(generated_building.get_meta("city_service_scene_profile", "")) == "courtyard_gun_shop", "Gun shop scene must publish the formal courtyard_gun_shop profile id"):
		return
	if not T.require_true(self, str(scene_root.get_meta("city_service_scene_kind", "")) == "gun_shop", "Gun shop service scene root must publish gun_shop kind metadata"):
		return

	for required_node in [
		"TerrainMitigation",
		"Shell",
		"Interior",
		"Lighting",
		"ServiceAnchors",
	]:
		if not T.require_true(self, generated_building.has_node(required_node), "Gun shop scene must keep %s" % required_node):
			return

	for required_collision in [
		"CollisionDoorJambLeft",
		"CollisionDoorJambRight",
		"CollisionWindowLeft",
		"CollisionWindowRight",
	]:
		if not T.require_true(self, generated_building.has_node(required_collision), "Gun shop facade must keep %s for a formal doorway/window collision contract" % required_collision):
			return

	var shell := generated_building.get_node("Shell")
	for required_shell_node in [
		"ShopSign",
		"DoorLeafLeft",
		"DoorLeafRight",
		"WindowLeft",
		"WindowRight",
	]:
		if not T.require_true(self, shell.has_node(required_shell_node), "Gun shop shell must keep %s so the facade reads as a real storefront" % required_shell_node):
			return

	var interior := generated_building.get_node("Interior")
	for required_interior_node in [
		"FrontDisplayLeft",
		"FrontDisplayRight",
		"Counter",
		"Workbench",
		"LeftRack",
		"RightRack",
		"BackAmmoWall",
	]:
		if not T.require_true(self, interior.has_node(required_interior_node), "Gun shop interior must include %s" % required_interior_node):
			return

	var lighting := generated_building.get_node("Lighting")
	var light_count := _count_nodes_of_type(lighting, OmniLight3D)
	if not T.require_true(self, light_count >= 3, "Gun shop interior must provide at least three OmniLight3D sources"):
		return

	var anchor_ids := {}
	var anchors := generated_building.get_node("ServiceAnchors")
	for child in anchors.get_children():
		var child_node := child as Node3D
		if child_node == null:
			continue
		var anchor_id := str(child_node.get_meta("city_service_anchor_id", ""))
		if anchor_id != "":
			anchor_ids[anchor_id] = true
	for required_anchor_id in [
		"door_entry",
		"counter",
		"browse_left",
		"browse_right",
		"workbench",
	]:
		if not T.require_true(self, anchor_ids.has(required_anchor_id), "Gun shop anchors must expose %s" % required_anchor_id):
			return

	if not T.require_true(self, generated_building.has_node("Staff/Gunsmith"), "Gun shop scene must place a gunsmith staff actor behind the counter"):
		return
	var gunsmith := generated_building.get_node("Staff/Gunsmith") as Node3D
	if not T.require_true(self, gunsmith != null, "Gun shop gunsmith actor must resolve as Node3D"):
		return
	if not T.require_true(self, str(gunsmith.get_meta("city_service_actor_role", "")) == "gunsmith", "Gun shop gunsmith actor must expose gunsmith role metadata"):
		return
	if not T.require_true(self, gunsmith.has_method("get_interaction_contract"), "Gun shop gunsmith actor must expose a formal interactable NPC contract"):
		return
	var interaction_contract: Dictionary = gunsmith.get_interaction_contract()
	if not T.require_true(self, str(interaction_contract.get("actor_id", "")) == "gunsmith_01", "Gun shop gunsmith actor contract must preserve the formal actor_id"):
		return
	if not T.require_true(self, str(interaction_contract.get("interaction_kind", "")) == "dialogue", "Gun shop gunsmith actor contract must opt into dialogue interaction"):
		return
	if not T.require_true(self, float(interaction_contract.get("interaction_radius_m", 0.0)) >= 4.9, "Gun shop gunsmith actor contract must expose the frozen 5m interaction radius"):
		return
	if not T.require_true(self, str(interaction_contract.get("dialogue_id", "")) == "gun_shop_opening", "Gun shop gunsmith actor contract must expose the stable gun_shop_opening dialogue id"):
		return
	if not T.require_true(self, str(interaction_contract.get("opening_line", "")).find("都很致命，想要哪一把") >= 0, "Gun shop gunsmith actor contract must expose the opening line text"):
		return
	if not T.require_true(self, absf(gunsmith.rotation_degrees.y) <= 0.1, "Gun shop gunsmith actor must face the customer area instead of turning away from the counter front"):
		return
	var model_root := gunsmith.get_node_or_null("Model") as Node3D
	if not T.require_true(self, model_root != null, "Gun shop gunsmith actor must keep a Model root"):
		return
	if not T.require_true(self, str(model_root.scene_file_path) == "res://city_game/assets/pedestrians/civilians/man.glb", "Gun shop gunsmith actor must instantiate the curated man.glb asset"):
		return
	var animation_player := _find_animation_player(gunsmith)
	if not T.require_true(self, animation_player != null, "Gun shop gunsmith actor must contain an AnimationPlayer"):
		return
	if not T.require_true(self, animation_player.has_animation("HumanArmature|Man_Idle"), "Gun shop gunsmith actor must expose HumanArmature|Man_Idle"):
		return
	if not T.require_true(self, animation_player.is_playing(), "Gun shop gunsmith actor must start playing an idle animation"):
		return
	if not T.require_true(self, animation_player.current_animation == "HumanArmature|Man_Idle", "Gun shop gunsmith actor must hold the idle clip by default"):
		return

	scene_root.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _count_nodes_of_type(root: Node, target_type: Variant) -> int:
	if root == null:
		return 0
	var count := 0
	if is_instance_of(root, target_type):
		count += 1
	for child in root.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		count += _count_nodes_of_type(child_node, target_type)
	return count

func _find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node == null:
		return null
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var found := _find_animation_player(child_node)
		if found != null:
			return found
	return null
