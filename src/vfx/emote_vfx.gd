class_name EmoteVfx
extends Node2D
## Speech-bubble emote that pops above a character, then dithers away (e.g. "!" when a monster
## spots you). On the grid (docs/vfx.md): drawn at 2x, popping one whole step bigger (4x) for its
## first frames, rising by whole art pixels, fading by ordered dithering (dither_fade.gdshader),
## never an alpha fade or a stretched sprite.

const LIFETIME := 0.9
## How long it shows at twice its size (two frames), how far it rises (world units).
const POP_TIME := 2.0 / 60.0
const RISE := 4.0
## The share of its life it stays whole before dithering away.
const SOLID := 0.7
const SCALE := 2.0

var _texture: Texture2D
var _age := 0.0
var _look: ShaderMaterial


static func create(texture: Texture2D, at: Vector2) -> EmoteVfx:
	var vfx := EmoteVfx.new()
	vfx._texture = texture
	vfx.position = PixelDraw.snap(at)
	vfx.z_index = 10
	return vfx


func _ready() -> void:
	_look = ShaderMaterial.new()
	_look.shader = FxLook.DITHER
	material = _look


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var t := _age / LIFETIME
	_look.set_shader_parameter("fade", clampf((1.0 - t) / (1.0 - SOLID), 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var t := _age / LIFETIME
	var factor := SCALE * 2.0 if _age < POP_TIME else SCALE
	var size := _texture.get_size() * factor
	var rise := PixelDraw.snap_length(RISE * ease(t, 0.3)) if t > 0.0 else 0.0
	draw_texture_rect(_texture, Rect2(PixelDraw.snap(Vector2(-size.x * 0.5, -size.y - rise)), size), false)
