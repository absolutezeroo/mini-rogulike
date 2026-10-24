class_name KeeperSnapshot
extends RefCounted
## The hero of a run that ended in "take his place" (EndingDef.keeper TAKE), kept in the profile
## (Profile.keeper) to wait at the bottom of the next runs' Well as the Nameless Keeper
## (NamelessKeeperDef.build()). Plain JSON data, by content ids rather than file paths (the
## profile outlives renamed files): what he wore (each piece with its rarity, affixes, runes and
## item level), the skills he had beyond the roll, his perks with their levels, his level and
## numbers, the run's difficulty and ascension, the date, and the pseudonym he played under (if
## he chose one). Versioned (VERSION); reading it back skips whatever the game no longer has (an
## id gone, a damaged entry): the Keeper is made of what is left.

const VERSION := 1

## The data, as Profile keeps it (empty: no snapshot).
var data := {}


func _init(snapshot: Dictionary = {}) -> void:
	data = snapshot


## Taken from `player` as `run` ends (the moment the ending is chosen). `known_as`: the name he
## played under, "" for none.
static func take(player: Player, run: RunState, known_as: String = "") -> Dictionary:
	var worn: Array = []
	for slot: EquipmentDef.Slot in EquipmentDef.Slot.values():
		var item := player.equipment.get_item(slot)
		if item:
			worn.append(_item_data(item))
	var skill_ids: Array = []
	for skill in player.skills.skills:
		if skill and not player.def.innate_skills.has(skill) and not skill_ids.has(String(skill.id)):
			skill_ids.append(String(skill.id))
	var perk_list: Array = []
	for entry in player.perks.entries:
		if entry.perk:
			perk_list.append({ "id": String(entry.perk.id), "stacks": entry.stacks })
	var stats := player.get_stats()
	return {
		"version": VERSION,
		"date": int(Time.get_unix_time_from_system()),
		"difficulty": String(run.difficulty.id) if run and run.difficulty else "",
		"ascension": run.difficulty.ascension if run and run.difficulty else 0,
		"level": player.level,
		"max_health": player.get_max_hp(),
		"power": player.get_power(),
		"armor": stats.defense,
		"pseudonym": known_as,
		"gear": worn,
		"skills": skill_ids,
		"perks": perk_list,
	}


## What a worn piece is: its id, and for a rolled one its rarity, affixes, runes and item level.
static func _item_data(item: EquipmentDef) -> Dictionary:
	var base := item.base_item if item.is_rolled() else item
	return {
		"id": String(base.id),
		"rarity": item.rarity,
		"affixes": item.affixes.map(func(affix: ItemAffixDef) -> String: return String(affix.id)),
		"runes": item.runes.map(func(rune: RuneDef) -> String: return String(rune.id)),
		"level": item.item_level,
	}


## A snapshot this game can read: a Dictionary of a version it knows, with gear to wear.
static func is_valid(snapshot: Variant) -> bool:
	return snapshot is Dictionary and not (snapshot as Dictionary).is_empty() \
		and int((snapshot as Dictionary).get("version", 0)) >= 1 and int((snapshot as Dictionary).get("version", 0)) <= VERSION


# --- Reading it back ------------------------------------------------------------------------

func level() -> int:
	return maxi(int(data.get("level", 1)), 1)


func date() -> int:
	return int(data.get("date", 0))


func pseudonym() -> String:
	return str(data.get("pseudonym", ""))


## The run's difficulty (DifficultyDef id) and ascension level.
func difficulty_id() -> StringName:
	return StringName(str(data.get("difficulty", "")))


func ascension() -> int:
	return int(data.get("ascension", 0))


## What he wore, made again (rolled copies as he had them); pieces the game no longer has are
## left out.
func gear(content: ContentDB) -> Array[EquipmentDef]:
	var result: Array[EquipmentDef] = []
	var worn: Variant = data.get("gear", [])
	if not worn is Array:
		return result
	for entry: Variant in worn:
		var item := _make_item(entry, content)
		if item and not result.any(func(other: EquipmentDef) -> bool: return other.slot == item.slot):
			result.append(item)
	return result


