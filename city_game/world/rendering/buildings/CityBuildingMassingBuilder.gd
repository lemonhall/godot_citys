extends RefCounted

# v62 procedural building kit.
#
# Composes a cinematic city building out of:
#   - layered massing boxes (podium / shaft / setbacks / crown),
#   - a procedural facade shader (window bays, frames, spandrels, glass),
#   - a shared trim material driven by MultiMesh instance custom data,
#   - storefront glazing, canopy, signage, balconies, fins, cornices,
#   - rooftop equipment (mechanical rooms, tanks, vents, antennas, railings).
#
# Everything is deterministic from the building contract (size / archetype /
# detail_seed / colors). The kit never touches the old LEGO toy style.

const MeshBuilder := preload("res://city_game/world/rendering/buildings/CityBuildingMeshBuilder.gd")
const DetailBatch := preload("res://city_game/world/rendering/buildings/CityBuildingDetailBatch.gd")

const FACADE_SHADER := preload("res://city_game/world/rendering/buildings/CityBuildingFacade.gdshader")
const FacadeTextureAtlas := preload("res://city_game/world/rendering/buildings/CityFacadeTextureAtlas.gd")
const TRIM_SHADER := preload("res://city_game/world/rendering/buildings/CityBuildingTrim.gdshader")
const GLASS_SHADER := preload("res://city_game/world/rendering/buildings/CityBuildingGlass.gdshader")

const STYLE_PUNCHED := 0
const STYLE_RIBBON := 1
const STYLE_CURTAIN := 2
const STYLE_STONE := 3
const STYLE_BRICK := 4
const STYLE_RETAIL := 5
const STYLE_METAL := 6

const BASE_FLOOR_M := 4.6
const PARAPET_HEIGHT_M := 0.95
const PARAPET_THICKNESS_M := 0.30
const CORNICE_HEIGHT_M := 0.55
const CORNICE_OVERHANG_M := 0.48
const ROOF_CAP_THICKNESS_M := 0.12
const SKY_COLOR := Color(0.46, 0.60, 0.78, 1.0)

const SIGN_PALETTE := [
	Color(0.88, 0.20, 0.14),
	Color(0.95, 0.60, 0.10),
	Color(0.08, 0.62, 0.58),
	Color(0.82, 0.22, 0.52),
	Color(0.20, 0.44, 0.90),
	Color(0.92, 0.86, 0.72),
]

const AWNING_PALETTE := [
	Color(0.72, 0.16, 0.14),
	Color(0.16, 0.38, 0.62),
	Color(0.20, 0.48, 0.32),
	Color(0.86, 0.70, 0.30),
]

static var _unit_box_mesh: BoxMesh = null
static var _unit_cylinder_mesh: CylinderMesh = null
static var _trim_material: ShaderMaterial = null
static var _glass_material: ShaderMaterial = null
static var _detail_texture: ImageTexture = null

var _size := Vector3(18.0, 24.0, 18.0)
var _height := 24.0
var _half_w := 9.0
var _half_d := 9.0
var _detail_seed := 0
var _rng := RandomNumberGenerator.new()

var _wall_color := Color(0.55, 0.57, 0.59, 1.0)
var _trim_color := Color(0.26, 0.28, 0.30, 1.0)
var _roof_color := Color(0.32, 0.33, 0.35, 1.0)
var _metal_color := Color(0.20, 0.22, 0.24, 1.0)
var _stone_color := Color(0.62, 0.60, 0.56, 1.0)
var _glass_tint := Color(0.07, 0.11, 0.14, 1.0)
var _sign_color := Color(0.9, 0.3, 0.2, 1.0)
var _awning_color := Color(0.7, 0.2, 0.15, 1.0)

var _style := STYLE_PUNCHED
var _archetype := "mass"
var _bay_x := 3.2
var _bay_z := 3.2
var _bays_x := 5
var _bays_z := 5
var _floor_height := 3.6
var _floors := 6
var _base_top := 0.0
var _has_retail := false
var _lit_ratio := 0.28
var _grime := 0.45

var _facade: MeshBuilder
var _glass: MeshBuilder
var _boxes: DetailBatch
var _cylinders: DetailBatch
var _masses: Array = []

static func build(building: Dictionary) -> Dictionary:
	var kit := new()
	kit._setup(building)
	kit._compose()
	return kit._finish()

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func _setup(building: Dictionary) -> void:
	_size = building.get("size", Vector3(18.0, 24.0, 18.0))
	_height = maxf(_size.y, 8.0)
	_half_w = maxf(_size.x, 4.0) * 0.5
	_half_d = maxf(_size.z, 4.0) * 0.5
	_archetype = str(building.get("archetype_id", "mass"))
	_detail_seed = int(building.get("detail_seed", 0))
	if _detail_seed == 0:
		_detail_seed = abs(str(building.get("building_id", building.get("name", "building"))).hash())
	_rng.seed = _detail_seed

	_wall_color = building.get("main_color", _wall_color)
	_trim_color = building.get("accent_color", _trim_color)
	_roof_color = building.get("roof_color", _roof_color)
	if _roof_color.get_luminance() > 0.55:
		_roof_color = _roof_color.darkened(0.22)
	_metal_color = _trim_color.darkened(0.35)
	_stone_color = _wall_color.lightened(0.10)
	var glass_override = building.get("glass_color", null)
	if glass_override is Color:
		_glass_tint = glass_override
	else:
		_glass_tint = Color(0.075, 0.105, 0.135, 1.0).lerp(_wall_color.darkened(0.60), 0.30)
	_sign_color = SIGN_PALETTE[_rng.randi_range(0, SIGN_PALETTE.size() - 1)]
	_awning_color = AWNING_PALETTE[_rng.randi_range(0, AWNING_PALETTE.size() - 1)]
	_lit_ratio = _rng.randf_range(0.12, 0.38)
	_grime = _rng.randf_range(0.25, 0.70)

	# Window module: snap the bay and floor counts so the grid lands exactly on
	# the building corners and the roof line.
	_bays_x = clampi(int(round(_half_w * 2.0 / 3.2)), 2, 14)
	_bays_z = clampi(int(round(_half_d * 2.0 / 3.2)), 2, 14)
	_bay_x = (_half_w * 2.0) / float(_bays_x)
	_bay_z = (_half_d * 2.0) / float(_bays_z)
	_floors = clampi(int(round(_height / 3.6)), 3, 32)
	_floor_height = _height / float(_floors)

	_style = _resolve_style()
	_has_retail = _height >= 15.0 and _archetype != "industrial" and _archetype != "courtyard"
	_base_top = minf(BASE_FLOOR_M, _height * 0.30) if _has_retail else 0.0

	# Per-building tonal variation keeps a block of generated towers from
	# reading as one repeated material.
	var tone_shift := _rng.randf_range(-0.10, 0.10)
	_wall_color = _wall_color.lightened(tone_shift) if tone_shift > 0.0 else _wall_color.darkened(-tone_shift)
	var trim_shift := _rng.randf_range(-0.06, 0.06)
	_trim_color = _trim_color.lightened(trim_shift) if trim_shift > 0.0 else _trim_color.darkened(-trim_shift)

	_facade = MeshBuilder.new()
	_facade.configure(_bay_x, _bay_z, _floor_height, -_half_w, -_half_d, -_height * 0.5)
	_glass = MeshBuilder.new()
	_glass.configure(_bay_x, _bay_z, _floor_height, -_half_w, -_half_d, -_height * 0.5)
	_boxes = DetailBatch.new()
	_cylinders = DetailBatch.new()

