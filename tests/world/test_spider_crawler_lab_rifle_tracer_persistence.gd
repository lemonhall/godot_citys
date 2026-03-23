extends SceneTree

const T := preload("res://tests/_test_util.gd")

const LAB_SCENE_PATH := "res://city_game/scenes/labs/SpiderCrawlerLab.tscn"
const REQUIRED_OVERLAP_COUNT := 3
const MAX_RETRY_FRAMES_PER_SHOT := 24
const CLEAR_TIMEOUT_SEC := 1.2

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Spider crawler lab rifle tracer persistence contract requires SpiderCrawlerLab.tscn"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame
	await process_frame

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Spider crawler lab rifle tracer persistence contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "Spider crawler lab rifle tracer persistence contract requires Player.set_weapon_mode()"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "Spider crawler lab rifle tracer persistence contract requires Player.request_primary_fire()"):
		return
	if not T.require_true(self, lab.has_method("get_active_projectile_tracer_count"), "Spider crawler lab rifle tracer persistence contract requires get_active_projectile_tracer_count()"):
		return
	if not T.require_true(self, lab.has_method("get_nearest_live_spider_to_player"), "Spider crawler lab rifle tracer persistence contract requires get_nearest_live_spider_to_player()"):
		return
	if not T.require_true(self, lab.has_method("aim_player_at_world_position"), "Spider crawler lab rifle tracer persistence contract requires aim_player_at_world_position()"):
		return

	player.set_weapon_mode("rifle")
	var target := lab.get_nearest_live_spider_to_player() as Node3D
	if target != null:
		lab.aim_player_at_world_position(_combat_target_position(target))
	await physics_frame

	var tracer_count_before := int(lab.get_active_projectile_tracer_count())
	var accepted_shots := 0
	for _shot_index in range(REQUIRED_OVERLAP_COUNT):
		var accepted := await _request_next_rifle_shot(player)
		if not T.require_true(self, accepted, "Spider crawler lab rifle tracer persistence contract requires three accepted consecutive shots"):
			return
		accepted_shots += 1

	var tracer_count_after_burst := int(lab.get_active_projectile_tracer_count())
	var tracer_root := lab.get_node_or_null("CombatRoot/ProjectileTracers") as Node3D
	var latest_tracer := tracer_root.get_child(tracer_root.get_child_count() - 1) as Node3D if tracer_root != null and tracer_root.get_child_count() > 0 else null
	var latest_lifetime_sec := float(latest_tracer.get("lifetime_sec")) if latest_tracer != null else 0.0

	print("SPIDER_CRAWLER_LAB_RIFLE_TRACER_PERSISTENCE %s" % JSON.stringify({
		"accepted_shots": accepted_shots,
		"tracer_count_before": tracer_count_before,
		"tracer_count_after_burst": tracer_count_after_burst,
		"latest_lifetime_sec": latest_lifetime_sec,
	}))

	if not T.require_true(self, tracer_count_after_burst >= tracer_count_before + REQUIRED_OVERLAP_COUNT, "Spider crawler lab continuous rifle fire must also keep about three smoke traces alive at once"):
		return
	if not T.require_true(self, latest_lifetime_sec >= 0.2 and latest_lifetime_sec <= 0.5, "Spider crawler lab must reuse the same 0.2s-0.5s rifle tracer persistence window as the main world"):
		return

	var tracer_cleared := false
	var clear_deadline_usec := Time.get_ticks_usec() + int(CLEAR_TIMEOUT_SEC * 1000000.0)
	while Time.get_ticks_usec() < clear_deadline_usec:
		await process_frame
		if int(lab.get_active_projectile_tracer_count()) <= tracer_count_before:
			tracer_cleared = true
			break
	if not T.require_true(self, tracer_cleared, "Spider crawler lab smoke tracers must still clear after the short persistence window"):
		return

	lab.queue_free()
	await process_frame
	T.pass_and_quit(self)

func _request_next_rifle_shot(player: Node) -> bool:
	for _frame in range(MAX_RETRY_FRAMES_PER_SHOT):
		if bool(player.request_primary_fire()):
			return true
		await process_frame
		await physics_frame
	return false

func _combat_target_position(target: Node3D) -> Vector3:
	if target.has_method("get_combat_target_world_position"):
		return target.get_combat_target_world_position()
	return target.global_position + Vector3.UP * 0.8
