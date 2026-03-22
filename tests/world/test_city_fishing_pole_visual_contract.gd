extends SceneTree

const T := preload("res://tests/_test_util.gd")

const FISHING_POLE_ASSET_PATH := "res://city_game/assets/minigames/fishing/props/FishingPole.glb"
const FISHING_POLE_SCENE_PATH := "res://city_game/assets/minigames/fishing/props/FishingPoleVisual.tscn"
const FISHING_POLE_EQUIPPED_SCENE_PATH := "res://city_game/assets/minigames/fishing/props/FishingPoleEquippedVisual.tscn"
const VENUE_SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v38_lakeside_fishing_chunk_147_181/lake_fishing_minigame_venue.tscn"
const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"
const WORLD_SCENE_PATH := "res://city_game/scenes/CityPrototype.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(FISHING_POLE_ASSET_PATH, "PackedScene"), "Fishing pole visual contract requires the curated pole glb under the formal fishing prop asset directory"):
		return
	if not T.require_true(self, ResourceLoader.exists(FISHING_POLE_SCENE_PATH, "PackedScene"), "Fishing pole visual contract requires a dedicated FishingPoleVisual.tscn wrapper scene"):
		return
	if not T.require_true(self, ResourceLoader.exists(FISHING_POLE_EQUIPPED_SCENE_PATH, "PackedScene"), "Fishing pole visual contract requires a dedicated FishingPoleEquippedVisual.tscn wrapper scene for player-held usage"):
		return
	if not T.require_true(self, ResourceLoader.exists(VENUE_SCENE_PATH, "PackedScene"), "Fishing pole visual contract requires the canonical lakeside fishing venue scene"):
		return

	var pole_scene := load(FISHING_POLE_SCENE_PATH) as PackedScene
	if not T.require_true(self, pole_scene != null, "Fishing pole visual contract must load FishingPoleVisual.tscn as PackedScene"):
		return
	var pole_visual := pole_scene.instantiate() as Node3D
	root.add_child(pole_visual)
	await process_frame

	if not T.require_true(self, pole_visual.has_method("get_debug_state"), "Fishing pole visual wrapper must expose get_debug_state() for regression coverage"):
		return
	var pole_model := pole_visual.get_node_or_null("MountRoot/Model") as Node3D
	if not T.require_true(self, pole_model != null, "Fishing pole visual wrapper must mount the imported model under MountRoot/Model"):
		return
	if not T.require_true(self, str(pole_model.scene_file_path) == FISHING_POLE_ASSET_PATH, "Fishing pole visual wrapper must source the curated FishingPole.glb asset"):
		return
	var equipped_scene := load(FISHING_POLE_EQUIPPED_SCENE_PATH) as PackedScene
	if not T.require_true(self, equipped_scene != null, "Fishing pole visual contract must load FishingPoleEquippedVisual.tscn as PackedScene"):
		return
	var equipped_visual := equipped_scene.instantiate() as Node3D
	root.add_child(equipped_visual)
	await process_frame
	if not T.require_true(self, equipped_visual.has_method("get_visual_state"), "Fishing pole equipped visual must expose get_visual_state() for regression coverage"):
		return
	var equipped_pole := equipped_visual.get_node_or_null("MountRoot/Pole") as Node3D
	if not T.require_true(self, equipped_pole != null, "Fishing pole equipped visual must mount the held pole under MountRoot/Pole"):
		return

	var venue_scene := load(VENUE_SCENE_PATH) as PackedScene
	if not T.require_true(self, venue_scene != null, "Fishing pole visual contract must load the canonical fishing venue scene"):
		return
	var venue := venue_scene.instantiate() as Node3D
	root.add_child(venue)
	await process_frame

	var pole_anchor := venue.get_node_or_null("FishingPoleRestAnchor") as Node3D
	if not T.require_true(self, pole_anchor != null, "Fishing venue scene must author a dedicated FishingPoleRestAnchor for hand-tuned pole placement"):
		return
	var mounted_pole := venue.get_node_or_null("FishingPoleRestAnchor/FishingPoleVisual") as Node3D
	if not T.require_true(self, mounted_pole != null and mounted_pole.has_method("get_debug_state"), "Fishing venue scene must mount the wrapped FishingPoleVisual under the authored rest anchor"):
		return
	var mounted_model := mounted_pole.get_node_or_null("MountRoot/Model") as Node3D
	if not T.require_true(self, mounted_model != null and str(mounted_model.scene_file_path) == FISHING_POLE_ASSET_PATH, "Mounted fishing pole prop must continue to reference the formal FishingPole.glb asset"):
		return
	var mounted_debug_state: Dictionary = mounted_pole.get_debug_state()
	if not T.require_true(self, int(mounted_debug_state.get("visual_count", 0)) > 0, "Mounted fishing pole prop must contribute visible geometry to the venue scene"):
		return
	if not T.require_true(self, venue.get_node_or_null("MatchStartRing") == null, "Fishing venue scene must no longer author MatchStartRing after the pole-driven interaction rework"):
		return
	var bobber_visual := venue.get_node_or_null("FishingBobberVisual") as Node3D
	if not T.require_true(self, bobber_visual != null and bobber_visual.has_method("get_debug_state"), "Fishing venue scene must author a dedicated FishingBobberVisual runtime carrier"):
		return
	var line_visual := venue.get_node_or_null("FishingLineVisual") as Node3D
	if not T.require_true(self, line_visual != null and line_visual.has_method("get_debug_state"), "Fishing venue scene must author a dedicated FishingLineVisual runtime carrier"):
		return

	for scene_path in [LAB_SCENE_PATH, WORLD_SCENE_PATH]:
		var player_scene := load(scene_path) as PackedScene
		if not T.require_true(self, player_scene != null, "Fishing pole visual contract must load %s for authored hold-anchor checks" % scene_path):
			return
		var scene_root := player_scene.instantiate() as Node3D
		root.add_child(scene_root)
		await process_frame
		var hold_anchor := scene_root.get_node_or_null("Player/Visual/FishingPoleHoldAnchor") as Node3D
		if not T.require_true(self, hold_anchor != null, "%s must author Player/Visual/FishingPoleHoldAnchor for scene-first held-pole placement" % scene_path):
			return
		var mounted_equipped_visual := scene_root.get_node_or_null("Player/Visual/FishingPoleHoldAnchor/FishingPoleEquippedVisual") as Node3D
		if not T.require_true(self, mounted_equipped_visual != null and mounted_equipped_visual.has_method("get_visual_state"), "%s must author the wrapped FishingPoleEquippedVisual under Player/Visual/FishingPoleHoldAnchor" % scene_path):
			return
		scene_root.queue_free()
		await process_frame

	venue.queue_free()
	equipped_visual.queue_free()
	pole_visual.queue_free()
	await process_frame
	T.pass_and_quit(self)
