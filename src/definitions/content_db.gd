class_name ContentDB
extends Resource
## Index of all game content. To add an item, perk, prop or trap, create its .tres
## and add it to the matching list in res://data/content_db.tres.
## Monsters are listed per act in the dungeon config (dungeon.acts > monsters).

@export var player: PlayerDef
@export var dungeon: DungeonConfig
@export var sounds: SoundBank
## Items that can be found lying on the floor. Loot tables can also reference items not listed here.
@export var items: Array[ItemDef] = []
## Perks offered on level up (common) and after bosses (rare relics).
@export var perks: Array[PerkDef] = []
## Breakable props placed in rooms (lanterns are set in the dungeon config).
@export var props: Array[PropDef] = []
@export var traps: Array[TrapDef] = []


## A monster of the act holding `depth`, by spawn weight.
func pick_monster(depth: int, rng: RandomNumberGenerator) -> MonsterDef:
	var act := dungeon.act_for_depth(depth)
	if act == null:
		return null
	var weights := PackedInt32Array()
	for monster in act.monsters:
		weights.append(monster.spawn_weight if monster else 0)
	return RandomUtils.pick_weighted(act.monsters, weights, rng)


## Every monster of every act (bosses excluded).
func all_monsters() -> Array[MonsterDef]:
	var result: Array[MonsterDef] = []
	for act in dungeon.acts:
		for monster in act.monsters:
			if monster and not result.has(monster):
				result.append(monster)
	return result


func pick_item(depth: int, rng: RandomNumberGenerator) -> ItemDef:
	return _pick(items, depth, rng)


func pick_prop(depth: int, rng: RandomNumberGenerator) -> PropDef:
	return _pick(props, depth, rng)


func pick_trap(depth: int, rng: RandomNumberGenerator) -> TrapDef:
	return _pick(traps, depth, rng)


## Up to `count` different perks of `rarity` that `owned` can still take.
## Tops up with perks of the other rarity when there are not enough.
func pick_perks(owned: PerkSet, count: int, rarity: PerkDef.Rarity, rng: RandomNumberGenerator) -> Array[PerkDef]:
	var result: Array[PerkDef] = []
	for wanted_rarity in [rarity, PerkDef.Rarity.COMMON if rarity == PerkDef.Rarity.RARE else PerkDef.Rarity.RARE]:
		var candidates: Array = []
		var weights := PackedInt32Array()
		for perk in perks:
			if perk and perk.rarity == wanted_rarity and owned.can_take(perk) and not result.has(perk):
				candidates.append(perk)
				weights.append(perk.weight)
		while result.size() < count and not candidates.is_empty():
			var picked: PerkDef = RandomUtils.pick_weighted(candidates, weights, rng)
			if picked == null:
				break
			var index := candidates.find(picked)
			candidates.remove_at(index)
			weights.remove_at(index)
			result.append(picked)
	return result


static func _pick(pool: Array, depth: int, rng: RandomNumberGenerator) -> ContentDef:
	var candidates: Array = []
	var weights := PackedInt32Array()
	for def: ContentDef in pool:
		if def != null and def.min_depth <= depth and def.spawn_weight > 0:
			candidates.append(def)
			weights.append(def.spawn_weight)
	return RandomUtils.pick_weighted(candidates, weights, rng)
