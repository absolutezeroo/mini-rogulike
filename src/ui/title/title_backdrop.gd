class_name TitleBackdrop
extends Control
## The title screen's picture, drawn in big pixels: a cave at night, its rock closing in from the
## sides and the top, and on the right the Well itself, a ring of old stones with the souls' light
## rising from its depth. The hero sits on its rim (TitleScreen places him at hero_spot()).

## Screen pixels per art pixel.
const PIXEL := 4.0
const SKY_TOP := Color(0.055, 0.04, 0.085)
const SKY_BOTTOM := Color(0.13, 0.085, 0.14)
const ROCK := Color(0.07, 0.05, 0.08)
const ROCK_EDGE := Color(0.22, 0.15, 0.2)
const GROUND := Color(0.1, 0.07, 0.1)
const STONE := Color(0.36, 0.3, 0.32)
const STONE_DARK := Color(0.2, 0.16, 0.19)
const STONE_LIGHT := Color(0.52, 0.45, 0.44)
const SOUL := Color(0.55, 0.95, 0.95)

var _time := 0.0
var _rocks_left := PackedFloat32Array()
var _rocks_right := PackedFloat32Array()
var _ceiling := PackedFloat32Array()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # the same cave every time
	for i in 64:
		_rocks_left.append(rng.randf())
		_rocks_right.append(rng.randf())
		_ceiling.append(rng.randf())


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


## The middle of the Well's mouth (screen position).
func well_center() -> Vector2:
	return Vector2(size.x * 0.7, size.y * 0.74).snapped(Vector2(PIXEL, PIXEL))


## Half the Well's mouth, across and deep.
func well_radius() -> Vector2:
	return Vector2(clampf(size.x * 0.11, 120.0, 200.0), clampf(size.y * 0.075, 36.0, 60.0)).snapped(Vector2(PIXEL, PIXEL))


## Where the hero sits: on the rim, left of the mouth.
func hero_spot() -> Vector2:
	var center := well_center()
	return center + Vector2(-well_radius().x - 64.0, -6.0)


func _draw() -> void:
	var w := size.x
	var h := size.y
	# The dark of the cave, a little warmer near the ground.
	var bands := 24
	for i in bands:
		var t := float(i) / (bands - 1)
		draw_rect(Rect2(0, h * i / bands, w, h / bands + 1), SKY_TOP.lerp(SKY_BOTTOM, t))
	_draw_beam()
	# The ground.
	var ground_y := well_center().y - well_radius().y * 0.3
	draw_rect(Rect2(0, ground_y, w, h - ground_y), GROUND)
	for i in int(w / (PIXEL * 6)):
		var x := i * PIXEL * 6
		var bump := floorf(_rocks_left[i % 64] * 3.0) * PIXEL
		draw_rect(Rect2(x, ground_y - bump, PIXEL * 6, bump + PIXEL), GROUND)
		draw_rect(Rect2(x, ground_y - bump, PIXEL * 6, PIXEL), ROCK_EDGE)
	_draw_rock_walls()
	_draw_well()


## The souls' light rising from the Well, faint and slowly breathing.
func _draw_beam() -> void:
	var center := well_center()
	var radius := well_radius()
	var breath := 0.75 + 0.25 * sin(_time * 0.8)
	var steps := 10
	for i in steps:
		var t := float(i) / steps
		var half := radius.x * (0.9 - t * 0.55)
		var top := center.y - (center.y + 40.0) * (1.0 - t)
		draw_rect(Rect2(center.x - half, top, half * 2.0, center.y - top), Color(SOUL, 0.022 * breath))