func _resolve_style() -> int:
	match _archetype:
		"needle":
			return STYLE_CURTAIN
		"podium_tower":
			return STYLE_CURTAIN if _height > 44.0 else STYLE_RIBBON
		"slab":
			return STYLE_RIBBON if _rng.randf() < 0.65 else STYLE_STONE
		"step_midrise":
			return STYLE_STONE if _rng.randf() < 0.6 else STYLE_PUNCHED
		"courtyard":
			return STYLE_STONE if _rng.randf() < 0.5 else STYLE_BRICK
		"midrise_bar":
			return STYLE_PUNCHED if _rng.randf() < 0.55 else STYLE_BRICK
		"row_house":
			return STYLE_BRICK
		"residential_tower":
			return STYLE_PUNCHED if _rng.randf() < 0.70 else STYLE_BRICK
		"hotel_tower":
			return STYLE_STONE if _rng.randf() < 0.55 else STYLE_RIBBON
		"industrial":
			return STYLE_METAL
		_:
			return STYLE_PUNCHED if _rng.randf() < 0.6 else STYLE_RIBBON

# ---------------------------------------------------------------------------
# Composition
# ---------------------------------------------------------------------------

func _compose() -> void:
	match _archetype:
		"needle":
			_compose_needle()
		"podium_tower":
			_compose_podium_tower()
		"slab":
			_compose_slab()
		"step_midrise":
			_compose_step_midrise()
		"courtyard":
			_compose_courtyard()
		"midrise_bar":
			_compose_midrise_bar()
		"row_house":
			_compose_row_house()
		"residential_tower":
			_compose_residential_tower()
		"hotel_tower":
			_compose_hotel_tower()
		"industrial":
			_compose_industrial()
		_:
			_compose_generic()
	if _has_retail:
		_shopfront(0.0, 0.0, _half_w * 2.0, _half_d * 2.0, 0.0, _base_top, true)
		_entrance_steps(_half_w * 2.0, _half_d * 2.0, _base_top)
	_plaza()
	if _style == STYLE_PUNCHED or _style == STYLE_RIBBON or _style == STYLE_CURTAIN or _style == STYLE_STONE or _style == STYLE_BRICK:
		_facade_ledges()
	_parapet_cap(_half_w * 2.0, _half_d * 2.0, _height)
	if _archetype == "industrial" or _archetype == "row_house" or _archetype == "midrise_bar":
		_solar_panels(_half_w * 2.0, _half_d * 2.0, _height)

func _compose_needle() -> void:
	var podium_h := clampf(_height * 0.11, 7.0, 10.5)
	var podium_w := _half_w * 2.0
	var podium_d := _half_d * 2.0
	var shaft_w := _half_w * 2.0 * 0.84
	var shaft_d := _half_d * 2.0 * 0.84
	var crown_start := _height * 0.865

	_mass(0.0, 0.0, podium_w, podium_d, _base_top, podium_h)
	_roof_cap(0.0, 0.0, podium_w, podium_d, podium_h)
	_cornice(0.0, 0.0, podium_w, podium_d, podium_h, CORNICE_HEIGHT_M, 0.40, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, podium_w, podium_d, podium_h, 0.55, 0.24, _stone_color)

	var tiers := [
		[_height * 0.55, shaft_w, shaft_d],
		[_height * 0.72, shaft_w * 0.94, shaft_d * 0.94],
		[crown_start, shaft_w * 0.89, shaft_d * 0.89],
	]
	var tier_bottom := podium_h
	for tier in tiers:
		var tier_top: float = tier[0]
		var tier_w: float = tier[1]
		var tier_d: float = tier[2]
		_mass(0.0, 0.0, tier_w, tier_d, tier_bottom, tier_top)
		_roof_cap(0.0, 0.0, tier_w, tier_d, tier_top)
		_cornice(0.0, 0.0, tier_w, tier_d, tier_top, 0.45, 0.26, _stone_color.darkened(0.30))
		_terrace_railing(0.0, 0.0, tier_w, tier_d, tier_top)
		_corner_piers(0.0, 0.0, tier_w, tier_d, tier_bottom, tier_top, 0.62)
		tier_bottom = tier_top

	var crown_w := shaft_w * 0.84
	var crown_d := shaft_d * 0.84
	var crown_top := _height * 0.945
	_mass(0.0, 0.0, crown_w, crown_d, crown_start, crown_top)
	_roof_cap(0.0, 0.0, crown_w, crown_d, crown_top)
	_cornice(0.0, 0.0, crown_w, crown_d, crown_top, 0.40, 0.30, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, crown_w, crown_d, crown_top, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M, _metal_color)
	_crown_fins(crown_w, crown_d, crown_start, crown_top)
	_roof_equipment(crown_w * 0.22, crown_d * 0.22, crown_w * 0.45, crown_d * 0.45, crown_top + 0.1, false, 2)
	_mast(-crown_w * 0.30, -crown_d * 0.30, crown_top, clampf(_height * 0.16, 8.0, 22.0), true)
	_entrance_canopy(0.0, 0.0, podium_w * 0.8, podium_d, _base_top)

func _compose_podium_tower() -> void:
	var podium_h := clampf(_height * 0.16, 8.0, 12.0)
	var podium_w := _half_w * 2.0 * 1.34
	var podium_d := _half_d * 2.0 * 1.34
	var tower_w := _half_w * 2.0 * 0.74
	var tower_d := _half_d * 2.0 * 0.74

	_mass(0.0, 0.0, podium_w, podium_d, _base_top, podium_h)
	_roof_cap(0.0, 0.0, podium_w, podium_d, podium_h)
	_cornice(0.0, 0.0, podium_w, podium_d, podium_h, CORNICE_HEIGHT_M, 0.45, _stone_color)
	_parapet(0.0, 0.0, podium_w, podium_d, podium_h, 0.6, 0.26, _stone_color)
	_roof_equipment(podium_w * 0.34, 0.0, podium_w * 0.28, podium_d * 0.3, podium_h + 0.1, false, 1)

	var shaft_top := _height
	_mass(0.0, 0.0, tower_w, tower_d, podium_h, shaft_top)
	_roof_cap(0.0, 0.0, tower_w, tower_d, shaft_top)
	_side_fins(tower_w, tower_d, podium_h, shaft_top, 2)
	_cornice(0.0, 0.0, tower_w, tower_d, shaft_top, 0.40, 0.22, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, tower_w, tower_d, shaft_top, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M, _metal_color)
	_roof_equipment(tower_w * 0.16, tower_d * 0.16, tower_w * 0.5, tower_d * 0.5, shaft_top + 0.1, false, 2)
	_mast(-tower_w * 0.32, -tower_d * 0.32, shaft_top, clampf(_height * 0.10, 5.0, 12.0), false)
	_entrance_canopy(0.0, 0.0, podium_w * 0.75, podium_d, _base_top)

func _compose_slab() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	_mass(0.0, 0.0, w, d, _base_top, _height)
	_roof_cap(0.0, 0.0, w, d, _height)
	_cornice(0.0, 0.0, w, d, _height, CORNICE_HEIGHT_M + 0.15, CORNICE_OVERHANG_M, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w, d, _height, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M, _metal_color)
	_vertical_piers(w, d, _base_top, _height, 3)
	_roof_equipment(0.0, 0.0, w * 0.55, d * 0.5, _height + 0.1, false, 2)
	_entrance_canopy(0.0, 0.0, w * 0.8, d, _base_top)
	_vertical_sign(w, d, "east", _base_top + 6.0, 4.2, 2.2)

func _compose_step_midrise() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	# Modern mid-rise: one straight volume with a cornice and a roof parapet.
	_mass(0.0, 0.0, w, d, _base_top, _height)
	_roof_cap(0.0, 0.0, w, d, _height)
	_cornice(0.0, 0.0, w, d, _height, CORNICE_HEIGHT_M, 0.26, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w, d, _height, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M, _stone_color.darkened(0.06))
	_balcony_rows(w, d, _base_top + _floor_height * 0.6, _height - 2.0, 2)
	_roof_equipment(0.0, 0.0, w * 0.4, d * 0.4, _height + 0.1, true, 2)
	_entrance_canopy(0.0, 0.0, w * 0.8, d, _base_top)

