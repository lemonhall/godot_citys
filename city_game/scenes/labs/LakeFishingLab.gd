extends Node3D

const CityTerrainRegionFeatureRegistry := preload("res://city_game/world/features/CityTerrainRegionFeatureRegistry.gd")
const CityTerrainRegionFeatureRuntime := preload("res://city_game/world/features/CityTerrainRegionFeatureRuntime.gd")
const CityLakeFishSchoolRuntime := preload("res://city_game/world/features/lake/CityLakeFishSchoolRuntime.gd")
const LakeFishActorScene := preload("res://city_game/world/features/lake/LakeFishActor.tscn")
const CityFishingVenueRuntime := preload("res://city_game/world/minigames/CityFishingVenueRuntime.gd")

const TERRAIN_REGION_REGISTRY_PATH := "res://city_game/serviceability/terrain_regions/generated/terrain_region_registry.json"
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"
const VENUE_ID := "venue:v38:lakeside_fishing:chunk_147_181"
const LAB_WORLD_ORIGIN := Vector3(2834.0, 0.0, 11546.0)

class LakeFishSchoolLabAdapter:
	extends RefCounted

	var _shared_runtime = null
	var _world_origin := Vector3.ZERO

	func configure(shared_runtime, world_origin: Vector3) -> void:
		_shared_runtime = shared_runtime if shared_runtime != null and shared_runtime.has_method("get_school_summaries_for_region") else null
		_world_origin = world_origin

	func get_school_summaries_for_region(region_id: String) -> Array:
		if _shared_runtime == null:
			return []
		var shared_summaries: Array = _shared_runtime.get_school_summaries_for_region(region_id)
		var localized_summaries: Array = []
		for summary_variant in shared_summaries:
			if not (summary_variant is Dictionary):
				continue
			var summary: Dictionary = (summary_variant as Dictionary).duplicate(true)
			var world_position_variant: Variant = summary.get("world_position", Vector3.ZERO)
			if world_position_variant is Vector3:
				summary["world_position"] = (world_position_variant as Vector3) - _world_origin
			localized_summaries.append(summary)
		return localized_summaries

@onready var player := $Player
@onready var hud := $Hud
@onready var fish_schools_root := $LakeRoot/FishSchools
@onready var venue_root := $VenueRoot

var _terrain_region_feature_runtime = null
var _lake_runtime = null
var _fish_school_runtime = null
var _fish_school_runtime_adapter = null
var _fishing_runtime = null
var _initial_player_position := Vector3.ZERO
var _initial_player_rotation := Vector3.ZERO
var _water_state: Dictionary = {}
var _fish_school_summaries: Array = []

func _ready() -> void:
	_capture_initial_state()
	_setup_runtimes()
	_rebuild_fish_school_visuals()
	_apply_hud_state()

func _process(delta: float) -> void:
	_update_lake_player_water_state()
	if _fishing_runtime != null and _fishing_runtime.has_method("update_direct"):
		_fishing_runtime.update_direct(venue_root, player, delta)
	_apply_hud_state()

func get_lake_player_water_state() -> Dictionary:
	return _water_state.duplicate(true)

func get_fish_school_summaries() -> Array:
	var snapshot: Array = []
	for school_variant in _fish_school_summaries:
		snapshot.append((school_variant as Dictionary).duplicate(true))
	return snapshot

func get_fishing_runtime_state() -> Dictionary:
	if _fishing_runtime == null or not _fishing_runtime.has_method("get_state"):
		return {}
	return _fishing_runtime.get_state()

func request_fishing_primary_interaction() -> Dictionary:
	if _fishing_runtime == null or not _fishing_runtime.has_method("handle_primary_interaction_direct"):
		return {"success": false, "error": "runtime_unavailable"}
	return _fishing_runtime.handle_primary_interaction_direct(venue_root, player)

func reset_lab_state() -> void:
	if _fishing_runtime != null and _fishing_runtime.has_method("reset_runtime_state"):
		_fishing_runtime.reset_runtime_state(true)
	if player != null and is_instance_valid(player):
		player.global_position = _initial_player_position
		player.rotation = _initial_player_rotation
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		if player.has_method("set_movement_locked"):
			player.set_movement_locked(false)
	_update_lake_player_water_state()
	_apply_hud_state()

func find_scene_minigame_venue_node(venue_id: String) -> Node3D:
	if venue_root == null or not is_instance_valid(venue_root) or not venue_root.has_method("get_fishing_contract"):
		return null
	var contract: Dictionary = venue_root.get_fishing_contract()
	return venue_root if str(contract.get("venue_id", "")) == venue_id else null

