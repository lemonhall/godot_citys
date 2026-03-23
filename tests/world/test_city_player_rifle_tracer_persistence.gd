extends SceneTree

const T := preload("res://tests/_test_util.gd")

const REQUIRED_OVERLAP_COUNT := 3
const MAX_RETRY_FRAMES_PER_SHOT := 24
const CLEAR_TIMEOUT_SEC := 1.2

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for rifle tracer persistence contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Rifle tracer persistence contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_weapon_mode"), "PlayerController must expose set_weapon_mode() for tracer persistence verification"):
		return
	if not T.require_true(self, player.has_method("request_primary_fire"), "PlayerController must expose request_primary_fire() for tracer persistence verification"):
		return
	if not T.require_true(self, world.has_method("get_active_projectile_tracer_count"), "CityPrototype must expose get_active_projectile_tracer_count() for tracer persistence verification"):
		return

	player.set_weapon_mode("rifle")
	await process_frame

	var tracer_count_before := int(world.get_active_projectile_tracer_count())
	var accepted_shots := 0
	for _shot_index in range(REQUIRED_OVERLAP_COUNT):
		var accepted := await _request_next_rifle_shot(player)
		if not T.require_true(self, accepted, "Rifle tracer persistence contract requires three accepted consecutive shots"):
			return
		accepted_shots += 1

	var tracer_count_after_burst := int(world.get_active_projectile_tracer_count())
	var tracer_root := world.get_node_or_null("CombatRoot/ProjectileTracers") as Node3D
	var latest_tracer := tracer_root.get_child(tracer_root.get_child_count() - 1) as Node3D if tracer_root != null and tracer_root.get_child_count() > 0 else null
	var latest_lifetime_sec := float(latest_tracer.get("lifetime_sec")) if latest_tracer != null else 0.0

	print("CITY_PLAYER_RIFLE_TRACER_PERSISTENCE %s" % JSON.stringify({
		"accepted_shots": accepted_shots,
		"tracer_count_before": tracer_count_before,
		"tracer_count_after_burst": tracer_count_after_burst,
		"latest_lifetime_sec": latest_lifetime_sec,
	}))

	if not T.require_true(self, tracer_count_after_burst >= tracer_count_before + REQUIRED_OVERLAP_COUNT, "Continuous rifle fire must keep about three smoke traces alive at once instead of collapsing to a single streak"):
		return
	if not T.require_true(self, latest_lifetime_sec >= 0.2 and latest_lifetime_sec <= 0.5, "Rifle smoke tracer lifetime should sit in the 0.2s-0.5s persistence window for automatic-fire overlap"):
		return

	var tracer_cleared := false
	var clear_deadline_usec := Time.get_ticks_usec() + int(CLEAR_TIMEOUT_SEC * 1000000.0)
	while Time.get_ticks_usec() < clear_deadline_usec:
		await process_frame
		if int(world.get_active_projectile_tracer_count()) <= tracer_count_before:
			tracer_cleared = true
			break
	if not T.require_true(self, tracer_cleared, "Rifle smoke tracers must still clear after the short automatic-fire persistence window"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _request_next_rifle_shot(player: Node) -> bool:
	for _frame in range(MAX_RETRY_FRAMES_PER_SHOT):
		if bool(player.request_primary_fire()):
			return true
		await process_frame
		await physics_frame
	return false
