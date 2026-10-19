class_name ContentDB
extends Resource
## Index of all game content. To add an item, perk, prop or elite affix, create its .tres
## and add it to the matching list in res://data/content_db.tres.
## Monsters and hazards (traps, holes...) are listed per act in the dungeon config (dungeon.acts).

@export var player: PlayerDef
@export var dungeon: DungeonConfig
@export var sounds: SoundBank
## The game's name, its story and the texts that tell it.
@export var story: StoryDef
## Items that can be found lying on the floor. Loot tables can also reference items not listed here.
@export var items: Array[ItemDef] = []
## Perks offered on level up (common) and after bosses (rare relics).
@export var perks: Array[PerkDef] = []
## The bestiary's hunter ranks and their rewards.
@export var bestiary: BestiaryRules
## Perk families and their bonuses (the codex lists them; perks point at theirs).
@export var synergies: Array[SynergyDef] = []
## Difficulties, easiest first (picked on the title screen).
@export var difficulties: Array[DifficultyDef] = []
## Used when nothing was picked yet (tests, first launch).
@export var default_difficulty: DifficultyDef
## Permanent upgrades sold at the shrine (title screen).
@export var upgrades: Array[UpgradeDef] = []
## Items that only appear in the dungeon once a shrine upgrade unlocked them.
@export var locked_items: Array[ItemDef] = []
## Breakable props placed in rooms (lanterns are set in the dungeon config).
@export var props: Array[PropDef] = []
## What makes elite monsters special (Swift, Vampiric, Explosive...).
@export var elite_affixes: Array[EliteAffixDef] = []
## Special floors (haunted, treasure vault, swarm...).
@export var floor_events: Array[FloorEventDef] = []
## Whole-floor curses (frozen, burning, lightless...). See CurseDef.
@export var curses: Array[CurseDef] = []
## Nightmare +1, +2...: each level adds its twist (in order).
@export var ascensions: Array[AscensionDef] = []
## Goals across runs (they pay souls).
@export var achievements: Array[AchievementDef] = []
## Daily and weekly quests (QuestBoard draws a few of each from the date).
@export var quests: Array[QuestDef] = []
## Springs, altars, spirits and statues met in rooms.
@export var encounters: Array[EncounterDef] = []
## Random bonuses on found equipment (Magic, Rare and Epic items).
@export var item_affixes: Array[ItemAffixDef] = []
## Rune stones (RuneDef): dropped by elites and bosses, found in chests, set at the forge.
@export var runes: Array[RuneDef] = []


## A monster of the act holding `depth`, by spawn weight.
func pick_monster(depth: int, rng: RandomNumberGenerator) -> MonsterDef:
	var act := dungeon.act_for_depth(depth)
	if act == null:
		return null
	var weights := PackedInt32Array()
	for monster in act.monsters:
		weights.append(monster.spawn_weight if monster else 0)
	return RandomUtils.pick_weighted(act.monsters, weights, rng)


func get_difficulty(id: StringName) -> DifficultyDef:
	for difficulty in difficulties:
		if difficulty.id == id:
			return difficulty
	return default_difficulty


## Every monster of every act (bosses excluded).
func all_monsters() -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	for act in dungeon.acts:
		for monster in act.monsters:
			if monster and not result.has(monster):
				result.append(monster)
	return result


## Locked items unlocked for the current run (set by the game from the profile).
var unlocked_items: Array[ItemDef] = []


func pick_item(depth: int, rng: RandomNumberGenerator) -> ItemDef:
	return _pick(items.filter(is_available), depth, rng)


## A rune for `depth`, by spawn weight (null if none).
func pick_rune(depth: int, rng: RandomNumberGenerator) -> RuneDef:
	return _pick(runes, depth, rng) as RuneDef


func is_available(item: ItemDef) -> bool:
	return not locked_items.has(item) or unlocked_items.has(item)


func pick_prop(depth: int, rng: RandomNumberGenerator) -> PropDef:
	return _pick(props, depth, rng)


func pick_affix(depth: int, rng: RandomNumberGenerator) -> EliteAffixDef:
	return _pick(elite_affixes, depth, rng)


## Every hazard of every act.
func all_hazards() -> Array[HazardDef]:
	var result: Array[HazardDef] = []
	for act in dungeon.acts:
		for hazard in act.hazards:
			if hazard and not result.has(hazard):
				result.append(hazard)
	return result


## Up to `count` different perks of `rarity` that `owned` can still take.
## Tops up with perks of the other rarity when there are not enough.
## Never `left_out` ones (banished for the run, the cards on the table being rerolled...).
## `family_bias`: perks of a family `owned` has started but not woken weigh (1 + bias) times
## more per such family, so families come together.
func pick_perks(owned: PerkSet, count: int, rarity: PerkDef.Rarity, rng: RandomNumberGenerator, left_out: Array[PerkDef] = [], family_bias: float = 0.0) -> Array[PerkDef]:
	var result: Array[PerkDef] = []
	var started: Array[SynergyDef] = []
	for synergy in owned.families():
		if not owned.is_awake(synergy):
			started.append(synergy)
	for wanted_rarity in [rarity, PerkDef.Rarity.COMMON if rarity == PerkDef.Rarity.RARE else PerkDef.Rarity.RARE]:
		var candidates: Array = []
		var weights := PackedInt32Array()
		for perk in perks:
			if perk and perk.rarity == wanted_rarity and owned.can_take(perk) and not result.has(perk) and not left_out.has(perk):
				var shared := perk.synergies.filter(func(s: SynergyDef) -> bool: return started.has(s)).size()
				candidates.append(perk)
				weights.append(roundi(perk.weight * 10.0 * (1.0 + family_bias * shared)))
		while result.size() < count and not candidates.is_empty():
			var picked: PerkDef = RandomUtils.pick_weighted(candidates, weights, rng)
			if picked == null:
				break
			var index := candidates.find(picked)
			candidates.remove_at(index)
			weights.remove_at(index)
			result.append(picked)
	return result


## A ContentDef of `pool` allowed at `depth`, by spawn weight (null if none).
static func pick_from(pool: Array, depth: int, rng: RandomNumberGenerator) -> ContentDef:
	return _pick(pool, depth, rng)


static func _pick(pool: Array, depth: int, rng: RandomNumberGenerator) -> ContentDef:
	var candidates: Array = []
	var weights := PackedInt32Array()
	for def: ContentDef in pool:
		if def != null and def.min_depth <= depth and def.spawn_weight > 0:
			candidates.append(def)
			weights.append(def.spawn_weight)
	return RandomUtils.pick_weighted(candidates, weights, rng)
