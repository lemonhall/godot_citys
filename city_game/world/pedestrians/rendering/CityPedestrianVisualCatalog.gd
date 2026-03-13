extends RefCounted

const MANIFEST_PATH := "res://city_game/assets/pedestrians/civilians/pedestrian_model_manifest.json"
const MIN_DEATH_VISUAL_DURATION_SEC := 3.0

var _manifest_snapshot: Dictionary = {}
var _model_entries: Array[Dictionary] = []
var _scene_cache: Dictionary = {}
var _scene_metadata_cache: Dictionary = {}

func _init() -> void:
	_load_manifest()
	_prewarm_scene_resources()

func get_manifest_snapshot() -> Dictionary:
	return _manifest_snapshot.duplicate(true)

func get_model_count() -> int:
	return _model_entries.size()

func select_entry_for_state(state) -> Dictionary:
	if _model_entries.is_empty():
		return {}
	var seed_value := _state_seed(state)
	var model_index := posmod(seed_value, _model_entries.size())
	return _model_entries[model_index] as Dictionary

func instantiate_scene_for_entry(entry: Dictionary) -> Node3D:
	var packed_scene := _resolve_packed_scene(entry)
	if packed_scene == null:
		return null
	var instance_variant = packed_scene.instantiate()
	var node_3d := instance_variant as Node3D
	if node_3d != null:
		return node_3d
	var wrapper := Node3D.new()
	if instance_variant is Node:
		wrapper.add_child(instance_variant as Node)
	return wrapper

func resolve_cached_animation_player(root_node: Node, entry: Dictionary) -> AnimationPlayer:
	var metadata: Dictionary = _resolve_scene_metadata(entry)
	var animation_player_path: NodePath = metadata.get("animation_player_path", NodePath(""))
	if animation_player_path is NodePath and String(animation_player_path) != "":
		var cached_player := root_node.get_node_or_null(animation_player_path) as AnimationPlayer
		if cached_player != null:
			return cached_player
	return find_animation_player(root_node)

func entry_uses_placeholder_box_mesh(entry: Dictionary) -> bool:
	return bool(_resolve_scene_metadata(entry).get("contains_placeholder_box_mesh", false))

func resolve_death_visual_duration_sec(entry: Dictionary) -> float:
	var metadata := _resolve_scene_metadata(entry)
	return maxf(float(metadata.get("death_animation_length_sec", 0.0)), MIN_DEATH_VISUAL_DURATION_SEC)

func resolve_animation_name(entry: Dictionary, state) -> String:
	var life_state := _state_life_state(state)
	if life_state == "dead":
		return _first_non_empty([
			str(entry.get("death_animation", "")),
			str(entry.get("idle_animation", "")),
			str(entry.get("run_animation", "")),
			str(entry.get("walk_animation", "")),
		])
	var reaction_state := _state_reaction_state(state)
	if reaction_state == "panic" or reaction_state == "flee":
		return _first_non_empty([
			str(entry.get("run_animation", "")),
			str(entry.get("walk_animation", "")),
			str(entry.get("idle_animation", "")),
		])
	return _first_non_empty([
		str(entry.get("walk_animation", "")),
		str(entry.get("idle_animation", "")),
		str(entry.get("run_animation", "")),
	])

func find_animation_player(root_node: Node) -> AnimationPlayer:
	if root_node is AnimationPlayer:
		return root_node as AnimationPlayer
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		var animation_player := find_animation_player(child_node)
		if animation_player != null:
			return animation_player
	return null

func scene_contains_placeholder_box_mesh(root_node: Node) -> bool:
	if root_node is MeshInstance3D:
		var mesh_instance := root_node as MeshInstance3D
		if mesh_instance.mesh is BoxMesh:
			return true
	for child in root_node.get_children():
		var child_node := child as Node
		if child_node == null:
			continue
		if scene_contains_placeholder_box_mesh(child_node):
			return true
	return false

func animation_name_has_any_token(animation_name: String, tokens: Array[String]) -> bool:
	var normalized_animation := animation_name.to_lower()
	for token in tokens:
		if normalized_animation.find(token.to_lower()) >= 0:
			return true
	return false

func _load_manifest() -> void:
	_manifest_snapshot.clear()
	_model_entries.clear()
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var manifest_text := FileAccess.get_file_as_string(MANIFEST_PATH)
	var manifest_variant = JSON.parse_string(manifest_text)
	if not manifest_variant is Dictionary:
		return
	_manifest_snapshot = (manifest_variant as Dictionary).duplicate(true)
	var models: Array = _manifest_snapshot.get("models", [])
	for model_variant in models:
		if model_variant is Dictionary:
			_model_entries.append((model_variant as Dictionary).duplicate(true))

func _prewarm_scene_resources() -> void:
	for entry in _model_entries:
		_resolve_packed_scene(entry)
		_resolve_scene_metadata(entry)

func _resolve_packed_scene(entry: Dictionary) -> PackedScene:
	var file_path := str(entry.get("file", ""))
	if file_path == "":
		return null
	if _scene_cache.has(file_path):
		return _scene_cache[file_path] as PackedScene
	var scene_resource := load(file_path)
	var packed_scene := scene_resource as PackedScene
	if packed_scene == null:
		return null
	_scene_cache[file_path] = packed_scene
	return packed_scene

func _resolve_scene_metadata(entry: Dictionary) -> Dictionary:
	var file_path := str(entry.get("file", ""))
	if file_path == "":
		return {}
	if _scene_metadata_cache.has(file_path):
		return (_scene_metadata_cache[file_path] as Dictionary).duplicate(true)
	var model_root: Node3D = instantiate_scene_for_entry(entry)
	if model_root == null:
		return {}
	var metadata: Dictionary = {
		"animation_player_path": _resolve_animation_player_path(model_root),
		"contains_placeholder_box_mesh": scene_contains_placeholder_box_mesh(model_root),
		"death_animation_length_sec": _resolve_death_animation_length_sec(model_root, entry),
	}
	model_root.free()
	_scene_metadata_cache[file_path] = metadata
	return metadata.duplicate(true)

func _resolve_animation_player_path(root_node: Node) -> NodePath:
	var animation_player := find_animation_player(root_node)
	if animation_player == null:
		return NodePath("")
	return root_node.get_path_to(animation_player)

func _resolve_death_animation_length_sec(root_node: Node, entry: Dictionary) -> float:
	var animation_player := find_animation_player(root_node)
	if animation_player == null:
		return 0.0
	var death_animation := str(entry.get("death_animation", ""))
	if death_animation == "" or not animation_player.has_animation(death_animation):
		return 0.0
	var animation := animation_player.get_animation(death_animation)
	return 0.0 if animation == null else float(animation.length)

func _first_non_empty(values: Array[String]) -> String:
	for value in values:
		if value != "":
			return value
	return ""

func _state_seed(state) -> int:
	if state is Dictionary:
		return int((state as Dictionary).get("seed", 0))
	return int(state.seed_value) if state != null else 0

func _state_life_state(state) -> String:
	if state is Dictionary:
		return str((state as Dictionary).get("life_state", "alive"))
	return str(state.life_state) if state != null else "alive"

func _state_reaction_state(state) -> String:
	if state is Dictionary:
		return str((state as Dictionary).get("reaction_state", "none"))
	return str(state.reaction_state) if state != null else "none"
