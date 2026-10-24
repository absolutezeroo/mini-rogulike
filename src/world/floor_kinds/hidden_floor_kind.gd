class_name HiddenFloorKind
extends BossFloorKind
## The hidden floor (HiddenFloorDef): its own world, a few rooms of its own monsters before its
## boss' arena (laid by the def, from the seed too: a resumed run lays them again and the save
## takes back what was spent). Its depth is the boss floor's before it, its seed its own
## (Game._enter_floor()).

var def: HiddenFloorDef


func _init(hidden: HiddenFloorDef) -> void:
	super(hidden.boss)
	def = hidden


## Its own world (before a forced one); the act draws one if it has none.
func pick_biome(world: World, content: ContentDB) -> BiomeDef:
	return def.biome if def.biome else super(world, content)


func generate(world: World, content: ContentDB) -> DungeonMap:
	return DungeonGenerator.generate_hidden(content.dungeon, world.rng, world.arena_plan, def.rooms)


func _lay_more(world: World) -> void:
	def.populate(world)
