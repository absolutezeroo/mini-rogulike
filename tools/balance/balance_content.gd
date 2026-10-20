class_name BalanceContent
extends RefCounted
## What the balance tools measure, found by walking the content (ContentDB and the data/ folders),
## never from hand-made lists: a new weapon, perk, rune, affix, monster, boss, rank or difficulty
## is measured the next run without touching the tools.
## Also: the difficulty variants the tools know (the four difficulties and Nightmare +N
## ascensions, "nightmare+5"), and small lookups shared by the model, the arena and the lab.

## Difficulty keys measured when none are asked for (--difficulty): the whole curve.
const ALL_DIFFICULTIES := ["easy", "normal", "hard", "nightmare", "nightmare+5", "nightmare+10"]
## Folders scanned for every kind of content (and checked against ContentDB).
const FOLDERS := {
	"weapons": "res://data/items/weapons/",
	"armors": "res://data/items/armors/",
	"perks": ["res://data/perks/common/", "res://data/perks/relics/"],
	"families": "res://data/perks/synergies/",
	"runes": "res://data/runes/",
	"affixes": "res://data/affixes/",
	"upgrades": "res://data/upgrades/",
	"elites": "res://data/elites/",
	"ranks": "res://data/monster_ranks/",
	"monsters": "res://data/monsters/",
	"bosses": "res://data/monsters/bosses/",
	"encounters": "res://data/encounters/",
	"difficulties": "res://data/difficulties/",
	"tomes": "res://data/items/tomes/",
	"consumables": "res://data/items/consumables/",
}


