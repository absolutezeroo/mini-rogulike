class_name DungeonConfig
extends Resource
## The run (acts, in order) and tuning for floor generation and difficulty.

## The acts of a run, in order. Beating the last act's boss wins the run; after that the
## acts loop (endless mode), harder every time because monsters scale with depth.
@export var acts: Array[ActDef] = []

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

@export_group("Props and traps")
## Lantern placed along the walls of every room (light in the dark).
@export var room_light: PropDef
@export_range(0, 6) var lights_per_room: int = 2
## Small groups of crates, pots and barrels per room.
@export_range(0, 10) var prop_clusters_min: int = 0
@export_range(0, 10) var prop_clusters_max: int = 2
## Groups of traps per floor (a row of spikes, a few plates...).
@export_range(0, 20) var trap_groups_min: int = 2
@export_range(0, 20) var trap_groups_max: int = 4

@export_group("Bosses")
## Size of the arena room, in cells.
@export var arena_size: Vector2i = Vector2i(21, 15)

@export_group("Difficulty")
## Monster HP grows by this fraction per depth (0.15 = +15% per floor).
@export var monster_hp_scale_per_depth: float = 0.15
@export var monster_attack_per_depth: int = 1


## Floors in one pass through every act.
func total_floors() -> int:
	var total := 0
	for act in acts:
		total += act.floors
	return total


## Index in `acts` of the act holding `depth` (looping after the last one).
func act_index(depth: int) -> int:
	if acts.is_empty():
		return -1
	var floor_number := (depth - 1) % maxi(total_floors(), 1)
	for i in acts.size():
		if floor_number < acts[i].floors:
			return i
		floor_number -= acts[i].floors
	return acts.size() - 1


func act_for_depth(depth: int) -> ActDef:
	var index := act_index(depth)
	return acts[index] if index >= 0 else null


## 1 for the first floor of an act.
func floor_in_act(depth: int) -> int:
	var floor_number := (depth - 1) % maxi(total_floors(), 1)
	for act in acts:
		if floor_number < act.floors:
			return floor_number + 1
		floor_number -= act.floors
	return 1


func theme_for_depth(depth: int) -> DungeonTheme:
	var act := act_for_depth(depth)
	return act.theme if act else null


## The boss guarding `depth` (the last floor of each act), or null on a normal floor.
func boss_for_depth(depth: int) -> BossDef:
	var act := act_for_depth(depth)
	if act == null or floor_in_act(depth) != act.floors:
		return null
	return act.boss


## The floor whose boss ends the run.
func is_final_floor(depth: int) -> bool:
	return depth == total_floors()
