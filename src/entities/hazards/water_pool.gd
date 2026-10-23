class_name WaterPool
extends Node2D
## Deep water in a shaped room's core (RoomShapeDef.Core.POOL): drawn as a ground of its own
## (GroundLayer: a rounded, ragged shore, the water shimmering), nobody walks in it (a body on
## the water layer: shots and sight go over it, as over a pond), its cells blocked for paths.

## Pixels of shore a body may step on at the water's edge.
const SHORE := 8.0

var cells := {}


## `water`: the cells; `look`: the deep water (BiomeDef.pool); `bounds`: the room around it.
func setup(world: World, water: Dictionary, look: GroundLayerDef, bounds: Rect2i) -> void:
	cells = water
	var map := world.map
	if look and Vfx.shown:
		var layer := GroundLayer.new()
		layer.setup(look, map, water, bounds)
		add_child(layer)
	var body := StaticBody2D.new()
	body.collision_layer = Layers.WATER
	body.collision_mask = 0
	add_child(body)
	_build_shapes(body, map)
	for cell: Vector2i in water:
		world.set_cell_blocked(cell, true)


## One rectangle per run of water cells along a row that share their open sides (the shore is
## stepped back by SHORE where there is no water next to it).
func _build_shapes(body: StaticBody2D, map: DungeonMap) -> void:
	var ts := float(map.tile_size)
	var rows := {}
	for cell: Vector2i in cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		(rows[cell.y] as Array).append(cell.x)
	for y: int in rows:
		var xs: Array = rows[y]
		xs.sort()
		var i := 0
		while i < xs.size():
			var start: int = xs[i]
			var top := not cells.has(Vector2i(start, y - 1))
			var bottom := not cells.has(Vector2i(start, y + 1))
			var end := start
			while i + 1 < xs.size() and xs[i + 1] == end + 1 \
					and (not cells.has(Vector2i(end + 1, y - 1))) == top and (not cells.has(Vector2i(end + 1, y + 1))) == bottom:
				i += 1
				end += 1
			i += 1
			var left := SHORE if not cells.has(Vector2i(start - 1, y)) else 0.0
			var right := SHORE if not cells.has(Vector2i(end + 1, y)) else 0.0
			var rect := Rect2(Vector2(start * ts + left, y * ts + (SHORE if top else 0.0)),
				Vector2((end - start + 1) * ts - left - right, ts - (SHORE if top else 0.0) - (SHORE if bottom else 0.0)))
			var shape := RectangleShape2D.new()
			shape.size = rect.size
			var collision := CollisionShape2D.new()
			collision.shape = shape
			collision.position = rect.get_center()
			body.add_child(collision)
