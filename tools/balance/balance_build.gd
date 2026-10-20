class_name BalanceBuild
extends RefCounted
## Turns a BalanceBuildDef (data) into a real hero: the same Player, Equipment, PerkSet and
## LootRoller code the game uses, so the stats the tools measure are the game's own.
## Used by the model (a Player that never enters a world) and by the arena (the run's hero).

const BUILDS_DIR := "res://data/balance/builds/"
const TARGETS_PATH := "res://data/balance/targets.tres"
const PLAYER_SCENE := "res://src/entities/player/player.tscn"


## Every build in data/balance/builds/, sorted by act then name.
static func load_all(dir: String = BUILDS_DIR) -> Array[BalanceBuildDef]:
	var result: Array[BalanceBuildDef] = []
	for file in DirAccess.get_files_at(dir):
		var path := dir.path_join(file.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var build := load(path) as BalanceBuildDef
		if build:
			if build.name.is_empty():
				build.name = path.get_file().get_basename()
			result.append(build)
	result.sort_custom(func(a: BalanceBuildDef, b: BalanceBuildDef) -> bool:
		return a.name < b.name if a.act == b.act else a.act < b.act)
	return result


static func load_targets(path: String = TARGETS_PATH) -> BalanceTargets:
	var targets := load(path) as BalanceTargets
	return targets if targets else BalanceTargets.new()


## Builds whose name is in `names` (all of them when empty).
static func select(all: Array[BalanceBuildDef], names: PackedStringArray) -> Array[BalanceBuildDef]:
	if names.is_empty():
		return all
	return all.filter(func(b: BalanceBuildDef) -> bool: return names.has(b.name))


static func find(all: Array[BalanceBuildDef], build_name: String) -> BalanceBuildDef:
	for build in all:
		if build.name == build_name:
			return build
	return null


# --- Content lookups ------------------------------------------------------------

static func perk(content: ContentDB, id: String) -> PerkDef:
	for p in content.perks:
		if p and String(p.id) == id:
			return p
	return null


static func rune(content: ContentDB, id: String) -> RuneDef:
	for r in content.runes:
		if r and String(r.id) == id:
			return r
	return null


static func affix(content: ContentDB, id: String) -> ItemAffixDef:
	for a in content.item_affixes:
		if a and String(a.id) == id:
			return a
	return null


static func upgrade(content: ContentDB, id: String) -> UpgradeDef:
	for u in content.upgrades:
		if u and String(u.id) == id:
			return u
	return null


## What is wrong with a build's data (unknown ids, too many runes...). Empty when it is sound.
static func problems(build: BalanceBuildDef, content: ContentDB) -> PackedStringArray:
	var result := PackedStringArray()
	if build.weapon == null:
		result.append("%s: no weapon" % build.name)
	for id in build.weapon_affixes:
		if affix(content, id) == null:
			result.append("%s: unknown weapon affix '%s'" % [build.name, id])
	for id in build.runes:
		if rune(content, id) == null:
			result.append("%s: unknown rune '%s'" % [build.name, id])
	if build.runes.size() > ItemRarity.SOCKETS[clampi(build.weapon_rarity, 0, 3)]:
		result.append("%s: %d runes but a %s weapon has %d socket(s)" % [build.name, build.runes.size(), ItemRarity.NAMES[build.weapon_rarity], ItemRarity.SOCKETS[build.weapon_rarity]])
	if build.weapon_affixes.size() > ItemRarity.AFFIX_COUNT[clampi(build.weapon_rarity, 0, 3)]:
		result.append("%s: more weapon affixes than a %s item rolls" % [build.name, ItemRarity.NAMES[build.weapon_rarity]])
	for i in build.armor_affixes.size():
		for id in _split(build.armor_affixes[i]):
			if affix(content, id) == null:
				result.append("%s: unknown armor affix '%s'" % [build.name, id])
	for id: Variant in build.perks:
		var p := perk(content, String(id))
		if p == null:
			result.append("%s: unknown perk '%s'" % [build.name, id])
		elif int(build.perks[id]) > p.max_stacks:
			result.append("%s: %s x%d but it stops at %d" % [build.name, id, int(build.perks[id]), p.max_stacks])
	for id: Variant in build.upgrades:
		var u := upgrade(content, String(id))
		if u == null:
			result.append("%s: unknown upgrade '%s'" % [build.name, id])
		elif int(build.upgrades[id]) > u.max_level:
			result.append("%s: upgrade %s level %d above its max %d" % [build.name, id, int(build.upgrades[id]), u.max_level])
	return result


static func _split(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	for part in text.split(",", false):
		if not part.strip_edges().is_empty():
			result.append(part.strip_edges())
	return result


# --- Gear ------------------------------------------------------------------------

## The build's weapon as the game would make it (a rolled copy when it has a rarity or runes).
static func make_weapon(build: BalanceBuildDef, content: ContentDB) -> WeaponDef:
	if build.weapon == null:
		return null
	var affixes: Array[ItemAffixDef] = []
	for id in build.weapon_affixes:
		var a := affix(content, id)
		if a:
			affixes.append(a)
	var runes: Array[RuneDef] = []
	var sockets: int = ItemRarity.SOCKETS[clampi(build.weapon_rarity, 0, 3)]
	for id in build.runes:
		var r := rune(content, id)
		if r and runes.size() < sockets:
			runes.append(r)
	if build.weapon_rarity <= ItemRarity.COMMON and affixes.is_empty() and runes.is_empty():
		return build.weapon
	return LootRoller.make(build.weapon, clampi(build.weapon_rarity, 0, 3), affixes, runes) as WeaponDef


static func make_armors(build: BalanceBuildDef, content: ContentDB) -> Array[ArmorDef]:
	var result: Array[ArmorDef] = []
	for i in build.armors.size():
		var base := build.armors[i]
		if base == null:
			continue
		var rarity := build.armor_rarities[i] if i < build.armor_rarities.size() else 0
		var affixes: Array[ItemAffixDef] = []
		if i < build.armor_affixes.size():
			for id in _split(build.armor_affixes[i]):
				var a := affix(content, id)
				if a:
					affixes.append(a)
		if rarity <= ItemRarity.COMMON and affixes.is_empty():
			result.append(base)
		else:
			result.append(LootRoller.make(base, clampi(rarity, 0, 3), affixes) as ArmorDef)
	return result


# --- The hero ---------------------------------------------------------------------

## Puts the build on `player` (already set up with PlayerDef): base stats, shrine upgrades as
## ShrineUpgrades.apply_to() does, the level ups, gear, perks and the learned spell. Full HP,
## skills ready. `difficulty`: its hero_max_hp counts, like at the start of a run.
static func apply(build: BalanceBuildDef, player: Player, content: ContentDB, difficulty: DifficultyDef = null) -> void:
	var def := content.player
	player.perks.clear()
	player.base_stats = def.base_stats.duplicate()
	for id: Variant in build.upgrades:
		var u := upgrade(content, String(id))
		var level := int(build.upgrades[id])
		if u == null or level <= 0:
			continue
		match u.kind:
			UpgradeDef.Kind.STATS:
				if u.bonuses:
					player.base_stats = player.base_stats.plus(u.bonuses.times(level))
			UpgradeDef.Kind.STARTING_PERK:
				if u.perk:
					player.perks.add(u.perk)
	if difficulty and difficulty.hero_max_hp != 1.0:
		player.base_stats.max_hp = roundi(player.base_stats.max_hp * difficulty.hero_max_hp)
	for i in maxi(build.level - 1, 0):
		if def.level_bonus:
			player.base_stats = player.base_stats.plus(def.level_bonus)
	player.level = maxi(build.level, 1)
	player.xp = 0

	for slot: EquipmentDef.Slot in EquipmentDef.Slot.values():
		player.equipment.unequip(slot)
	var weapon := make_weapon(build, content)
	if weapon:
		player.equipment.equip(weapon)
	for armor in make_armors(build, content):
		player.equipment.equip(armor)

	for id: Variant in build.perks:
		var p := perk(content, String(id))
		if p == null:
			continue
		for i in clampi(int(build.perks[id]), 0, p.max_stacks):
			player.perks.add(p)
	player.learned_skill = build.learned_skill
	# Skills ready, as after a long walk to the boss (an equip puts new skills on a short cooldown).
	var none: Array[SkillDef] = []
	player.skills.set_skills(none)
	player._rebuild_skills(0.0)
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.health_changed.emit(player.hp, player.get_max_hp())


## A Player with the build on, outside any world (for the model: stats and perks only).
## Free it with free() when done.
static func make_player(build: BalanceBuildDef, content: ContentDB, difficulty: DifficultyDef = null) -> Player:
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.setup(content.player)
	apply(build, player, content, difficulty)
	return player