## His weapon (null if the game no longer has it).
func weapon(content: ContentDB) -> WeaponDef:
	for item in gear(content):
		if item is WeaponDef:
			return item as WeaponDef
	return null


## What he wore apart from his weapon.
func armor(content: ContentDB) -> Array[EquipmentDef]:
	var result: Array[EquipmentDef] = []
	for item in gear(content):
		if not item is WeaponDef:
			result.append(item)
	return result


## His skills beyond the roll, found where the game keeps them: his weapon's, then the tomes'.
func skills(content: ContentDB) -> Array[SkillDef]:
	var known := {}
	var held := weapon(content)
	if held:
		for skill in held.skills:
			if skill:
				known[skill.id] = skill
	for item in content.items + content.locked_items:
		var tome := item as SkillTomeDef
		if tome and tome.skill and not known.has(tome.skill.id):
			known[tome.skill.id] = tome.skill
	var result: Array[SkillDef] = []
	var ids: Variant = data.get("skills", [])
	if ids is Array:
		for id: Variant in ids:
			var skill: SkillDef = known.get(StringName(str(id)))
			if skill and not result.has(skill):
				result.append(skill)
	return result


## His perks and relics, [{ perk: PerkDef, stacks: int }]; ids the game no longer has are skipped.
func perks(content: ContentDB) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var saved: Variant = data.get("perks", [])
	if not saved is Array:
		return result
	for entry: Variant in saved:
		if not entry is Dictionary:
			continue
		var id := StringName(str((entry as Dictionary).get("id", "")))
		for perk in content.perks:
			if perk and perk.id == id:
				result.append({ "perk": perk, "stacks": maxi(int((entry as Dictionary).get("stacks", 1)), 1) })
				break
	return result


## His weapon's name as the game says it now (rolled names are made in the language shown).
func weapon_name(content: ContentDB) -> String:
	var held := weapon(content)
	return held.display_name if held else ""


static func _make_item(entry: Variant, content: ContentDB) -> EquipmentDef:
	if not entry is Dictionary:
		return null
	var saved := entry as Dictionary
	var base := _find(_wearable(content), StringName(str(saved.get("id", "")))) as EquipmentDef
	if base == null:
		return null
	var rarity := clampi(int(saved.get("rarity", ItemRarity.COMMON)), ItemRarity.COMMON, ItemRarity.EPIC)
	var affixes: Array[ItemAffixDef] = []
	for id: Variant in _list(saved.get("affixes", [])):
		var affix := _find(content.item_affixes, StringName(str(id))) as ItemAffixDef
		if affix:
			affixes.append(affix)
	var runes: Array[RuneDef] = []
	for id: Variant in _list(saved.get("runes", [])):
		var rune := _find(content.runes, StringName(str(id))) as RuneDef
		if rune:
			runes.append(rune)
	var item_level := maxi(int(saved.get("level", 1)), 1)
	if rarity == ItemRarity.COMMON and affixes.is_empty() and runes.is_empty() and item_level <= 1:
		return base
	return LootRoller.make(base, rarity, affixes, runes, item_level)


## Everything a hero can wear: the items found, the shrine's locked ones, what he starts with.
static func _wearable(content: ContentDB) -> Array:
	var pool: Array = []
	pool.append_array(content.items)
	pool.append_array(content.locked_items)
	if content.player:
		pool.append_array(content.player.starting_equipment)
	return pool


static func _find(pool: Array, id: StringName) -> ContentDef:
	if id == &"":
		return null
	for entry: Variant in pool:
		var def := entry as ContentDef
		if def and def.id == id:
			return def
	return null


static func _list(value: Variant) -> Array:
	return value as Array if value is Array else []
