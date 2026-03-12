extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for ADS contract")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	if not T.require_true(self, player != null, "ADS contract requires Player node"):
		return
	if not T.require_true(self, player.has_method("set_aim_down_sights_active"), "PlayerController must expose set_aim_down_sights_active() for right-click ADS"):
		return
	if not T.require_true(self, player.has_method("is_aim_down_sights_active"), "PlayerController must expose is_aim_down_sights_active() for ADS state checks"):
		return
	if not T.require_true(self, player.has_method("get_camera_fov_state"), "PlayerController must expose get_camera_fov_state() for ADS zoom verification"):
		return

	var hud := world.get_node_or_null("Hud")
	if not T.require_true(self, hud != null, "ADS contract requires Hud node"):
		return
	if not T.require_true(self, hud.has_method("get_crosshair_state"), "PrototypeHud must expose get_crosshair_state() for ADS HUD verification"):
		return

	var camera := player.get_node_or_null("CameraRig/Camera3D") as Camera3D
	if not T.require_true(self, camera != null, "ADS contract requires CameraRig/Camera3D"):
		return

	var base_fov := camera.fov
	player.set_aim_down_sights_active(true)
	for _frame in range(18):
		await process_frame

	if not T.require_true(self, player.is_aim_down_sights_active(), "Right-click ADS must mark the player as aiming"):
		return
	var ads_fov_state: Dictionary = player.get_camera_fov_state()
	if not T.require_true(self, float(ads_fov_state.get("current", base_fov)) <= base_fov - 5.0, "ADS must visibly reduce the active camera FOV"):
		return
	if not T.require_true(self, camera.fov <= base_fov - 5.0, "ADS must zoom the gameplay camera instead of keeping the default FOV"):
		return

	var crosshair_state: Dictionary = hud.get_crosshair_state()
	if not T.require_true(self, bool(crosshair_state.get("aim_down_sights_active", false)), "Crosshair state must expose whether ADS is active"):
		return

	player.set_aim_down_sights_active(false)
	for _frame in range(18):
		await process_frame

	if not T.require_true(self, not player.is_aim_down_sights_active(), "Releasing ADS must restore the non-aim state"):
		return
	if not T.require_true(self, absf(camera.fov - base_fov) <= 1.0, "Releasing ADS must restore the default camera FOV"):
		return

	world.queue_free()
	T.pass_and_quit(self)
