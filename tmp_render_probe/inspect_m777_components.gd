extends SceneTree

func _init() -> void:
	var packed: PackedScene = load("res://city_game/assets/environment/source/artillery/m777/M 777.glb")
	var inst: Node3D = packed.instantiate() as Node3D
	var mesh_node := inst.get_child(0) as MeshInstance3D
	if mesh_node == null or mesh_node.mesh == null:
		push_error("mesh missing")
		quit(1)
		return
	var arrays := mesh_node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		indices.resize(verts.size())
		for i in range(verts.size()):
			indices[i] = i
	var vert_to_tris := {}
	for tri_idx in range(indices.size() / 3):
		for corner in 3:
			var vi: int = indices[tri_idx * 3 + corner]
			if not vert_to_tris.has(vi):
				vert_to_tris[vi] = PackedInt32Array()
			var arr: PackedInt32Array = vert_to_tris[vi]
			arr.append(tri_idx)
			vert_to_tris[vi] = arr
	var visited := PackedByteArray()
	visited.resize(indices.size() / 3)
	var components := []
	for start_tri in range(indices.size() / 3):
		if visited[start_tri] != 0:
			continue
		var queue := [start_tri]
		visited[start_tri] = 1
		var tri_count := 0
		var min_v := Vector3(INF, INF, INF)
		var max_v := Vector3(-INF, -INF, -INF)
		var unique_verts := {}
		while not queue.is_empty():
			var tri: int = queue.pop_back()
			tri_count += 1
			for corner in 3:
				var vi: int = indices[tri * 3 + corner]
				unique_verts[vi] = true
				var v := verts[vi]
				min_v = min_v.min(v)
				max_v = max_v.max(v)
				for next_tri in vert_to_tris[vi]:
					if visited[next_tri] == 0:
						visited[next_tri] = 1
						queue.append(next_tri)
		components.append({
			"triangles": tri_count,
			"vertices": unique_verts.size(),
			"min": min_v,
			"max": max_v,
			"size": max_v - min_v,
		})
	components.sort_custom(func(a, b): return a["triangles"] > b["triangles"])
	print("components=", components.size())
	for i in range(min(components.size(), 20)):
		var c = components[i]
		print(i, ": tris=", c["triangles"], " verts=", c["vertices"], " min=", c["min"], " max=", c["max"], " size=", c["size"])
	inst.free()
	quit()
