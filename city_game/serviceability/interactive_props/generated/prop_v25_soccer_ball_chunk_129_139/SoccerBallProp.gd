extends RigidBody3D

const GROUP_NAME := "city_interactable_prop"
const DEFAULT_DISPLAY_NAME := "足球"
const DEFAULT_INTERACTION_KIND := "kick"
const DEFAULT_PROMPT_TEXT := "按 E 踢球"
const DEFAULT_TARGET_DIAMETER_M := 1.20
const DEFAULT_INTERACTION_RADIUS_M := 2.15
const DEFAULT_MASS_KG := 0.43
const DEFAULT_KICK_IMPULSE := 4.6
const DEFAULT_KICK_LIFT_IMPULSE := 0.52

@onready var _collision_shape := $CollisionShape3D as CollisionShape3D
@onready var _visual_root := $VisualRoot as Node3D

var _entry: Dictionary = {}
var _contract: Dictionary = {}
var _target_diameter_m := DEFAULT_TARGET_DIAMETER_M
var _interaction_radius_m := DEFAULT_INTERACTION_RADIUS_M
var _kick_impulse := DEFAULT_KICK_IMPULSE
var _kick_lift_impulse := DEFAULT_KICK_LIFT_IMPULSE

func _ready() -> void:
	_apply_entry_settings()
	_normalize_visual_scale()
	sleeping = true
	if not is_in_group(GROUP_NAME):
		add_to_group(GROUP_NAME)

func configure_interactive_prop(entry: Dictionary) -> void:
	_entry = entry.duplicate(true)
	if is_node_ready():
		_apply_entry_settings()
		_normalize_visual_scale()

func get_interaction_contract() -> Dictionary:
	return _contract.duplicate(true)

func apply_player_interaction(player_node: Node3D, interaction_contract: Dictionary = {}) -> Dictionary:
	if player_node == null or not is_instance_valid(player_node):
		return _build_interaction_result(false, "missing_player", interaction_contract)
	var direction := global_position - player_node.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -player_node.global_transform.basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var run_up_boost := 0.0
	var player_velocity_variant: Variant = player_node.get("velocity")
	if player_velocity_variant is Vector3:
		var player_velocity: Vector3 = player_velocity_variant
		run_up_boost = clampf(Vector2(player_velocity.x, player_velocity.z).length() * 0.18, 0.0, 1.8)
	sleeping = false
	apply_central_impulse(direction * (_kick_impulse + run_up_boost) + Vector3.UP * (_kick_lift_impulse + run_up_boost * 0.08))
	return _build_interaction_result(true, "", interaction_contract)

func _apply_entry_settings() -> void:
	var display_name := str(_entry.get("display_name", DEFAULT_DISPLAY_NAME)).strip_edges()
	if display_name == "":
		display_name = DEFAULT_DISPLAY_NAME
	_target_diameter_m = maxf(float(_entry.get("target_diameter_m", DEFAULT_TARGET_DIAMETER_M)), 0.12)
	_interaction_radius_m = maxf(float(_entry.get("interaction_radius_m", DEFAULT_INTERACTION_RADIUS_M)), 0.5)
	_kick_impulse = maxf(float(_entry.get("kick_impulse", DEFAULT_KICK_IMPULSE)), 0.1)
	_kick_lift_impulse = maxf(float(_entry.get("kick_lift_impulse", DEFAULT_KICK_LIFT_IMPULSE)), 0.0)
	mass = maxf(float(_entry.get("physics_mass_kg", DEFAULT_MASS_KG)), 0.1)
	var sphere_shape := _collision_shape.shape as SphereShape3D
	if sphere_shape == null:
		sphere_shape = SphereShape3D.new()
		_collision_shape.shape = sphere_shape
	sphere_shape.radius = _target_diameter_m * 0.5
	_contract = {
		"prop_id": str(_entry.get("prop_id", "")),
		"display_name": display_name,
		"feature_kind": str(_entry.get("feature_kind", "scene_interactive_prop")),
		"interaction_kind": str(_entry.get("interaction_kind", DEFAULT_INTERACTION_KIND)),
		"interaction_radius_m": _interaction_radius_m,
		"prompt_text": str(_entry.get("prompt_text", DEFAULT_PROMPT_TEXT)),
	}

func _normalize_visual_scale() -> void:
	if _visual_root == null:
		return
	var local_bounds := _collect_visual_bounds()
	if local_bounds.is_empty():
		return
	var size: Vector3 = local_bounds.get("size", Vector3.ZERO)
	var center: Vector3 = local_bounds.get("center", Vector3.ZERO)
	var max_extent := maxf(size.x, maxf(size.y, size.z))
	if max_extent <= 0.0001:
		return
	var scale_factor := _target_diameter_m / max_extent
	_visual_root.scale = Vector3.ONE * scale_factor
	_visual_root.position = -center * scale_factor

func _collect_visual_bounds() -> Dictionary:
	if _visual_root == null:
		return {}
	var min_corner := Vector3(INF, INF, INF)
	var max_corner := Vector3(-INF, -INF, -INF)
	var visual_count := 0
	var root_inverse := _visual_root.global_transform.affine_inverse()
	for child in _visual_root.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var local_transform := root_inverse * visual.global_transform
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var local_corner := local_transform * corner
			min_corner.x = minf(min_corner.x, local_corner.x)
			min_corner.y = minf(min_corner.y, local_corner.y)
			min_corner.z = minf(min_corner.z, local_corner.z)
			max_corner.x = maxf(max_corner.x, local_corner.x)
			max_corner.y = maxf(max_corner.y, local_corner.y)
			max_corner.z = maxf(max_corner.z, local_corner.z)
		visual_count += 1
	if visual_count <= 0:
		return {}
	return {
		"size": max_corner - min_corner,
		"center": (min_corner + max_corner) * 0.5,
	}

func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var base := aabb.position
	var size := aabb.size
	return [
		base,
		base + Vector3(size.x, 0.0, 0.0),
		base + Vector3(0.0, size.y, 0.0),
		base + Vector3(0.0, 0.0, size.z),
		base + Vector3(size.x, size.y, 0.0),
		base + Vector3(size.x, 0.0, size.z),
		base + Vector3(0.0, size.y, size.z),
		base + size,
	]

func _build_interaction_result(success: bool, error: String, interaction_contract: Dictionary) -> Dictionary:
	var prop_id := str(_contract.get("prop_id", ""))
	if prop_id == "":
		prop_id = str(interaction_contract.get("prop_id", ""))
	return {
		"success": success,
		"error": error,
		"prop_id": prop_id,
		"interaction_kind": str(_contract.get("interaction_kind", DEFAULT_INTERACTION_KIND)),
	}
