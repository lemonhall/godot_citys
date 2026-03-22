extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/LakeFishingLab.tscn"
const WATER_ENTRY_POINT := Vector3(4.0, 0.8, -36.0)
const UNDERWATER_POINT := Vector3(4.0, -1.2, -36.0)
const REGION_ID := "region:v38:fishing_lake:chunk_147_181"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Lake lab observer contract requires the dedicated LakeFishingLab.tscn scene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Lake lab observer contract requires the formal Player teleport API"):
		return

	player.teleport_to_world_position(WATER_ENTRY_POINT)
	var water_state: Dictionary = await _wait_for_water_state(lab, true)
	if not T.require_true(self, bool(water_state.get("in_water", false)), "Lake fishing lab must expose formal in_water state after entering the water body"):
		return
	if not T.require_true(self, str(water_state.get("region_id", "")) == REGION_ID, "Lake fishing lab water observer must preserve the formal lake region_id"):
		return

	var schools: Array = lab.get_fish_school_summaries()
	if not T.require_true(self, schools.size() >= 2, "Lake fishing lab must expose non-empty fish school summaries from the shared habitat runtime"):
		return

	player.teleport_to_world_position(UNDERWATER_POINT)
	var underwater_state: Dictionary = await _wait_for_underwater_state(lab)
	if not T.require_true(self, bool(underwater_state.get("underwater", false)), "Lake fishing lab must expose formal underwater state below the waterline"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_for_water_state(lab, expected_state: bool) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var water_state: Dictionary = lab.get_lake_player_water_state()
		if bool(water_state.get("in_water", false)) == expected_state:
			return water_state
	return lab.get_lake_player_water_state()

func _wait_for_underwater_state(lab) -> Dictionary:
	for _frame in range(120):
		await physics_frame
		await process_frame
		var water_state: Dictionary = lab.get_lake_player_water_state()
		if bool(water_state.get("underwater", false)):
			return water_state
	return lab.get_lake_player_water_state()
