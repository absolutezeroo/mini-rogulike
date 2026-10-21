class_name FlameVfx
extends Node2D
## A small fire that burns on its own (a brazier's bowl, a torch): the fire kit's flicker
## (assets/fx/fire/fire_flicker.png) looping at the art's 2x, its base on this node, one or a
## few flames out of step. On the grid like every effect (docs/vfx.md); the same flames as a
## campfire and a burning body. Flame tongues lick up through it (flame.gdshader), a stepped
## glow halo lights the air around its heart (GlowHalo; the brazier's own lamp lights the floor)
## and the air trembles above it (a HEAT DistortionStamp).

const FLICKER: Texture2D = preload("res://assets/fx/fire/fire_flicker.png")
const FRAMES := 12

## Flames side by side, out of step.
@export_range(1, 3) var copies: int = 1
@export var fps: float = 10.0

var _time := 0.0
var _frame := -1


func _ready() -> void:
	_time = randf() * 2.0  # two braziers never flicker in step
	var fire := VfxElementDef.named(&"fire")
	material = FxLook.flame(fire)
	var height := FLICKER.get_height() * PixelDraw.PX
	GlowHalo.attach(self, fire, 4.0 + 2.0 * copies, Vector2(0, -height * 0.35))
	var heat := DistortionStamp.attach(self, DistortionStamp.Kind.HEAT, 6.0 + 6.0 * copies, 1.0, 0.0, Vector2(0, -height * 0.6))
	if heat:
		heat.height = height * 2.0


func _process(delta: float) -> void:
	_time += delta
	var frame := int(_time * fps)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	var cell := Vector2(FLICKER.get_width() / FRAMES, FLICKER.get_height())
	var size := cell * PixelDraw.PX
	for i in copies:
		var frame := (_frame + i * 5) % FRAMES
		var x := (i - (copies - 1) * 0.5) * 8.0
		var at := PixelDraw.snap(Vector2(x - size.x * 0.5, -size.y + (2.0 if i != (copies - 1) / 2 else 0.0)))
		draw_texture_rect_region(FLICKER, Rect2(at, size), Rect2(Vector2(frame * cell.x, 0), cell))
