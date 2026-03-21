extends RefCounted

const GROUND_HEIGHT_Y := 0.0

static func sample_height(_world_x: float, _world_z: float, _world_seed: int) -> float:
	return GROUND_HEIGHT_Y

static func sample_world_point(world_x: float, world_z: float, world_seed: int) -> Vector3:
	return Vector3(world_x, sample_height(world_x, world_z, world_seed), world_z)
