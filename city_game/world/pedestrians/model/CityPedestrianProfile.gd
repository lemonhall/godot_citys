extends RefCounted

var district_id := ""
var district_key := Vector2i.ZERO
var district_class := ""
var density_scalar := 0.0
var density_bucket := ""
var archetype_weights: Dictionary = {}
var profile_seed := 0

func setup(profile_data: Dictionary) -> void:
	district_id = str(profile_data.get("district_id", ""))
	district_key = profile_data.get("district_key", Vector2i.ZERO)
	district_class = str(profile_data.get("district_class", ""))
	density_scalar = float(profile_data.get("density_scalar", 0.0))
	density_bucket = str(profile_data.get("density_bucket", ""))
	archetype_weights = (profile_data.get("archetype_weights", {}) as Dictionary).duplicate(true)
	profile_seed = int(profile_data.get("profile_seed", 0))

func to_dictionary() -> Dictionary:
	return {
		"district_id": district_id,
		"district_key": district_key,
		"district_class": district_class,
		"density_scalar": density_scalar,
		"density_bucket": density_bucket,
		"archetype_weights": archetype_weights.duplicate(true),
		"profile_seed": profile_seed,
	}
