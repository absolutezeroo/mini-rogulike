class_name FloorOverrides
extends RefCounted
## Debug (the debug panel, its monster gallery, the level and balance tools): what the next floor
## built gets instead of what it would roll. One object instead of a handful of loose fields on
## the World. Each is used once: the floor that reads it takes it (the take_*() calls clear it),
## so the floor after is the seed's again.

## The next floor's curse or event instead of rolling one; `plain`: neither (all three are one
## twist: taken together by take_twist()).
var curse: CurseDef
var event: FloorEventDef
var plain := false
## The next floor is this biome.
var biome: BiomeDef
## The next floor that has no boss is this map instead of a generated one (the monster gallery,
## DebugGallery). Dropped by the next floor built, boss or not (World.build_floor()).
var map: DungeonMap
## The next boss arena is this one.
var arena: ArenaDef
## The next boss comes at this rank.
var boss_rank: MonsterRankDef


## A twist is forced on the next floor (ForcedFloorKind).
func has_twist() -> bool:
	return curse != null or event != null or plain


## The forced twist as a way holding only it (FloorRoute: curse and event, no world); cleared.
func take_twist() -> FloorRoute:
	var twist := FloorRoute.new()
	twist.curse = curse
	twist.floor_event = event
	curse = null
	event = null
	plain = false
	return twist


func take_biome() -> BiomeDef:
	var forced := biome
	biome = null
	return forced


func take_arena() -> ArenaDef:
	var forced := arena
	arena = null
	return forced


func take_boss_rank() -> MonsterRankDef:
	var forced := boss_rank
	boss_rank = null
	return forced