func _draw_rock_walls() -> void:
	var w := size.x
	var h := size.y
	var step := PIXEL * 8
	var rows := int(h / step) + 1
	# Left and right walls: jagged columns of rock, deeper near the top.
	for i in rows:
		var y := i * step
		var t := 1.0 - float(i) / rows
		var left := (40.0 + 90.0 * t + _rocks_left[i % 64] * 36.0)
		var right := (30.0 + 70.0 * t + _rocks_right[i % 64] * 30.0)
		left = snappedf(left, PIXEL)
		right = snappedf(right, PIXEL)
		draw_rect(Rect2(0, y, left, step), ROCK)
		draw_rect(Rect2(left - PIXEL, y, PIXEL, step), ROCK_EDGE)
		draw_rect(Rect2(w - right, y, right, step), ROCK)
		draw_rect(Rect2(w - right, y, PIXEL, step), ROCK_EDGE)
	# The ceiling: a ragged edge of rock with a few hanging points.
	var columns := int(w / step) + 1
	for i in columns:
		var x := i * step
		var depth := snappedf(24.0 + _ceiling[i % 64] * 40.0, PIXEL)
		draw_rect(Rect2(x, 0, step, depth), ROCK)
		draw_rect(Rect2(x, depth - PIXEL, step, PIXEL), ROCK_EDGE)
		if _ceiling[(i * 7) % 64] > 0.82:
			var drip := snappedf(16.0 + _ceiling[(i * 3) % 64] * 40.0, PIXEL)
			draw_rect(Rect2(x + step * 0.25, depth, step * 0.5, drip), ROCK)
			draw_rect(Rect2(x + step * 0.375, depth + drip, step * 0.25, PIXEL * 2), ROCK)


## A ring of stones round a mouth of light: the back stones, the glowing hole, the front stones.
func _draw_well() -> void:
	var center := well_center()
	var radius := well_radius()
	var breath := 0.8 + 0.2 * sin(_time * 1.3)
	# The hole: dark, with the souls' light deep inside.
	_ellipse(center, radius * 0.92, Color(0.02, 0.02, 0.05))
	for i in 6:
		var t := float(i) / 6.0
		_ellipse(center + Vector2(0, radius.y * 0.1 * t), radius * (0.85 - t * 0.6), Color(SOUL, (0.08 + t * 0.12) * breath))
	# The stones: blocks along the ring, darker at the back, lit from the hole at the front.
	var stones := 22
	for front in [false, true]:
		for i in stones:
			var angle := TAU * i / stones
			var is_front := sin(angle) > 0.0
			if is_front != front:
				continue
			var at := center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y)
			var block := Vector2(snappedf(radius.x * 0.3, PIXEL), PIXEL * (5 if front else 4))
			var rect := Rect2((at - block * 0.5).snapped(Vector2(PIXEL, PIXEL)), block)
			var base := STONE if front else STONE_DARK
			draw_rect(rect, base)
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, PIXEL)), STONE_LIGHT if front else STONE)
			draw_rect(Rect2(rect.position + Vector2(rect.size.x - PIXEL, 0), Vector2(PIXEL, rect.size.y)), STONE_DARK)
	# The wall of the well under its front rim.
	var wall := Rect2(center.x - radius.x, center.y, radius.x * 2.0, radius.y * 1.2).abs()
	for row in 3:
		for column in 6:
			var offset := (PIXEL * 6 if row % 2 == 1 else 0.0)
			var brick := Rect2(wall.position + Vector2(column * wall.size.x / 6.0 + offset, radius.y * 0.35 + row * PIXEL * 5), Vector2(wall.size.x / 6.0 - PIXEL, PIXEL * 4))
			brick.size.x = minf(brick.size.x, wall.end.x - brick.position.x)
			if brick.size.x > PIXEL:
				draw_rect(Rect2(brick.position.snapped(Vector2(PIXEL, PIXEL)), brick.size.snapped(Vector2(PIXEL, PIXEL))), STONE_DARK if (row + column) % 3 else STONE)


func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	# In big pixels: rows of rects, stepped like the rest of the art.
	var rows := int(radius.y * 2.0 / PIXEL)
	for i in rows:
		var y := -radius.y + i * PIXEL + PIXEL * 0.5
		var half := radius.x * sqrt(maxf(0.0, 1.0 - (y * y) / (radius.y * radius.y)))
		half = snappedf(half, PIXEL)
		if half > 0.0:
			draw_rect(Rect2(center.x - half, center.y + y - PIXEL * 0.5, half * 2.0, PIXEL), color)
