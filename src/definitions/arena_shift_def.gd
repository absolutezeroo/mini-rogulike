class_name ArenaShiftDef
extends Resource
## One change of a boss arena (ArenaDef.shifts): which cells (a pattern), what they become, and
## a warning first (the cells blink red) so the hero can get out of the way.

enum Pattern {
	## A band along the arena's edge, `width` cells wide: the arena shrinks.
	EDGE,
	## Lines through the middle, across and down (the middle itself stays clear).
	CROSS,
	## `count` cells here and there.
	SCATTER,
	## A block in each corner, `width` cells wide.
	CORNERS,
}
enum Becomes {
	## Holes: whoever stands there falls.
	PIT,
	## Cracked floor: it gives way once stepped on.
	CRUMBLE,
	## Spikes rising and falling.
	SPIKES,
}

@export var pattern: Pattern = Pattern.EDGE
@export var becomes: Becomes = Becomes.CRUMBLE
@export_range(1, 6) var width: int = 1
@export_range(1, 60) var count: int = 8
## Said when it happens ("The floor gives way!").
@export var message: String = ""
@export var warning_time: float = 1.4
@export var pit: PitDef
@export var trap: TrapDef


## The cells of `arena_cells` this change takes (`room`: the arena's rectangle). Never within
## `keep_clear` cells of any point in `keep` (the hero, the boss). `ground`: every floor cell of
## the arena, pillars included (the edge is where the floor ends, not where a pillar stands).
func pick_cells(arena_cells: Array[Vector2i], room: Rect2i, keep: Array[Vector2i], keep_clear: int, rng: RandomNumberGenerator, ground: Dictionary = {}) -> Array[Vector2i]:
	var lookup := {}
	for cell in arena_cells:
		lookup[cell] = true
	if not ground.is_empty():
		lookup = ground
	var center := room.get_center()
	var picked: Array[Vector2i] = []
	for cell in arena_cells:
		var take := false
		match pattern:
			Pattern.EDGE:
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					for step in range(1, width + 1):
						take = take or not lookup.has(cell + direction * step)
			Pattern.CROSS:
				var off := cell - center
				take = (absi(off.x) <= int(width / 2.0) or absi(off.y) <= int(width / 2.0)) and maxi(absi(off.x), absi(off.y)) > 2
			Pattern.CORNERS:
				var from_left := cell.x - room.position.x
				var from_top := cell.y - room.position.y
				var from_right := room.end.x - 1 - cell.x
				var from_bottom := room.end.y - 1 - cell.y
				take = mini(from_left, from_right) < width + 2 and mini(from_top, from_bottom) < width + 2 \
					and mini(from_left, from_right) >= 2 and mini(from_top, from_bottom) >= 2
		if take and _clear_of(cell, keep, keep_clear):
			picked.append(cell)
	if pattern == Pattern.SCATTER:
		var pool := arena_cells.filter(func(cell: Vector2i) -> bool:
			return _clear_of(cell, keep, keep_clear) and (cell - center).length() > 2.5)
		RandomUtils.shuffle(pool, rng)
		for cell: Vector2i in pool:
			if picked.size() >= count:
				break
			picked.append(cell)
	return picked


func _clear_of(cell: Vector2i, keep: Array[Vector2i], distance: int) -> bool:
	for other in keep:
		if maxi(absi(cell.x - other.x), absi(cell.y - other.y)) <= distance:
			return false
	return true
