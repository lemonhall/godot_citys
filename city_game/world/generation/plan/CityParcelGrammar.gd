extends RefCounted

# Per-district parcel grammar: plot width, depth, frontage, courtyard chance
# and alley cadence. This is what makes old town lanes differ from CBD slabs.

static func config(district: String) -> Dictionary:
	match district:
		"oldtown":
			return {"width": Vector2(6.0, 12.0), "depth": Vector2(10.0, 16.0), "frontage_m": 5.0, "courtyard_chance": 0.45, "alley_every": 5, "alley_width_m": 4.5}
		"downtown":
			return {"width": Vector2(24.0, 40.0), "depth": Vector2(20.0, 32.0), "frontage_m": 6.0, "courtyard_chance": 0.05, "alley_every": 12, "alley_width_m": 6.0}
		"commercial":
			return {"width": Vector2(14.0, 26.0), "depth": Vector2(16.0, 24.0), "frontage_m": 6.0, "courtyard_chance": 0.12, "alley_every": 8, "alley_width_m": 5.0}
		"residential":
			return {"width": Vector2(10.0, 22.0), "depth": Vector2(12.0, 20.0), "frontage_m": 7.0, "courtyard_chance": 0.25, "alley_every": 6, "alley_width_m": 4.5}
		"industrial":
			return {"width": Vector2(30.0, 60.0), "depth": Vector2(24.0, 40.0), "frontage_m": 8.0, "courtyard_chance": 0.0, "alley_every": 10, "alley_width_m": 8.0}
		"waterfront":
			return {"width": Vector2(12.0, 24.0), "depth": Vector2(14.0, 22.0), "frontage_m": 8.0, "courtyard_chance": 0.10, "alley_every": 7, "alley_width_m": 5.0}
	return {"width": Vector2(14.0, 26.0), "depth": Vector2(16.0, 24.0), "frontage_m": 6.0, "courtyard_chance": 0.15, "alley_every": 8, "alley_width_m": 5.0}

static func era_for_district(district: String) -> String:
	match district:
		"oldtown":
			return "oldtown"
		"downtown":
			return "glass_cbd"
		"commercial":
			return "art_deco"
		"industrial":
			return "industrial"
	return "modern"
