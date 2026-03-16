extends SceneTree

const T := preload("res://tests/_test_util.gd")
const CAFE_SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_137_136_003/咖啡馆.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(CAFE_SCENE_PATH)
	if not T.require_true(self, scene != null and scene is PackedScene, "Cafe service scene must load as PackedScene"):
		return
	var scene_root := (scene as PackedScene).instantiate()
	if not T.require_true(self, scene_root is Node3D, "Cafe service scene must instantiate as Node3D"):
		return
	root.add_child(scene_root)
	await process_frame

	var generated_building := scene_root.get_node_or_null("GeneratedBuilding")
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

	if not T.require_true(self, generated_building.has_node("Staff/Barista"), "Cafe service scene must place a barista staff actor in the interior"):
		return
	var barista := generated_building.get_node("Staff/Barista") as Node3D
	if not T.require_true(self, barista != null, "Cafe barista actor must resolve as Node3D"):
		return
	if not T.require_true(self, str(barista.get_meta("city_service_actor_role", "")) == "barista", "Cafe barista actor must expose barista role metadata"):
		return
	if not T.require_true(self, absf(barista.rotation_degrees.y) <= 0.1, "Cafe barista actor must face the customer area instead of turning its back to the room"):
		return
	var animation_player := _find_animation_player(barista)
	if not T.require_true(self, animation_player != null, "Cafe barista actor must contain an AnimationPlayer"):
		return
	if not T.require_true(self, animation_player.has_animation("CharacterArmature|Idle"), "Cafe barista actor must expose CharacterArmature|Idle"):
		return
	if not T.require_true(self, animation_player.is_playing(), "Cafe barista actor must start playing an idle animation"):
		return
	if not T.require_true(self, animation_player.current_animation == "CharacterArmature|Idle", "Cafe barista actor must hold the idle clip by default"):
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