func _compose_courtyard() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	var wing := minf(7.0, minf(w, d) * 0.24)
	var inner_w := w - wing * 2.0
	var inner_d := d - wing * 2.0

	# Perimeter wings, leaving a real courtyard in the middle.
	_mass(0.0, -(_half_d - wing * 0.5), w, wing, 0.0, _height)
	_mass(0.0, _half_d - wing * 0.5, w, wing, 0.0, _height)
	_mass(-(_half_w - wing * 0.5), 0.0, wing, inner_d, 0.0, _height)
	_mass(_half_w - wing * 0.5, 0.0, wing, inner_d, 0.0, _height)
	for block in [
		[0.0, -(_half_d - wing * 0.5), w, wing],
		[0.0, _half_d - wing * 0.5, w, wing],
		[- (_half_w - wing * 0.5), 0.0, wing, inner_d],
		[_half_w - wing * 0.5, 0.0, wing, inner_d],
	]:
		_roof_cap(block[0], block[1], block[2], block[3], _height)
		_cornice(block[0], block[1], block[2], block[3], _height, CORNICE_HEIGHT_M, 0.38, _stone_color)
	_parapet_ring_outer(w, d, _height, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M)

	# Courtyard floor, planters and fountain.
	_boxes.add_box(Vector3(0.0, _to_local_y(0.08), 0.0), Vector3(inner_w - 0.4, 0.16, inner_d - 0.4), _lin(_stone_color.darkened(0.12)))
	var planter_offsets := [
		Vector2(-inner_w * 0.28, -inner_d * 0.28),
		Vector2(inner_w * 0.28, -inner_d * 0.28),
		Vector2(-inner_w * 0.28, inner_d * 0.28),
		Vector2(inner_w * 0.28, inner_d * 0.28),
	]
	for offset in planter_offsets:
		var planter: Vector2 = offset
		_boxes.add_box(Vector3(planter.x, _to_local_y(0.45), planter.y), Vector3(1.8, 0.9, 1.8), _lin(_stone_color))
		_boxes.add_box(Vector3(planter.x, _to_local_y(1.25), planter.y), Vector3(1.5, 0.7, 1.5), _lin(Color(0.20, 0.42, 0.18)))
	_cylinders.add_cylinder(Vector3(0.0, _to_local_y(0.4), 0.0), 2.6, 0.8, _lin(_stone_color.lightened(0.05)))
	_cylinders.add_cylinder(Vector3(0.0, _to_local_y(1.2), 0.0), 0.45, 1.4, _lin(_stone_color.lightened(0.15)))

	# Roof terraces and access towers.
	_roof_equipment(-(_half_w - wing * 0.5), -(_half_d - wing * 0.5), wing * 0.6, wing * 0.6, _height + 0.1, false, 1)
	_roof_equipment(_half_w - wing * 0.5, _half_d - wing * 0.5, wing * 0.6, wing * 0.6, _height + 0.1, true, 1)
	_stair_tower(0.0, -(_half_d - wing * 0.5), _height, 4.2, 3.2, 5.0)

func _compose_midrise_bar() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	_mass(0.0, 0.0, w, d, _base_top, _height)
	_roof_cap(0.0, 0.0, w, d, _height)
	_cornice(0.0, 0.0, w, d, _height, CORNICE_HEIGHT_M, 0.40, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w, d, _height, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M, _metal_color)
	_balcony_rows(w, d, _base_top + _floor_height * 0.8, _height - 1.2, 2)
	_roof_equipment(0.0, 0.0, w * 0.45, d * 0.4, _height + 0.1, true, 3)
	_entrance_canopy(0.0, 0.0, w * 0.8, d, _base_top)
	_vertical_sign(w, d, "west", _base_top + 5.0, 3.6, 2.0)
	_shop_awnings(w, d)

func _compose_industrial() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	var hall_w := w * 0.72
	var hall_center_x := -w * 0.10
	var hall_h := _height * 0.78
	_mass(hall_center_x, 0.0, hall_w, d, 0.0, hall_h)
	_roof_cap(hall_center_x, 0.0, hall_w, d, hall_h)
	_sawtooth_roof(hall_center_x, 0.0, hall_w, d, hall_h)
	# Loading docks along +Z.
	var door_count := 3
	var door_spacing := hall_w / float(door_count)
	for index in range(door_count):
		var door_x := hall_center_x - hall_w * 0.5 + door_spacing * (float(index) + 0.5)
		_boxes.add_box(Vector3(door_x, _to_local_y(3.2), _half_d + 0.06), Vector3(4.6, 5.0, 0.24), _lin(_metal_color.darkened(0.2)))
		_boxes.add_box(Vector3(door_x, _to_local_y(5.85), _half_d + 0.05), Vector3(4.9, 0.35, 0.3), _lin(_metal_color))
		_boxes.add_box(Vector3(door_x, _to_local_y(0.35), _half_d + 0.9), Vector3(4.9, 0.7, 1.8), _lin(_stone_color.darkened(0.1)))
	_boxes.add_box(Vector3(hall_center_x, _to_local_y(6.4), _half_d + 1.4), Vector3(hall_w * 0.92, 0.32, 3.0), _lin(_metal_color.lightened(0.05)))
	_boxes.add_box(Vector3(hall_center_x, _to_local_y(3.0), _half_d + 2.75), Vector3(hall_w * 0.9, 0.2, 0.2), _lin(_metal_color))
	# Side office block.
	_mass(w * 0.34, 0.0, w * 0.30, d * 0.55, 0.0, _height * 0.52)
	_roof_cap(w * 0.34, 0.0, w * 0.30, d * 0.55, _height * 0.52)
	_cornice(w * 0.34, 0.0, w * 0.30, d * 0.55, _height * 0.52, 0.4, 0.3, _stone_color.darkened(0.30))
	_boxes.add_box(Vector3(w * 0.34, _to_local_y(_height * 0.52 + 1.2), 0.0), Vector3(3.0, 2.2, 2.2), _lin(_metal_color))
	# Chimney and tank silhouettes.
	var stack_height := _height * 0.9 + 8.0
	_cylinders.add_cylinder(Vector3(w * 0.30, _to_local_y(stack_height * 0.5), -d * 0.32), 0.9, stack_height, _lin(_metal_color.darkened(0.15)))
	_cylinders.add_cylinder(Vector3(hall_center_x - hall_w * 0.36, _to_local_y(3.0), -d * 0.38), 2.2, 6.0, _lin(_stone_color.darkened(0.05)))
	for index in range(3):
		_cylinders.add_cylinder(
			Vector3(hall_center_x - hall_w * 0.3 + float(index) * 3.4, _to_local_y(hall_h + 0.9), d * 0.22),
			0.42,
			1.8,
			_lin(_metal_color.lightened(0.1))
		)

func _compose_row_house() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	# Low brick residential block: flat roof with parapet, chimneys, awnings.
	_mass(0.0, 0.0, w, d, 0.0, _height)
	_roof_cap(0.0, 0.0, w, d, _height)
	_cornice(0.0, 0.0, w, d, _height, 0.42, 0.24, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w, d, _height, 0.70, 0.22, _wall_color.darkened(0.34))
	_boxes.add_box(Vector3(-w * 0.28, _to_local_y(_height + 1.6), -d * 0.24), Vector3(1.1, 3.2, 1.1), _lin(_wall_color.darkened(0.30)))
	_boxes.add_box(Vector3(w * 0.30, _to_local_y(_height + 1.2), d * 0.20), Vector3(0.9, 2.4, 0.9), _lin(_wall_color.darkened(0.32)))
	_cylinders.add_cylinder(Vector3(w * 0.14, _to_local_y(_height + 1.1), -d * 0.30), 0.9, 2.2, _lin(_metal_color))
	# Canvas awnings over the shopfronts.
	var awning_count := clampi(int(round(w / 6.5)), 2, 5)
	for index in range(awning_count):
		var x := lerpf(-w * 0.36, w * 0.36, float(index) / float(maxi(awning_count - 1, 1)))
		for sz in [-1.0, 1.0]:
			_boxes.add_box(Vector3(x, _to_local_y(3.3), sz * (d * 0.5 + 0.7)), Vector3(3.2, 0.14, 1.5), _lin(_awning_color))
			_boxes.add_box(Vector3(x, _to_local_y(2.5), sz * (d * 0.5 + 1.35)), Vector3(3.2, 0.45, 0.14), _lin(_awning_color.darkened(0.1)))
	_vertical_sign(w, d, "east", 3.4, 2.6, 1.5)

