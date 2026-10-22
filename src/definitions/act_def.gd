class_name ActDef
extends Resource
## A chapter of the run: a few floors with one look, one set of monsters and a boss at the end.
## The run is the list of acts in DungeonConfig.acts; beating the last boss wins it.

@export var title: String = "Act"
## Shown under the title when the act begins.
@export var subtitle: String = ""
## A line or two of story on the card shown when the act begins.
@export_multiline var lore: String = ""
## Its floors' worlds (a mossy cave, an underground garden...): each floor is one of them, whole.
@export var biomes: Array[BiomeDef] = []
## The boss arena's (empty: the first biome).
@export var boss_biome: BiomeDef
## Floors in this act. The last one is the boss arena.
@export_range(1, 10) var floors: int = 3
## Monsters met on the act's floors (their spawn_weight decides how often).
@export var monsters: Array[MonsterDef] = []
## The act's own threat, on every difficulty (FloorRules): its monsters' Health and what their
## attacks and skills deal, on top of the depth's scaling. Not its bosses (tuned one by one,
## BossDef), not the dungeon's own damage (traps, bursts, the cold). Shapes the curve where the
## hero's power outgrows the depth's steady scaling (docs/balance-log.md, the Keeper curve).
@export var monster_hp: float = 1.0
@export var monster_damage: float = 1.0
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


## The biome of a floor of this act (its boss arena's if `boss`).
func pick_biome(depth: int, boss: bool, rng: RandomNumberGenerator) -> BiomeDef:
	if boss and boss_biome:
		return boss_biome
	var picked := ContentDB.pick_from(biomes, depth, rng) as BiomeDef
	return picked if picked else main_biome()


## The act's look and music on its cards and menus: the boss arena's, or the first biome's.
func main_biome() -> BiomeDef:
	if boss_biome:
		return boss_biome
	return biomes[0] if not biomes.is_empty() else null


func pick_hazard(depth: int, rng: RandomNumberGenerator) -> HazardDef:
	return ContentDB.pick_from(hazards, depth, rng) as HazardDef
