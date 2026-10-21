class_name SheetVfx
extends Node2D
## Plays a sprite sheet once and frees itself: slashes, impacts, smoke, magic circles...
## Always on the art's grid: drawn at a whole number of world units per texel (2 for sheets
## drawn at one art pixel per texel; a wanted size in between snaps to the nearest even one),
## at a grid position, turned only to one of 16 directions (or a drawn direction row), and it
## doesn't vanish on its last frame: that frame lingers and dithers away (docs/vfx.md).

const DEFAULT_FPS := 16.0
const SHADER := preload("res://assets/shaders/dither_fade.gdshader")
## Directions a turned sheet snaps to.
const DIRECTIONS := 16

var sheet: VfxSheetDef
var element: VfxElementDef
## Mirrored (a claw from the other side).
var flip := false
var _direction := Vector2.RIGHT
var _age := 0.0
var _modulate_color := Color.WHITE
var _look: ShaderMaterial
## A standing sheet's node sits at its base (to sort with the actors): its frame is drawn this
## far up.
var _lift := 0.0


## `sheet` played once at `at`, facing `direction`, in `element`'s colors when it is recolored,
## on the sheet's layer (VfxLayer: over, under or among the actors).
static func play(def: VfxSheetDef, at: Vector2, direction: Vector2 = Vector2.RIGHT, of_element: VfxElementDef = null) -> SheetVfx:
	var vfx := SheetVfx.new()
	vfx.sheet = def
	vfx.element = of_element
	vfx._direction = direction if direction != Vector2.ZERO else Vector2.RIGHT
	vfx.position = PixelDraw.snap(at)
	vfx.on_layer(def.layer)
	return vfx


## Moves it to `layer` (a plain texture played with `create` is AIR unless told).
func on_layer(layer: VfxLayer.Layer) -> SheetVfx:
	position = PixelDraw.snap(position + Vector2(0, -_lift))
	_lift = roundf(sheet.base_offset() / PixelDraw.PX) * PixelDraw.PX if layer == VfxLayer.Layer.STANDING else 0.0
	position += Vector2(0, _lift)
	VfxLayer.apply(self, layer)
	return self


## A plain texture (frames in a row, square unless `frame_width` says) played once.
## `rotation_angle` in radians, snapped to one of 16 directions; `size` world units per texel,
## snapped to a whole even number (2 = the art's own size).
static func create(texture: Texture2D, at: Vector2, rotation_angle: float = 0.0, size: float = 2.0, fps: float = DEFAULT_FPS, frame_width: int = 0) -> SheetVfx:
	var def := VfxSheetDef.new()
	def.texture = texture
	def.fps = fps
	if frame_width > 0 and frame_width != texture.get_height():
		def.frames = maxi(texture.get_width() / frame_width, 1)
	def.texel = int(PixelDraw.sheet_scale(size))
	if rotation_angle != 0.0:
		def.orient = VfxSheetDef.Orient.SNAPPED
		def.directions = DIRECTIONS
	return play(def, at, Vector2.from_angle(rotation_angle))


func with_color(color: Color) -> SheetVfx:
	_modulate_color = color
	return self


## Painted in `of_element`'s ramp (a plain sheet reused by an element: Thunder's bolts in
## storm violet). Nothing changes without an element.
func in_element(of_element: VfxElementDef) -> SheetVfx:
	if of_element:
		element = of_element
		sheet.recolor = true
	return self


func _ready() -> void:
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	material = _look
	VfxLayer.light_up(self, element, sheet.frame_size().x * sheet.texel)


## Seconds it shows: the frames, then the last one lingering.
func lifetime() -> float:
	return sheet.duration() + sheet.linger


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime():
		queue_free()
		return
	var past := _age - sheet.duration()
	_look.set_shader_parameter("fade", 1.0 - past / sheet.linger if past > 0.0 and sheet.linger > 0.0 else 1.0)
	queue_redraw()


func _draw() -> void:
	var frame := mini(int(_age * sheet.fps), sheet.frame_count() - 1)
	PixelDraw.sheet(self, sheet, frame, Vector2(0, -_lift), _direction, element, _modulate_color, flip)
