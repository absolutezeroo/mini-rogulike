class_name SustainRules
extends Resource
## How much the hero can heal from "per hit", "per kill" and "per skill" sources (Leech,
## Vampirism, the Blood family, the Fury rune, Devotion...). Potions, springs, spells that heal
## and level ups are not limited. See SustainMeter, Actor.sustain_heal().
##
## All these sources share one budget: it holds `burst` of the max health (a pack slain at once
## still heals well) and refills at `rate_per_second` of the max health per second, so stacking
## them can never out-heal a boss. Healing is paid in whole points; fractions add up.

## The budget refills this share of the max health per second (0.04 = 4 Health per second at 100).
@export_range(0.0, 0.5, 0.005) var rate_per_second: float = 0.04
## The budget holds at most this share of the max health.
@export_range(0.0, 1.0, 0.01) var burst: float = 0.2
## While a boss fight is on, the budget refills this much slower (0.5 = half the rate).
@export_range(0.0, 1.0, 0.01) var boss_fight_rate: float = 0.5
## While a boss fight is on, the budget holds this share of `burst` (1 = the same). A boss fight
## is long: what heals there must forgive a mistake, not out-heal the boss.
@export_range(0.0, 1.0, 0.01) var boss_fight_burst: float = 1.0


## Health the budget gains per second for a hero with `max_hp`.
func refill_per_second(max_hp: int, boss_fight: bool) -> float:
	return rate_per_second * max_hp * (boss_fight_rate if boss_fight else 1.0)


## The most the budget can hold for a hero with `max_hp`.
func capacity(max_hp: int, boss_fight: bool = false) -> float:
	return burst * max_hp * (boss_fight_burst if boss_fight else 1.0)
