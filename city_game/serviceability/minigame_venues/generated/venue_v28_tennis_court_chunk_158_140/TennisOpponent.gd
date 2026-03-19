@tool
extends Node3D

const VISUAL_SCENE_PATH := "res://city_game/serviceability/minigame_venues/generated/venue_v28_tennis_court_chunk_158_140/TennisOpponent.tscn"
const VISUAL_ROOT_PATH := NodePath("Visual")
const TENNIS_RACKET_VISUAL_PATH := NodePath("Visual/RootNode/Human Armature/Skeleton3D/TennisRacketHandAnchor/TennisRacketSocket/TennisRacketVisual")

const TEAM_COLORS := {
	"home": Color(0.88, 0.9, 0.84, 1.0),
	"away": Color(0.18, 0.56, 0.38, 1.0),
}

const DEFAULT_ANIMATION_BLEND_SEC := 0.16
const TENNIS_RACKET_CONFIG := {
	"forehand_rotation_deg": Vector3(-42.0, 24.0, -138.0),
	"backhand_rotation_deg": Vector3(-34.0, -28.0, 130.0),
	"serve_rotation_deg": Vector3(-114.0, 20.0, -162.0),
	"forehand_position_offset": Vector3(0.16, -0.06, 0.22),
	"backhand_position_offset": Vector3(-0.16, -0.04, 0.18),
	"serve_position_offset": Vector3(0.04, 0.34, 0.28),
	"normalize_visual_to_target_length": false,
	"grip_anchor_source_point": Vector3(14.79297, 1.824243, -254.1751),
	"target_length_m": 0.69,
	"swing_duration_sec": 0.26,
}

var _opponent_contract: Dictionary = {}
var _runtime_state: Dictionary = {}
var _model_root: Node3D = null
var _animation_player: AnimationPlayer = null
var _tennis_racket_visual: Node3D = null
var _animation_catalog := {
	"idle": "",
	"run": "",
	"work": "",
}
var _active_animation_name := ""
var _last_swing_token := 0

func _ready() -> void:
	_resolve_scene_nodes()
	_configure_scene_racket()
	_apply_contract_visuals()
	_apply_runtime_state()

func configure_opponent(opponent_contract: Dictionary) -> void:
	_opponent_contract = opponent_contract.duplicate(true)
	name = str(_opponent_contract.get("player_id", "TennisOpponent"))
	_resolve_scene_nodes()
	_configure_scene_racket()
	_apply_contract_visuals()
	if _runtime_state.is_empty():
		_runtime_state = _build_default_runtime_state()
	_apply_runtime_state()

func apply_runtime_state(runtime_state: Dictionary) -> void:
	_runtime_state = runtime_state.duplicate(true)
	_apply_runtime_state()

func get_visual_scene_path() -> String:
	return VISUAL_SCENE_PATH

func get_tennis_visual_state() -> Dictionary:
	if _tennis_racket_visual != null and is_instance_valid(_tennis_racket_visual) and _tennis_racket_visual.has_method("get_visual_state"):
		return _tennis_racket_visual.get_visual_state()
	return {
		"racket_present": false,
		"equipped_visible": false,
		"swing_active": false,
		"swing_progress": 0.0,
		"swing_count": 0,
		"swing_sound_count": 0,
		"last_swing_style": "",
	}

func _resolve_scene_nodes() -> void:
	_model_root = get_node_or_null(VISUAL_ROOT_PATH) as Node3D
	_animation_player = _find_animation_player(_model_root)
	_animation_catalog = _build_animation_catalog(_animation_player)
	_tennis_racket_visual = get_node_or_null(TENNIS_RACKET_VISUAL_PATH) as Node3D

func _configure_scene_racket() -> void:
	if _tennis_racket_visual == null or not is_instance_valid(_tennis_racket_visual):
		return
	if _tennis_racket_visual.has_method("configure_rig"):
		_tennis_racket_visual.configure_rig(TENNIS_RACKET_CONFIG)
	if _tennis_racket_visual.has_method("set_equipped_visible"):
		_tennis_racket_visual.set_equipped_visible(true)

func _apply_contract_visuals() -> void:
	if _model_root == null:
		return
	var team_color_id := str(_opponent_contract.get("team_color_id", "away"))
	var base_color: Color = TEAM_COLORS.get(team_color_id, TEAM_COLORS["away"])
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.roughness = 0.92
	material.metallic = 0.02
	material.emission_enabled = true
	material.emission = base_color * 0.08
	material.emission_energy_multiplier = 0.32
	_apply_material_to_meshes(_model_root, material)

