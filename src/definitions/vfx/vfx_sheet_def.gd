class_name VfxSheetDef
extends Resource
## One animated effect sheet of an element's kit (VfxElementDef): a projectile, an impact, the
## pieces of a nova... Frames side by side in a row; for a shape that points somewhere (an ice
## shard), one row per direction, drawn rather than rotated so its pixels never shear.
## Drawn at a whole number of world units per texel (`texel`, 2 = the art's 2x), never stretched.
## See docs/vfx.md.

## How it moves beyond its own frames (a shader over it, docs/vfx.md "Shaders").
enum Look {
	## Its frames, dithered away at the end.
	PLAIN,
	## Bands of light climbing it, its sides flickering (a column of light).
	SHIMMER,
	## A cloud of gas: its surface churning, a glowing rim, the floor showing through.
	GAS,
	## Draws itself stroke by stroke, then burns out (a sigil, a glyph).
	RUNE,
	## Flame tongues licking up through it.
	FLAME,
}

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
## Where it draws among the actors (VfxLayer, docs/vfx.md "Layers"): AIR (the default: a shot,
## an impact, a halo) over them; GROUND (a sigil, crackles) flat under them; STANDING (a crystal,
## a column of light, a bolt) sorted with them by the bottom of its frame.
@export var layer: VfxLayer.Layer = VfxLayer.Layer.AIR

@export_group("Shader")
## How it moves beyond its frames: PLAIN, SHIMMER, GAS, RUNE, FLAME (FxLook).
@export var look: Look = Look.PLAIN
## RUNE: a glyph drawn top-down (on) or a ring drawn around (off).
@export var glyph: bool = false
## Frames on which the whole screen flashes for one frame (a bolt striking; at most 3 a second,
## never when the player turned flashes off).
@export var flash_frames := PackedInt32Array()
## A glow halo (GlowHalo) around its core while it plays: the core's radius in world units
## (0: none), and where the core is, in texels from the frame's middle.
@export var halo: float = 0.0
@export var halo_at := Vector2.ZERO


## How far below its center (`at` + anchor) the bottom of its drawn frame is, in world units:
## a standing sheet sorts with the actors by that point.
func base_offset() -> float:
	return frame_size().y * texel * 0.5 + anchor.y * texel


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


## Frames in a row of `art`: `frame_total` when given, else square frames (`row_total` rows).
## A sheet whose width isn't a whole number of square frames needs `frame_total` (an 18x10 shard
## strip would otherwise be one frame of the whole strip).
static func columns(art: Texture2D, frame_total: int, row_total: int = 1) -> int:
	if art == null:
		return 1
	if frame_total > 0:
		return frame_total
	var height := int(art.get_height() / float(maxi(row_total, 1)))
	if height <= 0 or art.get_width() % height != 0:
		return 1
	return maxi(int(art.get_width() / float(height)), 1)


## Size of one frame of `art` cut in `frame_total` columns (0 = square) and `row_total` rows.
static func cell_size(art: Texture2D, frame_total: int, row_total: int = 1) -> Vector2i:
	if art == null:
		return Vector2i.ONE
	var count := VfxSheetDef.columns(art, frame_total, row_total)
	return Vector2i(int(art.get_width() / float(count)), int(art.get_height() / float(maxi(row_total, 1))))


## Whether a strip of `frame_total` (0 = square) cuts `art` into whole frames.
static func slices_evenly(art: Texture2D, frame_total: int) -> bool:
	if art == null:
		return true
	if frame_total > 0:
		return art.get_width() % frame_total == 0
	return art.get_width() % art.get_height() == 0


## Index of the nearest of `count` directions to `direction` (0 = right, then clockwise on
## screen, y pointing down).
static func direction_index(direction: Vector2, count: int) -> int:
	if count <= 1 or direction == Vector2.ZERO:
		return 0
	return posmod(roundi(direction.angle() / (TAU / count)), count)


## A plain texture as a sheet: frames in a row (`frame_total`, 0 = square), drawn as it is when its
## frames are about square (orbs, stars, coins), turned to the nearest of 16 directions when
## they are long (arrows, kunai, shards drawn pointing right).
static func from_texture(art: Texture2D, frame_total: int = 0, speed: float = 12.0) -> VfxSheetDef:
	var sheet := VfxSheetDef.new()
	sheet.texture = art
	sheet.frames = frame_total
	sheet.fps = speed
	sheet.loop = true
	var size := sheet.frame_size()
	if size.x >= int(size.y * 3 / 2.0):
		sheet.orient = Orient.SNAPPED
		sheet.directions = 16
	return sheet
