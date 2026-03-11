extends RefCounted

static func sample_height(world_x: float, world_z: float, world_seed: int) -> float:
	var ridge_scale_x := 2200.0 + float((world_seed >> 3) % 700)
	var ridge_scale_z := 1900.0 + float((world_seed >> 5) % 600)
	var basin_scale := 1100.0 + float((world_seed >> 7) % 300)
	var macro_a := sin(world_x / ridge_scale_x) * 7.2
	var macro_b := sin(world_z / ridge_scale_z) * 5.1
	var macro_c := sin((world_x + world_z) / basin_scale) * 2.4
	return macro_a + macro_b + macro_c

static func sample_world_point(world_x: float, world_z: float, world_seed: int) -> Vector3:
	return Vector3(world_x, sample_height(world_x, world_z, world_seed), world_z)