func _compose_residential_tower() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	# Straight residential slab block: no telescoping setback.
	_mass(0.0, 0.0, w, d, _base_top, _height)
	_roof_cap(0.0, 0.0, w, d, _height)
	_cornice(0.0, 0.0, w, d, _height, CORNICE_HEIGHT_M, 0.26, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w, d, _height, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M, _metal_color)
	_balcony_rows(w, d, _base_top + _floor_height * 0.8, _height - 2.4, 3)
	_balcony_strip_x(w, d, _base_top + _floor_height * 1.6, -1.0)
	_balcony_strip_x(w, d, _base_top + _floor_height * 2.8, 1.0)
	_roof_equipment(0.0, 0.0, w * 0.36, d * 0.36, _height + 0.1, true, 2)
	_mast(-w * 0.22, -d * 0.22, _height, 7.0, false)

func _compose_hotel_tower() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	var podium_h := clampf(_height * 0.14, 7.0, 10.0)
	_mass(0.0, 0.0, w * 1.12, d * 1.12, _base_top, podium_h)
	_roof_cap(0.0, 0.0, w * 1.12, d * 1.12, podium_h)
	_cornice(0.0, 0.0, w * 1.12, d * 1.12, podium_h, CORNICE_HEIGHT_M, 0.36, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w * 1.12, d * 1.12, podium_h, 0.6, 0.24, _stone_color.darkened(0.06))
	# Straight hotel shaft above the podium, with vertical ribs for scale.
	_mass(0.0, 0.0, w, d, podium_h, _height)
	_roof_cap(0.0, 0.0, w, d, _height)
	_vertical_ribs(w, d, podium_h, _height, 4.6)
	_cornice(0.0, 0.0, w, d, _height, 0.45, 0.28, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w, d, _height, 0.6, 0.22, _metal_color)
	_roof_equipment(0.0, 0.0, w * 0.3, d * 0.3, _height + 0.1, false, 2)
	_mast(0.0, 0.0, _height, clampf(_height * 0.14, 6.0, 16.0), true)
	_entrance_canopy(0.0, 0.0, w * 0.9, d * 1.12, _base_top)

func _compose_generic() -> void:
	var w := _half_w * 2.0
	var d := _half_d * 2.0
	_mass(0.0, 0.0, w, d, _base_top, _height)
	_roof_cap(0.0, 0.0, w, d, _height)
	_cornice(0.0, 0.0, w, d, _height, CORNICE_HEIGHT_M, CORNICE_OVERHANG_M, _stone_color.darkened(0.30))
	_parapet(0.0, 0.0, w, d, _height, PARAPET_HEIGHT_M, PARAPET_THICKNESS_M, _metal_color)
	_roof_equipment(0.0, 0.0, w * 0.55, d * 0.55, _height + 0.1, false, 2)
	_entrance_canopy(0.0, 0.0, w * 0.8, d, _base_top)

# ---------------------------------------------------------------------------
# Massing helpers (elevation arguments are measured from the ground)
# ---------------------------------------------------------------------------

func _plaza() -> void:
	var apron_w := _half_w * 2.0 + 6.0
	var apron_d := _half_d * 2.0 + 6.0
	var base_y := 0.045 + _rng.randf_range(0.0, 0.02)
	_boxes.add_box(
		Vector3(0.0, _to_local_y(base_y), 0.0),
		Vector3(apron_w, 0.09, apron_d),
		_lin(_stone_color.darkened(0.38))
	)
	_boxes.add_box(
		Vector3(0.0, _to_local_y(base_y + 0.02), 0.0),
		Vector3(apron_w + 0.5, 0.04, apron_d + 0.5),
		_lin(_stone_color.darkened(0.44))
	)

func _facade_ledges() -> void:
	# Real 3D facade grid: horizontal floor bands and vertical bay mullions.
	# They sit exactly on the shader's window-cell boundaries, so the geometry
	# and the procedural windows reinforce each other instead of fighting.
	var band_color := _metal_color.darkened(0.42)
	for mass_variant in _masses:
		var mass: Array = mass_variant
		var cx: float = mass[0]
		var cz: float = mass[1]
		var w: float = mass[2]
		var d: float = mass[3]
		var e0: float = mass[4]
		var e1: float = mass[5]
		var floor_count := int((e1 - e0) / _floor_height)
		var floor_step := 3 if floor_count <= 12 else 4
		var floor_index := floor_step
		while floor_index < floor_count:
			var e := e0 + float(floor_index) * _floor_height
			var thickness := 0.24
			var protrude := 0.15
			_boxes.add_box(Vector3(cx, _to_local_y(e), cz - d * 0.5 - protrude * 0.5), Vector3(w + protrude * 2.0, thickness, protrude), _lin(band_color))
			_boxes.add_box(Vector3(cx, _to_local_y(e), cz + d * 0.5 + protrude * 0.5), Vector3(w + protrude * 2.0, thickness, protrude), _lin(band_color))
			_boxes.add_box(Vector3(cx - w * 0.5 - protrude * 0.5, _to_local_y(e), cz), Vector3(protrude, thickness, d + protrude * 2.0), _lin(band_color))
			_boxes.add_box(Vector3(cx + w * 0.5 + protrude * 0.5, _to_local_y(e), cz), Vector3(protrude, thickness, d + protrude * 2.0), _lin(band_color))
			floor_index += floor_step

		# Vertical mullions every third bay on the two long faces.
		var bay_count := maxi(int(round(w / _bay_x)), 2)
		var bay_index := 3
		while bay_index < bay_count:
			var x := cx - w * 0.5 + float(bay_index) * _bay_x
			_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), cz - d * 0.5 - 0.06), Vector3(0.16, e1 - e0, 0.14), _lin(band_color))
			_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), cz + d * 0.5 + 0.06), Vector3(0.16, e1 - e0, 0.14), _lin(band_color))
			bay_index += 3
		var bay_count_z := maxi(int(round(d / _bay_z)), 2)
		var bay_index_z := 3
		while bay_index_z < bay_count_z:
			var z := cz - d * 0.5 + float(bay_index_z) * _bay_z
			_boxes.add_box(Vector3(cx - w * 0.5 - 0.06, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.14, e1 - e0, 0.16), _lin(band_color))
			_boxes.add_box(Vector3(cx + w * 0.5 + 0.06, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.14, e1 - e0, 0.16), _lin(band_color))
			bay_index_z += 3

func _to_local_y(elevation: float) -> float:
	return -_height * 0.5 + elevation

func _ao(elevation: float) -> float:
	var normalized := clampf(elevation / maxf(_height, 1.0), 0.0, 1.0)
	var ao := lerpf(0.60, 1.0, pow(normalized, 0.62))
	ao *= lerpf(0.82, 1.0, clampf(elevation / 6.0, 0.0, 1.0))
	return clampf(ao, 0.0, 1.0)

func _mass(cx: float, cz: float, w: float, d: float, e0: float, e1: float) -> void:
	var span := e1 - e0
	if span <= 0.05:
		return
	_facade.add_box_sides(
		Vector3(cx, _to_local_y((e0 + e1) * 0.5), cz),
		Vector3(w, span, d),
		_ao(e0),
		_ao(e1)
	)
	_masses.append([cx, cz, w, d, e0, e1])

