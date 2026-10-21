class_name PixelDraw
## Drawing on the art's pixel grid, for every effect drawn in `_draw()` (docs/vfx.md).
##
## The art is 16x16 pixel art drawn at 2x: one art pixel is `PX` (2) world units. Smooth
## `draw_circle` / `draw_arc` and alpha fades put half-size pixels ("mixels") and colors from no
## palette on screen, next to sprites whose pixels are all 2x2. These helpers only ever draw
## whole art pixels at grid positions, in opaque colors, and fade by ordered dithering (a 4x4
## Bayer matrix: each pixel is fully there or not at all) instead of alpha.
##
## Positions are in the canvas's own space; the grid is anchored at its origin, so an effect
## parented to an actor stays on that actor's grid.

## One art pixel, in world units.
const PX := 2.0
## 4x4 ordered dithering thresholds (0..15).
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


## `v` snapped to the art grid.
static func snap(v: Vector2) -> Vector2:
	return (v / PX).round() * PX


## `value` (a length) snapped to whole art pixels, at least one.
static func snap_length(value: float) -> float:
	return maxf(roundf(value / PX), 1.0) * PX


## The nearest scale that keeps a sheet authored at 1 art pixel per texel on the grid: a whole,
## even number of world units per texel (2, 4, 6...), never below 2.
static func sheet_scale(wanted: float) -> float:
	return maxf(roundf(wanted / PX), 1.0) * PX


## Whether the art pixel at `cell` is drawn for a fade at `amount` (1 = all of them, 0 = none),
## by ordered dithering. `cell` is in art pixels (see `cell_of`).
static func dither(cell: Vector2i, amount: float) -> bool:
	if amount >= 1.0:
		return true
	if amount <= 0.0:
		return false
	var threshold := (BAYER[(cell.y & 3) * 4 + (cell.x & 3)] + 0.5) / 16.0
	return amount > threshold


## The art pixel a point falls in.
static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / PX), floori(point.y / PX))


## One block of `size_px` art pixels, its top-left corner snapped to the grid.
static func pixel(canvas: CanvasItem, at: Vector2, color: Color, size_px: int = 1) -> void:
	canvas.draw_rect(Rect2(snap(at), Vector2.ONE * PX * size_px), color)


## One art pixel at the art-pixel coordinates `cell`.
static func cell(canvas: CanvasItem, at: Vector2i, color: Color) -> void:
	canvas.draw_rect(Rect2(Vector2(at) * PX, Vector2(PX, PX)), color)


## A ring `thickness_px` art pixels thick, squashed vertically by `squash` (0.5 for a ring lying
## on the ground), dithered away by `fade` (1 = solid). Stepped like a hand-drawn circle.
static func ring(canvas: CanvasItem, center: Vector2, radius: float, color: Color, thickness_px: int = 1, fade: float = 1.0, squash: float = 1.0) -> void:
	var c := cell_of(snap(center))
	var r := maxf(radius / PX, 1.0)
	var inner := maxf(r - thickness_px, 0.0)
	var rows := ceili(r * squash)
	for y in range(-rows, rows + 1):
		var dy := y / maxf(squash, 0.01)
		if absf(dy) > r:
			continue
		var outer_x := floori(sqrt(r * r - dy * dy) + 0.5)
		var inner_x := floori(sqrt(maxf(inner * inner - dy * dy, 0.0)) + 0.5) if absf(dy) < inner else -1
		# Each side of the row: from inner_x + 1 to outer_x (the whole row where the ring is thin).
		for side in [-1, 1]:
			var from := inner_x + 1
			if fade >= 1.0:
				var length := outer_x - from + 1
				if length <= 0:
					continue
				var start := c.x + (from if side == 1 else -outer_x)
				canvas.draw_rect(Rect2(Vector2(start, c.y + y) * PX, Vector2(length, 1) * PX), color)
			else:
				for x in range(from, outer_x + 1):
					var at := Vector2i(c.x + x * side, c.y + y)
					if dither(at, fade):
						cell(canvas, at, color)


