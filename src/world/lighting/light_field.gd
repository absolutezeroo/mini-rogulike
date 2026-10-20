class_name LightField
extends Node2D
## The floor's light, in steps like the art: every half tile has a light level from 0 to 15,
## and each level is one flat band of color (LightingDef.ramp: the color changes as the light
## fades). A lamp of level 12 lights its tile 12, the next tiles 11, then 10... It spreads
## around corners but walls stop it. Cliff faces catch it (their whole tile). The plateau above is
## covered in mist (PlateauMist): a lamp by a wall glows into it, fading twice as fast (two levels
## a tile), and light that went into the mist never comes out on the other side.
##
## Lights are LightSources. Those that stay put are spread once (and again when one appears,
## goes out or changes); moving ones (the hero's torch, glowing shots, flashes) are added every
## frame by a shader. The result is drawn one pixel per cell in a small viewport, then
## stretched over the floor and multiplied with it: nothing ever gets brighter than the art.

const MAX_LEVEL := 15
## What each cell is, for the light.
const OPEN := 0
const FACE := 1  ## a cliff face (two tiles high): catches the light, doesn't pass it on
const SOLID := 2  ## the plateau, in its mist: lit only from the edge, fading fast
## Cells per tile, each way.
const CELLS := 2
## Cost of a step to the side, and diagonally; one level is lost every STEP (one tile).
const SIDE := 2
const DIAGONAL := 3
const STEP := SIDE * CELLS
## In the mist: a level lost every half tile.
const MIST_SIDE := SIDE * 2
const MIST_DIAGONAL := DIAGONAL * 2
## Moving lights drawn at once (the nearest to the hero).
const MAX_MOVING := 24
## Over the floor, whoever walks on it and their hits' sparks below 5 (those shine on their own).
const Z := 3
const SHADER := preload("res://src/world/lighting/light_cells.gdshader")
const NEIGHBOURS: Array[Vector3i] = [
	Vector3i(1, 0, SIDE), Vector3i(-1, 0, SIDE), Vector3i(0, 1, SIDE), Vector3i(0, -1, SIDE),
	Vector3i(1, 1, DIAGONAL), Vector3i(-1, 1, DIAGONAL), Vector3i(1, -1, DIAGONAL), Vector3i(-1, -1, DIAGONAL),
]

## Light everywhere on this floor, lamps or not.
var ambient_level := MAX_LEVEL
## Color of each level (the ramp, tinted for the floor).
var colors := PackedColorArray()
var tint_strength := 0.0

var _map: DungeonMap
var _size := Vector2i.ZERO
var _cell_size := 16.0
var _walls := PackedByteArray()
var _levels := PackedByteArray()
var _tints := PackedByteArray()
## Each cell's light before rounding to levels (level x STEP minus the way there).
var _value := PackedInt32Array()
## Cells with a lamp on them (a lamp on a wall still shines out).
var _starts := PackedByteArray()
var _revision := -1
var _baked := ImageTexture.new()
var _viewport: SubViewport
var _cells: ColorRect
var _material := ShaderMaterial.new()


func _ready() -> void:
	z_index = Z
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	multiply.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = multiply
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.size = Vector2i.ONE
	_cells = ColorRect.new()
	_material.shader = SHADER
	_cells.material = _material
	_viewport.add_child(_cells)
	add_child(_viewport)


