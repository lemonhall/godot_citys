extends SceneTree

const T := preload("res://tests/_test_util.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ring_script := load("res://city_game/world/navigation/CityWorldRingMarker.gd")
	if ring_script == null:
		T.fail_and_quit(self, "World ring marker theme idempotent test requires CityWorldRingMarker.gd")
		return

	var ring: Node3D = ring_script.new()
	root.add_child(ring)
	await process_frame

	ring.set_marker_theme("task_active_objective")
	var outer_ring := ring.get_node_or_null("OuterRing") as MeshInstance3D
	var inner_ring := ring.get_node_or_null("InnerRing") as MeshInstance3D
	var core_disc := ring.get_node_or_null("CoreDisc") as MeshInstance3D
	var dash_ring := ring.get_node_or_null("DashRing") as Node3D
	var flame_column := ring.get_node_or_null("FlameColumn0") as MeshInstance3D
	if not T.require_true(self, outer_ring != null and inner_ring != null and core_disc != null and dash_ring != null and flame_column != null, "World ring marker must expose its shared mesh pieces for theme regression coverage"):
		return

	var dash_segment := dash_ring.get_node_or_null("Segment0") as MeshInstance3D
	if not T.require_true(self, dash_segment != null, "World ring marker must keep dash segments for theme regression coverage"):
		return

	var outer_material := outer_ring.material_override
	var inner_material := inner_ring.material_override
	var core_material := core_disc.material_override
	var dash_material := dash_segment.material_override
	var flame_material := flame_column.material_override

	ring.set_marker_theme("task_active_objective")

	if not T.require_true(self, outer_ring.material_override == outer_material, "Reapplying the same theme must not recreate outer ring material instances"):
		return
	if not T.require_true(self, inner_ring.material_override == inner_material, "Reapplying the same theme must not recreate inner ring material instances"):
		return
	if not T.require_true(self, core_disc.material_override == core_material, "Reapplying the same theme must not recreate core disc material instances"):
		return
	if not T.require_true(self, dash_segment.material_override == dash_material, "Reapplying the same theme must not recreate dash segment material instances"):
		return
	if not T.require_true(self, flame_column.material_override == flame_material, "Reapplying the same theme must not recreate flame column material instances"):
		return

	T.pass_and_quit(self)
