class_name FinaleFloorKind
extends BossFloorKind
## The bottom of the Well (FinaleDef): its own world and arena (drawn first as a warden's floor
## would be, so the floor's dice roll as they always did, then replaced), who waits there this
## run (the Nameless Keeper, else the finale's own boss), and its own lamps in the arena.

var def: FinaleDef


## `waiting`: who waits there this run (RunState.bottom_boss()); null: the finale's own boss.
func _init(bottom: FinaleDef, waiting: BossDef) -> void:
	super(waiting if waiting else bottom.boss)
	def = bottom


func pick_biome(world: World, content: ContentDB) -> BiomeDef:
	var drawn := super(world, content)
	return def.biome if def.biome else drawn


func pick_arena(world: World, content: ContentDB) -> ArenaDef:
	var drawn := super(world, content)
	return def.arena if def.arena else drawn


## The arena's own lamps (the hero's lantern, mostly).
func _lamps(world: World, room: Rect2i) -> int:
	return def.arena_lights if room == world.map.boss_room else -1
