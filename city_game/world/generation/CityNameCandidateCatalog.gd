extends RefCounted

const ROAD_ROOT_TARGET := 12000
const LANDMARK_TARGET := 4096

const ROAD_FRONT := [
	"Al", "Ash", "At", "Bel", "Br", "Cal", "Car", "Cor", "Del", "Dor",
	"Elm", "Fal", "Glen", "Har", "Jun", "Ken", "Lak", "Mar", "Nor", "Oak",
	"Park", "Quin", "Ros", "Silver", "Stone", "Sun", "Tim", "Val", "West", "Win",
]

const ROAD_MIDDLE := [
	"a", "e", "i", "o", "u", "ae", "ai", "ar", "ea", "el",
	"en", "er", "ia", "ie", "or", "ra",
]

const ROAD_TAIL := [
	"bar", "beck", "briar", "brook", "crest", "cross", "dale", "field", "ford", "gate",
	"grove", "haven", "hurst", "keep", "land", "mere", "mont", "moor", "point", "ridge",
	"run", "side", "spring", "stead", "stone", "ton", "vale", "view", "wall", "water",
]

const LANDMARK_FRONT := [
	"Arc", "Beacon", "Cedar", "Cobalt", "Echo", "Ember", "Ever", "Granite", "Harbor", "Ivory",
	"Jade", "Lumen", "Marble", "North", "Opal", "Palisade", "River", "Sol", "Summit", "Verdant",
]

const LANDMARK_MIDDLE := [
	"a", "e", "i", "o", "u", "ar", "el", "en", "ia", "or", "um", "iv", "on", "ea", "io", "ur",
]

const LANDMARK_TAIL := [
	"Atrium", "Center", "Commons", "Forum", "Gallery", "Gardens", "Hall", "Heights", "House", "Landing",
	"Market", "Outlook", "Pavilion", "Plaza", "Point", "Square",
]

func build_catalog(catalog_seed: int) -> Dictionary:
	var road_roots := _rotate_pool(_build_word_pool(ROAD_FRONT, ROAD_MIDDLE, ROAD_TAIL, ROAD_ROOT_TARGET), catalog_seed)
	var landmark_seed := int(float(catalog_seed) / 3.0) + 17
	var landmark_names := _rotate_pool(_build_word_pool(LANDMARK_FRONT, LANDMARK_MIDDLE, LANDMARK_TAIL, LANDMARK_TARGET), landmark_seed)
	return {
		"source_seed": catalog_seed,
		"road_name_root_pool": road_roots,
		"landmark_proper_name_pool": landmark_names,
	}

func _build_word_pool(front: Array, middle: Array, tail: Array, target_count: int) -> Array[String]:
	var seen: Dictionary = {}
	var pool: Array[String] = []
	for front_part_variant in front:
		var front_part := str(front_part_variant)
		for middle_part_variant in middle:
			var middle_part := str(middle_part_variant)
			for tail_part_variant in tail:
				var tail_part := str(tail_part_variant)
				var word := _sanitize_name("%s%s%s" % [front_part, middle_part, tail_part])
				if word == "" or seen.has(word):
					continue
				seen[word] = true
				pool.append(word)
				if pool.size() >= target_count:
					return pool
	return pool

func _rotate_pool(pool: Array[String], rotation_seed: int) -> Array[String]:
	if pool.is_empty():
		return []
	var rotated: Array[String] = pool.duplicate()
	var offset := int(posmod(rotation_seed, rotated.size()))
	if offset == 0:
		return rotated
	return rotated.slice(offset) + rotated.slice(0, offset)

func _sanitize_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned == "":
		return ""
	return cleaned[0].to_upper() + cleaned.substr(1).to_lower()
