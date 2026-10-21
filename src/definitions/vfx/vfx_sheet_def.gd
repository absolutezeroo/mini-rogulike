class_name VfxSheetDef
extends Resource
## One animated effect sheet of an element's kit (VfxElementDef): a projectile, an impact, the
## pieces of a nova... Frames side by side in a row; for a shape that points somewhere (an ice
## shard), one row per direction, drawn rather than rotated so its pixels never shear.
## Drawn at a whole number of world units per texel (`texel`, 2 = the art's 2x), never stretched.
## See docs/vfx.md.

## How a sheet follows the direction it travels in.
enum Orient {
	## Drawn as it is (a round orb, a spinning star, a ring on the ground).
	NONE,
	## One row per direction (`directions` rows, row 0 pointing right, then clockwise).
	ROWS,
	## A single row turned to the nearest of `directions` angles (arrows; pixels shear a little).
	SNAPPED,
}

@export var texture: Texture2D
## Frames in a row. 0 = square frames (the sheet's height).
@export_range(0, 64) var frames: int = 0
@export var orient: Orient = Orient.NONE
## Directions for ROWS (the sheet's rows) or SNAPPED (8 or 16).
@export_range(1, 32) var directions: int = 1
## Rows of a sheet that doesn't turn (NONE): variants of the same thing (three ice crystals),
## one picked at random each time.
@export_range(1, 16) var variants: int = 1
@export var fps: float = 12.0
## Loops (a projectile in flight, a status on a body) instead of playing once.
@export var loop: bool = false
## World units per texel: 2 for a sheet drawn at one art pixel per texel (always even).
@export_range(2, 8, 2) var texel: int = 2
## Painted in the element's ramp by luminance at load (VfxRamp), so one sheet serves several
## elements (the energy orb: water, poison...). Off for sheets authored on their ramp.
@export var recolor: bool = false
## Where the sheet's middle sits, in texels from the frame's center (art drawn off-center).
@export var anchor := Vector2.ZERO
## Seconds the last frame lingers and dithers away instead of vanishing (one-shot sheets).
@export var linger: float = 0.1


## Columns in the sheet (frames per row).
func frame_count() -> int:
	return VfxSheetDef.columns(texture, frames, rows())


## Rows in the sheet (directions when they are drawn, else variants).
func rows() -> int:
	return directions if orient == Orient.ROWS else variants


## Size of one frame in texels.
func frame_size() -> Vector2i:
	return VfxSheetDef.cell_size(texture, frames, rows())


## Seconds the animation takes, once.
func duration() -> float:
	return frame_count() / maxf(fps, 0.1)


## The region of frame `frame` (wrapped) facing `direction` (for ROWS sheets), or of the
## variant `variant` (for sheets that don't turn).
func region(frame: int, direction: Vector2 = Vector2.RIGHT, variant: int = 0) -> Rect2:
	var size := frame_size()
	var row := posmod(variant, maxi(variants, 1)) if orient != Orient.ROWS else 0
	if orient == Orient.ROWS and directions > 1:
		row = VfxSheetDef.direction_index(direction, directions)
	var column := posmod(frame, maxi(frame_count(), 1))
	return Rect2(Vector2(column * size.x, row * size.y), Vector2(size))


## The angle to turn the sheet by (SNAPPED: the nearest of `directions`; otherwise none).
func angle_for(direction: Vector2) -> float:
	if orient != Orient.SNAPPED or direction == Vector2.ZERO:
		return 0.0
	return VfxSheetDef.direction_index(direction, directions) * TAU / directions


## Frames in a row of `texture`: `frames` when given, else square frames (`rows` rows).
## A sheet whose width isn't a whole number of square frames needs `frames` (an 18x10 shard
## strip would otherwise be one frame of the whole strip).
static func columns(texture: Texture2D, frames: int, rows: int = 1) -> int:
	if texture == null:
		return 1
	if frames > 0:
		return frames
	var height := texture.get_height() / maxi(rows, 1)
	if height <= 0 or texture.get_width() % height != 0:
		return 1
	return maxi(texture.get_width() / height, 1)


## Size of one frame of `texture` cut in `frames` columns (0 = square) and `rows` rows.
static func cell_size(texture: Texture2D, frames: int, rows: int = 1) -> Vector2i:
	if texture == null:
		return Vector2i.ONE
	var count := VfxSheetDef.columns(texture, frames, rows)
	return Vector2i(texture.get_width() / count, texture.get_height() / maxi(rows, 1))


## Whether a strip of `frames` (0 = square) cuts `texture` into whole frames.
static func slices_evenly(texture: Texture2D, frames: int) -> bool:
	if texture == null:
		return true
	if frames > 0:
		return texture.get_width() % frames == 0
	return texture.get_width() % texture.get_height() == 0


## Index of the nearest of `count` directions to `direction` (0 = right, then clockwise on
## screen, y pointing down).
static func direction_index(direction: Vector2, count: int) -> int:
	if count <= 1 or direction == Vector2.ZERO:
		return 0
	return posmod(roundi(direction.angle() / (TAU / count)), count)


## A plain texture as a sheet: frames in a row (`frames`, 0 = square), drawn as it is when its
## frames are about square (orbs, stars, coins), turned to the nearest of 16 directions when
## they are long (arrows, kunai, shards drawn pointing right).
static func from_texture(texture: Texture2D, frames: int = 0, fps: float = 12.0) -> VfxSheetDef:
	var sheet := VfxSheetDef.new()
	sheet.texture = texture
	sheet.frames = frames
	sheet.fps = fps
	sheet.loop = true
	var size := sheet.frame_size()
	if size.x >= size.y * 3 / 2:
		sheet.orient = Orient.SNAPPED
		sheet.directions = 16
	return sheet
