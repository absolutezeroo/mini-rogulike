class_name DungeonConfig
extends Resource
## Tuning for floor generation and difficulty.

## Floor looks, used in order: depth 1 uses the first, depth 2 the second, and so on (looping).
@export var themes: Array[DungeonTheme] = []

@export_group("Layout")
@export var tile_size: int = 32
@export var width: int = 64
@export var height: int = 64
@export var max_rooms: int = 12
@export var room_min_size: int = 7
@export var room_max_size: int = 13
@export_range(1, 5) var corridor_width: int = 3

@export_group("Population")
@export var monsters_per_room_min: int = 1
@export var monsters_per_room_max: int = 3
## Extra monsters per room for each depth below the first.
@export var extra_monsters_per_depth: float = 0.5
@export var max_monsters_per_room: int = 6
@export var items_per_floor: int = 4

@export_group("Bosses")
## Every Nth floor is a boss arena (3 = floors 3, 6, 9...). 0 = no bosses.
@export_range(0, 20) var boss_every: int = 3
## Used in order on boss floors, looping: the first on floor 3, the second on floor 6...
@export var bosses: Array[BossDef] = []
## Size of the arena room, in cells.
@export var arena_size: Vector2i = Vector2i(21, 15)

@export_group("Difficulty")
## Monster HP grows by this fraction per depth (0.15 = +15% per floor).
@export var monster_hp_scale_per_depth: float = 0.15
@export var monster_attack_per_depth: int = 1


func theme_for_depth(depth: int) -> DungeonTheme:
	if themes.is_empty():
		return null
	return themes[(depth - 1) % themes.size()]


## The boss guarding `depth`, or null when it is a normal floor.
func boss_for_depth(depth: int) -> BossDef:
	if boss_every <= 0 or bosses.is_empty() or depth % boss_every != 0:
		return null
	return bosses[(depth / boss_every - 1) % bosses.size()]
