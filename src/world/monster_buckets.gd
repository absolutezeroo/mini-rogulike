class_name MonsterBuckets
extends RefCounted
## The awake monsters (ActivityManager.awake) sorted into a coarse grid once per physics frame, so
## a monster keeping its distance from the others (MonsterSteering.keep_spacing) looks only at those in
## the cells around it instead of the whole list: with 40 awake, 1,600 checks a frame became a few
## dozen (docs/performance.md).
##
## The grid is laid at the first question of a frame, from where the monsters stand then; those
## that already moved this frame moved a few pixels at most, which `MARGIN` covers. The answer is
## a superset of the monsters close enough, in the list's own order, so the sums made over it are
## the same as over the whole list (same floats, same seeded fights).

## Grid cell, px: about two small bodies side by side.
const CELL := 32.0
## Slack around a question's reach, px: how far a body may have moved since the grid was laid
## (a frame's dash or knockback stays well under it).
const MARGIN := 16.0

var _list: Array = []
var _frame := -1
var _cells := {}  # Vector2i -> Array[int] (indices into _list)
var _max_radius := 0.0
var _found := PackedInt32Array()


## The grid is stale (the awake list was rebuilt): laid again at the next question.
func invalidate() -> void:
	_frame = -1


## Indices into `list` of the monsters that may lie within `reach` px of `at` (plus their own
## radius), sorted (the list's order). The array is reused: read it before the next call.
func near(list: Array, at: Vector2, reach: float) -> PackedInt32Array:
	var frame := Engine.get_physics_frames()
	if frame != _frame or not is_same(list, _list):
		_build(list, frame)
	var span := reach + _max_radius + MARGIN
	var low := Vector2i(floori((at.x - span) / CELL), floori((at.y - span) / CELL))
	var high := Vector2i(floori((at.x + span) / CELL), floori((at.y + span) / CELL))
	_found.clear()
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var bucket: Variant = _cells.get(Vector2i(x, y))
			if bucket != null:
				for index: int in bucket:
					_found.append(index)
	_found.sort()
	return _found


func _build(list: Array, frame: int) -> void:
	_list = list
	_frame = frame
	_cells.clear()
	_max_radius = 0.0
	for i in list.size():
		var entry: Variant = list[i]
		if not is_instance_valid(entry):
			continue
		var monster := entry as Monster
		_max_radius = maxf(_max_radius, monster.radius)
		var key := Vector2i(floori(monster.global_position.x / CELL), floori(monster.global_position.y / CELL))
		var bucket: Variant = _cells.get(key)
		if bucket == null:
			_cells[key] = [i]
		else:
			(bucket as Array).append(i)
