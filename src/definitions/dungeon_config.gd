class_name DungeonConfig
extends Resource
## The run (acts, in order) and tuning for floor generation and difficulty.

## The acts of a run, in order. Beating the last act's boss wins the run; after that the
## acts loop (endless mode), harder every time because monsters scale with depth.
@export var acts: Array[ActDef] = []

@export_group("Layout")
@export var tile_size: int = 32
@export var width: int = 64
@export var height: int = 64
@export var max_rooms: int = 12
@export var room_min_size: int = 7
@export var room_max_size: int = 13
@export_range(1, 5) var corridor_width: int = 3

@export_group("Stairs seal")
## The stairs of a normal floor open once the hero has slain this share of the floor's
## monsters (0 = always open). Every kill counts: ambush waves, summons... See StairsSeal.
@export_range(0.0, 1.0) var seal_share: float = 0.7
## When this few kills are left, the minimap shows where the remaining monsters are.
@export_range(0, 20) var seal_reveal_left: int = 4

@export_group("Perk choices")
## Rerolls (three new cards) and banishes (a perk gone for the run) the hero starts every run
## with; the shrine adds more (UpgradeDef REROLLS / BANISHES).
@export_range(0, 10) var base_rerolls: int = 1
@export_range(0, 10) var base_banishes: int = 1
## Rerolls gained for every boss slain.
@export_range(0, 5) var rerolls_per_boss: int = 1
## Offers favour perks of the families the hero has started but not woken yet: their weight
## is multiplied by (1 + this) for each such family.
@export_range(0.0, 5.0) var family_bias: float = 1.0

@export_group("Population")
@export var monsters_per_room_min: int = 1
@export var monsters_per_room_max: int = 3
## Extra monsters per room for each depth below the first.
@export var extra_monsters_per_depth: float = 0.5
@export var max_monsters_per_room: int = 6
@export var items_per_floor: int = 4

@export_group("Props and hazards")
## Lantern placed along the walls of every room (light in the dark).
@export var room_light: PropDef
@export_range(0, 6) var lights_per_room: int = 2
## Small groups of crates, pots and barrels per room.
@export_range(0, 10) var prop_clusters_min: int = 0
@export_range(0, 10) var prop_clusters_max: int = 2
## Groups of hazards per floor (a row of spikes, a few holes...), picked from the act's list.
@export_range(0, 20) var hazard_groups_min: int = 3
@export_range(0, 20) var hazard_groups_max: int = 5

@export_group("Chests")
## Chests lying around a floor (some are trapped: see ChestDef).
@export var chest: ChestDef
@export_range(0, 6) var chests_min: int = 0
@export_range(0, 6) var chests_max: int = 2

@export_group("Ambushes")
## Chance for a floor to have an ambush room: it looks empty, then the exits close and
## monsters pour in, wave after wave. A big chest waits for whoever survives.
@export_range(0.0, 1.0) var ambush_chance: float = 0.6
@export_range(1, 5) var ambush_waves: int = 2
## Monsters per wave, plus one every 3 floors.
@export_range(1, 12) var ambush_wave_size: int = 3
## Reward for clearing an ambush.
@export var ambush_chest: ChestDef

@export_group("Loot")
## Chances for found equipment to be Common, Magic, Rare or Epic (relative weights), and how
## the better ones grow per floor. Bosses, elites and chests multiply the better ones (quality).
@export var common_weight: float = 70.0
@export var magic_weight: float = 22.0
@export var magic_weight_per_depth: float = 1.0
@export var rare_weight: float = 5.0
@export var rare_weight_per_depth: float = 1.0
@export var epic_weight: float = 0.6
@export var epic_weight_per_depth: float = 0.4
## Quality of what bosses drop (1 = a common monster; elites: MonsterRankDef.loot_quality).
@export var boss_loot_quality: float = 5.0
## Consumables found while the hero already carries this many of the same one (belt and bag)
## drop as gold instead: no bag full of potions.
@export_range(1, 20) var consumable_carry_cap: int = 4

@export_group("Gold")
## Chance for a monster to drop gold (elites and bosses always do).
@export_range(0.0, 1.0) var gold_drop_chance: float = 0.45
@export var gold_per_kill: Vector2i = Vector2i(1, 4)
## Extra gold per floor below the first.
@export var gold_per_depth: float = 0.6
@export var boss_gold_multiplier: float = 15.0
## Crates and pots sometimes hold a few coins.
@export_range(0.0, 1.0) var prop_gold_chance: float = 0.25
@export var prop_gold: Vector2i = Vector2i(1, 3)
@export var prop_gold_per_depth: float = 0.5