## Lights a new floor. `tint` (the difficulty's darkness, a curse's or an event's color): its
## brightness lowers (or raises) the floor's own light, its color tints it (less and less by the
## lamps).
func setup(map: DungeonMap, lighting: LightingDef, tint: Color = Color.WHITE) -> void:
	_map = map
	_cell_size = float(map.tile_size) / CELLS
	_size = Vector2i(map.width, map.height) * CELLS
	var brightness := maxf(maxf(tint.r, tint.g), maxf(tint.b, 0.001))
	var hue := Color(tint.r / brightness, tint.g / brightness, tint.b / brightness)
	ambient_level = clampi(roundi((lighting.ambient_level if lighting else MAX_LEVEL) * brightness), 0, MAX_LEVEL)
	# Darker floors are a shade darker too, below the lamps (so two difficulties never look alike).
	hue = Color(hue * sqrt(minf(brightness, 1.0)), 1.0)
	tint_strength = lighting.tint_strength if lighting else 0.0
	colors.resize(MAX_LEVEL + 1)
	var ramp := Image.create(MAX_LEVEL + 1, 1, false, Image.FORMAT_RGBA8)
	for level in MAX_LEVEL + 1:
		# The floor's color in its own light, fading out by the lamps (they keep theirs).
		var lamp := clampf(float(level - ambient_level) / maxf(MAX_LEVEL - ambient_level, 1.0), 0.0, 1.0)
		colors[level] = (lighting.color_of(level) if lighting else Color.WHITE) * hue.lerp(Color.WHITE, lamp)
		ramp.set_pixel(level, 0, Color(colors[level], 1.0))
	var count := _size.x * _size.y
	_walls.resize(count)
	for y in _size.y:
		for x in _size.x:
			var tile := Vector2i(x / CELLS, y / CELLS)
			_walls[y * _size.x + x] = OPEN if map.is_floor(tile) else (FACE if _is_face(map, tile) else SOLID)
	_levels.resize(count)
	_tints.resize(count * 4)
	_value.resize(count)
	_starts.resize(count)
	_viewport.size = _size
	_cells.size = Vector2(_size)
	_material.set_shader_parameter("walls", ImageTexture.create_from_image(Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_R8, _scaled(_walls, 127))))
	_material.set_shader_parameter("ramp", ImageTexture.create_from_image(ramp))
	_material.set_shader_parameter("grid", Vector2(_size))
	_material.set_shader_parameter("ambient_level", float(ambient_level))
	_material.set_shader_parameter("tint_strength", tint_strength)
	_revision = -1
	_bake()
	queue_redraw()


## The light level at a point of the floor (what the shader shows there).
func level_at(point: Vector2) -> int:
	var cell := _cell_of(point)
	if _map == null or not _in_grid(cell):
		return ambient_level
	if _revision != LightSource.revision:
		_bake()
	var best := maxi(ambient_level, _levels[_index(cell)])
	for source in _moving_lights(point):
		best = maxi(best, _moving_level(source, cell))
	return best


func color_at(point: Vector2) -> Color:
	return colors[level_at(point)] if not colors.is_empty() else Color.WHITE


func _process(_delta: float) -> void:
	if _map == null:
		return
	if _revision != LightSource.revision:
		_bake()
	var centre := get_viewport().get_camera_2d().get_screen_center_position() if get_viewport().get_camera_2d() else Vector2.ZERO
	var moving := _moving_lights(centre)
	var at := PackedVector4Array()
	var tints := PackedColorArray()
	at.resize(MAX_MOVING)
	tints.resize(MAX_MOVING)
	for i in moving.size():
		var source := moving[i]
		var cell := _cell_of(source.global_position)
		at[i] = Vector4(cell.x + 0.5, cell.y + 0.5, source.level_over(ambient_level), 0.0)
		tints[i] = _normalized(source.color)
	_material.set_shader_parameter("lights", at)
	_material.set_shader_parameter("light_colors", tints)
	_material.set_shader_parameter("light_count", moving.size())


func _draw() -> void:
	if _map == null:
		return
	var area := Rect2(Vector2.ZERO, Vector2(_size) * _cell_size)
	draw_texture_rect(_viewport.get_texture(), area, false)
	# Beyond the map: the floor's own light.
	var far := 4096.0
	var dim := colors[ambient_level]
	draw_rect(Rect2(area.position.x - far, area.position.y - far, area.size.x + far * 2.0, far), dim)
	draw_rect(Rect2(area.position.x - far, area.end.y, area.size.x + far * 2.0, far), dim)
	draw_rect(Rect2(area.position.x - far, area.position.y, far, area.size.y), dim)
	draw_rect(Rect2(area.end.x, area.position.y, far, area.size.y), dim)


# --- Lights that stay put: spread through the cells ----------------------------------

