class_name BalanceTargets
extends Resource
## The design goals of the game's balance, as numbers (data/balance/targets.tres). The model, the
## arena and the "balance" test suite all read these, so a goal is changed in one place.
## A number that breaks a goal becomes a FLAG in the reports (see BalanceFlags).
## The values shipped are a first proposal for an action roguelike played on a phone: tune them
## with the owner, and say why next to each one in targets.tres.

@export_group("Bosses")
## Seconds to kill an act's boss with that act's expected build: shortest acceptable. A boss
## that falls faster than this is not a fight (the model assumes 100% uptime: always hitting).
@export var boss_ttk_min: float = 40.0
## Seconds to kill an act's boss with that act's expected build: longest acceptable. Longer and
## the fight drags on a phone.
@export var boss_ttk_max: float = 100.0
## Builds with these tags must LOSE when the face-tank bot (never dodges, never drinks, just hits)
## fights their act's bosses, on `facetank_must_lose_from` and harder. Standing still and trading
## blows must never win: the boss' patterns are the game.
@export var facetank_must_lose_tags: PackedStringArray = ["expected", "degenerate"]
## Difficulty id from which the face-tank must lose (and every harder one).
@export var facetank_must_lose_from: StringName = &"normal"
## Healing received during a boss fight, as a share of the damage taken, for "expected" builds:
## at most this. Sustain should top you up, not undo the boss' damage.
@export var heal_share_max_expected: float = 0.25
## The same for "degenerate" builds: they may lean on sustain, never cancel the fight.
@export var heal_share_max_degenerate: float = 0.5
## How many average boss hits (melee or skill, after armor) kill the act's expected build at full
## health: at least this (a single mistake must not end the run)...
@export var boss_hits_to_kill_min: float = 6.0
## ...and at most this (ignoring the boss must cost you: a hit-free run is possible, a careless one dies).
@export var boss_hits_to_kill_max: float = 12.0
## The kite bot (keeps its range, rolls away from telegraphs) with the expected build should win
## on this difficulty: the fight must be beatable by playing it. Empty = not checked.
@export var kite_should_win_on: StringName = &"normal"

@export_group("Monsters")
## Seconds the act's expected build spends killing a common monster of its act (attacks needed x
## attack time): at least this, or monsters are paper...
@export var common_ttk_min: float = 0.5
## ...and at most this, or rooms drag.
@export var common_ttk_max: float = 2.5
## The same for an elite (x HP, an affix): a short duel, not a wall.
@export var elite_ttk_min: float = 3.0
@export var elite_ttk_max: float = 10.0
## Damage taken while clearing a pack of the act's monsters with the kite bot and the expected
## build, as a share of max HP: at most this (a room shouldn't cost half your life when you play well).
@export var pack_damage_share_max: float = 0.35

@export_group("Builds and perks")
## Any single perk at its max level, added to the reference build, must be worth at most this
## many times the median perk's value (same rarity). One perk must not be the only right pick.
@export var perk_value_max_vs_median: float = 2.0
## Id of the build the perk values are measured on (added one at a time, at max stacks).
@export var perk_reference_build: String = "expected_a2"
## A degenerate build's single-target DPS against its act's boss: at most this many times the
## expected build's of the same act. Stacking one thing should pay, not trivialise.
@export var degenerate_dps_ratio_max: float = 2.5
## Every weapon's DPS (Common, the reference build's hero) within this range of the median
## weapon's: no weapon is a trap, none is the only choice.
@export var weapon_dps_ratio_min: float = 0.6
@export var weapon_dps_ratio_max: float = 1.6
