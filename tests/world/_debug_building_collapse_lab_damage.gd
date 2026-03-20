extends SceneTree

const LAB_SCENE_PATH := "res://city_game/scenes/labs/BuildingCollapseLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	var player = lab.get_node_or_null("Player")
	var target_runtime = lab.call("get_target_building_runtime")
	var target_position: Vector3 = target_runtime.get_primary_target_world_position()
	print("target_position=", target_position)
	lab.aim_player_at_world_position(target_position)
	await physics_frame
	print("projectile_direction=", player.get_projectile_direction())
	print("aim_target=", player.get_aim_target_world_position())
	print("weapon_mode=", player.get_weapon_mode())
	print("building_state_before=", target_runtime.get_state())
	print("fire_started=", player.request_missile_launcher_fire())
	print("missile_count_after_fire=", lab.get_active_missile_count())
	for frame_index in range(160):
		await physics_frame
		if frame_index % 20 == 0:
			print("frame=", frame_index, " health=", target_runtime.get_state().get("current_health"), " missile_count=", lab.get_active_missile_count(), " last_explosion=", lab.get_last_missile_explosion_result())
	print("final_state=", target_runtime.get_state())
	quit()
