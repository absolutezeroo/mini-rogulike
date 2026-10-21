class_name ProjectileHalo
extends Node2D
## The glow around a magic shot: dithered discs of art pixels in its element's darker steps,
## added onto what is behind it (so it shines even in bright rooms). Additive light only on
## emissive shots and from dark source colors, so it brightens without washing out to white;
## it breathes in whole pixels, never in smooth alpha (docs/vfx.md).

var element: VfxElementDef
var size := 6.0

var _time := 0.0


func _ready() -> void:
	show_behind_parent = true
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = add
	_time = randf() * 3.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if element == null:
		return
	# Two steps of light: a sparse outer one, a denser inner one; one pixel wider on the beat.
	var beat := PixelDraw.PX if fmod(_time * 6.0, 1.0) < 0.5 else 0.0
	PixelDraw.disc(self, Vector2.ZERO, PixelDraw.snap_length(size * 1.7) + beat, element.edge(), 0.3)
	PixelDraw.disc(self, Vector2.ZERO, PixelDraw.snap_length(size * 1.1), element.shade(0.7), 0.5)
