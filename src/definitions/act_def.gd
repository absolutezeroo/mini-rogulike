class_name ActDef
extends Resource
## A chapter of the run: a few floors with one look, one set of monsters and a boss at the end.
## The run is the list of acts in DungeonConfig.acts; beating the last boss wins it.

@export var title: String = "Act"
## Shown under the title when the act begins.
@export var subtitle: String = ""
## A line or two of story on the card shown when the act begins.
@export_multiline var lore: String = ""
@export var theme: DungeonTheme
## Floors in this act. The last one is the boss arena.
@export_range(1, 10) var floors: int = 3
## Monsters met on the act's floors (their spawn_weight decides how often).
@export var monsters: Array[MonsterDef] = []
@export var boss: BossDef
## Other bosses that may guard the act instead (one is drawn for each run).
@export var other_bosses: Array[BossDef] = []
## Traps, holes, quicksand... laid out in the act's rooms (min_depth and spawn_weight decide).
@export var hazards: Array[HazardDef] = []


## The main boss and the alternatives.
func all_bosses() -> Array[BossDef]:
	var result: Array[BossDef] = []
	if boss:
		result.append(boss)
	for other in other_bosses:
		if other and not result.has(other):
			result.append(other)
	return result


func pick_hazard(depth: int, rng: RandomNumberGenerator) -> HazardDef:
	return ContentDB.pick_from(hazards, depth, rng) as HazardDef
