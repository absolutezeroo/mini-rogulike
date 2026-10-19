class_name ArenaDef
extends Resource
## A boss arena's plan: its size and shape, the pillars standing in it, and how it changes as
## the boss loses its HP (ArenaShiftDef, one per phase: the edge crumbles, pits open, spikes
## rise...). Bosses pick among their own (BossDef.arenas) or the dungeon's (DungeonConfig.arenas).

enum Shape {
	RECT,
	## An ellipse inside the size.
	OVAL,
	## Two crossing halls, `arm` cells wide.
	CROSS,
}

@export var id: StringName
@export var display_name: String
## Cells (width, height). Odd sizes keep a true middle.
@export var size: Vector2i = Vector2i(25, 17)
@export var shape: Shape = Shape.RECT
## CROSS: width of each hall.
@export var arm: int = 11

@export_group("Pillars")
## Props standing in the arena (cover from shots, something to dodge around).
@export var pillar: PropDef
## Where, as fractions of the arena (0..1 across, 0..1 down); the middle stays clear for the boss.
@export var pillars: PackedVector2Array = []

@export_group("Changes")
## The arena's changes, the first at the boss' second phase, the next at its third.
@export var shifts: Array[ArenaShiftDef] = []


## The arena's floor cells, for a top-left corner at `origin`.
func cells(origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var center := Vector2(size) * 0.5
	for y in size.y:
		for x in size.x:
			var cell := Vector2i(x, y)
			if contains(cell, center):
				result.append(origin + cell)
	return result


func contains(cell: Vector2i, center: Vector2) -> bool:
	match shape:
		Shape.OVAL:
			var offset := (Vector2(cell) + Vector2(0.5, 0.5) - center) / center
			return offset.length_squared() <= 1.0
		Shape.CROSS:
			var half := arm * 0.5
			var at := Vector2(cell) + Vector2(0.5, 0.5)
			return absf(at.x - center.x) <= half or absf(at.y - center.y) <= half
	return true
