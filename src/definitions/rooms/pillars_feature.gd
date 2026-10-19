class_name PillarsFeature
extends RoomFeature
## Columns in rows (or a ring) through the room: a PropDef (unbreakable, usually) at each spot.
## They stay off the ring along the walls, so the way through is never blocked.

enum Pattern { GRID, RING, TWO_ROWS }

@export var pillar: PropDef
@export var pattern: Pattern = Pattern.GRID
## Cells from one column to the next.
@export var spacing: Vector2i = Vector2i(3, 3)
@export_range(2, 4) var margin: int = 2
## Chance for each column to be missing (fallen): no two halls alike.
@export_range(0.0, 1.0) var missing_chance: float = 0.15


func furnish(world: World, room: Rect2i, taken: Dictionary) -> void:
	if pillar == null:
		return
	var space := inner(room, margin)
	if space.size.x < pillar.footprint.x or space.size.y < pillar.footprint.y:
		return
	for cell in _spots(space, pillar.footprint):
		if world.rng.randf() < missing_chance:
			continue
		var area := Rect2i(cell, pillar.footprint)
		if not space.encloses(area) or not HazardDef.is_free(world, area, taken) or not stays_open(world, room, area):
			continue
		world.spawn_prop(pillar, cell)
		HazardDef.take_rect(taken, area)


func _spots(space: Rect2i, size: Vector2i) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	var step := Vector2i(maxi(spacing.x, size.x + 1), maxi(spacing.y, size.y + 1))
	var columns := (space.size.x - size.x) / step.x + 1
	var rows := (space.size.y - size.y) / step.y + 1
	# Centered in the room.
	var start := space.position + (space.size - Vector2i((columns - 1) * step.x + size.x, (rows - 1) * step.y + size.y)) / 2
	match pattern:
		Pattern.GRID:
			for row in rows:
				for column in columns:
					spots.append(start + Vector2i(column * step.x, row * step.y))
		Pattern.TWO_ROWS:
			for column in columns:
				spots.append(Vector2i(start.x + column * step.x, space.position.y))
				spots.append(Vector2i(start.x + column * step.x, space.end.y - size.y))
		Pattern.RING:
			for column in columns:
				spots.append(Vector2i(start.x + column * step.x, space.position.y))
				spots.append(Vector2i(start.x + column * step.x, space.end.y - size.y))
			for row in range(1, rows - 1):
				spots.append(Vector2i(space.position.x, start.y + row * step.y))
				spots.append(Vector2i(space.end.x - size.x, start.y + row * step.y))
	return spots
