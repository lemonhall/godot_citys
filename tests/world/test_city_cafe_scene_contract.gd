extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CAFE_SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_003/咖啡馆.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CAFE_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Cafe service scene must load as PackedScene"):
		return
	var root := (scene as PackedScene).instantiate()
	if not T.require_true(self, root is Node3D, "Cafe service scene must instantiate as Node3D"):
		return

	var generated_building := root.get_node_or_null("GeneratedBuilding")
	if not T.require_true(self, generated_building is StaticBody3D, "Cafe service scene must keep GeneratedBuilding StaticBody3D root"):
		return

	if not T.require_true(self, generated_building.has_node("TerrainMitigation"), "Cafe service scene must include terrain mitigation geometry to hide ground intrusion"):
		return
	if not T.require_true(self, generated_building.has_node("Lighting"), "Cafe service scene must include dedicated lighting nodes"):
		return
	if not T.require_true(self, generated_building.has_node("ServiceAnchors"), "Cafe service scene must expose future NPC/service anchors"):
		return

	var lighting := generated_building.get_node("Lighting")
	var light_count := _count_nodes_of_type(lighting, OmniLight3D)
	if not T.require_true(self, light_count >= 3, "Cafe service scene must provide at least three OmniLight3D sources for interior lighting"):
		return

	var terrain_mitigation := generated_building.get_node("TerrainMitigation")
	if not T.require_true(self, terrain_mitigation.has_node("BackPlatform"), "Cafe terrain mitigation must include a back platform/banquette cover"):
		return
	if not T.require_true(self, terrain_mitigation.has_node("RightBanquette"), "Cafe terrain mitigation must include a right-side banquette cover"):
		return
	if not T.require_true(self, terrain_mitigation.has_node("LeftBanquette"), "Cafe terrain mitigation must include a left-side banquette cover"):
		return

	var interior := generated_building.get_node_or_null("Interior")
	if not T.require_true(self, interior != null, "Cafe service scene must keep the Interior node"):
		return
	if not T.require_true(self, interior.has_node("Register"), "Cafe interior must include a register mesh block"):
		return
	if not T.require_true(self, interior.has_node("CoffeeMachine"), "Cafe interior must include a coffee machine mesh block"):
		return
	if not T.require_true(self, interior.has_node("MenuText"), "Cafe interior must include a visible menu text mesh"):
		return

	var anchors := generated_building.get_node("ServiceAnchors")
	var anchor_ids := {}
	for child in anchors.get_children():
		var child_node := child as Node3D
		if child_node == null:
			continue
		var anchor_id := str(child_node.get_meta("city_service_anchor_id", ""))
		if anchor_id != "":
			anchor_ids[anchor_id] = true
	if not T.require_true(self, anchor_ids.has("barista"), "Cafe anchors must expose a barista anchor"):
		return
	if not T.require_true(self, anchor_ids.has("register_queue"), "Cafe anchors must expose a register queue anchor"):
		return
	if not T.require_true(self, anchor_ids.has("window_seat_left"), "Cafe anchors must expose a left seating anchor"):
		return
	if not T.require_true(self, anchor_ids.has("window_seat_right"), "Cafe anchors must expose a right seating anchor"):
		return
	if not T.require_true(self, anchor_ids.has("door_entry"), "Cafe anchors must expose a doorway anchor"):
		return

	root.free()
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
