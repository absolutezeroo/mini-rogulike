class_name DungeonConfig
extends Resource
## Tuning for floor generation and difficulty.

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

@export_group("Difficulty")
## Monster HP grows by this fraction per depth (0.15 = +15% per floor).
@export var monster_hp_scale_per_depth: float = 0.15
@export var monster_attack_per_depth: int = 1