## A filled disc (squashed like `ring`), dithered by `fade`. Keep it small: a dithered disc draws
## one rect per pixel.
static func disc(canvas: CanvasItem, center: Vector2, radius: float, color: Color, fade: float = 1.0, squash: float = 1.0) -> void:
	var c := cell_of(snap(center))
	var r := maxf(radius / PX, 0.5)
	var rows := ceili(r * squash)
	for y in range(-rows, rows + 1):
		var dy := y / maxf(squash, 0.01)
		if absf(dy) > r:
			continue
		var half := floori(sqrt(r * r - dy * dy) + 0.5)
		if fade >= 1.0:
			canvas.draw_rect(Rect2(Vector2(c.x - half, c.y + y) * PX, Vector2(half * 2 + 1, 1) * PX), color)
		else:
			for x in range(-half, half + 1):
				var at := Vector2i(c.x + x, c.y + y)
				if dither(at, fade):
					cell(canvas, at, color)


## A straight line of art pixels (Bresenham on the grid), `thickness_px` thick.
static func line(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, thickness_px: int = 1, fade: float = 1.0) -> void:
	var a := cell_of(snap(from))
	var b := cell_of(snap(to))
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var at := a
	var half := (thickness_px - 1) / 2
	while true:
		if dither(at, fade):
			canvas.draw_rect(Rect2(Vector2(at - Vector2i(half, half)) * PX, Vector2.ONE * PX * thickness_px), color)
		if at == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			at.x += sx
		if e2 <= dx:
			err += dx
			at.y += sy


## A particle "bit" of an element (VfxElementDef.Bit) of `size_px` art pixels (1 to 3), pointing
## along `direction` for the shapes that have one (a shard, a teardrop). Drawn in `color`, with
## `core` for its brightest pixel when given.
static func bit(canvas: CanvasItem, shape: int, at: Vector2, size_px: int, color: Color, direction: Vector2 = Vector2.UP, core: Color = Color.TRANSPARENT) -> void:
	var c := cell_of(snap(at))
	var s := clampi(size_px, 1, 4)
	var d := _octant(direction)
	match shape:
		VfxElementDef.Bit.DIAMOND:
			# An angular chip: a pixel, a 3-pixel wedge, a slanted sliver; turned along
			# `direction` (never a plus sign: that is the storm's spark).
			var chip: Array[Vector2i] = [Vector2i.ZERO]
			if s == 2:
				chip = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, -1)]
			elif s >= 3:
				chip = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, -1), Vector2i(2, -1), Vector2i(0, 1)]
			var turn := posmod(roundi(direction.angle() / (PI / 2.0)), 4)
			for offset in chip:
				var o := offset
				for i in turn:
					o = Vector2i(-o.y, o.x)
				cell(canvas, c + o, color)
			if core.a > 0.0:
				cell(canvas, c, core)
		VfxElementDef.Bit.SHARD:
			# A sliver of ice: s+1 pixels along a diagonal-ish direction, a bright tip.
			var cells: Array[Vector2i] = []
			for i in s + 1:
				cells.append(Vector2i(roundi(d.x * i), roundi(d.y * i)))
			_cells(canvas, c, cells, color)
			if core.a > 0.0:
				cell(canvas, c + Vector2i(roundi(d.x * s), roundi(d.y * s)), core)
		VfxElementDef.Bit.TEARDROP:
			# A flame lick: a round base and a point toward `direction`.
			_cells(canvas, c, _plus(1) if s > 1 else [Vector2i.ZERO], color)
			cell(canvas, c + Vector2i(roundi(d.x * s), roundi(d.y * s)), color)
			if core.a > 0.0:
				cell(canvas, c, core)
		VfxElementDef.Bit.CROSS:
			# A spark: a thin plus, arms of s pixels.
			var cells: Array[Vector2i] = [Vector2i.ZERO]
			for i in range(1, s + 1):
				cells.append_array([Vector2i(i, 0), Vector2i(-i, 0), Vector2i(0, i), Vector2i(0, -i)])
			_cells(canvas, c, cells, color)
			if core.a > 0.0:
				cell(canvas, c, core)
		VfxElementDef.Bit.RING:
			# A bubble: a hollow square-ish ring with a shine.
			var r := maxi(s, 1)
			var cells: Array[Vector2i] = []
			for i in range(-r + 1, r):
				cells.append_array([Vector2i(i, -r), Vector2i(i, r), Vector2i(-r, i), Vector2i(r, i)])
			_cells(canvas, c, cells, color)
			if core.a > 0.0:
				cell(canvas, c + Vector2i(-r + 1, -r + 1), core)
		VfxElementDef.Bit.GLINT:
			# A four-point glint: a plus with longer vertical arms (holy, arcane).
			var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0)]
			for i in range(1, s + 2):
				cells.append_array([Vector2i(0, i), Vector2i(0, -i)])
			_cells(canvas, c, cells, color)
			if core.a > 0.0:
				cell(canvas, c, core)
		VfxElementDef.Bit.DROP:
			# A drop: a pixel with one under it (blood, water), wider when big.
			var cells: Array[Vector2i] = [Vector2i.ZERO, Vector2i(0, 1)]
			if s > 1:
				cells.append_array([Vector2i(-1, 1), Vector2i(1, 1), Vector2i(0, 2)])
			_cells(canvas, c, cells, color)
			if core.a > 0.0:
				cell(canvas, c, core)
		_:
			# SQUARE, MOTE: a block of s x s pixels.
			canvas.draw_rect(Rect2(Vector2(c) * PX, Vector2.ONE * PX * s), color)
			if core.a > 0.0 and s > 1:
				cell(canvas, c, core)


