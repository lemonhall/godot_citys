extends RefCounted

static func sample_height(world_x: float, world_z: float, world_seed: int) -> float:
	var ridge_scale_x := 2200.0 + float((world_seed >> 3) % 700)
	var ridge_scale_z := 1900.0 + float((world_seed >> 5) % 600)
	var basin_scale := 1100.0 + float((world_seed >> 7) % 300)
	var hill_scale := 520.0 + float((world_seed >> 9) % 180)
	var terrace_scale := 860.0 + float((world_seed >> 11) % 220)
	var neighborhood_scale_x := 240.0 + float((world_seed >> 13) % 70)
	var neighborhood_scale_z := 280.0 + float((world_seed >> 15) % 80)
	var macro_a := sin(world_x / ridge_scale_x) * 11.5
	var macro_b := sin(world_z / ridge_scale_z) * 8.7
	var macro_c := sin((world_x + world_z) / basin_scale) * 4.2
	var hill := sin(world_x / hill_scale + float(world_seed & 255) * 0.012) * cos(world_z / (hill_scale * 1.18) + float((world_seed >> 4) & 255) * 0.009) * 5.8
	var terrace := sin((world_x * 0.62 - world_z * 0.28) / terrace_scale + float((world_seed >> 6) & 255) * 0.01) * 3.4
	var neighborhood := sin(world_x / neighborhood_scale_x + float((world_seed >> 2) & 255) * 0.019) * 5.6 + cos(world_z / neighborhood_scale_z + float((world_seed >> 8) & 255) * 0.017) * 4.8
	var local_ridge := sin((world_x * 0.78 + world_z * 0.22) / 190.0 + float((world_seed >> 10) & 255) * 0.013) * 3.0
	return macro_a + macro_b + macro_c + hill + terrace + neighborhood + local_ridge

static func sample_world_point(world_x: float, world_z: float, world_seed: int) -> Vector3:
	return Vector3(world_x, sample_height(world_x, world_z, world_seed), world_z)
