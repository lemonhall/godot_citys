extends SceneTree

const T := preload("res://tests/_test_util.gd")

const SOCCER_CHUNK_ID := "chunk_129_139"
const SOCCER_PROP_ID := "prop:v25:soccer_ball:chunk_129_139"
const SOCCER_ANCHOR_WORLD_POSITION := Vector3(-1877.94, 2.52, 618.57)
const MIN_DIAMETER_M := 1.10
const MAX_DIAMETER_M := 1.45
const MAX_BOTTOM_OFFSET_M := 0.08

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := load("res://city_game/scenes/CityPrototype.tscn")
	if scene == null or not (scene is PackedScene):
		T.fail_and_quit(self, "Missing CityPrototype.tscn for soccer ball visual envelope")
		return

	var world := (scene as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var player := world.get_node_or_null("Player")
	var chunk_renderer = world.get_chunk_renderer() if world.has_method("get_chunk_renderer") else null
	if not T.require_true(self, player != null and player.has_method("teleport_to_world_position"), "Soccer ball visual envelope test requires Player teleport API"):
		return
	if not T.require_true(self, chunk_renderer != null and chunk_renderer.has_method("get_chunk_scene"), "Soccer ball visual envelope test requires chunk renderer lookup"):
		return

	player.teleport_to_world_position(SOCCER_ANCHOR_WORLD_POSITION + Vector3(0.0, 3.0, 4.0))
	var mounted_prop: Node3D = null
	for _frame in range(180):
		await process_frame
		var chunk_scene = chunk_renderer.get_chunk_scene(SOCCER_CHUNK_ID)
		if chunk_scene == null or not chunk_scene.has_method("find_scene_interactive_prop_node"):
			continue
		mounted_prop = chunk_scene.find_scene_interactive_prop_node(SOCCER_PROP_ID) as Node3D
		if mounted_prop != null:
			break
	if not T.require_true(self, mounted_prop != null, "Soccer ball visual envelope test must mount the prop in chunk_129_139"):
		return

	var visual_extents := _collect_visual_extents(mounted_prop)
	if not T.require_true(self, int(visual_extents.get("visual_count", 0)) > 0, "Soccer ball prop must contribute at least one visible VisualInstance3D"):
		return
	var diameter_x_m := float(visual_extents.get("footprint_x_m", 0.0))
	var diameter_z_m := float(visual_extents.get("footprint_z_m", 0.0))
	var height_m := float(visual_extents.get("height_m", 0.0))
	var bottom_y := float(visual_extents.get("bottom_y", 0.0))
	if not T.require_true(self, diameter_x_m >= MIN_DIAMETER_M and diameter_x_m <= MAX_DIAMETER_M, "Soccer ball visual diameter on X must stay inside the frozen readable range"):
		return
	if not T.require_true(self, diameter_z_m >= MIN_DIAMETER_M and diameter_z_m <= MAX_DIAMETER_M, "Soccer ball visual diameter on Z must stay inside the frozen readable range"):
		return
	if not T.require_true(self, height_m >= MIN_DIAMETER_M and height_m <= MAX_DIAMETER_M, "Soccer ball visual height must stay inside the frozen readable range"):
		return
	if not T.require_true(self, absf(bottom_y - SOCCER_ANCHOR_WORLD_POSITION.y) <= MAX_BOTTOM_OFFSET_M, "Soccer ball visual bottom must stay close to the authored ground anchor height"):
		return

	world.queue_free()
	T.pass_and_quit(self)

func _collect_visual_extents(root_node: Node3D) -> Dictionary:
	var min_x := INF
	var max_x := -INF
	var min_y := INF
	var max_y := -INF
	var min_z := INF
	var max_z := -INF
	var visual_count := 0
	for child in root_node.find_children("*", "VisualInstance3D", true, false):
		var visual := child as VisualInstance3D
		if visual == null or not visual.visible:
			continue
		var aabb := visual.get_aabb()
		for corner in _aabb_corners(aabb):
			var world_corner := visual.global_transform * corner
			min_x = minf(min_x, world_corner.x)
			max_x = maxf(max_x, world_corner.x)
			min_y = minf(min_y, world_corner.y)
			max_y = maxf(max_y, world_corner.y)
			min_z = minf(min_z, world_corner.z)
			max_z = maxf(max_z, world_corner.z)
		visual_count += 1
	if visual_count <= 0:
		return {
			"visual_count": 0,
		}
	return {
		"visual_count": visual_count,
		"footprint_x_m": max_x - min_x,
		"footprint_z_m": max_z - min_z,
		"height_m": max_y - min_y,
		"bottom_y": min_y,
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
