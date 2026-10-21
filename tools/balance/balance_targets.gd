class_name BalanceTargets
extends Resource
## The design goals of the game's balance, as numbers (data/balance/targets.tres). The model, the
## arena, the lab and the "balance" test suite all read these, so a goal is changed in one place.
## A number that breaks a goal becomes a FLAG in the reports.
## The values shipped are a FIRST PROPOSAL for an action roguelike played on a phone: tune them
## with the owner, and say why next to each one in targets.tres.

@export_group("Bosses")
## Seconds to kill an act's boss with that act's expected build (Normal): shortest acceptable.
## Under it the boss is not a fight.
@export var boss_ttk_min: float = 40.0
## ...longest acceptable. Over it the fight drags on a phone.
@export var boss_ttk_max: float = 100.0
## A boss at a rare rank (Epic, Legendary, Shiny) may last longer, up to this (Normal, expected build).
@export var ranked_boss_ttk_max: float = 150.0
## Builds with these tags must LOSE when the face-tank bot (never dodges, never drinks, just hits)
## fights their act's bosses, on `facetank_must_lose_from` and harder. Standing still and trading
## blows must never win: the boss' patterns are the game.
@export var facetank_must_lose_tags: PackedStringArray = ["expected", "degenerate"]
## Difficulty key from which the face-tank must lose (and every harder one).
@export var facetank_must_lose_from: StringName = &"normal"
## Healing received during a boss fight, as a share of the damage taken, for "expected" builds:
## at most this. Sustain should top you up, not undo the boss' damage.
@export var heal_share_max_expected: float = 0.25
## The same for "degenerate" (and "family") builds: they may lean on sustain, never cancel the fight.
@export var heal_share_max_degenerate: float = 0.5
## How many average boss hits (melee or skill, after armor) kill the act's expected build at full
## health on Normal: at least this (a single mistake must not end the run)...
@export var boss_hits_to_kill_min: float = 6.0
## ...and at most this (ignoring the boss must cost you).
@export var boss_hits_to_kill_max: float = 12.0
## The kite bot (keeps its range, rolls away from telegraphs) with the expected build should win
## on these difficulties: the fight must be beatable by playing it.
@export var kite_should_win_on: PackedStringArray = ["easy", "normal"]

@export_group("Curve")
## Threat of a boss for the act's expected build = share of the hero's health a face-tank fight
## would cost (boss damage per second x time to kill / max health). From one act to the next it
## should grow by this factor at least... (a steady curve, pillar 5)
@export var act_threat_step_min: float = 0.9
## ...and at most this (no wall between two acts).
@export var act_threat_step_max: float = 1.6
## Threat on each difficulty relative to Normal (same act, same build): [min, max].
@export var difficulty_threat: Dictionary = {
	"easy": Vector2(0.2, 0.7), "hard": Vector2(1.3, 2.6), "nightmare": Vector2(2.0, 5.0),
	"nightmare+5": Vector2(2.5, 8.0), "nightmare+10": Vector2(3.0, 12.0),
}

@export_group("Monsters")
## Seconds the act's expected build spends killing a common monster of its act on Normal (last
## normal floor): at least this, or monsters are paper...
@export var common_ttk_min: float = 0.5
## ...and at most this, or rooms drag.
@export var common_ttk_max: float = 2.5
## The same per rank (rank id -> Vector2(min, max) seconds), averaged over its affixes.
@export var rank_ttk: Dictionary = {
	"elite": Vector2(3.0, 10.0), "epic": Vector2(5.0, 16.0), "legendary": Vector2(8.0, 25.0), "shiny": Vector2(2.0, 10.0),
}
## Each rank (Elite, Epic, Legendary) takes at least this many times as long to kill as the rank
## below it (plain for an Elite), medians over each act's monsters on Normal, and costs more health:
## a rank must feel like a clearly tougher fight, not a recolor.
@export var rank_ladder_step_min: float = 1.2
## Average hits of a common monster (after armor) to kill the act's expected build (Normal):
## at least this. One monster must never be a two-shot.
@export var common_hits_to_kill_min: float = 6.0
## Damage taken while clearing a pack of the act's monsters with the kite bot and the expected
## build, as a share of max health: at most this (a room shouldn't cost half your life when you play well).
@export var pack_damage_share_max: float = 0.35
## Seconds to clear a room of the act's monsters (kite bot, expected build, Normal): at most this.
@export var pack_clear_max: float = 25.0

@export_group("Perks, gear and builds")
## Any single pick (a perk at its max level, a relic, a family, a rune, an affix, a shrine level)
## added to the act's expected build: worth at most this many times the median of its category...
@export var perk_value_max_vs_median: float = 2.0
## ...and at least this many times (below it the pick is a trap).
@export var perk_value_min_vs_median: float = 0.5
## Id of the build the static perk table is measured on (the lab measures every act's expected build).
@export var perk_reference_build: String = "expected_a2"
## A degenerate build's single-target DPS against its act's boss: at most this many times the
## expected build's of the same act. Stacking one thing should pay, not trivialise.
@export var degenerate_dps_ratio_max: float = 2.5
## Every weapon's DPS (each rarity, the act's expected hero) within this range of the median
## weapon's: no weapon is a trap, none is the only choice.
@export var weapon_dps_ratio_min: float = 0.6
@export var weapon_dps_ratio_max: float = 1.6
## Arena: share of the bosses a weapon (Common, on the act's expected build, kite bot, Normal)
## beats: at least this. A weapon that loses to most bosses is a trap.
@export var weapon_boss_win_share_min: float = 0.5

@export_group("Compound and sustain")
## A combination of bonuses (attack speed x crit x damage, extra projectiles, echo, burns) may
## multiply the expected build's DPS by at most this.
@export var compound_dps_ratio_max: float = 2.5
## Armor: with the most armor a build can stack, at most this share of the act's monsters may
## be brought down to the 1-damage floor (Combat.mitigate) - armor must not make swarms harmless.
@export var min_damage_share_max: float = 0.5
## Healing from one sustain source alone (one Leech rune, Vampirism...) against packs: at most
## this share of what it asked for may be cut by the shared budget (SustainRules).
@export var single_source_cut_max: float = 0.1

@export_group("Economy")
## Gold earned between two merchants (on average, Normal) divided by the average price of an
## item in the merchant's stock at that depth: at least this (buy something most visits)...
@export var gold_per_visit_items_min: float = 0.8
## ...and at most this (gold must not lose its meaning).
@export var gold_per_visit_items_max: float = 3.0
## A merchant reroll costs at most this share of the gold of one floor.
@export var reroll_floor_share_max: float = 0.35
## The forge's rune removal costs at most this share of the gold of one floor.
@export var forge_floor_share_max: float = 0.6
## A whole Keeper career (every source: runs, the bestiary's ranks and challenges,
## achievements, quests; BalanceSouls): runs to a full Tree of Souls, at least this (the tree
## is a campaign, not a few evenings)...
@export var campaign_runs_to_tree_min: float = 40.0
## ...and at most this (not a grind).
@export var campaign_runs_to_tree_max: float = 60.0
## The first node bought by this run at the latest.
@export var campaign_first_node_runs_max: int = 2
## Souls from one-time sources (hunter ranks, challenges, achievements) in the first 10 runs:
## at most this share of the full tree (the first hours' burst must not hand out the tree).
@export var campaign_burst_share_max: float = 0.2
