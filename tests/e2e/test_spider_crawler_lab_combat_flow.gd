extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const MIN_SURVIVE_RIFLE_HITS := 9
const MAX_RIFLE_HITS_TO_KILL := 14

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if scene == null:
		T.fail_and_quit(self, "Spider crawler lab combat flow requires the dedicated lab scene")
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	if not T.require_true(self, lab.has_method("get_active_spider_count"), "Spider crawler lab combat flow requires get_active_spider_count()"):
		return
	if not T.require_true(self, lab.has_method("get_defeated_spider_count"), "Spider crawler lab combat flow requires get_defeated_spider_count()"):
		return
	if not T.require_true(self, lab.has_method("get_nearest_live_spider_to_player"), "Spider crawler lab combat flow requires get_nearest_live_spider_to_player()"):
		return
	if not T.require_true(self, lab.has_method("aim_player_at_world_position"), "Spider crawler lab combat flow requires deterministic aiming support"):
		return
	if not T.require_true(self, lab.has_method("reset_lab_state"), "Spider crawler lab combat flow requires reset_lab_state()"):
		return

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Spider crawler lab combat flow requires the formal Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "Spider crawler lab combat flow requires Player.set_weapon_mode()"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Spider crawler lab combat flow requires Player.request_primary_fire()"):
		return

	var total_spiders := int(lab.get_active_spider_count())
	if not T.require_true(self, total_spiders >= 12, "Spider crawler lab combat flow requires a swarm large enough to feel threatening"):
		return

	player.set_weapon_mode("rifle")
	var target := lab.get_nearest_live_spider_to_player() as Node3D
	if not T.require_true(self, target != null, "Spider crawler lab combat flow requires an initial live spider target"):
		return
	if not T.require_true(self, target.has_method("get_health_state"), "Spider crawler lab combat flow requires spider targets to expose get_health_state()"):
		return

	for _shot_index in range(MIN_SURVIVE_RIFLE_HITS):
		lab.aim_player_at_world_position(_combat_target_position(target))
		await physics_frame
		if not T.require_true(self, player.request_primary_fire(), "Spider crawler lab combat flow requires each rifle shot request to succeed"):
			return
		await _wait_frames(8)

	var post_nine_health: Dictionary = target.get_health_state()
	if not T.require_true(self, bool(post_nine_health.get("alive", false)), "Spider crawler lab combat flow requires spiders to survive the first nine rifle hits"):
		return

	var killed_by_cap := false
	for _shot_index in range(MAX_RIFLE_HITS_TO_KILL - MIN_SURVIVE_RIFLE_HITS):
		lab.aim_player_at_world_position(_combat_target_position(target))
		await physics_frame
		if not T.require_true(self, player.request_primary_fire(), "Spider crawler lab combat flow requires repeated rifle fire to keep working until the kill shot"):
			return
		await _wait_frames(8)
		var health_state: Dictionary = target.get_health_state()
		if not bool(health_state.get("alive", true)):
			killed_by_cap = true
			break
	if not T.require_true(self, killed_by_cap, "Spider crawler lab combat flow requires a spider to die within fourteen rifle hits"):
		return

	if not T.require_true(self, int(lab.get_defeated_spider_count()) >= 1, "Spider crawler lab combat flow requires defeated spiders to be counted in the swarm state"):
		return
	if not T.require_true(self, int(lab.get_active_spider_count()) == total_spiders - 1, "Spider crawler lab combat flow requires the live swarm count to drop after a spider dies"):
		return

	lab.reset_lab_state()
	await process_frame
	await process_frame

	if not T.require_true(self, int(lab.get_defeated_spider_count()) == 0, "Spider crawler lab combat flow reset must clear defeated spiders"):
		return
	if not T.require_true(self, int(lab.get_active_spider_count()) == total_spiders, "Spider crawler lab combat flow reset must restore the full live swarm"):
		return

	var restored_target := lab.get_nearest_live_spider_to_player() as Node3D
	if not T.require_true(self, restored_target != null, "Spider crawler lab combat flow reset requires a restored live spider target"):
		return
	var restored_health: Dictionary = restored_target.get_health_state()
	if not T.require_true(self, bool(restored_health.get("alive", false)), "Spider crawler lab combat flow reset requires the restored target to be alive again"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _wait_frames(frame_count: int) -> void:
	for _frame in range(frame_count):
		await physics_frame
		await process_frame

func _combat_target_position(target: Node3D) -> Vector3:
	if target.has_method("get_combat_target_world_position"):
		return target.get_combat_target_world_position()
	return target.global_position + Vector3.UP * 0.8