func _bake() -> void:
	_revision = LightSource.revision
	_value.fill(0)
	_starts.fill(0)
	_tints.fill(0)
	var buckets: Array[Array] = []
	buckets.resize(MAX_LEVEL * STEP + 1)
	for i in buckets.size():
		buckets[i] = []
	for node in get_tree().get_nodes_in_group(LightSource.GROUP):
		var source := node as LightSource
		if source == null or source.moves or not source.is_lit():
			continue
		var value := source.level_over(ambient_level) * STEP
		if value < (ambient_level + 1) * STEP:
			continue  # no brighter than the floor's own light
		var tint := _normalized(source.color)
		# A lamp on a tile's centre sits where four cells meet: it lights all four.
		for index in _start_cells(source.global_position):
			_starts[index] = 1
			if value > _value[index]:
				_value[index] = value
				_tints[index * 4] = roundi(tint.r * 255.0)
				_tints[index * 4 + 1] = roundi(tint.g * 255.0)
				_tints[index * 4 + 2] = roundi(tint.b * 255.0)
				buckets[value].append(index)
	_levels.fill(0)
	_spread(buckets)
	_baked.set_image(Image.create_from_data(_size.x, _size.y, false, Image.FORMAT_RGBA8, _tints))
	_material.set_shader_parameter("baked", _baked)


## Spreads all the lights at once, brightest first (each cell is settled once): a cell's value
## is its best lamp's level x STEP minus the cost of the way there, so it loses one level per
## tile, goes around corners, never through a wall nor between two walls touching by a corner.
## A cliff face catches the light on its whole tile. The mist on the plateau takes it in from the
## floor or a face, fading twice as fast, and never gives it back (no light through the walls
## into the next room). A cell takes the color of its best lamp. It stops where it gets no
## brighter than the floor's own light.
func _spread(buckets: Array[Array]) -> void:
	var width := _size.x
	var lit_min := (ambient_level + 1) * STEP
	for value in range(buckets.size() - 1, 0, -1):
		for index: int in buckets[value]:
			if _value[index] != value:
				continue  # reached brighter since
			var level := value / STEP
			_levels[index] = level
			_tints[index * 4 + 3] = level * 17
			var x := index % width
			var y := index / width
			var kind := _walls[index]
			var in_wall := kind != OPEN and _starts[index] == 0
			for step in NEIGHBOURS:
				var nx := x + step.x
				var ny := y + step.y
				if nx < 0 or ny < 0 or nx >= width or ny >= _size.y:
					continue
				var next := ny * width + nx
				var next_kind := _walls[next]
				if next_kind == SOLID:
					# Into the mist (or on through it): from anywhere, fading fast; diagonally
					# only through mist.
					if step.z == DIAGONAL and (_walls[y * width + nx] != SOLID or _walls[ny * width + x] != SOLID):
						continue
					var mist_value := value - (MIST_DIAGONAL if step.z == DIAGONAL else MIST_SIDE)
					if mist_value < lit_min or _value[next] >= mist_value:
						continue
					_value[next] = mist_value
					_tints[next * 4] = _tints[index * 4]
					_tints[next * 4 + 1] = _tints[index * 4 + 1]
					_tints[next * 4 + 2] = _tints[index * 4 + 2]
					buckets[mist_value].append(next)
					continue
				if kind == SOLID and _starts[index] == 0:
					continue  # the mist never gives light back
				var next_value := value - step.z
				if next_value < lit_min:
					continue
				# In a wall: only on through its own tile, or up the cliff face it belongs to.
				if in_wall and nx / CELLS != x / CELLS:
					continue
				if in_wall and ny / CELLS != y / CELLS and (step.x != 0 or next_kind != FACE):
					continue
				if step.z == DIAGONAL and (_walls[y * width + nx] != OPEN or _walls[ny * width + x] != OPEN):
					continue
				if _value[next] >= next_value:
					continue
				_value[next] = next_value
				_tints[next * 4] = _tints[index * 4]
				_tints[next * 4 + 1] = _tints[index * 4 + 1]
				_tints[next * 4 + 2] = _tints[index * 4 + 2]
				buckets[next_value].append(next)


