extends SceneTree
const MassingBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMassingBuilder.gd")
func _init():
	var size := Vector3(30.0, 12.0, 14.0)
	var visual := MassingBuilder.build({
		"name": "RowProbe", "building_id": "row_probe", "archetype_id": "row_house",
		"center": Vector3(0, size.y*0.5, 0), "size": size, "collision_size": size,
		"yaw_rad": 0.0, "main_color": Color(0.46,0.31,0.25), "accent_color": Color(0.62,0.58,0.51),
		"roof_color": Color(0.24,0.22,0.21), "glass_color": Color(0.05,0.06,0.07), "detail_seed": 99,
	})
	var boxes = visual.get("detail_boxes")
	print("BOXCOUNT ", boxes.count())
	for i in range(boxes.transforms.size()):
		var t: Transform3D = boxes.transforms[i]
		if t.origin.y > 5.0:
			print("  y=%.2f x=%.2f z=%.2f size=(%.2f,%.2f,%.2f) color=%s" % [t.origin.y, t.origin.x, t.origin.z, t.basis.x.length(), t.basis.y.length(), t.basis.z.length(), str(boxes.custom_data[i])])
	quit()