## Every resource of the .tres files directly in `dir` (not its subfolders), sorted by file name.
static func scan(dir: String) -> Array:
	var result: Array = []
	var files := Array(DirAccess.get_files_at(dir))
	files.sort()
	for file: String in files:
		var path := dir.path_join(file.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var resource := load(path)
		if resource:
			result.append(resource)
	return result


static func scan_all(dirs: Variant) -> Array:
	if dirs is String:
		return scan(dirs)
	var result: Array = []
	for dir: String in dirs:
		result.append_array(scan(dir))
	return result


# --- Difficulties -------------------------------------------------------------

## The difficulty for a key: "easy", "normal", "hard", "nightmare", or "nightmare+N" (Nightmare
## with its first N ascensions, AscensionDef.apply_levels()). Null for an unknown key.
## The key is kept in the DifficultyDef's meta "balance_key" (see key()).
static func difficulty(content: ContentDB, difficulty_key: String) -> DifficultyDef:
	var base_id := difficulty_key.get_slice("+", 0)
	var level := int(difficulty_key.get_slice("+", 1)) if difficulty_key.contains("+") else 0
	var base: DifficultyDef = null
	for d in content.difficulties:
		if String(d.id) == base_id:
			base = d
	if base == null:
		return null
	if level <= 0:
		base.set_meta("balance_key", base_id)  # (meta only: never saved, changes nothing in the game)
		return base
	if not base.has_ascensions:
		return null
	var result := AscensionDef.apply_levels(base, content.ascensions, level)
	result.set_meta("balance_key", difficulty_key)
	return result


## The difficulties for `keys` (all of ALL_DIFFICULTIES when empty), in the curve's order.
static func difficulties(content: ContentDB, keys: PackedStringArray) -> Array[DifficultyDef]:
	var result: Array[DifficultyDef] = []
	var wanted := Array(keys) if not keys.is_empty() else ALL_DIFFICULTIES
	var ordered: Array = ALL_DIFFICULTIES.duplicate()
	for k: String in wanted:
		if not ordered.has(k):
			ordered.append(k)
	for k: String in ordered:
		if not wanted.has(k):
			continue
		var d := difficulty(content, k)
		if d:
			result.append(d)
		else:
			printerr("balance: unknown difficulty '%s' (easy, normal, hard, nightmare, nightmare+N)" % k)
	return result


## "normal", "nightmare+5"...
static func key(d: DifficultyDef) -> String:
	if d == null:
		return "?"
	return String(d.get_meta("balance_key", String(d.id)))


## Position on the curve (easy 0, normal 1, hard 2, nightmare 3, nightmare+N 3 + N/100).
static func rank_of(d_key: String) -> float:
	var base := d_key.get_slice("+", 0)
	var index := ["easy", "normal", "hard", "nightmare"].find(base)
	var level := int(d_key.get_slice("+", 1)) if d_key.contains("+") else 0
	return index + level / 100.0


# --- Acts, bosses, monsters -----------------------------------------------------------

static func act_of_boss(content: ContentDB, boss: BossDef) -> int:
	for i in content.dungeon.acts.size():
		if content.dungeon.acts[i].all_bosses().has(boss):
			return i + 1
	return 0


## The boss floor of act `act` (1-based).
static func boss_depth(content: ContentDB, act: int) -> int:
	return content.dungeon.first_depth(act - 1) + content.dungeon.acts[act - 1].floors - 1


## Every boss of every act (main boss first), in act order.
static func bosses(content: ContentDB) -> Array[BossDef]:
	var result: Array[BossDef] = []
	for act in content.dungeon.acts:
		for boss in act.all_bosses():
			if not result.has(boss):
				result.append(boss)
	return result


## The normal floors of act `act` where `monster` can spawn ([] if never).
static func monster_depths(content: ContentDB, act: int, monster: MonsterDef) -> Array[int]:
	var result: Array[int] = []
	var first := content.dungeon.first_depth(act - 1)
	for depth in range(first, boss_depth(content, act)):
		if depth >= monster.min_depth:
			result.append(depth)
	return result


## Monster ranks: the plain elite then the rare ones (as DungeonConfig lists them), plus any rank
## file in data/monster_ranks/ that the config doesn't use (reported, still measured).
static func ranks(content: ContentDB) -> Array[MonsterRankDef]:
	var result: Array[MonsterRankDef] = []
	if content.dungeon.elite_rank:
		result.append(content.dungeon.elite_rank)
	for rank in content.dungeon.rare_ranks:
		if rank and not result.has(rank):
			result.append(rank)
	for rank: MonsterRankDef in scan(FOLDERS.ranks):
		var known := result.any(func(r: MonsterRankDef) -> bool: return r.id == rank.id)
		if not known:
			result.append(rank)
	return result


## Ranks a boss can roll (boss_chance > 0).
static func boss_ranks(content: ContentDB) -> Array[MonsterRankDef]:
	return ranks(content).filter(func(r: MonsterRankDef) -> bool: return r.boss_chance > 0.0)


## Monsters that can be summoned by a skill or a death trait, with who summons them.
static func summoners(content: ContentDB) -> Dictionary:
	var result := {}
	var all: Array = content.all_monsters()
	all.append_array(bosses(content))
	for monster: MonsterDef in all:
		var skill_list: Array[SkillDef] = monster.skills.duplicate()
		if monster is BossDef:
			for phase in (monster as BossDef).phases:
				skill_list.append_array(phase.skills)
		for skill in skill_list:
			if skill == null:
				continue
			for effect in skill.effects:
				if effect is SummonEffect:
					for m in (effect as SummonEffect).monsters:
						if m:
							if not result.has(m.id):
								result[m.id] = PackedStringArray()
							if not (result[m.id] as PackedStringArray).has(String(monster.id)):
								(result[m.id] as PackedStringArray).append(String(monster.id))
	return result


## "summoner", "support", "ranged", "melee"... what a monster is, from its skills and weapon.
static func roles(monster: MonsterDef) -> PackedStringArray:
	var result := PackedStringArray()
	if monster.weapon:
		result.append("ranged" if monster.weapon.kind == WeaponDef.Kind.RANGED else "melee")
	for skill in monster.skills:
		if skill == null:
			continue
		for effect in skill.effects:
			if effect is SummonEffect and not result.has("summoner"):
				result.append("summoner")
			elif effect is AllyEffect and not result.has("support"):
				result.append("support")
	for t in monster.traits:
		if t is DeathSpawnTrait and not result.has("splits"):
			result.append("splits")
		elif t is DeathBurstTrait and not result.has("bursts"):
			result.append("bursts")
	return result


# --- Gear and perks ---------------------------------------------------------------

## Every player weapon (data/items/weapons/, not monster/), sorted by id.
static func weapons() -> Array[WeaponDef]:
	var result: Array[WeaponDef] = []
	for w: Variant in scan(FOLDERS.weapons):
		if w is WeaponDef:
			result.append(w)
	return result


static func perks() -> Array[PerkDef]:
	var result: Array[PerkDef] = []
	for p: Variant in scan_all(FOLDERS.perks):
		if p is PerkDef:
			result.append(p)
	return result


static func of_type(folder: String, type: Variant) -> Array:
	return scan(folder).filter(func(r: Resource) -> bool: return is_instance_of(r, type))


## Content files missing from ContentDB (they would never appear in a run): one line each.
static func unlisted(content: ContentDB) -> PackedStringArray:
	var result := PackedStringArray()
	var checks := [
		["perks", scan_all(FOLDERS.perks), content.perks],
		["runes", scan(FOLDERS.runes), content.runes],
		["affixes", scan(FOLDERS.affixes), content.item_affixes],
		["upgrades", scan(FOLDERS.upgrades), content.upgrades],
		["elites", scan(FOLDERS.elites), content.elite_affixes],
		["families", scan(FOLDERS.families), content.synergies],
		["encounters", scan(FOLDERS.encounters), content.encounters],
		["difficulties", scan(FOLDERS.difficulties), content.difficulties],
	]
	for check: Array in checks:
		var listed: Array = check[2]
		for resource: Resource in check[1]:
			if not listed.has(resource):
				result.append("%s: %s is in data/ but not in content_db.tres" % [check[0], resource.resource_path.get_file()])
	var items: Array = content.items.duplicate()
	items.append_array(content.locked_items)
	items.append_array(content.player.starting_equipment)
	for w in weapons():
		if not items.has(w):
			result.append("weapons: %s is in data/ but can't drop (not in items, locked items or the starting kit)" % w.resource_path.get_file())
	var in_acts := content.all_monsters()
	var summoned := summoners(content)
	for m: Variant in scan(FOLDERS.monsters):
		if m is MonsterDef and not in_acts.has(m) and not summoned.has((m as MonsterDef).id):
			result.append("monsters: %s is in no act and summoned by no one" % (m as MonsterDef).resource_path.get_file())
	var boss_list := bosses(content)
	for b: Variant in scan(FOLDERS.bosses):
		if b is BossDef and not boss_list.has(b):
			result.append("bosses: %s is in no act" % (b as BossDef).resource_path.get_file())
	return result


## A PerkDef by id among `list` (or every perk file).
static func perk(id: String) -> PerkDef:
	for p in perks():
		if String(p.id) == id:
			return p
	return null


## Average of an Array of floats (-1 when empty).
static func mean(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var total := 0.0
	for v: float in values:
		total += v
	return total / values.size()


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	return sorted[n / 2] if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) * 0.5
