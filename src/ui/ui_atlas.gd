class_name UiAtlas
## Access to the Kenney "UI Pack - Pixel Adventure" tilesheets (upscaled 2x) by tile index
## (left to right, top to bottom, starting at 0).

const LARGE_SHEET: Texture2D = preload("res://assets/ui/kenney_pixel_adventure/large_tiles_2x.png")
const SMALL_SHEET: Texture2D = preload("res://assets/ui/kenney_pixel_adventure/small_tiles_2x.png")
const LARGE_SIZE := 64
const LARGE_COLUMNS := 13
const SMALL_SIZE := 32
const SMALL_COLUMNS := 23

# Tiles used by the hand-drawn controls.
const ROUND_BUTTON := 41
const ROUND_BUTTON_PRESSED := 42
const BAR_FRAME := 13

static var _cache := {}


static func large(index: int) -> AtlasTexture:
	return _tile(LARGE_SHEET, LARGE_SIZE, LARGE_COLUMNS, index)


static func small(index: int) -> AtlasTexture:
	return _tile(SMALL_SHEET, SMALL_SIZE, SMALL_COLUMNS, index)


static func _tile(sheet: Texture2D, size: int, columns: int, index: int) -> AtlasTexture:
	var key := "%d:%d" % [size, index]
	if not _cache.has(key):
		var texture := AtlasTexture.new()
		texture.atlas = sheet
		texture.region = Rect2((index % columns) * size, (index / columns) * size, size, size)
		_cache[key] = texture
	return _cache[key]