# --- Moving lights --------------------------------------------------------------------

## The lit moving lights, nearest to `centre` first, at most MAX_MOVING.
func _moving_lights(centre: Vector2) -> Array[LightSource]:
	var result: Array[LightSource] = []
	for node in get_tree().get_nodes_in_group(LightSource.GROUP):
		var source := node as LightSource
		if source and source.moves and source.is_lit():
			result.append(source)
	if result.size() > MAX_MOVING:
		result.sort_custom(func(a: LightSource, b: LightSource) -> bool:
			return a.global_position.distance_squared_to(centre) < b.global_position.distance_squared_to(centre))
		result.resize(MAX_MOVING)
	return result


## What a moving light gives a cell (the shader's sums, for the game and the tests).
func _moving_level(source: LightSource, cell: Vector2i) -> int:
	var at := Vector2(_cell_of(source.global_position)) + Vector2(0.5, 0.5)
	var to := Vector2(cell) + Vector2(0.5, 0.5)
	var lit := source.level_over(ambient_level) - floori(at.distance_to(to) * 0.5)
	if lit <= 0:
		return 0
	var d := at - to
	var steps := ceili(maxf(absf(d.x), absf(d.y)))
	if _in_grid(cell) and _walls[_index(cell)] == SOLID:
		# Into the mist: over the floor and the faces, then the mist (never out of it and in
		# again: that is through a wall), a level more lost every mist tile.
		var misty := 1
		var entered := false
		for k in range(steps - 1, 0, -1):
			var p := Vector2i((to + d * (float(k) / steps)).floor())
			var kind := _walls[_index(p)] if _in_grid(p) else SOLID
			if kind == SOLID:
				entered = true
				misty += 1
			elif entered:
				return 0
		return maxi(lit - floori(misty * 0.5), 0)
	for k in range(1, steps):
		var p := Vector2i((to + d * (float(k) / steps)).floor())
		if _in_grid(p) and _walls[_index(p)] != OPEN and not _same_face(p, cell):
			return 0
	return lit


# --- Cells ----------------------------------------------------------------------------

## A wall tile showing the cliff: right above the floor, or right above such a tile.
static func _is_face(map: DungeonMap, tile: Vector2i) -> bool:
	if map.is_floor(tile + Vector2i.DOWN):
		return true
	return not map.is_floor(tile + Vector2i.DOWN) and map.in_bounds(tile + Vector2i.DOWN * 2) and map.is_floor(tile + Vector2i.DOWN * 2)


## True if wall cell `p` is part of the cliff face `target` is on (its tile, or the tile below):
## light reaching `target` there may cross it.
static func _same_face(p: Vector2i, target: Vector2i) -> bool:
	var a := p / CELLS
	var b := target / CELLS
	return a.x == b.x and (a.y == b.y or a.y == b.y + 1)


## The cells a still light starts from: those within a quarter cell of it (one, or the four
## around a tile's centre).
func _start_cells(point: Vector2) -> Array[int]:
	var result: Array[int] = []
	var quarter := _cell_size * 0.25
	for offset: Vector2 in [Vector2(-quarter, -quarter), Vector2(quarter, -quarter), Vector2(-quarter, quarter), Vector2(quarter, quarter)]:
		var cell := _cell_of(point + offset)
		if _in_grid(cell) and not result.has(_index(cell)):
			result.append(_index(cell))
	return result


## The cell under a point of the world.
func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i((to_local(point) / _cell_size).floor())


func _in_grid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _size.x and cell.y < _size.y


func _index(cell: Vector2i) -> int:
	return cell.y * _size.x + cell.x


## A light's color with its brightest channel at 1 (lights color, they don't darken).
static func _normalized(color: Color) -> Color:
	var top := maxf(maxf(color.r, color.g), maxf(color.b, 0.001))
	return Color(color.r / top, color.g / top, color.b / top)


static func _scaled(bytes: PackedByteArray, factor: int) -> PackedByteArray:
	var result := bytes.duplicate()
	for i in result.size():
		result[i] = bytes[i] * factor
	return result