func _roof_cap(cx: float, cz: float, w: float, d: float, e: float) -> void:
	_boxes.add_box(
		Vector3(cx, _to_local_y(e - ROOF_CAP_THICKNESS_M * 0.5), cz),
		Vector3(maxf(w - 0.06, 0.2), ROOF_CAP_THICKNESS_M, maxf(d - 0.06, 0.2)),
		_lin(_roof_color)
	)

func _entrance_steps(w: float, d: float, e: float) -> void:
	var step_color := _stone_color.darkened(0.18)
	for index in range(3):
		var step_depth := 0.42
		var step_w := w * 0.46 + float(index) * 0.5
		_boxes.add_box(
			Vector3(0.0, _to_local_y(e + 0.07 + float(index) * 0.14), d * 0.5 + 0.55 + float(index) * step_depth),
			Vector3(step_w, 0.14, step_depth),
			_lin(step_color)
		)
	for side: float in [-1.0, 1.0]:
		var planter_x: float = side * (w * 0.32)
		_boxes.add_box(Vector3(planter_x, _to_local_y(e + 0.30), d * 0.5 + 0.85), Vector3(1.7, 0.60, 0.70), _lin(_stone_color.darkened(0.05)))
		_boxes.add_box(Vector3(planter_x, _to_local_y(e + 0.70), d * 0.5 + 0.85), Vector3(1.50, 0.36, 0.55), _lin(Color(0.10, 0.20, 0.09)))
	for index in range(4):
		var bollard_x := lerpf(-w * 0.40, w * 0.40, float(index) / 3.0)
		_cylinders.add_cylinder(Vector3(bollard_x, _to_local_y(e + 0.45), d * 0.5 + 1.55), 0.09, 0.9, _lin(_metal_color.darkened(0.10)))

func _corner_pilasters(w: float, d: float, e0: float, e1: float) -> void:
	var thickness := 0.55
	var color := _stone_color.darkened(0.06)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var x: float = sx * (w * 0.5 - thickness * 0.5)
			var z: float = sz * (d * 0.5 - thickness * 0.5)
			_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), z), Vector3(thickness, e1 - e0, thickness), _lin(color))
			_boxes.add_box(Vector3(x, _to_local_y(e1 + 0.15), z), Vector3(thickness + 0.22, 0.30, thickness + 0.22), _lin(color.darkened(0.22)))

func _parapet_cap(w: float, d: float, e: float) -> void:
	var cap_y := e + PARAPET_HEIGHT_M + 0.05
	var cap_color := _metal_color.lightened(0.18)
	_boxes.add_box(Vector3(0.0, _to_local_y(cap_y), -d * 0.5 + 0.06), Vector3(w + 0.10, 0.10, 0.28), _lin(cap_color))
	_boxes.add_box(Vector3(0.0, _to_local_y(cap_y), d * 0.5 - 0.06), Vector3(w + 0.10, 0.10, 0.28), _lin(cap_color))
	_boxes.add_box(Vector3(-w * 0.5 + 0.06, _to_local_y(cap_y), 0.0), Vector3(0.28, 0.10, d), _lin(cap_color))
	_boxes.add_box(Vector3(w * 0.5 - 0.06, _to_local_y(cap_y), 0.0), Vector3(0.28, 0.10, d), _lin(cap_color))

func _solar_panels(w: float, d: float, e: float) -> void:
	var panel_color := Color(0.07, 0.09, 0.13)
	for index in range(3):
		var panel_x := lerpf(-w * 0.26, w * 0.26, float(index) / 2.0)
		_boxes.add_box(Vector3(panel_x, _to_local_y(e + 0.32), 0.0), Vector3(w * 0.18, 0.10, d * 0.34), _lin(panel_color))

func _cornice(cx: float, cz: float, w: float, d: float, e: float, thickness: float, overhang: float, color: Color) -> void:
	# A projecting band must be a ring, not a slab, or it becomes a fake roof
	# plate that hides the actual roof cap below it.
	var outer_w := w + overhang * 2.0
	var outer_d := d + overhang * 2.0
	var ring := maxf(overhang + 0.35, 0.5)
	var center_y := _to_local_y(e + thickness * 0.5)
	_boxes.add_box(Vector3(cx, center_y, cz - (outer_d - ring) * 0.5), Vector3(outer_w, thickness, ring), _lin(color))
	_boxes.add_box(Vector3(cx, center_y, cz + (outer_d - ring) * 0.5), Vector3(outer_w, thickness, ring), _lin(color))
	_boxes.add_box(Vector3(cx - (outer_w - ring) * 0.5, center_y, cz), Vector3(ring, thickness, outer_d - ring * 2.0), _lin(color))
	_boxes.add_box(Vector3(cx + (outer_w - ring) * 0.5, center_y, cz), Vector3(ring, thickness, outer_d - ring * 2.0), _lin(color))

func _terrace_railing(cx: float, cz: float, w: float, d: float, e: float) -> void:
	# Glass balustrade around an exposed setback terrace. Without it the slab
	# edge reads as a bare floating floor plate.
	var height := 0.90
	var inset := 0.10
	var panel := 0.05
	var tint := Color(0.34, 0.46, 0.52)
	_glass.add_box(Vector3(cx, _to_local_y(e + height * 0.5), cz - d * 0.5 + inset), Vector3(w - inset * 2.0, height, panel), _lin_glass(tint))
	_glass.add_box(Vector3(cx, _to_local_y(e + height * 0.5), cz + d * 0.5 - inset), Vector3(w - inset * 2.0, height, panel), _lin_glass(tint))
	_glass.add_box(Vector3(cx - w * 0.5 + inset, _to_local_y(e + height * 0.5), cz), Vector3(panel, height, d - inset * 2.0), _lin_glass(tint))
	_glass.add_box(Vector3(cx + w * 0.5 - inset, _to_local_y(e + height * 0.5), cz), Vector3(panel, height, d - inset * 2.0), _lin_glass(tint))
	var rail := 0.08
	_boxes.add_box(Vector3(cx, _to_local_y(e + height + rail * 0.5), cz - d * 0.5 + inset), Vector3(w - inset * 2.0, rail, rail * 1.6), _lin(_metal_color))
	_boxes.add_box(Vector3(cx, _to_local_y(e + height + rail * 0.5), cz + d * 0.5 - inset), Vector3(w - inset * 2.0, rail, rail * 1.6), _lin(_metal_color))
	_boxes.add_box(Vector3(cx - w * 0.5 + inset, _to_local_y(e + height + rail * 0.5), cz), Vector3(rail * 1.6, rail, d - inset * 2.0), _lin(_metal_color))
	_boxes.add_box(Vector3(cx + w * 0.5 - inset, _to_local_y(e + height + rail * 0.5), cz), Vector3(rail * 1.6, rail, d - inset * 2.0), _lin(_metal_color))

func _parapet(cx: float, cz: float, w: float, d: float, e: float, height: float, thickness: float, color: Color) -> void:
	var inner_w := maxf(w - thickness, 0.2)
	var inner_d := maxf(d - thickness, 0.2)
	_boxes.add_box(Vector3(cx, _to_local_y(e + height * 0.5), cz - (d - thickness) * 0.5), Vector3(w, height, thickness), _lin(color))
	_boxes.add_box(Vector3(cx, _to_local_y(e + height * 0.5), cz + (d - thickness) * 0.5), Vector3(w, height, thickness), _lin(color))
	_boxes.add_box(Vector3(cx - (w - thickness) * 0.5, _to_local_y(e + height * 0.5), cz), Vector3(thickness, height, inner_d), _lin(color))
	_boxes.add_box(Vector3(cx + (w - thickness) * 0.5, _to_local_y(e + height * 0.5), cz), Vector3(thickness, height, inner_d), _lin(color))

