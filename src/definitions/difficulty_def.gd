class_name DifficultyDef
extends Resource
## How hard a run is. Chosen on the title screen before playing.
## Every number is a multiplier on the normal game (1 = unchanged).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var color: Color = Color.WHITE
## Beat a run on this difficulty to unlock this one. Empty = always available.
@export var unlocked_by: DifficultyDef

@export_group("Monsters")
@export var monster_hp: float = 1.0
## Damage of everything that hurts the hero: monster attacks and skills, traps, bursts.
@export var monster_damage: float = 1.0
@export var monster_speed: float = 1.0
## Wind-ups and casts: above 1 = more time to dodge.
@export var telegraph_time: float = 1.0
## How far monsters spot the hero (MonsterDef.detect_radius): they see you from further away on
## harder difficulties.
@export var detect_range: float = 1.0
## Extra monsters in every room.
@export_range(0, 5) var extra_monsters: int = 0
@export var boss_hp: float = 1.0
## Multiplies the chance for a monster to be an elite.
@export var elite_chance: float = 1.0
## Chance for a floor (not the first, not a boss floor) to be cursed (CurseDef).
@export_range(0.0, 1.0) var curse_chance: float = 0.1

@export_group("Floors")
## Multiplies the floors' width and height (DungeonConfig): harder runs go through bigger floors.
@export_range(0.5, 2.0) var floor_size: float = 1.0
## Multiplies the rooms per floor (and with them the monsters, chests, hazards and items).
@export_range(0.5, 3.0) var rooms: float = 1.0

@export_group("Rewards and help")
## Multiplies every monster's and prop's drop chance.
@export var loot_chance: float = 1.0
## Multiplies the quality of what drops (Magic, Rare and Epic come rarer below 1: LootRoller).
@export var loot_quality: float = 1.0
## Feats count here: achievements and their progress (the Tree's feat nodes, the oaths), the
## deepest floor and the victories on the records. Off on Pilgrim: the Well spares you, it
## doesn't crown you. Quests and the bestiary count everywhere.
@export var counts_feats: bool = true
## Multiplies the souls earned at the end of a run.
@export var souls: float = 1.0
## Fraction of max HP healed when reaching a new floor.
@export_range(0.0, 1.0) var heal_on_new_floor: float = 0.0
## Multiplies the floors' darkness (below 1 = darker).
@export var light: float = 1.0
## Multiplies the merchant's prices.
@export var shop_prices: float = 1.0
## Multiplies the hero's max HP at the start of a run.
@export var hero_max_hp: float = 1.0
## Can be climbed past with ascension levels (Nightmare +1, +2...: see AscensionDef).
@export var has_ascensions: bool = false

## Ascension level of a run (set on the copy made by AscensionDef.apply_levels()).
var ascension := 0


## Its name as shown, in the player's language: "Nightmare", or "Nightmare +3" with ascension
## levels (one sentence with its codes, never the name and the level glued: AGENTS.md).
func shown_name() -> String:
	return named(display_name, ascension)


## `difficulty_name` (a display_name, English) with `level` ascensions, translated.
static func named(difficulty_name: String, level: int) -> String:
	var translated := TranslationServer.tr(difficulty_name)
	if level <= 0:
		return translated
	return TranslationServer.tr("{difficulty} +{level}").format({ "difficulty": translated, "level": level })
