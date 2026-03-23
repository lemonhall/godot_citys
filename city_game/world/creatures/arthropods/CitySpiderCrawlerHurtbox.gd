extends AnimatableBody3D

func _ready() -> void:
	add_to_group("city_enemy")

func apply_projectile_hit(projectile_damage: float, hit_position: Vector3, impulse: Vector3) -> Dictionary:
	var spider := _resolve_spider_owner()
	if spider == null or not spider.has_method("apply_projectile_hit"):
		return {}
	return spider.apply_projectile_hit(projectile_damage, hit_position, impulse)

func get_health_state() -> Dictionary:
	var spider := _resolve_spider_owner()
	if spider == null or not spider.has_method("get_health_state"):
		return {}
	return spider.get_health_state()

func _resolve_spider_owner() -> Node:
	var current: Node = get_parent()
	while current != null:
		if current.has_method("apply_projectile_hit") and current.has_method("get_health_state"):
			return current
		current = current.get_parent()
	return null
