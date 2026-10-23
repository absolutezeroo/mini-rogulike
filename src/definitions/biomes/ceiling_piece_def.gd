class_name CeilingPieceDef
extends Resource
## One kind of thing hanging over a biome's rooms (a root, a chain, a banner, a broken arch...):
## a picture in its CeilingDef's atlas, where it hangs (`where`), how many of it. Drawn over the
## actors by the CeilingLayer, and fading away around anyone under it (docs/vfx.md, 2b).

enum Where {
	## From the cliff above a room's top edge, down over the floor below it (roots, stalactites,
	## banners, awnings).
	TOP_WALL,
	## Down the side walls (vines, roots), turned to face the room.
	SIDE_WALL,
	## In a top corner (cobwebs), turned for the right one.
	CORNER,
	## From the unseen ceiling over the room, its lowest pixel `height` above the floor (chains,
	## censers, cages); never within two cells of a wall.
	OVER_ROOM,
	## Straight across the room from wall to wall (beams, arches): `region` is three parts side by
	## side, the left end, a middle repeated as far as needed, the right end.
	ACROSS,
}

## Its picture in the ceiling's atlas (art pixels: drawn at 2x).
@export var region: Rect2i = Rect2i(0, 0, 16, 32)
@export var where: Where = Where.TOP_WALL
## Chance for each spot that qualifies.
@export_range(0.0, 1.0) var density: float = 0.15
## At most this many in a room (corridors: only `spacing` limits them).
@export_range(0, 20) var max_per_room: int = 3
## Cells from any other piece of the ceiling (keeps them from piling up).
@export_range(1, 12) var spacing: int = 3
## Also along the corridors' walls (TOP_WALL, SIDE_WALL, CORNER).
@export var in_corridors: bool = false
## Flipped left-right half of the time.
@export var mirror: bool = true
## World units between its lowest pixel and the floor under it: its shadow falls that far below
## (0: no shadow). Things hanging high cast theirs further down.
@export_range(0.0, 200.0) var height: float = 0.0
## ACROSS: chance for each middle part to be missing (a broken arch, a fallen beam).
@export_range(0.0, 0.9) var broken: float = 0.0
## Something drawn by the piece, on its own (smoke rising off a censer, sand trickling from a
## crack): a PixelMotes scene put at the piece's `emitter_offset` (from its lowest middle pixel).
@export var emitter: PackedScene
@export var emitter_offset: Vector2 = Vector2.ZERO
