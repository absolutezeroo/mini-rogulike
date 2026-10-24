class_name FootprintVfx
extends Node2D
## A footprint left on the floor, dithering away (docs/vfx.md: whole art pixels, never turned off
## the grid, no alpha fade). The sole is drawn in the nearest of four directions, as cells.

const LIFETIME := 3.5
## The sole pointing right, in art pixels around the foot: 3 long, 2 wide, a toe in front.
const SOLE: Array[Vector2i] = [Vector2i(-2, -1), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]

var _color := Color(0, 0, 0, 0.2)
var _age := 0.0
## The sole's cells, turned to the step's direction.
var _cells: Array[Vector2i] = []
## The dither step drawn (redrawn only when it changes).
var _step := -1


static func create(at: Vector2, direction: Vector2, color: Color) -> FootprintVfx:
	var footprint := FootprintVfx.new()
	footprint.position = PixelDraw.snap(at)
	footprint._cells = turned(direction)
	footprint._color = color
	footprint.z_index = -5
	footprint.add_to_group(&"footprints")
	return footprint


## The sole's cells for a step toward `direction` (right, down, left or up: quarter turns of
## whole cells, never a rotated node).
static func turned(direction: Vector2) -> Array[Vector2i]:
	var quarter := posmod(roundi(direction.angle() / (PI / 2.0)), 4)
	var cells: Array[Vector2i] = []
	for cell in SOLE:
		var at := cell
		for i in quarter:
			at = Vector2i(-at.y, at.x)
		cells.append(at)
	return cells


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var step := floori((1.0 - _age / LIFETIME) * 16.0)
	if step != _step:
		_step = step
		queue_redraw()


func _draw() -> void:
	var left := 1.0 - _age / LIFETIME
	var origin := PixelDraw.cell_of(position)
	for cell in _cells:
		if PixelDraw.dither(origin + cell, left):
			PixelDraw.cell(self, cell, _color)
