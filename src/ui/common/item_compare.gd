class_name ItemCompare
## What changes if the hero wears an item instead of what they wear now, in plain words:
## "+3 damage", "-1 armor", "skills recharge 5% faster"... (the shop's item card).


## "Compared with your Katana:" / "Nothing on your head yet. It adds:".
static func heading(item: EquipmentDef, worn: EquipmentDef) -> String:
	if worn != null:
		return TranslationServer.tr("Compared with your %s:") % TranslationServer.tr(worn.display_name)
	if item.slot == EquipmentDef.Slot.WEAPON:
		return TranslationServer.tr("You hold no weapon yet. It adds:")
	if item.slot == EquipmentDef.Slot.HEAD:
		return TranslationServer.tr("Nothing on your head yet. It adds:")
	return TranslationServer.tr("Nothing on your body yet. It adds:")


## `item` is worse than what is worn (`worn`): what "Dismantle the worse" breaks down and what
## "Better only" leaves on the ground. Never when it is of a higher item level or rarer, has a rune
## set, or an affix (or a weapon's own status) doing something the worn one doesn't (Vampiric,
## Burning...). Of a lower level or rarity: worse unless it is better at its main job (more damage
## per second for a weapon; more Health, Armor or Damage for an armor), quicker or lighter does
## not save it. Same level and rarity: worse only with not one stat line in its favour (lines()).
## Nothing is worse than an empty slot.
static func is_worse(item: EquipmentDef, worn: EquipmentDef) -> bool:
	if item == null or worn == null or item == worn or item.slot != worn.slot:
		return false
	if item.item_level > worn.item_level or item.rarity > worn.rarity or not item.runes.is_empty():
		return false
	for affix in item.affixes:
		if affix and (affix.on_hit or not affix.passives.is_empty()) and not worn.affixes.has(affix):
			return false
	var weapon := item as WeaponDef
	if weapon and weapon.on_hit and weapon.on_hit != (worn as WeaponDef).on_hit:
		return false  # it poisons, burns or slows: not the same tool
	if item.item_level < worn.item_level or item.rarity < worn.rarity:
		return not _better_at_main_job(item, worn)
	for change in lines(item, worn):
		if change.good:
			return false
	return true


## A weapon: more damage per second (what item levels grow). An armor: more Health, Armor or Damage.
static func _better_at_main_job(item: EquipmentDef, worn: EquipmentDef) -> bool:
	if item is WeaponDef and worn is WeaponDef:
		return damage_per_second(item as WeaponDef) > damage_per_second(worn as WeaponDef) + 0.05
	var mine := _stats(item)
	var theirs := _stats(worn)
	return mine.max_hp > theirs.max_hp or mine.defense > theirs.defense or mine.attack > theirs.attack


## A weapon's damage per second with its own bonuses (a volley counts its share: ItemLevelRules).
static func damage_per_second(weapon: WeaponDef) -> float:
	var share := 1.0
	if weapon.kind == WeaponDef.Kind.RANGED:
		share = maxf(weapon.projectile_damage * maxi(weapon.projectile_count, 1), 0.1)
	return _damage(weapon) * share / maxf(weapon.cooldown, 0.01)


## One entry per stat that changes: { text, good }. Empty when nothing changes.
static func lines(item: EquipmentDef, worn: EquipmentDef) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var mine := _stats(item)
	var theirs := _stats(worn)
	if worn != null:
		var levels := item.item_level - worn.item_level
		_add_int(result, levels, TranslationServer.tr("%+d item level") if absi(levels) == 1 else TranslationServer.tr("%+d item levels"))
	_add_int(result, _damage(item) - _damage(worn), TranslationServer.tr("%+d damage"))
	if item is WeaponDef and worn is WeaponDef:
		var speed := 1.0 / maxf((item as WeaponDef).cooldown, 0.01) - 1.0 / maxf((worn as WeaponDef).cooldown, 0.01)
		if absf(speed) >= 0.05:
			result.append({ "text": TranslationServer.tr("%+.1f hits per second") % speed, "good": speed > 0.0 })
	_add_int(result, mine.max_hp - theirs.max_hp, TranslationServer.tr("%+d max health"))
	_add_int(result, mine.defense - theirs.defense, TranslationServer.tr("%+d armor"))
	_add_int(result, roundi(mine.move_speed - theirs.move_speed), TranslationServer.tr("%+d move speed"))
	_add_percent(result, mine.crit_chance - theirs.crit_chance, TranslationServer.tr("%+d%% critical hit chance"))
	_add_percent(result, mine.attack_speed - theirs.attack_speed, TranslationServer.tr("%+d%% attack speed"))
	_add_percent(result, mine.skill_power - theirs.skill_power, TranslationServer.tr("%+d%% skill damage"))
	var recharge := roundi((mine.cooldown_reduction - theirs.cooldown_reduction) * 100.0)
	if recharge != 0:
		var words := TranslationServer.tr("skills recharge %d%% faster") if recharge > 0 else TranslationServer.tr("skills recharge %d%% slower")
		result.append({ "text": words % absi(recharge), "good": recharge > 0 })
	return result


## The damage an item adds to the hero's hits (a weapon's own, plus any bonus).
static func _damage(item: EquipmentDef) -> int:
	if item == null:
		return 0
	return ((item as WeaponDef).damage if item is WeaponDef else 0) + _stats(item).attack


static func _stats(item: EquipmentDef) -> StatBlock:
	return item.bonuses if item and item.bonuses else StatBlock.new()


## `words`: the whole line, translated, with the number in it ("%+d armor").
static func _add_int(result: Array[Dictionary], change: int, words: String) -> void:
	if change != 0:
		result.append({ "text": words % change, "good": change > 0 })


static func _add_percent(result: Array[Dictionary], change: float, words: String) -> void:
	var percent := roundi(change * 100.0)
	if percent != 0:
		result.append({ "text": words % percent, "good": percent > 0 })
