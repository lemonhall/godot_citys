extends SceneTree

const T := preload("res://tests/_test_util.gd")
const GUN_SHOP_SCENE_PATH := "res://city_game/serviceability/buildings/generated/bld_v15-building-id-1_seed424242_chunk_134_130_014/枪店_A.tscn"
const EXPECTED_WEAPON_CLASSES := [
	"pistol_9mm",
	"pistol_compact",
	"pistol_compact_alt",
	"revolver",
	"assault_rifle",
	"assault_rifle_alt",
	"shotgun",
	"shotgun_sawed_off",
	"shotgun_short_stock",
	"sniper_rifle",
	"sniper_rifle_alt",
	"submachine_gun",
	"submachine_gun_alt",
	"flare_gun",
	"grenade",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(GUN_SHOP_SCENE_PATH)
	if not T.require_true(self, scene is PackedScene, "Gun shop weapon display contract requires the generated gun shop PackedScene"):
		return
	var scene_root := (scene as PackedScene).instantiate()
	if not T.require_true(self, scene_root is Node3D, "Gun shop weapon display contract must instantiate as Node3D"):
		return
	root.add_child(scene_root)
	await process_frame

	var generated_building := scene_root.get_node_or_null("GeneratedBuilding") as Node3D
	if not T.require_true(self, generated_building != null, "Gun shop weapon display contract requires GeneratedBuilding root"):
		return
	var interior := generated_building.get_node_or_null("Interior") as Node3D
	if not T.require_true(self, interior != null, "Gun shop weapon display contract requires Interior root"):
		return
	if not T.require_true(self, interior.has_node("WeaponDisplays"), "Gun shop interior must expose a dedicated WeaponDisplays root for normalized imported weapon props"):
		return

	for legacy_path in [
		"LeftRack/RifleA",
		"LeftRack/RifleB",
		"LeftRack/RifleC",
		"RightRack/RifleA",
		"RightRack/RifleB",
		"RightRack/RifleC",
	]:
		if not T.require_true(self, not interior.has_node(legacy_path), "Gun shop must remove legacy placeholder rifle sticks once real weapon models are mounted: %s" % legacy_path):
			return

	var contracts := _collect_weapon_contracts(interior.get_node("WeaponDisplays"))
	if not T.require_true(self, contracts.size() == EXPECTED_WEAPON_CLASSES.size(), "Gun shop must mount every curated imported weapon prop exactly once in WeaponDisplays"):
		return

	var seen_classes := {}
	for contract_variant in contracts:
		var contract: Dictionary = contract_variant
		var weapon_class := str(contract.get("weapon_class", ""))
		if not T.require_true(self, weapon_class != "", "Every weapon display prop must publish a stable weapon_class contract"):
			return
		seen_classes[weapon_class] = true
		var source_scene_path := str(contract.get("source_scene_path", ""))
		if not T.require_true(self, source_scene_path.begins_with("res://city_game/assets/weapons/source/"), "Weapon display props must load curated GLB assets from city_game/assets/weapons/source"):
			return
		var target_length_m := float(contract.get("target_length_m", 0.0))
		var normalized_length_m := float(contract.get("normalized_length_m", 0.0))
		if not T.require_true(self, target_length_m > 0.05, "Weapon display props must publish a real-world target_length_m"):
			return
		if not T.require_true(self, normalized_length_m > 0.05, "Weapon display props must publish a measured normalized_length_m"):
			return
		var tolerance_m := maxf(0.02, target_length_m * 0.08)
		if not T.require_true(self, absf(normalized_length_m - target_length_m) <= tolerance_m, "Weapon display props must normalize imported GLB size close to the configured real-world target length"):
			return
	for expected_weapon_class in EXPECTED_WEAPON_CLASSES:
		if not T.require_true(self, seen_classes.has(expected_weapon_class), "Gun shop weapon display contract must include %s" % expected_weapon_class):
			return

	scene_root.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _collect_weapon_contracts(root_node: Node) -> Array[Dictionary]:
	var contracts: Array[Dictionary] = []
	if root_node == null:
		return contracts
	_collect_weapon_contracts_recursive(root_node, contracts)
	return contracts

func _collect_weapon_contracts_recursive(node: Node, contracts: Array[Dictionary]) -> void:
	if node == null:
		return
	if node.has_method("get_weapon_display_contract"):
		var contract: Dictionary = node.get_weapon_display_contract()
		if not contract.is_empty():
			contracts.append(contract)
	for child in node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		_collect_weapon_contracts_recursive(child_node, contracts)
