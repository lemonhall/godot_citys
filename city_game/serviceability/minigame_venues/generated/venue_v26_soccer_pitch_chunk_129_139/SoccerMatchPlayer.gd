extends Node3D

const PLAYER_MODEL_SCENE := preload("res://city_game/assets/minigames/soccer/players/animated_human.glb")

const TEAM_COLORS := {
	"red": Color(0.88, 0.2, 0.18, 1.0),
	"blue": Color(0.18, 0.4, 0.9, 1.0),
}

const GOALKEEPER_COLOR_MIX := 0.22
const DEFAULT_ANIMATION_BLEND_SEC := 0.16

var _player_contract: Dictionary = {}
var _runtime_state: Dictionary = {}
var _model_root: Node3D = null
var _animation_player: AnimationPlayer = null
var _animation_catalog := {
	"idle": "",
	"run": "",
	"work": "",
}
var _active_animation_name := ""

func _ready() -> void:
	_ensure_visual_root()
	_apply_contract_visuals()
	_apply_runtime_state()

func configure_player(player_contract: Dictionary) -> void:
	_player_contract = player_contract.duplicate(true)
	name = str(_player_contract.get("player_id", "SoccerMatchPlayer"))
	_ensure_visual_root()
	_apply_contract_visuals()
	if _runtime_state.is_empty():
		_runtime_state = _build_default_runtime_state()
	_apply_runtime_state()

func apply_runtime_state(runtime_state: Dictionary) -> void:
	_runtime_state = runtime_state.duplicate(true)
	_apply_runtime_state()

func get_player_state() -> Dictionary:
	var state := _runtime_state.duplicate(true)
	state["player_id"] = str(_player_contract.get("player_id", ""))
	state["team_id"] = str(_player_contract.get("team_id", ""))
	state["role_id"] = str(_player_contract.get("role_id", ""))
	state["team_color_id"] = str(_player_contract.get("team_color_id", ""))
	state["active_animation_name"] = _active_animation_name
	return state

func _ensure_visual_root() -> void:
	if _model_root != null and is_instance_valid(_model_root):
		return
	if PLAYER_MODEL_SCENE != null:
		_model_root = PLAYER_MODEL_SCENE.instantiate() as Node3D
	if _model_root == null:
		_model_root = _build_fallback_model()
	_model_root.name = "Visual"
	add_child(_model_root)
	_animation_player = _find_animation_player(_model_root)
	_animation_catalog = _build_animation_catalog(_animation_player)

func _apply_contract_visuals() -> void:
	if _model_root == null:
		return
	var team_color_id := str(_player_contract.get("team_color_id", "red"))
	var role_id := str(_player_contract.get("role_id", "field_player"))
	var base_color: Color = TEAM_COLORS.get(team_color_id, TEAM_COLORS["red"])
	if role_id == "goalkeeper":
		base_color = base_color.lerp(Color.WHITE, GOALKEEPER_COLOR_MIX)
	var material := StandardMaterial3D.new()
	material.albedo_color = base_color
	material.roughness = 0.96
	material.metallic = 0.02
	material.emission_enabled = true
	material.emission = base_color * 0.1
	material.emission_energy_multiplier = 0.35
	_apply_material_to_meshes(_model_root, material)

func _apply_runtime_state() -> void:
	if _runtime_state.is_empty():
		_runtime_state = _build_default_runtime_state()
	var local_position_variant: Variant = _runtime_state.get("local_position", _player_contract.get("local_anchor_position", Vector3.ZERO))
	if local_position_variant is Vector3:
		position = local_position_variant as Vector3
	var facing_direction_variant: Variant = _runtime_state.get("facing_direction", _player_contract.get("idle_facing_direction", Vector3.FORWARD))
	if facing_direction_variant is Vector3:
		var facing_direction := facing_direction_variant as Vector3
		facing_direction.y = 0.0
		if facing_direction.length_squared() > 0.0001:
			rotation.y = atan2(facing_direction.x, facing_direction.z)
	_play_animation_state(str(_runtime_state.get("animation_state", "idle")))

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
		"local_position": _player_contract.get("local_anchor_position", Vector3.ZERO),
		"facing_direction": _player_contract.get("idle_facing_direction", Vector3.FORWARD),
		"animation_state": "idle",
	}

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
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
	if root is MeshInstance3D:
		(root as MeshInstance3D).material_override = material
	for child in root.get_children():
		_apply_material_to_meshes(child, material)

func _build_fallback_model() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	body.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.mid_height = 1.0
	capsule.radius = 0.24
	body.mesh = capsule
	body.position = Vector3(0.0, 0.74, 0.0)
	root.add_child(body)
	var head := MeshInstance3D.new()
	head.name = "Head"
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	head.mesh = sphere
	head.position = Vector3(0.0, 1.58, 0.0)
	root.add_child(head)
	return root