func _apply_runtime_state() -> void:
	if _runtime_state.is_empty():
		_runtime_state = _build_default_runtime_state()
	var local_position_variant: Variant = _runtime_state.get("local_position", _opponent_contract.get("local_anchor_position", Vector3.ZERO))
	if local_position_variant is Vector3:
		position = local_position_variant as Vector3
	var facing_direction_variant: Variant = _runtime_state.get("facing_direction", _opponent_contract.get("idle_facing_direction", Vector3.FORWARD))
	if facing_direction_variant is Vector3:
		var facing_direction := facing_direction_variant as Vector3
		facing_direction.y = 0.0
		if facing_direction.length_squared() > 0.0001:
			rotation.y = atan2(facing_direction.x, facing_direction.z)
	_play_animation_state(str(_runtime_state.get("animation_state", "idle")))
	_sync_tennis_racket_visual()

func _play_animation_state(animation_state: String) -> void:
	if _animation_player == null:
		_active_animation_name = ""
		return
	var resolved_name := ""
	match animation_state:
		"run":
			resolved_name = str(_animation_catalog.get("run", ""))
		"work":
			resolved_name = str(_animation_catalog.get("work", ""))
		_:
			resolved_name = str(_animation_catalog.get("idle", ""))
	if resolved_name == "":
		resolved_name = str(_animation_catalog.get("idle", ""))
	if resolved_name == "":
		_animation_player.stop()
		_active_animation_name = ""
		return
	if _active_animation_name == resolved_name and _animation_player.is_playing():
		return
	_animation_player.play(resolved_name, DEFAULT_ANIMATION_BLEND_SEC)
	_active_animation_name = resolved_name

func _build_default_runtime_state() -> Dictionary:
	return {
		"local_position": _opponent_contract.get("local_anchor_position", Vector3.ZERO),
		"facing_direction": _opponent_contract.get("idle_facing_direction", Vector3.FORWARD),
		"animation_state": "idle",
		"racket_visible": true,
		"swing_token": 0,
		"swing_style": "",
	}

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	if root == null:
		return null
	for child in root.get_children():
		var match_player := _find_animation_player(child)
		if match_player != null:
			return match_player
	return null

func _build_animation_catalog(animation_player: AnimationPlayer) -> Dictionary:
	var catalog := {
		"idle": "",
		"run": "",
		"work": "",
	}
	if animation_player == null:
		return catalog
	var animation_names := animation_player.get_animation_list()
	for animation_name_variant in animation_names:
		var animation_name := str(animation_name_variant)
		var lowered := animation_name.to_lower()
		if catalog["idle"] == "" and lowered.contains("idle"):
			catalog["idle"] = animation_name
		elif catalog["run"] == "" and (lowered.contains("run") or lowered.contains("walk")):
			catalog["run"] = animation_name
		elif catalog["work"] == "" and (lowered.contains("work") or lowered.contains("punch")):
			catalog["work"] = animation_name
	if catalog["idle"] == "" and not animation_names.is_empty():
		catalog["idle"] = str(animation_names[0])
	if catalog["run"] == "":
		catalog["run"] = catalog["idle"]
	if catalog["work"] == "":
		catalog["work"] = catalog["idle"]
	return catalog

func _apply_material_to_meshes(root: Node, material: Material) -> void:
	if _is_tennis_racket_visual_subtree(root):
		return
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = material
	for child in root.get_children():
		_apply_material_to_meshes(child, material)

func _is_tennis_racket_visual_subtree(root: Node) -> bool:
	if _tennis_racket_visual == null or not is_instance_valid(_tennis_racket_visual):
		return false
	return root == _tennis_racket_visual or _tennis_racket_visual.is_ancestor_of(root)

func _sync_tennis_racket_visual() -> void:
	if _tennis_racket_visual == null or not is_instance_valid(_tennis_racket_visual):
		return
	if _tennis_racket_visual.has_method("set_equipped_visible"):
		_tennis_racket_visual.set_equipped_visible(bool(_runtime_state.get("racket_visible", true)))
	var swing_token := int(_runtime_state.get("swing_token", 0))
	if swing_token > 0 and swing_token != _last_swing_token and _tennis_racket_visual.has_method("play_swing"):
		_tennis_racket_visual.play_swing(str(_runtime_state.get("swing_style", "forehand")))
	_last_swing_token = swing_token
