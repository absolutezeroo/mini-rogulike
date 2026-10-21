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