func _parapet_ring_outer(w: float, d: float, e: float, height: float, thickness: float) -> void:
	_parapet(0.0, 0.0, w, d, e, height, thickness, _stone_color.darkened(0.06))
	_parapet(0.0, 0.0, w - thickness * 2.0, d - thickness * 2.0, e, height, thickness, _stone_color.darkened(0.06))

func _railing(cx: float, cz: float, w: float, d: float, e: float, height: float, color: Color) -> void:
	var rail_thickness := 0.08
	_boxes.add_box(Vector3(cx, _to_local_y(e + height), cz - d * 0.5), Vector3(w, rail_thickness, rail_thickness), _lin(color))
	_boxes.add_box(Vector3(cx, _to_local_y(e + height), cz + d * 0.5), Vector3(w, rail_thickness, rail_thickness), _lin(color))
	_boxes.add_box(Vector3(cx - w * 0.5, _to_local_y(e + height), cz), Vector3(rail_thickness, rail_thickness, d), _lin(color))
	_boxes.add_box(Vector3(cx + w * 0.5, _to_local_y(e + height), cz), Vector3(rail_thickness, rail_thickness, d), _lin(color))
	var posts_x := clampi(int(round(w / 2.4)), 2, 5)
	var posts_z := clampi(int(round(d / 2.4)), 2, 5)
	for index in range(posts_x):
		var x := lerpf(cx - w * 0.5, cx + w * 0.5, float(index) / float(maxi(posts_x - 1, 1)))
		_boxes.add_box(Vector3(x, _to_local_y(e + height * 0.5), cz - d * 0.5), Vector3(0.07, height, 0.07), _lin(color))
		_boxes.add_box(Vector3(x, _to_local_y(e + height * 0.5), cz + d * 0.5), Vector3(0.07, height, 0.07), _lin(color))
	for index in range(posts_z):
		var z := lerpf(cz - d * 0.5, cz + d * 0.5, float(index) / float(maxi(posts_z - 1, 1)))
		_boxes.add_box(Vector3(cx - w * 0.5, _to_local_y(e + height * 0.5), z), Vector3(0.07, height, 0.07), _lin(color))
		_boxes.add_box(Vector3(cx + w * 0.5, _to_local_y(e + height * 0.5), z), Vector3(0.07, height, 0.07), _lin(color))

func _corner_piers(cx: float, cz: float, w: float, d: float, e0: float, e1: float, thickness: float) -> void:
	var inset := thickness * 0.5 - 0.12
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_boxes.add_box(
				Vector3(cx + sx * (w * 0.5 - inset), _to_local_y((e0 + e1) * 0.5), cz + sz * (d * 0.5 - inset)),
				Vector3(thickness, e1 - e0, thickness),
				_lin(_wall_color.darkened(0.14))
			)

func _vertical_piers(w: float, d: float, e0: float, e1: float, count: int) -> void:
	for index in range(count):
		var x := lerpf(-w * 0.5 + 2.1, w * 0.5 - 2.1, float(index) / float(maxi(count - 1, 1)))
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), -d * 0.5 - 0.18), Vector3(0.75, e1 - e0, 0.55), _lin(_wall_color.darkened(0.10)))
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), d * 0.5 + 0.18), Vector3(0.75, e1 - e0, 0.55), _lin(_wall_color.darkened(0.10)))
	for index in range(2):
		var z := lerpf(-d * 0.5 + 2.4, d * 0.5 - 2.4, float(index))
		_boxes.add_box(Vector3(-w * 0.5 - 0.18, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.55, e1 - e0, 0.75), _lin(_wall_color.darkened(0.10)))
		_boxes.add_box(Vector3(w * 0.5 + 0.18, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.55, e1 - e0, 0.75), _lin(_wall_color.darkened(0.10)))

func _side_fins(w: float, d: float, e0: float, e1: float, count: int) -> void:
	for index in range(count):
		var x := lerpf(-w * 0.32, w * 0.32, float(index) / float(maxi(count - 1, 1)))
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), -d * 0.5 - 0.30), Vector3(0.42, e1 - e0, 0.62), _lin(_metal_color))
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), d * 0.5 + 0.30), Vector3(0.42, e1 - e0, 0.62), _lin(_metal_color))

func _crown_fins(w: float, d: float, e0: float, e1: float) -> void:
	var count := 4
	for index in range(count):
		var x := lerpf(-w * 0.5 + 0.6, w * 0.5 - 0.6, float(index) / float(maxi(count - 1, 1)))
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), -d * 0.5 - 0.24), Vector3(0.36, e1 - e0, 0.5), _lin(_metal_color))
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), d * 0.5 + 0.24), Vector3(0.36, e1 - e0, 0.5), _lin(_metal_color))
	for index in range(count):
		var z := lerpf(-d * 0.5 + 0.6, d * 0.5 - 0.6, float(index) / float(maxi(count - 1, 1)))
		_boxes.add_box(Vector3(-w * 0.5 - 0.24, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.5, e1 - e0, 0.36), _lin(_metal_color))
		_boxes.add_box(Vector3(w * 0.5 + 0.24, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.5, e1 - e0, 0.36), _lin(_metal_color))

# ---------------------------------------------------------------------------
# Ground floor
# ---------------------------------------------------------------------------

func _shopfront(cx: float, cz: float, w: float, d: float, e0: float, e1: float, with_sign: bool) -> void:
	var inset := 0.55
	var glass_w := maxf(w - inset * 2.0, 0.5)
	var glass_d := maxf(d - inset * 2.0, 0.5)
	var base_height := 0.95
	_glass.add_box(
		Vector3(cx, _to_local_y((e0 + base_height + e1) * 0.5), cz),
		Vector3(glass_w, maxf(e1 - e0 - base_height - 0.15, 0.8), glass_d),
		_lin_glass(_glass_tint)
	)
	# Solid stone base under the glazing.
	_boxes.add_box(Vector3(cx, _to_local_y(e0 + base_height * 0.5), cz), Vector3(glass_w + 0.2, base_height, glass_d + 0.2), _lin(_stone_color.darkened(0.10)))
	# Storefront mullions and transom on the two long faces.
	var mullions := clampi(int(round(w / _bay_x * 0.5)), 3, 6)
	var glass_bottom := e0 + base_height
	var glass_top := e1 - 0.15
	for index in range(mullions + 1):
		var x := lerpf(cx - glass_w * 0.5, cx + glass_w * 0.5, float(index) / float(maxi(mullions, 1)))
		_boxes.add_box(Vector3(x, _to_local_y((glass_bottom + glass_top) * 0.5), cz + glass_d * 0.5 + 0.04), Vector3(0.14, glass_top - glass_bottom, 0.12), _lin(_metal_color))
		_boxes.add_box(Vector3(x, _to_local_y((glass_bottom + glass_top) * 0.5), cz - glass_d * 0.5 - 0.04), Vector3(0.14, glass_top - glass_bottom, 0.12), _lin(_metal_color))
	for sz in [-1.0, 1.0]:
		_boxes.add_box(
			Vector3(cx, _to_local_y(glass_bottom + 1.55), cz + sz * (glass_d * 0.5 + 0.05)),
			Vector3(glass_w, 0.16, 0.12),
			_lin(_metal_color)
		)
	# Fascia band above the glazing.
	_boxes.add_box(Vector3(cx, _to_local_y(e1 + 0.28), cz), Vector3(w + 0.1, 0.56, d + 0.1), _lin(_trim_color))
	# Entrance doors on both long faces.
	for sz in [-1.0, 1.0]:
		_boxes.add_box(
			Vector3(cx, _to_local_y((glass_bottom + e1) * 0.5 - 0.15), cz + sz * (glass_d * 0.5 + 0.06)),
			Vector3(minf(3.2, glass_w * 0.28), maxf(e1 - glass_bottom - 0.4, 1.4), 0.16),
			_lin(Color(0.05, 0.06, 0.07))
		)
		_boxes.add_box(
			Vector3(cx, _to_local_y(e1 - 0.35), cz + sz * (glass_d * 0.5 + 0.14)),
			Vector3(minf(3.6, glass_w * 0.32), 0.18, 0.22),
			_lin(_metal_color)
		)
	if with_sign:
		_boxes.add_box(Vector3(cx, _to_local_y(e1 + 0.43), cz + d * 0.5 + 0.12), Vector3(minf(w * 0.5, 9.0), 0.34, 0.16), _lin(_sign_color), 1.0)
		_boxes.add_box(Vector3(cx, _to_local_y(e1 + 0.43), cz - d * 0.5 - 0.12), Vector3(minf(w * 0.4, 7.0), 0.26, 0.16), _lin(_sign_color.lightened(0.1)), 1.0)

