class_name AfterimageVfx
extends Node2D
## A copy of a dashing body left behind, in the dash's element (steel grey for a plain dash),
## that dithers away art pixel by art pixel (dither_fade.gdshader) instead of fading in alpha.

const LIFETIME := 0.22
const SHADER := preload("res://assets/shaders/dither_fade.gdshader")
## How solid it starts (then down to nothing, in dither steps).
const START := 0.6

var _texture: Texture2D
var _rect: Rect2
var _flip := 1.0
var _color := Color.WHITE
var _age := 0.0
var _look: ShaderMaterial


static func create(at: Vector2, texture: Texture2D, rect: Rect2, flip: float, color: Color) -> AfterimageVfx:
	var vfx := AfterimageVfx.new()
	vfx.position = at
	vfx._texture = texture
	vfx._rect = rect
	vfx._flip = flip
	vfx._color = color
	vfx.z_index = -1
	return vfx


## Copies the frame an ActorRig is showing right now, tinted in `element`'s light step.
static func from_body(rig: ActorRig, element: VfxElementDef = null) -> AfterimageVfx:
	var vfx := AfterimageVfx.new()
	var texture := rig.current_frame()
	vfx.transform = rig.body.get_global_transform()
	vfx._texture = texture
	var size := texture.get_size()
	vfx._rect = Rect2(rig.body.offset - size * 0.5, size)
	var look := element if element else VfxElementDef.named(&"physical")
	vfx._color = look.shade(0.34)
	vfx.z_index = -1
	return vfx


func _ready() -> void:
	_look = ShaderMaterial.new()
	_look.shader = SHADER
	material = _look


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_look.set_shader_parameter("fade", START * (1.0 - _age / LIFETIME))
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_flip, 1.0))
	draw_texture_rect(_texture, _rect, false, Color(_color, 1.0))
