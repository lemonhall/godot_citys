extends SceneTree

const T := preload("res://tests/_test_util.gd")

const ROOT_MODEL_PATH := "res://Animated Human.glb"
const SOCCER_MODEL_PATH := "res://city_game/assets/minigames/soccer/players/animated_human.glb"
const PEDESTRIAN_MANIFEST_PATH := "res://city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json"
const MATCH_PLAYER_SCRIPT_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v26_soccer_pitch_chunk_129_139/SoccerMatchPlayer.gd"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, not FileAccess.file_exists(ProjectSettings.globalize_path(ROOT_MODEL_PATH)), "Soccer match asset contract must stop using the root-level Animated Human.glb as a formal runtime asset entrypoint"):
		return
	if not T.require_true(self, FileAccess.file_exists(ProjectSettings.globalize_path(SOCCER_MODEL_PATH)), "Soccer match asset contract must relocate Animated Human.glb into the soccer-only asset directory"):
		return
	if not T.require_true(self, ResourceLoader.exists(MATCH_PLAYER_SCRIPT_PATH), "Soccer match asset contract requires a dedicated SoccerMatchPlayer wrapper instead of reusing ambient pedestrian scenes"):
		return

	var manifest_text := FileAccess.get_file_as_string(ProjectSettings.globalize_path(PEDESTRIAN_MANIFEST_PATH))
	var manifest_variant = JSON.parse_string(manifest_text)
	if not T.require_true(self, manifest_variant is Dictionary, "Soccer match asset contract requires pedestrian_model_manifest.json to parse as Dictionary"):
		return
	var manifest: Dictionary = manifest_variant
	var models: Array = manifest.get("models", [])
	for model_variant in models:
		var model: Dictionary = model_variant
		var file_path := str(model.get("file", ""))
		if not T.require_true(self, file_path != SOCCER_MODEL_PATH, "Soccer match asset contract must keep the soccer player model out of the ambient pedestrian manifest"):
			return

	T.pass_and_quit(self)
