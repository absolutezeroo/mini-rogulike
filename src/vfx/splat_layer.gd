class_name SplatLayer
extends Node2D
## What fights leave on the floor: blood, slime, ink... A pixel blob with a few drops, in the
## monster's MonsterDef.splat_color, that stays a while then fades. One layer per floor draws
## them all (World.add_splat); the oldest go first past MAX_SPLATS.

const MAX_SPLATS := 80
const LIFE := 45.0
const FADE := 10.0
## Size of a pixel of the art, in world pixels.
const PIXEL := 2.0

## Each: {rows: Array of Rect2, color: Color, shine: Array of Rect2, born: float}
var _splats: Array[Dictionary] = []
var _time := 0.0
var _redraw_timer := 0.0


func _ready() -> void:
	z_index = -8  # on the ground, under whoever walks by


## A blob at `at` (`size` 1 = a monster's death, smaller for a drop on a hit), its drops
## flung along `direction` if given.
func add(at: Vector2, color: Color, size: float, direction: Vector2, rng: RandomNumberGenerator) -> void:
	var cells := {}
	var radius := (8.0 + rng.randf() * 5.0) * size
	_blob(cells, at, radius, rng)
	var drops := rng.randi_range(3, 7) if size >= 0.6 else rng.randi_range(1, 3)
	for i in drops:
		var angle := direction.angle() + rng.randf_range(-0.7, 0.7) if direction != Vector2.ZERO else rng.randf() * TAU
		var distance := radius + rng.randf_range(3.0, 14.0) * maxf(size, 0.5)
		_blob(cells, at + Vector2.from_angle(angle) * distance, rng.randf_range(1.5, 3.5) * maxf(size, 0.6), rng)
	var shine: Array[Rect2] = []
	if size >= 0.6:
		var spot := at + Vector2(-radius * 0.3, -radius * 0.35)
		shine.append(Rect2(spot.snapped(Vector2(PIXEL, PIXEL)), Vector2(PIXEL * 2.0, PIXEL)))
	_splats.append({rows = _rows(cells), color = color, shine = shine, born = _time})
	if _splats.size() > MAX_SPLATS:
		_splats.pop_front()
	queue_redraw()


func count() -> int:
	return _splats.size()


## Art pixels within `radius` of `center`, a little ragged.
func _blob(cells: Dictionary, center: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var steps := ceili(radius / PIXEL) + 1
	var origin := (center / PIXEL).floor()
	for y in range(-steps, steps + 1):
		for x in range(-steps, steps + 1):
			var d := Vector2(x, y).length() * PIXEL
			if d <= radius * (0.8 + 0.2 * rng.randf()):
				cells[Vector2i(int(origin.x) + x, int(origin.y) + y)] = true


## The pixels merged into horizontal runs: few rectangles to draw.
func _rows(cells: Dictionary) -> Array[Rect2]:
	var keys := cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var rows: Array[Rect2] = []
	var start := Vector2i(-99999, -99999)
	var last := start
	for cell: Vector2i in keys:
		if cell.y == last.y and cell.x == last.x + 1:
			last = cell
			continue
		if start.x != -99999:
			rows.append(Rect2(Vector2(start) * PIXEL, Vector2(last.x - start.x + 1, 1) * PIXEL))
		start = cell
		last = cell
	if start.x != -99999:
		rows.append(Rect2(Vector2(start) * PIXEL, Vector2(last.x - start.x + 1, 1) * PIXEL))
	return rows


func _process(delta: float) -> void:
	_time += delta
	_redraw_timer -= delta
	if _redraw_timer > 0.0 or _splats.is_empty():
		return
	_redraw_timer = 0.5
	while not _splats.is_empty() and _time - float(_splats[0].born) > LIFE:
		_splats.pop_front()
	queue_redraw()


func _draw() -> void:
	for splat in _splats:
		var age := _time - float(splat.born)
		var fade := clampf((LIFE - age) / FADE, 0.0, 1.0)
		var color: Color = splat.color
		color.a *= fade
		for row: Rect2 in splat.rows:
			draw_rect(row, color)
		var shine := Color(color.lightened(0.35), color.a * 0.6)
		for spot: Rect2 in splat.shine:
			draw_rect(spot, shine)
