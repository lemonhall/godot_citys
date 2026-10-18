extends RefCounted

# Procedural facade material atlas for the v62 building kit.
# A 2x2 grid of 128px tiles: concrete, brick, stone, metal panel.

const TILE_SIZE := 128
const ATLAS_SIZE := 256

static var _texture: ImageTexture = null

static func facade_atlas() -> ImageTexture:
	if _texture != null:
		return _texture
	var atlas := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_L8)
	var concrete := _noise_image(0.06, 4)
	atlas.blit_rect(concrete, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(0, 0))
	atlas.blit_rect(_brick_image(concrete), Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(TILE_SIZE, 0))
	atlas.blit_rect(_stone_image(concrete), Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(0, TILE_SIZE))
	atlas.blit_rect(_metal_image(concrete), Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(TILE_SIZE, TILE_SIZE))
	_texture = ImageTexture.create_from_image(atlas)
	return _texture

static func _noise_image(frequency: float, octaves: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = 811
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.55
	return noise.get_image(TILE_SIZE, TILE_SIZE, false, false, true)

static func _brick_image(base: Image) -> Image:
	var image := base.duplicate()
	var mortar := Color(0.32, 0.32, 0.32)
	var row_height := 16
	var brick_width := 32
	for y in range(0, TILE_SIZE, row_height):
		image.fill_rect(Rect2i(0, y, TILE_SIZE, 2), mortar)
		var offset := 0 if (y / row_height) % 2 == 0 else brick_width / 2
		for x in range(offset, TILE_SIZE, brick_width):
			image.fill_rect(Rect2i(x, y, 2, row_height), mortar)
	return image

static func _stone_image(base: Image) -> Image:
	var image := base.duplicate()
	var joint := Color(0.38, 0.38, 0.38)
	var row_height := 32
	var block_width := 64
	for y in range(0, TILE_SIZE, row_height):
		image.fill_rect(Rect2i(0, y, TILE_SIZE, 3), joint)
		var offset := 0 if (y / row_height) % 2 == 0 else block_width / 2
		for x in range(offset, TILE_SIZE, block_width):
			image.fill_rect(Rect2i(x, y, 3, row_height), joint)
	return image

static func _metal_image(base: Image) -> Image:
	var image := base.duplicate()
	var rib := Color(0.30, 0.30, 0.30)
	for x in range(0, TILE_SIZE, 16):
		image.fill_rect(Rect2i(x, 0, 3, TILE_SIZE), rib)
	return image