## Frame `frame` of `sheet` centered on `at`, facing `direction` (a ROWS sheet picks its row, a
## SNAPPED one turns to the nearest allowed angle), at the sheet's whole texel size, in
## `element`'s ramp when the sheet is recolored. `flip` mirrors it (a claw from the other side);
## `variant` picks a row of a sheet of variants.
static func sheet(canvas: CanvasItem, def: VfxSheetDef, frame: int, at: Vector2, direction: Vector2 = Vector2.RIGHT, element: VfxElementDef = null, tint: Color = Color.WHITE, flip: bool = false, variant: int = 0) -> void:
	if def == null or def.texture == null:
		return
	var texture := def.texture
	if def.recolor and element:
		texture = VfxRamp.recolor(texture, element.ramp)
	var region := def.region(frame, direction, variant)
	var size := region.size * def.texel
	var angle := def.angle_for(direction)
	var offset := def.anchor * def.texel
	if angle == 0.0 and not flip:
		canvas.draw_texture_rect_region(texture, Rect2(snap(at - size * 0.5 + offset), size), region, tint)
		return
	canvas.draw_set_transform(snap(at), angle, Vector2(-1.0 if flip else 1.0, 1.0))
	canvas.draw_texture_rect_region(texture, Rect2(snap(-size * 0.5 + offset), size), region, tint)
	canvas.draw_set_transform(Vector2.ZERO)


static func _cells(canvas: CanvasItem, origin: Vector2i, cells: Array, color: Color) -> void:
	for offset: Vector2i in cells:
		cell(canvas, origin + offset, color)


static func _plus(r: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if absi(x) + absi(y) <= r:
				cells.append(Vector2i(x, y))
	return cells


## `direction` reduced to one of 8 grid steps (so shapes stay crisp).
static func _octant(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.UP
	var step := roundi(direction.angle() / (PI / 4.0))
	return Vector2(roundf(cos(step * PI / 4.0)), roundf(sin(step * PI / 4.0)))