func _entrance_canopy(cx: float, cz: float, w: float, d: float, e: float) -> void:
	var depth := 2.6
	for sz in [-1.0, 1.0]:
		_boxes.add_box(
			Vector3(cx, _to_local_y(e + 0.16), cz + sz * (d * 0.5 + depth * 0.5 - 0.2)),
			Vector3(w * 0.62, 0.32, depth),
			_lin(_metal_color.lightened(0.08))
		)
		var post_x := w * 0.28
		for sx in [-1.0, 1.0]:
			_boxes.add_box(
				Vector3(cx + sx * post_x, _to_local_y(e * 0.5 + 0.2), cz + sz * (d * 0.5 + depth - 0.45)),
				Vector3(0.22, e, 0.22),
				_lin(_metal_color)
			)

func _shop_awnings(w: float, d: float) -> void:
	var count := clampi(int(round(w / 6.0)), 2, 4)
	for index in range(count):
		var x := lerpf(-w * 0.32, w * 0.32, float(index) / float(maxi(count - 1, 1)))
		for sz in [-1.0, 1.0]:
			_boxes.add_box(Vector3(x, _to_local_y(_base_top + 0.55), sz * (d * 0.5 + 0.65)), Vector3(3.4, 0.16, 1.5), _lin(_awning_color))
			_boxes.add_box(Vector3(x, _to_local_y(_base_top - 0.35), sz * (d * 0.5 + 1.30)), Vector3(3.4, 0.5, 0.16), _lin(_awning_color.darkened(0.1)))

func _vertical_sign(w: float, d: float, side: String, e: float, height: float, width: float) -> void:
	var center := Vector3.ZERO
	var normal := Vector3.ZERO
	if side == "east":
		center = Vector3(w * 0.5 + 0.42, 0.0, 0.0)
		normal = Vector3(1.0, 0.0, 0.0)
	elif side == "west":
		center = Vector3(-w * 0.5 - 0.42, 0.0, 0.0)
		normal = Vector3(-1.0, 0.0, 0.0)
	elif side == "north":
		center = Vector3(0.0, 0.0, -d * 0.5 - 0.42)
		normal = Vector3(0.0, 0.0, -1.0)
	else:
		center = Vector3(0.0, 0.0, d * 0.5 + 0.42)
		normal = Vector3(0.0, 0.0, 1.0)
	var frame_size := Vector3(width, height, 0.30)
	if absf(normal.x) > 0.5:
		frame_size = Vector3(0.30, height, width)
	_boxes.add_box(Vector3(center.x, _to_local_y(e + height * 0.5), center.z), frame_size, _lin(_metal_color.darkened(0.15)))
	var panel_size := Vector3(width * 0.72, height * 0.9, 0.06)
	if absf(normal.x) > 0.5:
		panel_size = Vector3(0.06, height * 0.9, width * 0.72)
	_boxes.add_box(
		Vector3(center.x, _to_local_y(e + height * 0.5), center.z) + normal * 0.18,
		panel_size,
		_lin(_sign_color),
		1.0
	)

# ---------------------------------------------------------------------------
# Balconies and roof equipment
# ---------------------------------------------------------------------------

func _balcony_rows(w: float, d: float, e_start: float, e_end: float, rows: int) -> void:
	if e_end <= e_start:
		return
	for row in range(rows):
		var t := float(row) / float(maxi(rows - 1, 1))
		var e := lerpf(e_start, e_end, t)
		for sz in [-1.0, 1.0]:
			_balcony_strip(w, d, e, sz)

func _balcony_strip(w: float, d: float, e: float, sz: float) -> void:
	var count := clampi(int(round(w / 4.6)), 2, 4)
	var depth := 1.45
	var slab_y := _to_local_y(e)
	for index in range(count):
		var x := lerpf(-w * 0.34, w * 0.34, float(index) / float(maxi(count - 1, 1)))
		_boxes.add_box(Vector3(x, slab_y, sz * (d * 0.5 + depth * 0.5 - 0.05)), Vector3(2.8, 0.22, depth), _lin(_wall_color.darkened(0.34)))
		_boxes.add_box(Vector3(x, slab_y + 0.62, sz * (d * 0.5 + depth - 0.12)), Vector3(2.8, 0.92, 0.07), _lin(Color(0.12, 0.16, 0.19)), 0.0)
		_boxes.add_box(Vector3(x, slab_y + 1.12, sz * (d * 0.5 + depth - 0.12)), Vector3(2.9, 0.08, 0.13), _lin(_metal_color))

func _balcony_strip_x(w: float, d: float, e: float, sx: float) -> void:
	var count := clampi(int(round(d / 4.6)), 2, 4)
	var depth := 1.45
	var slab_y := _to_local_y(e)
	for index in range(count):
		var z := lerpf(-d * 0.34, d * 0.34, float(index) / float(maxi(count - 1, 1)))
		_boxes.add_box(Vector3(sx * (w * 0.5 + depth * 0.5 - 0.05), slab_y, z), Vector3(depth, 0.22, 2.8), _lin(_wall_color.darkened(0.34)))
		_boxes.add_box(Vector3(sx * (w * 0.5 + depth - 0.12), slab_y + 0.62, z), Vector3(0.07, 0.92, 2.8), _lin(Color(0.12, 0.16, 0.19)))
		_boxes.add_box(Vector3(sx * (w * 0.5 + depth - 0.12), slab_y + 1.12, z), Vector3(0.13, 0.08, 2.9), _lin(_metal_color))

func _vertical_ribs(w: float, d: float, e0: float, e1: float, spacing: float) -> void:
	var count_x := maxi(int(round(w / spacing)), 2)
	var count_z := maxi(int(round(d / spacing)), 2)
	var rib_color := _stone_color.darkened(0.12)
	var height := e1 - e0
	for index in range(1, count_x):
		var x := -w * 0.5 + w * float(index) / float(count_x)
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), -d * 0.5 - 0.16), Vector3(0.32, height, 0.34), _lin(rib_color))
		_boxes.add_box(Vector3(x, _to_local_y((e0 + e1) * 0.5), d * 0.5 + 0.16), Vector3(0.32, height, 0.34), _lin(rib_color))
	for index in range(1, count_z):
		var z := -d * 0.5 + d * float(index) / float(count_z)
		_boxes.add_box(Vector3(-w * 0.5 - 0.16, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.34, height, 0.32), _lin(rib_color))
		_boxes.add_box(Vector3(w * 0.5 + 0.16, _to_local_y((e0 + e1) * 0.5), z), Vector3(0.34, height, 0.32), _lin(rib_color))

