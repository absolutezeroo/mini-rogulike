class_name BossFloorKind
extends FloorKind
## The last floor of an act: its warden (the one drawn for the run, RunState.bosses) in an arena,
## no twist, no seal and no stairs until the warden falls (BossArena spawns them). The arena keeps
## clear: lamps, grounds and decor only.

const ARENA_SCENE := preload("res://src/world/boss_arena.tscn")

var _boss: BossDef


func _init(warden: BossDef) -> void:
	_boss = warden


## The act's warden at `world.depth` for this run: the one drawn for its act (World.run_bosses),
## else `act_boss`, the act's main one.
static func run_boss(world: World, content: ContentDB, act_boss: BossDef) -> BossDef:
	var act_index := content.dungeon.act_index(world.depth)
	if act_index < world.run_bosses.size() and world.run_bosses[act_index] != null:
		return world.run_bosses[act_index]
	return act_boss


func boss() -> BossDef:
	return _boss


## The boss' own arenas, else the dungeon's (the debug one if forced); null for a plain room.
func pick_arena(world: World, content: ContentDB) -> ArenaDef:
	var forced := world.overrides.take_arena()
	if forced:
		return forced
	var pool: Array[ArenaDef] = _boss.arenas if not _boss.arenas.is_empty() else content.dungeon.arenas
	return pool[world.rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else null


func generate(world: World, content: ContentDB) -> DungeonMap:
	return DungeonGenerator.generate_arena(content.dungeon, world.rng, world.arena_plan)


## No stairs until the boss is dead: the arena spawns them.
func lay(world: World, content: ContentDB) -> void:
	var arena := ARENA_SCENE.instantiate() as BossArena
	world.arena = arena
	world.add_entity(arena)
	arena.setup(world, _boss, world.arena_plan)
	for room in world.map.rooms:
		FloorPopulator.place_lights(world, content.dungeon, room, {}, _lamps(world, room))
	FloorDresser.dress(world, {}, false)  # the arena keeps clear: grounds and decor only
	_lay_more(world)
	world.seal.clear()


## Lamps for `room` (-1: as many as the dungeon puts in a room that size).
func _lamps(_world: World, _room: Rect2i) -> int:
	return -1


## What a kind lays beside its arena (the hidden floor's rooms), before the seal is cleared.
func _lay_more(_world: World) -> void:
	pass
