extends SceneTree

const T := preload("res://tests/_test_util.gd")
const DRONE_SCENE_PATH := "res://city_game/combat/drone/CityDroneGunship.tscn"
const DRONE_RUNTIME_SCRIPT_PATH := "res://city_game/combat/drone/CityPlayerDroneRuntime.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var drone_scene := load(DRONE_SCENE_PATH) as PackedScene
	if not T.require_true(self, drone_scene != null, "Player drone portability contract requires the formal CityDroneGunship.tscn scene"):
		return

	var drone := drone_scene.instantiate() as Node3D
	if not T.require_true(self, drone != null, "Player drone portability contract requires the formal drone scene to instantiate as a Node3D runtime carrier"):
		return
	root.add_child(drone)
	await process_frame

	if not T.require_true(self, drone.has_method("get_portability_contract"), "Player drone portability contract requires get_portability_contract() on the formal drone runtime"):
		return
	if not T.require_true(self, drone.has_method("get_debug_state"), "Player drone portability contract requires get_debug_state() on the formal drone runtime"):
		return

	var portability_contract: Dictionary = drone.get_portability_contract()
	for top_level_key in [
		"scene_path",
		"runtime_script_path",
		"world_anchor",
		"player_lock",
		"camera_owner",
		"input_source",
		"activation_gate",
		"debug_passthrough",
	]:
		if not T.require_true(self, portability_contract.has(top_level_key), "Player drone portability contract must freeze %s for future lab/main-world reuse" % top_level_key):
			return
	if not T.require_true(self, str(portability_contract.get("scene_path", "")) == DRONE_SCENE_PATH, "Player drone portability contract must preserve the formal drone scene path"):
		return
	if not T.require_true(self, str(portability_contract.get("runtime_script_path", "")) == DRONE_RUNTIME_SCRIPT_PATH, "Player drone portability contract must preserve the formal combat/drone runtime script path"):
		return
	if not T.require_true(self, str((portability_contract.get("world_anchor", {}) as Dictionary).get("kind", "")) == "external_player_anchor", "Player drone portability contract must externalize the deployment anchor to the mounting world wrapper"):
		return
	if not T.require_true(self, str((portability_contract.get("player_lock", {}) as Dictionary).get("kind", "")) == "player_controller_lock_api", "Player drone portability contract must freeze player lock/unlock onto the shared PlayerController API instead of a lab-local toggle"):
		return
	if not T.require_true(self, str((portability_contract.get("camera_owner", {}) as Dictionary).get("kind", "")) == "external_camera_switch", "Player drone portability contract must externalize current-camera switching instead of hard-wiring a single world root"):
		return
	if not T.require_true(self, str((portability_contract.get("input_source", {}) as Dictionary).get("kind", "")) == "input_singleton", "Player drone portability contract must read from the shared input layer instead of a lab-specific controller script"):
		return
	if not T.require_true(self, str((portability_contract.get("activation_gate", {}) as Dictionary).get("kind", "")) == "external_toggle_gate", "Player drone portability contract must freeze activation as an external world-owned toggle gate"):
		return
	if not T.require_true(self, str((portability_contract.get("debug_passthrough", {}) as Dictionary).get("method", "")) == "get_debug_state", "Player drone portability contract must wire future wrappers back to get_debug_state()"):
		return

	var world_scene := load("res://city_game/scenes/CityPrototype.tscn") as PackedScene
	if not T.require_true(self, world_scene != null, "Player drone portability contract requires CityPrototype.tscn for main-world mounting verification"):
		return
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	if not T.require_true(self, world.has_method("get_player_drone_debug_state"), "Player drone portability contract requires CityPrototype.get_player_drone_debug_state() for wrapper verification"):
		return
	var mounted_runtime := world.get_node_or_null("PlayerDroneRuntime")
	if not T.require_true(self, mounted_runtime != null, "Player drone portability contract requires CityPrototype to mount the formal PlayerDroneRuntime node"):
		return
	var mounted_script := mounted_runtime.get_script() as Script
	if not T.require_true(self, mounted_script != null and str(mounted_script.resource_path) == DRONE_RUNTIME_SCRIPT_PATH, "Player drone portability contract requires CityPrototype to mount the same combat/drone runtime that future labs will reuse"):
		return

	drone.queue_free()
	world.queue_free()
	await process_frame
	T.pass_and_quit(self)