func _setup_runtimes() -> void:
	var registry := CityTerrainRegionFeatureRegistry.new()
	registry.configure(TERRAIN_REGION_REGISTRY_PATH, [TERRAIN_REGION_REGISTRY_PATH])
	_terrain_region_feature_runtime = CityTerrainRegionFeatureRuntime.new()
	_terrain_region_feature_runtime.configure(registry.load_registry())
	if _terrain_region_feature_runtime != null and _terrain_region_feature_runtime.has_method("get_lake_runtime"):
		_lake_runtime = _terrain_region_feature_runtime.get_lake_runtime(REGION_ID)
	_fish_school_runtime = CityLakeFishSchoolRuntime.new()
	_fish_school_runtime.configure([_lake_runtime])
	_fish_school_runtime_adapter = LakeFishSchoolLabAdapter.new()
	_fish_school_runtime_adapter.configure(_fish_school_runtime, LAB_WORLD_ORIGIN)
	_fish_school_summaries = _fish_school_runtime_adapter.get_school_summaries_for_region(REGION_ID)
	_fishing_runtime = CityFishingVenueRuntime.new()
	if venue_root != null and venue_root.has_method("get_fishing_contract"):
		var venue_contract: Dictionary = venue_root.get_fishing_contract()
		_fishing_runtime.configure({
			str(venue_contract.get("venue_id", VENUE_ID)): venue_contract.duplicate(true),
		})
	_fishing_runtime.set_lake_context(_terrain_region_feature_runtime, _fish_school_runtime_adapter)
	_update_lake_player_water_state()

func _capture_initial_state() -> void:
	if player == null:
		return
	_initial_player_position = player.global_position
	_initial_player_rotation = player.rotation

func _update_lake_player_water_state() -> void:
	if _terrain_region_feature_runtime == null or player == null:
		_water_state = {
			"in_water": false,
			"underwater": false,
			"region_id": "",
			"world_position": player.global_position if player != null else Vector3.ZERO,
		}
		return
	var formal_world_position: Vector3 = player.global_position + LAB_WORLD_ORIGIN
	_water_state = _terrain_region_feature_runtime.query_water_state(formal_world_position)
	if not _water_state.is_empty():
		var sampled_world_position_variant: Variant = _water_state.get("world_position", formal_world_position)
		var sampled_world_position: Vector3 = sampled_world_position_variant as Vector3 if sampled_world_position_variant is Vector3 else formal_world_position
		_water_state["world_position"] = sampled_world_position - LAB_WORLD_ORIGIN
		_water_state["formal_world_position"] = formal_world_position
	if player.has_method("set_lake_water_state"):
		player.set_lake_water_state(_water_state)

func _rebuild_fish_school_visuals() -> void:
	if fish_schools_root == null:
		return
	for child in fish_schools_root.get_children():
		child.queue_free()
	for school_variant in _fish_school_summaries:
		if not (school_variant is Dictionary):
			continue
		var school: Dictionary = school_variant
		var fish_actor := LakeFishActorScene.instantiate() as Node3D
		if fish_actor == null:
			continue
		fish_actor.name = str(school.get("school_id", "FishSchool"))
		var school_world_position_variant: Variant = school.get("world_position", Vector3.ZERO)
		var school_world_position: Vector3 = school_world_position_variant as Vector3 if school_world_position_variant is Vector3 else Vector3.ZERO
		fish_actor.position = school_world_position
		fish_schools_root.add_child(fish_actor)
		if fish_actor.has_method("configure_school_visual"):
			fish_actor.configure_school_visual(school)

func _apply_hud_state() -> void:
	if hud == null:
		return
	if hud.has_method("set_fps_overlay_visible"):
		hud.set_fps_overlay_visible(true)
	if hud.has_method("set_fps_overlay_sample"):
		hud.set_fps_overlay_sample(Engine.get_frames_per_second())
	if hud.has_method("set_status"):
		var fishing_state := get_fishing_runtime_state()
		hud.set_status(
			"v38 Lake Fishing Lab\nstate=%s  schools=%d  in_water=%s  underwater=%s" % [
				str(fishing_state.get("cast_state", "idle")),
				_fish_school_summaries.size(),
				str(bool(_water_state.get("in_water", false))),
				str(bool(_water_state.get("underwater", false))),
			]
		)
	if hud.has_method("set_fishing_hud_state") and _fishing_runtime != null and _fishing_runtime.has_method("get_match_hud_state"):
		hud.set_fishing_hud_state(_fishing_runtime.get_match_hud_state())
	if hud.has_method("set_interaction_prompt_state") and _fishing_runtime != null and _fishing_runtime.has_method("get_primary_interaction_state"):
		hud.set_interaction_prompt_state(_fishing_runtime.get_primary_interaction_state(player))
