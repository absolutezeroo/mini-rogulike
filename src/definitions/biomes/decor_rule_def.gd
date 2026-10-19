class_name DecorRuleDef
extends Resource
## Small things lying on the ground (16 px pieces, drawn at 2x, nothing to bump into): grass,
## pebbles, bones, books... As in hand-made levels, never sprinkled over the whole floor: each
## piece has a reason to be where it is (`where`: at the foot of a wall, around a scene's
## furniture, on its ground), the middle of the rooms and the corridors stay clear, and a room
## holds a few at most (`max_per_room`). Noise gathers them in little clusters.

enum Where {
	ALONG_WALLS,  ## at the foot of the walls (debris, pebbles, ferns)
	AROUND_SCENES,  ## right around what the scenes put up (books by the shelves, bones by graves)
	ON_GROUND,  ## on `ground` only (grass on moss), anywhere in the rooms
}

@export var pieces: Array[Texture2D] = []
@export var where: Where = Where.ALONG_WALLS
## For ON_GROUND.
@export var ground: GroundLayerDef
## Chance for each cell that qualifies.
@export_range(0.0, 1.0) var density: float = 0.1
## At most this many in a room.
@export_range(0, 20) var max_per_room: int = 3
## 0: anywhere it qualifies; 1: only in tight clusters.
@export_range(0.0, 1.0) var clumping: float = 0.6
## Size of the clusters.
@export_range(0.02, 0.5) var noise_scale: float = 0.2
## Plants: they sway and bend when walked through.
@export var sway: bool = false