func _roof_equipment(cx: float, cz: float, w: float, d: float, e: float, residential: bool, budget: int) -> void:
	_stair_tower(cx, cz, e, 4.4, 3.4, 5.2)
	var hvac_count := clampi(budget, 1, 3)
	for index in range(hvac_count):
		var offset_x := _rng.randf_range(-w * 0.30, w * 0.30)
		var offset_z := _rng.randf_range(-d * 0.30, d * 0.30)
		var size := Vector3(_rng.randf_range(2.4, 4.6), _rng.randf_range(1.0, 2.2), _rng.randf_range(2.0, 3.8))
		_boxes.add_box(
			Vector3(cx + offset_x, _to_local_y(e + size.y * 0.5), cz + offset_z),
			size,
			_lin(_metal_color.lightened(0.12))
		)
		_cylinders.add_cylinder(
			Vector3(cx + offset_x + 0.8, _to_local_y(e + size.y + 0.45), cz + offset_z),
			0.22,
			0.9,
			_lin(_metal_color.darkened(0.1))
		)
	if residential:
		var tank_x := cx + _rng.randf_range(-w * 0.28, w * 0.28)
		var tank_z := cz + _rng.randf_range(-d * 0.28, d * 0.28)
		_cylinders.add_cylinder(Vector3(tank_x, _to_local_y(e + 2.6), tank_z), 2.0, 3.8, _lin(_stone_color.darkened(0.10)))
		_cylinders.add_cylinder(Vector3(tank_x, _to_local_y(e + 4.65), tank_z), 2.15, 0.28, _lin(_metal_color))
		for leg in [Vector2(-1.3, -1.3), Vector2(1.3, -1.3), Vector2(-1.3, 1.3), Vector2(1.3, 1.3)]:
			_boxes.add_box(Vector3(tank_x + leg.x, _to_local_y(e + 0.55), tank_z + leg.y), Vector3(0.18, 1.1, 0.18), _lin(_metal_color))

func _stair_tower(cx: float, cz: float, e: float, w: float, d: float, h: float) -> void:
	_boxes.add_box(Vector3(cx, _to_local_y(e + h * 0.5), cz), Vector3(w, h, d), _lin(_wall_color.darkened(0.06)))
	_boxes.add_box(Vector3(cx, _to_local_y(e + h + 0.10), cz), Vector3(w + 0.24, 0.2, d + 0.24), _lin(_metal_color))
	_boxes.add_box(Vector3(cx, _to_local_y(e + 1.05), cz + d * 0.5 + 0.03), Vector3(1.1, 2.1, 0.12), _lin(_metal_color.darkened(0.2)))

func _mast(cx: float, cz: float, e: float, height: float, wide_base: bool) -> void:
	if wide_base:
		_boxes.add_box(Vector3(cx, _to_local_y(e + 0.6), cz), Vector3(1.6, 1.2, 1.6), _lin(_metal_color))
	_boxes.add_box(Vector3(cx, _to_local_y(e + height * 0.5), cz), Vector3(0.24, height, 0.24), _lin(_metal_color.lightened(0.1)))
	_boxes.add_box(Vector3(cx, _to_local_y(e + height * 0.72), cz), Vector3(1.5, 0.12, 0.12), _lin(_metal_color))
	_boxes.add_box(Vector3(cx, _to_local_y(e + height + 0.18), cz), Vector3(0.32, 0.36, 0.32), _lin(Color(0.85, 0.12, 0.08)), 1.0)

func _sawtooth_roof(cx: float, cz: float, w: float, d: float, e: float) -> void:
	var teeth := clampi(int(round(w / 7.5)), 3, 6)
	var tooth_w := w / float(teeth)
	var rise := minf(2.4, tooth_w * 0.45)
	for index in range(teeth):
		var x := cx - w * 0.5 + tooth_w * (float(index) + 0.5)
		# Sloped glazed slab.
		var basis := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(-32.0))
		_boxes.add_oriented_box(
			Vector3(x, _to_local_y(e + rise * 0.5), cz),
			Vector3(tooth_w * 1.04, 0.18, d * 0.92),
			basis,
			_lin(Color(0.30, 0.38, 0.42)),
			0.0
		)
		# Vertical riser with a clerestory strip.
		_boxes.add_box(Vector3(x - tooth_w * 0.5, _to_local_y(e + rise * 0.5), cz), Vector3(0.22, rise, d * 0.92), _lin(_metal_color))
		_boxes.add_box(Vector3(x - tooth_w * 0.5, _to_local_y(e + rise - 0.35), cz), Vector3(0.26, 0.5, d * 0.8), _lin(Color(0.24, 0.34, 0.40)), 0.0)

# ---------------------------------------------------------------------------
# Finish
# ---------------------------------------------------------------------------

func _finish() -> Dictionary:
	var facade_material := _build_facade_material()
	var facade_mesh: ArrayMesh = _facade.commit(facade_material)
	var glass_mesh: ArrayMesh = _glass.commit(_shared_glass_material())
	return {
		"facade_mesh": facade_mesh,
		"facade_material": facade_material,
		"glass_mesh": glass_mesh,
		"detail_boxes": _boxes,
		"detail_cylinders": _cylinders,
		"triangle_count": (
			(_facade.triangle_count() if facade_mesh != null else 0)
			+ (_glass.triangle_count() if glass_mesh != null else 0)
			+ _boxes.count() * 12
			+ _cylinders.count() * 40
		),
		"style": _style,
		"detail_box_count": _boxes.count(),
		"detail_cylinder_count": _cylinders.count(),
		"bay_count_x": _bays_x,
		"bay_count_z": _bays_z,
		"floor_count": _floors,
		"bay_m": _bay_x,
		"floor_m": _floor_height,
	}

func _build_facade_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FACADE_SHADER
	material.set_shader_parameter("wall_color", _wall_color)
	material.set_shader_parameter("trim_color", _trim_color)
	material.set_shader_parameter("glass_color", _glass_tint)
	material.set_shader_parameter("sky_color", SKY_COLOR)
	material.set_shader_parameter("facade_style", float(_style))
	material.set_shader_parameter("detail_seed", float(_detail_seed % 997))
	material.set_shader_parameter("lit_ratio", _lit_ratio)
	material.set_shader_parameter("grime", _grime)
	material.set_shader_parameter("detail_texture", detail_texture())
	material.set_shader_parameter("facade_atlas", FacadeTextureAtlas.facade_atlas())
	return material

static func shared_trim_material() -> ShaderMaterial:
	if _trim_material == null:
		_trim_material = ShaderMaterial.new()
		_trim_material.shader = TRIM_SHADER
		_trim_material.set_shader_parameter("detail_texture", detail_texture())
	return _trim_material

static func detail_texture() -> ImageTexture:
	if _detail_texture != null:
		return _detail_texture
	var noise := FastNoiseLite.new()
	noise.seed = 20261018
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.55
	noise.fractal_lacunarity = 2.1
	var image := noise.get_image(256, 256, false, false, true)
	_detail_texture = ImageTexture.create_from_image(image)
	return _detail_texture

static func _shared_glass_material() -> ShaderMaterial:
	if _glass_material == null:
		_glass_material = ShaderMaterial.new()
		_glass_material.shader = GLASS_SHADER
		_glass_material.set_shader_parameter("sky_color", SKY_COLOR)
	return _glass_material

static func unit_box_mesh() -> BoxMesh:
	if _unit_box_mesh == null:
		_unit_box_mesh = BoxMesh.new()
		_unit_box_mesh.size = Vector3.ONE
	return _unit_box_mesh

static func unit_cylinder_mesh() -> CylinderMesh:
	if _unit_cylinder_mesh == null:
		_unit_cylinder_mesh = CylinderMesh.new()
		_unit_cylinder_mesh.top_radius = 0.5
		_unit_cylinder_mesh.bottom_radius = 0.5
		_unit_cylinder_mesh.height = 1.0
		_unit_cylinder_mesh.radial_segments = 10
		_unit_cylinder_mesh.rings = 1
	return _unit_cylinder_mesh

func _lin(color: Color) -> Color:
	return color.srgb_to_linear()

func _lin_glass(color: Color) -> Color:
	var linear := color.srgb_to_linear()
	return Color(linear.r, linear.g, linear.b, 1.0)

func _meta_sign_frame() -> Color:
	return _metal_color.darkened(0.15)
