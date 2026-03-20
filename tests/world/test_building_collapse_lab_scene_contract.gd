extends SceneTree

const T := preload("res://tests/_test_util.gd")
const LAB_SCENE_PATH := "res://city_game/scenes/labs/BuildingCollapseLab.tscn"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not T.require_true(self, ResourceLoader.exists(LAB_SCENE_PATH, "PackedScene"), "Building collapse lab contract requires a dedicated F6 scene"):
		return

	var scene := load(LAB_SCENE_PATH) as PackedScene
	if not T.require_true(self, scene != null, "Building collapse lab contract must load the lab scene as PackedScene"):
		return

	var lab := scene.instantiate() as Node3D
	root.add_child(lab)
	await process_frame

	if not T.require_true(self, lab.has_method("get_target_building_runtime"), "Building collapse lab scene must expose get_target_building_runtime()"):
		return
	if not T.require_true(self, lab.has_method("fire_player_missile_launcher"), "Building collapse lab scene must expose fire_player_missile_launcher()"):
		return
	if not T.require_true(self, lab.has_method("fire_missile_at_world_position"), "Building collapse lab scene must expose deterministic missile firing for focused verification"):
		return
	if not T.require_true(self, lab.has_method("get_active_missile_count"), "Building collapse lab scene must expose get_active_missile_count()"):
		return
	if not T.require_true(self, lab.has_method("get_last_missile_explosion_result"), "Building collapse lab scene must expose missile explosion inspection"):
		return
	if not T.require_true(self, lab.has_method("reset_lab_state"), "Building collapse lab scene must expose reset_lab_state() for rapid iteration"):
		return
	if not T.require_true(self, lab.has_method("aim_player_at_world_position"), "Building collapse lab scene must expose deterministic aiming support"):
		return

	var player := lab.get_node_or_null("Player")
	if not T.require_true(self, player != null, "Building collapse lab scene must mount the formal Player node"):
		return
	if not T.require_true(self, player.has_method("request_missile_launcher_fire"), "Lab player must preserve the formal missile launcher fire request"):
		return
	if not T.require_true(self, player.has_method("get_weapon_mode"), "Lab player must preserve the formal weapon mode contract"):
		return
	if not T.require_true(self, str(player.get_weapon_mode()) == "missile_launcher", "Lab scene must start with the missile launcher equipped for destruction testing"):
		return

	var missile_root := lab.get_node_or_null("CombatRoot/Missiles") as Node3D
	if not T.require_true(self, missile_root != null, "Building collapse lab scene must own CombatRoot/Missiles for live projectile mounting"):
		return

	var target_runtime: Variant = lab.get_target_building_runtime()
	if not T.require_true(self, target_runtime != null, "Building collapse lab scene must mount a destructible target building runtime"):
		return
	if not T.require_true(self, target_runtime.has_method("apply_damage"), "Destructible building runtime must expose apply_damage()"):
		return
	if not T.require_true(self, target_runtime.has_method("apply_explosion_damage"), "Destructible building runtime must expose apply_explosion_damage()"):
		return
	if not T.require_true(self, target_runtime.has_method("get_state"), "Destructible building runtime must expose get_state()"):
		return
	if not T.require_true(self, target_runtime.has_method("get_debug_state"), "Destructible building runtime must expose get_debug_state()"):
		return
	if not T.require_true(self, target_runtime.has_method("get_primary_target_world_position"), "Destructible building runtime must expose a deterministic aim point"):
		return

	var target_state: Dictionary = target_runtime.get_state()
	if not T.require_true(self, str(target_state.get("building_id", "")) != "", "Target building runtime must preserve a stable building_id"):
		return
	if not T.require_true(self, float(target_state.get("max_health", 0.0)) >= 10000.0, "Target building runtime must freeze the formal health pool"):
		return
	if not T.require_true(self, str(target_state.get("damage_state", "")) == "intact", "Target building runtime must boot in the intact state"):
		return

	lab.queue_free()
	T.pass_and_quit(self)
