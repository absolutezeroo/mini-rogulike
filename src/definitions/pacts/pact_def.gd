class_name PactDef
extends ContentDef
## A pact: the hard rule of a sealed side room (PactRoom). Before the door the hero reads the
## rule, the reward and the cost, and may swear it or walk away. Inside, the door seals and
## waves of foes come; keep the rule until the last one falls and a relic is yours; break it
## and you lose part of your max Health for the rest of the run (the fight goes on, the door
## opens once the waves are dead). `display_name` is its name, `description` its lore line,
## `color` its glow. Listed in dungeon_config.tres > Pacts (`min_depth`, `spawn_weight`).

## What must be kept, and how it is watched.
@export var rule: PactRule

@export_group("The fight")
## Waves of foes, one after the other.
@export_range(1, 6) var waves: int = 2
## Foes per wave, plus one every 3 floors (as in ambushes).
@export_range(1, 12) var wave_size: int = 3
## Share of the foes that come as elites (1: all of them). With 0, the last wave is still
## led by one elite.
@export_range(0.0, 1.0, 0.05) var elite_share: float = 0.0

@export_group("Stakes")
## Kept: a choice of this many relics (rare perks), as after a boss.
@export_range(1, 5) var relic_choices: int = 3
## Broken: this share of the hero's max Health is lost for the rest of the run.
@export_range(0.0, 0.5, 0.01) var max_hp_cost: float = 0.12


## The max Health a broken pact takes from this hero (what the card shows in red).
func max_hp_lost(player: Player) -> int:
	return maxi(1, roundi(player.base_stats.max_hp * max_hp_cost))


## Foes in each wave at `depth`.
func foes_per_wave(depth: int) -> int:
	return wave_size + floori(depth / 3.0)


## The rule in plain words.
func rule_text(player: Player) -> String:
	return rule.describe(player) if rule else ""
