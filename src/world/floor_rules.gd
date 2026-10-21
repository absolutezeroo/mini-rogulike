class_name FloorRules
extends RefCounted
## How hard and how rewarding the current floor is: the run's difficulty (and ascension), the
## floor's event (Blood Moon, Treasure Vault...) and the depth, combined in one place.
## Built by World.build_floor(); everything that scales asks it instead of multiplying
## difficulty and event values by hand.

var depth := 1
var config: DungeonConfig
## Never null: a neutral difficulty when the run has none.
var difficulty: DifficultyDef
## Null on most floors.
var event: FloorEventDef
## Null on most floors.
var curse: CurseDef

static var _neutral := DifficultyDef.new()


static func make(floor_config: DungeonConfig, run_difficulty: DifficultyDef, floor_event: FloorEventDef, floor_depth: int, floor_curse: CurseDef = null) -> FloorRules:
	var rules := FloorRules.new()
	rules.config = floor_config
	rules.difficulty = run_difficulty if run_difficulty else _neutral
	rules.event = floor_event
	rules.curse = floor_curse
	rules.depth = floor_depth
	return rules


# --- Monsters ----------------------------------------------------------------

## Multiplies a monster's HP (after the depth scaling, see scale_monster()).
func monster_hp(is_boss: bool) -> float:
	var scale := difficulty.boss_hp if is_boss else difficulty.monster_hp
	return scale * (event.monster_hp if event else 1.0)


## Multiplies everything the dungeon deals: monster attacks and skills, traps, bursts, the cold.
func monster_damage() -> float:
	return difficulty.monster_damage * (event.monster_damage if event else 1.0)


func monster_speed() -> float:
	return difficulty.monster_speed


## Multiplies the warning time before monster attacks and skills.
func telegraph_time() -> float:
	return difficulty.telegraph_time


## Multiplies how far monsters spot the hero.
func detect_range() -> float:
	return difficulty.detect_range if difficulty else 1.0


## A monster's stats for this floor: grows with depth, then the difficulty and the event.
func scale_monster(base: StatBlock, is_boss: bool) -> StatBlock:
	var stats := base.duplicate() as StatBlock
	var levels := depth - 1
	var hp_scale := config.boss_hp_scale_per_depth if is_boss else config.monster_hp_scale_per_depth
	var attack_scale := config.boss_attack_per_depth if is_boss else config.monster_attack_per_depth
	stats.max_hp = roundi(stats.max_hp * (1.0 + hp_scale * levels) * monster_hp(is_boss))
	stats.attack += roundi(attack_scale * levels)
	stats.move_speed *= monster_speed()
	return stats


## Damage from the dungeon itself (a trap, quicksand, a blast, the cold): `base`, plus
## `per_depth` for each floor, times the floor's damage multiplier.
func dungeon_damage(base: float, per_depth: float = 1.0) -> int:
	return maxi(1, roundi((base + depth * per_depth) * monster_damage()))


## Chance for a monster to come at a rare rank (Epic, Legendary, Shiny): its own chance at
## this depth, times the difficulty's taste for elites.
func rank_chance(rank: MonsterRankDef) -> float:
	return rank.chance_at(depth) * difficulty.elite_chance


func elite_chance() -> float:
	return config.elite_chance_at(depth) * difficulty.elite_chance + (event.elite_chance_bonus if event else 0.0)


## Extra monsters in each room (and on top of the per-room cap).
func extra_monsters() -> int:
	return floori(config.extra_monsters_per_depth * (depth - 1)) + difficulty.extra_monsters


func monster_count_scale() -> float:
	return event.monster_count if event else 1.0


# --- Rewards -----------------------------------------------------------------

## Multiplies drop chances.
func loot_chance() -> float:
	return difficulty.loot_chance


## Multiplies the quality of what drops (see LootRoller).
func loot_quality() -> float:
	return (event.loot_quality if event else 1.0) * (curse.loot_quality if curse else 1.0) * (difficulty.loot_quality if difficulty else 1.0)


## Gold actually dropped for `amount`.
func gold(amount: float) -> int:
	return roundi(amount * (event.gold if event else 1.0) * (curse.gold if curse else 1.0))


func shop_prices() -> float:
	return difficulty.shop_prices


# --- Floor -------------------------------------------------------------------

## Multiplies the theme's ambient light color.
func light() -> Color:
	var color := Color.WHITE * difficulty.light
	if event:
		color *= event.light
	if curse:
		color *= curse.tint
	return Color(color, 1.0)


## Body temperature change per second everywhere on the floor (see BodyTemperature).
func temperature_drift() -> float:
	return curse.temperature if curse else 0.0
