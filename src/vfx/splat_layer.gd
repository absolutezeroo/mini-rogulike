class_name SplatLayer
extends Node2D
## What fights leave on the floor: blood, slime, ink... A pixel blob with a few drops, in the
## monster's MonsterDef.splat_color, that stays a while then fades. One layer per floor draws
## them all (World.add_splat); the oldest go first past MAX_SPLATS.
## Also the chips a monster leaves when it dies (bone, armor, leaves... ImpactMaterialDef):
## flung out in a short hop, then they stay for the whole floor (`add_debris`).

const MAX_SPLATS := 80
const LIFE := 45.0
const FADE := 10.0
## Size of a pixel of the art, in world pixels.
const PIXEL := 2.0

const MAX_CHIPS := 400
## Seconds a chip flies before it lands.
const CHIP_FLIGHT := 0.3

## Each: {rows: Array of Rect2, color: Color, shine: Array of Rect2, born: float}
var _splats: Array[Dictionary] = []
## Each: {from: Vector2, to: Vector2, size: Vector2, color: Color, height: float, born: float}
var _chips: Array[Dictionary] = []
## Chips flung on this floor so far (the oldest go past MAX_CHIPS, this keeps counting).
var chips_made := 0
## Splats made on this floor so far (the oldest go past MAX_SPLATS, this keeps counting).
var splats_made := 0
## Chips may still be in the air: redraw every frame until one frame after they all landed.
var _flying := false
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
	splats_made += 1
	if _splats.size() > MAX_SPLATS:
		_splats.pop_front()
	queue_redraw()


func count() -> int:
	return splats_made


## Chips of `material` flung around `at` (`size` 1 = a monster of normal size), mostly along
## `direction` if given (the killing blow). `ground(point) -> bool`: where a chip may land (not
## on a wall, not over a hole).
func add_debris(at: Vector2, material: ImpactMaterialDef, size: float, direction: Vector2, rng: RandomNumberGenerator, ground := Callable()) -> void:
	if material.debris_colors.is_empty():
		return
	for i in roundi(material.debris_count * size):
		var angle := direction.angle() + rng.randf_range(-1.1, 1.1) if direction != Vector2.ZERO and rng.randf() < 0.7 else rng.randf() * TAU
		var distance := rng.randf_range(6.0, 22.0) * sqrt(size)
		var to := (at + Vector2.from_angle(angle) * Vector2(1.0, 0.6) * distance).snapped(Vector2(PIXEL, PIXEL))
		if ground.is_valid() and not ground.call(to):
			continue
		var big := rng.randf() < 0.3
		_chips.append({
			from = at + Vector2(0, -6),
			to = to,
			size = Vector2(PIXEL * (2 if big else 1), PIXEL * (2 if big and rng.randf() < 0.5 else 1)),
			color = material.debris_colors[rng.randi() % material.debris_colors.size()],
			height = rng.randf_range(6.0, 14.0),
			born = _time,
		})
		chips_made += 1
	while _chips.size() > MAX_CHIPS:
		_chips.pop_front()
	_flying = true
	queue_redraw()


func chip_count() -> int:
	return chips_made


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
	if _flying:
		queue_redraw()  # chips in the air (this frame draws them, landed or not)
		_flying = not _chips.is_empty() and _time - float(_chips[-1].born) <= CHIP_FLIGHT
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
	for chip in _chips:
		var t := clampf((_time - float(chip.born)) / CHIP_FLIGHT, 0.0, 1.0)
		var at: Vector2 = (chip.from as Vector2).lerp(chip.to, t) + Vector2(0, -sin(t * PI) * float(chip.height))
		at = at.snapped(Vector2(PIXEL, PIXEL))
		var color: Color = chip.color
		draw_rect(Rect2(at + Vector2(0, PIXEL), chip.size), color.darkened(0.55))  # its shadow edge
		draw_rect(Rect2(at, chip.size), color)
