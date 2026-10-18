extends SceneTree
const MassingBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMassingBuilder.gd")
func _init():
	var size := Vector3(24.0, 60.0, 20.0)
	var visual := MassingBuilder.build({
		"name": "P", "building_id": "p", "archetype_id": "slab",
		"center": Vector3(0, 30, 0), "size": size, "collision_size": size,
		"yaw_rad": 0.0, "main_color": Color(0.44,0.46,0.48), "accent_color": Color(0.17,0.19,0.21),
		"roof_color": Color(0.23,0.24,0.26), "glass_color": Color(0.045,0.075,0.105), "detail_seed": 7,
	})
	for batch_key in ["detail_boxes", "detail_cylinders"]:
		var batch = visual.get(batch_key)
		if batch == null: continue
		for i in range(batch.transforms.size()):
			var t: Transform3D = batch.transforms[i]
			if t.origin.y > 2.5:
				print("%s y=%.2f x=%.2f z=%.2f size=(%.2f,%.2f,%.2f)" % [batch_key, t.origin.y, t.origin.x, t.origin.z, t.basis.x.length(), t.basis.y.length(), t.basis.z.length()])
	quit()