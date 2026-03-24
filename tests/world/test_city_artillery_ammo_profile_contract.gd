extends SceneTree

const T := preload("res://tests/_test_util.gd")

const BALLISTICS_SCRIPT_PATH := "res://city_game/combat/artillery/CityArtilleryBallistics.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ballistics_script = load(BALLISTICS_SCRIPT_PATH)
	if not T.require_true(self, ballistics_script != null, "Artillery ammo profile contract requires CityArtilleryBallistics.gd"):
		return

	var ballistics = ballistics_script.new()
	if not T.require_true(self, ballistics != null, "CityArtilleryBallistics.gd must instantiate so ammo profiles have a formal runtime owner"):
		return

	if not T.require_true(self, ballistics.has_method("get_shell_profile"), "Artillery ammo profile contract requires get_shell_profile()"):
		return

	var profile := ballistics.get_shell_profile("m795_he") as Dictionary
	if not T.require_true(self, not profile.is_empty(), "Artillery ammo profile contract requires a formal m795_he gameplay profile"):
		return
	if not T.require_true(self, str(profile.get("shell_type_id", "")) == "m795_he", "m795_he profile must preserve its shell_type_id"):
		return
	if not T.require_true(self, float(profile.get("min_range_m", 0.0)) == 1500.0, "Current gameplay howitzer minimum range must be frozen to 1500m instead of floating in code comments or magic numbers"):
		return
	if not T.require_true(self, float(profile.get("max_range_m", 0.0)) == 22500.0, "Current gameplay howitzer maximum range must be frozen to 22500m instead of staying implicit"):
		return
	if not T.require_true(self, absf(float(profile.get("reference_muzzle_velocity_mps", 0.0)) - 827.0) <= 0.01, "m795_he profile must preserve the public reference muzzle velocity so the profile does not discard its source semantics entirely"):
		return
	if not T.require_true(self, float(profile.get("solver_muzzle_velocity_mps", 0.0)) > 0.0, "Gameplay ammo profile must expose a positive solver_muzzle_velocity_mps so forward/inverse solving and live shell launch can share one formal speed source"):
		return
	if not T.require_true(self, float(profile.get("solver_muzzle_velocity_mps", 0.0)) < float(profile.get("reference_muzzle_velocity_mps", 0.0)), "Gameplay solver velocity must be explicitly distinguishable from the public reference velocity; otherwise 22.5km gameplay range cannot be frozen cleanly"):
		return
	if not T.require_true(self, float(profile.get("pitch_min_deg", -1.0)) == 0.0 and float(profile.get("pitch_max_deg", -1.0)) == 71.0, "Gameplay ammo profile must preserve the formal howitzer pitch limits so ballistic solve does not drift away from the weapon scene contract"):
		return

	T.pass_and_quit(self)