@export_group("Temperature")
## The hero's body temperature (BodyTemperature): -100 frozen, 0 fine, 100 burning up.
## Back to normal by this much per second when nothing warms or chills.
@export var temperature_recovery: float = 25.0
## Campfires bring it back to normal this fast (per second).
@export var temperature_comfort_rate: float = 70.0
## Damage every `temperature_tick` seconds at either end (grows with depth).
@export var temperature_damage: int = 3
@export var temperature_tick: float = 1.0
## Slowed by up to this much when cold (from halfway to frozen).
@export_range(0.0, 0.9) var cold_slow: float = 0.35

@export_group("Floor events")
## Chance for a normal floor (not the first) to be special (content_db.tres > Floor Events).
@export_range(0.0, 1.0) var floor_event_chance: float = 0.3

@export_group("Encounters")
## Encounters per floor (springs, altars...), from content_db.tres > Encounters.
@export_range(0, 6) var encounters_min: int = 0
@export_range(0, 6) var encounters_max: int = 2

@export_group("Merchant")
## Chance for a floor to have the merchant (never on boss floors).
@export_range(0.0, 1.0) var merchant_chance: float = 0.55
@export var merchant: ShopDef

@export_group("Forge and runes")
## Chance for a floor to have the smith's forge (never on boss floors), plus this much for
## every floor since the last one (so it never stays away too long).
@export_range(0.0, 1.0) var forge_chance: float = 0.3
@export_range(0.0, 1.0) var forge_chance_growth: float = 0.15
@export var forge: ForgeDef
## Chance for a monster to drop a rune: plain ones, and elites and up (MonsterRankDef).
@export_range(0.0, 1.0) var rune_chance: float = 0.01
@export_range(0.0, 1.0) var ranked_rune_chance: float = 0.3
## Runes a slain boss always drops.
@export var boss_runes: int = 1
## Chance for an opened chest to hold a rune too.
@export_range(0.0, 1.0) var chest_rune_chance: float = 0.2

@export_group("Elites")
## Chance for a monster to be an elite on the first floor, and more per floor below.
@export_range(0.0, 1.0) var elite_chance: float = 0.04
@export_range(0.0, 1.0) var elite_chance_per_depth: float = 0.015
## What an elite is (one affix, tougher, better loot: MonsterRankDef).
@export var elite_rank: MonsterRankDef
## Rarer ranks, rarest first (Shiny, Legendary, Epic): each rolled with its own chance before
## the elite one. Bosses roll them too (MonsterRankDef.boss_chance).
@export var rare_ranks: Array[MonsterRankDef] = []

@export_group("Bosses")
## Size of the arena room, in cells (when there is no ArenaDef to pick).
@export var arena_size: Vector2i = Vector2i(21, 15)
## Arenas the bosses fight in (shapes, pillars, changes by phase), one picked per boss floor.
@export var arenas: Array[ArenaDef] = []

@export_group("Difficulty")
## Monster HP grows by this fraction per depth (0.15 = +15% per floor).
@export var monster_hp_scale_per_depth: float = 0.15
@export var monster_attack_per_depth: int = 1


## Chance for a monster spawned at `depth` to be an elite, before the difficulty.
func elite_chance_at(depth: int) -> float:
	return elite_chance + elite_chance_per_depth * (depth - 1)


## Gold dropped by a monster at `depth` (`multiplier`: elites, bosses).
func gold_for_kill(depth: int, multiplier: float, rng: RandomNumberGenerator) -> int:
	var base := rng.randi_range(gold_per_kill.x, gold_per_kill.y) + gold_per_depth * (depth - 1)
	return roundi(base * multiplier)


## Floors in one pass through every act.
func total_floors() -> int:
	var total := 0
	for act in acts:
		total += act.floors
	return total


## Index in `acts` of the act holding `depth` (looping after the last one).
func act_index(depth: int) -> int:
	if acts.is_empty():
		return -1
	var floor_number := (depth - 1) % maxi(total_floors(), 1)
	for i in acts.size():
		if floor_number < acts[i].floors:
			return i
		floor_number -= acts[i].floors
	return acts.size() - 1


## The first floor of act `index` (1 for the first act).
func first_depth(index: int) -> int:
	var depth := 1
	for i in mini(index, acts.size()):
		depth += acts[i].floors
	return depth


func act_for_depth(depth: int) -> ActDef:
	var index := act_index(depth)
	return acts[index] if index >= 0 else null


## 1 for the first floor of an act.
func floor_in_act(depth: int) -> int:
	var floor_number := (depth - 1) % maxi(total_floors(), 1)
	for act in acts:
		if floor_number < act.floors:
			return floor_number + 1
		floor_number -= act.floors
	return 1


## The boss guarding `depth` (the last floor of each act), or null on a normal floor.
func boss_for_depth(depth: int) -> BossDef:
	var act := act_for_depth(depth)
	if act == null or floor_in_act(depth) != act.floors:
		return null
	return act.boss


## The floor whose boss ends the run.
func is_final_floor(depth: int) -> bool:
	return depth == total_floors()
