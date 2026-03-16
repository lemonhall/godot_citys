extends SceneTree

const T := preload("res://tests/_test_util.gd")
const BURGER_SHOP_SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_131_143_003/汉堡店_A.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(BURGER_SHOP_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Burger shop service scene must load as PackedScene"):
		return
	var scene_root := (scene as PackedScene).instantiate()
	if not T.require_true(self, scene_root is Node3D, "Burger shop service scene must instantiate as Node3D"):
		return
	root.add_child(scene_root)
	await process_frame

	if not T.require_true(self, bool(scene_root.get_meta("city_service_scene_root", false)), "Burger shop service scene root must advertise city_service_scene_root metadata"):
		return

	var generated_building := scene_root.get_node_or_null("GeneratedBuilding")
	if not T.require_true(self, generated_building is StaticBody3D, "Burger shop service scene must keep GeneratedBuilding StaticBody3D root"):
		return
	if not T.require_true(self, str(generated_building.get_meta("city_service_scene_profile", "")) == "step_midrise_burger_shop", "Burger shop scene must publish the formal step_midrise_burger_shop profile id"):
		return
	if not T.require_true(self, str(scene_root.get_meta("city_service_scene_kind", "")) == "burger_shop", "Burger shop service scene root must publish burger_shop kind metadata"):
		return
	if not T.require_true(self, absf(generated_building.rotation_degrees.y - 90.0) <= 0.1, "Burger shop scene must flip 180 degrees from the previous orientation so the storefront finally faces the road instead of showing the back side"):
		return

	for required_node in [
		"TerrainMitigation",
		"Shell",
		"Interior",
		"Lighting",
		"ServiceAnchors",
	]:
		if not T.require_true(self, generated_building.has_node(required_node), "Burger shop scene must keep %s" % required_node):
			return

	for required_collision in [
		"CollisionDoorJambLeft",
		"CollisionDoorJambRight",
		"CollisionWindowLeft",
		"CollisionWindowRight",
		"CollisionCounter",
	]:
		if not T.require_true(self, generated_building.has_node(required_collision), "Burger shop facade/interior collision contract must keep %s" % required_collision):
			return

	var shell := generated_building.get_node("Shell")
	for required_shell_node in [
		"ShopSign",
		"DoorLeafLeft",
		"DoorLeafRight",
		"WindowLeft",
		"WindowRight",
		"UpperMassingA",
		"UpperMassingB",
		"RoofBurgerSign",
	]:
		if not T.require_true(self, shell.has_node(required_shell_node), "Burger shop shell must keep %s so the storefront reads as a burger shop set into a step-midrise shell" % required_shell_node):
			return
	var roof_burger_sign := shell.get_node_or_null("RoofBurgerSign") as Node3D
	if not T.require_true(self, roof_burger_sign != null, "Burger shop shell must expose a RoofBurgerSign root on the roofline"):
		return
	var roof_burger_model := shell.get_node_or_null("RoofBurgerSign/Model") as Node3D
	if not T.require_true(self, roof_burger_model != null, "Burger shop roof sign must instance a burger model under RoofBurgerSign/Model"):
		return
	if not T.require_true(self, str(roof_burger_model.scene_file_path) == "res://city_game/assets/food/source/Cheeseburger.glb", "Burger shop roof sign must source the curated Cheeseburger.glb asset from the formal food asset directory"):
		return

	var interior := generated_building.get_node("Interior")
	for required_interior_node in [
		"Counter",
		"MenuBoard",
		"Grill",
		"Fryer",
		"BoothLeft",
		"BoothRight",
		"DrinkStation",
	]:
		if not T.require_true(self, interior.has_node(required_interior_node), "Burger shop interior must include %s" % required_interior_node):
			return

	var lighting := generated_building.get_node("Lighting")
	var light_count := _count_nodes_of_type(lighting, OmniLight3D)
	if not T.require_true(self, light_count >= 4, "Burger shop interior must provide at least four OmniLight3D sources"):
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
		"counter_queue",
		"pickup",
		"booth_left",
		"booth_right",
	]:
		if not T.require_true(self, anchor_ids.has(required_anchor_id), "Burger shop anchors must expose %s" % required_anchor_id):
			return

	if not T.require_true(self, generated_building.has_node("Staff/Cashier"), "Burger shop scene must place a cashier staff actor behind the counter"):
		return
	var cashier := generated_building.get_node("Staff/Cashier") as Node3D
	if not T.require_true(self, cashier != null, "Burger shop cashier actor must resolve as Node3D"):
		return
	if not T.require_true(self, str(cashier.get_meta("city_service_actor_role", "")) == "cashier", "Burger shop cashier actor must expose cashier role metadata"):
		return
	if not T.require_true(self, cashier.has_method("get_interaction_contract"), "Burger shop cashier actor must expose a formal interactable NPC contract"):
		return
	var interaction_contract: Dictionary = cashier.get_interaction_contract()
	if not T.require_true(self, str(interaction_contract.get("actor_id", "")) == "burger_cashier_01", "Burger shop cashier actor contract must preserve the formal actor_id"):
		return
	if not T.require_true(self, str(interaction_contract.get("interaction_kind", "")) == "dialogue", "Burger shop cashier actor contract must opt into dialogue interaction"):
		return
	if not T.require_true(self, float(interaction_contract.get("interaction_radius_m", 0.0)) >= 4.9, "Burger shop cashier actor contract must expose the frozen 5m interaction radius"):
		return
	if not T.require_true(self, str(interaction_contract.get("dialogue_id", "")) == "burger_shop_opening", "Burger shop cashier actor contract must expose the stable burger_shop_opening dialogue id"):
		return
	if not T.require_true(self, str(interaction_contract.get("opening_line", "")).find("请问想点儿什么") >= 0, "Burger shop cashier actor contract must expose the opening line text"):
		return
	var model_root := cashier.get_node_or_null("Model") as Node3D
	if not T.require_true(self, model_root != null, "Burger shop cashier actor must keep a Model root"):
		return
	if not T.require_true(self, str(model_root.scene_file_path) == "res://city_game/assets/pedestrians/civilians/animated_woman.glb", "Burger shop cashier actor must instantiate the curated animated_woman.glb asset"):
		return
	var animation_player := _find_animation_player(cashier)
	if not T.require_true(self, animation_player != null, "Burger shop cashier actor must contain an AnimationPlayer"):
		return
	if not T.require_true(self, animation_player.has_animation("Armature|Idle"), "Burger shop cashier actor must expose Armature|Idle"):
		return
	if not T.require_true(self, animation_player.is_playing(), "Burger shop cashier actor must start playing an idle animation"):
		return
	if not T.require_true(self, animation_player.current_animation == "Armature|Idle", "Burger shop cashier actor must hold the idle clip by default"):
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
