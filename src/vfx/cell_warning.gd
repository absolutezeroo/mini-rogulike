class_name CellWarning
extends Node2D
## Cells about to change (a boss arena shifting): a threat telegraph, so it looks like the
## monsters' warnings (TelegraphView's danger red, a crisp rim one art pixel thick, the fill
## thickening in steps as the change comes) and blinks faster and faster: on or off, never a
## smooth pulse. Then the warning is gone and the change happens.

## The fill's thickness at first and how much it gains by the end (in FILL_STEPS steps), and the
## rim's (TelegraphView's look).
const FILL := 0.14
const FILL_GAIN := 0.24
const FILL_STEPS := 4
const RIM := 0.85
## The blink's period at first and at the end (seconds).
const BLINK_SLOW := 0.25
const BLINK_FAST := 0.07

var _cells: Array[Vector2i] = []
var _tile := 32.0
var _duration := 1.4
var _age := 0.0


static func create(cells: Array[Vector2i], tile_size: int, duration: float) -> CellWarning:
	var warning := CellWarning.new()
	warning._cells = cells
	warning._tile = float(tile_size)
	warning._duration = duration
	VfxLayer.apply(warning, VfxLayer.Layer.GROUND)  # on the floor, under whoever stands there
	return warning


func _process(delta: float) -> void:
	_age += delta
	if _age >= _duration:
		queue_free()
	queue_redraw()


## Whether the blink is on now (its period shrinking from BLINK_SLOW to BLINK_FAST).
func is_lit() -> bool:
	var t := clampf(_age / _duration, 0.0, 1.0)
	var period := BLINK_SLOW + (BLINK_FAST - BLINK_SLOW) * t
	return fmod(_age, period) < period * 0.5


func _draw() -> void:
	var t := clampf(_age / _duration, 0.0, 1.0)
	var lit := is_lit()
	var fill := Color(TelegraphView.DANGER, FILL + FILL_GAIN * floorf(t * FILL_STEPS) / FILL_STEPS + (0.12 if lit else 0.0))
	var rim := Color(TelegraphView.DANGER_EDGE if lit else TelegraphView.DANGER, RIM)
	var px := PixelDraw.PX
	for cell in _cells:
		# One art pixel in from the cell's edge, the rim one art pixel thick: all on the grid.
		var rect := Rect2(Vector2(cell) * _tile + Vector2.ONE * px, Vector2.ONE * (_tile - px * 2.0))
		draw_rect(rect.grow(-px), fill)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, px)), rim)
		draw_rect(Rect2(rect.position + Vector2(0, rect.size.y - px), Vector2(rect.size.x, px)), rim)
		draw_rect(Rect2(rect.position + Vector2(0, px), Vector2(px, rect.size.y - px * 2.0)), rim)
		draw_rect(Rect2(rect.position + Vector2(rect.size.x - px, px), Vector2(px, rect.size.y - px * 2.0)), rim)
