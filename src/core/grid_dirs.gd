class_name GridDirs
extends RefCounted
## The grid's neighbour steps, as shared constants: the floods and walks over cells (the
## generator, the populator, the dressing, the pools) loop over these instead of writing an array
## literal in the loop, built again for every cell (docs/performance.md). The order is the one
## those loops always used (it decides ties: the same seed lays the same floor).

## Left, right, up, down.
const FOUR: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
## Here, then left, right, up, down.
const HERE_AND_FOUR: Array[Vector2i] = [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
