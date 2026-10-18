extends SceneTree

# v62 ornament check: rooftop and facade detail must exist as a real instance
# batch and must not be buried inside the massing volume.

const T := preload("res://tests/_test_util.gd")
const MassingBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMassingBuilder.gd")

const ARCHETYPES := [
	"slab",
	"needle",
	"courtyard",
	"podium_tower",
	"step_midrise",
	"midrise_bar",
	"industrial",
]

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for archetype in ARCHETYPES:
		var size := Vector3(30.0, 36.0, 26.0)
		var building := _make_building(archetype, size)
		var visual := MassingBuilder.build(building)
		var facade_mesh: ArrayMesh = visual.get("facade_mesh", null)
		if not T.require_true(self, facade_mesh != null, "Building must produce a merged facade mesh"):
			return
		var facade_aabb := facade_mesh.get_aabb()
		var facade_top := facade_aabb.position.y + facade_aabb.size.y
		var roof_tolerance := size.y * 0.30 if archetype == "industrial" else maxf(2.5, size.y * 0.10)
		if not T.require_true(
			self,
			facade_top >= size.y * 0.5 - roof_tolerance,
			"%s facade top must land near the contract roof line" % archetype
		):
			return
		var detail_boxes = visual.get("detail_boxes", null)
		if not T.require_true(self, detail_boxes != null and detail_boxes.count() >= 8, "Building must emit a real detail batch"):
			return
		var protruding_count := 0
		var all_batches: Array = [detail_boxes]
		var detail_cylinders = visual.get("detail_cylinders", null)
		if detail_cylinders != null:
			all_batches.append(detail_cylinders)
		for batch in all_batches:
			for instance_transform in batch.transforms:
				var transform: Transform3D = instance_transform
				var half_height := transform.basis.y.length() * 0.5
				if transform.origin.y + half_height >= size.y * 0.5 - 0.4:
					protruding_count += 1
		if not T.require_true(
			self,
			protruding_count >= 1,
			"%s must keep at least one ornament protruding at the roof line instead of burying every detail" % archetype
		):
			return

	T.pass_and_quit(self)

func _make_building(archetype_id: String, size: Vector3) -> Dictionary:
	return {
		"name": "Review_%s" % archetype_id,
		"building_id": "review_%s" % archetype_id,
		"archetype_id": archetype_id,
		"center": Vector3(0.0, size.y * 0.5, 0.0),
		"size": size,
		"collision_size": size,
		"yaw_rad": 0.0,
		"main_color": Color(0.52, 0.48, 0.42, 1.0),
		"accent_color": Color(0.24, 0.22, 0.20, 1.0),
		"roof_color": Color(0.24, 0.24, 0.25, 1.0),
		"detail_seed": 5150,
	}
