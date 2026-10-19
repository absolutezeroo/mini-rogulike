class_name LootRoller
## Turns found equipment into Magic, Rare or Epic copies with random affixes.
## Chances grow with depth (DungeonConfig > Loot) and with the source: a boss or an elite
## drops better than a crate (`quality`). Consumables and tomes are never rolled.


## `item` itself (Common), or a better rolled copy of it.
static func roll(item: ItemDef, depth: int, quality: float, config: DungeonConfig, affixes: Array[ItemAffixDef], rng: RandomNumberGenerator) -> ItemDef:
	var equipment := item as EquipmentDef
	if equipment == null or equipment.is_rolled():
		return item
	var rarity := pick_rarity(depth, quality, config, rng)
	if rarity == ItemRarity.COMMON:
		return item
	var fitting := affixes.filter(func(affix: ItemAffixDef) -> bool: return affix.fits(equipment) and affix.min_depth <= depth)
	var picked: Array[ItemAffixDef] = []
	for i in ItemRarity.AFFIX_COUNT[rarity]:
		var weights := PackedInt32Array()
		for affix: ItemAffixDef in fitting:
			weights.append(0 if picked.has(affix) else affix.spawn_weight)
		var affix: ItemAffixDef = RandomUtils.pick_weighted(fitting, weights, rng)
		if affix == null:
			break
		picked.append(affix)
	return make(equipment, rarity, picked)


static func pick_rarity(depth: int, quality: float, config: DungeonConfig, rng: RandomNumberGenerator) -> int:
	var levels := depth - 1
	var weights := [
		config.common_weight,
		(config.magic_weight + config.magic_weight_per_depth * levels) * quality,
		(config.rare_weight + config.rare_weight_per_depth * levels) * quality,
		(config.epic_weight + config.epic_weight_per_depth * levels) * quality,
	]
	var total := 0.0
	for weight: float in weights:
		total += weight
	var roll := rng.randf() * total
	for rarity in weights.size():
		roll -= weights[rarity]
		if roll < 0.0:
			return rarity
	return ItemRarity.COMMON


## A copy of `base` with that rarity, those affixes and runes (also how saved items come back,
## and how a plain weapon becomes its own copy when a rune goes in).
static func make(base: EquipmentDef, rarity: int, affixes: Array[ItemAffixDef], runes: Array[RuneDef] = []) -> EquipmentDef:
	var item := base.duplicate() as EquipmentDef
	item.base_item = base
	item.rarity = rarity
	item.affixes = affixes
	item.runes = runes.duplicate()  # its own list, never the plain item's
	var power := ItemRarity.POWER[rarity]
	var total := StatBlock.new()
	if base.bonuses:
		total = total.plus(base.bonuses).scaled(power)
	# At most one prefix and one suffix in the name; more affixes still count.
	var prefix := ""
	var suffix := ""
	for affix in affixes:
		if affix.bonuses:
			total = total.plus(affix.bonuses)
		if affix.is_prefix and prefix.is_empty():
			prefix = affix.display_name + " "
		elif not affix.is_prefix and suffix.is_empty():
			suffix = " " + affix.display_name
	item.bonuses = total
	item.display_name = prefix + base.display_name + suffix
	var weapon := item as WeaponDef
	if weapon:
		weapon.damage = maxi(base.damage + 1, roundi((base as WeaponDef).damage * power))
		if weapon.on_hit == null:
			for affix in affixes:
				if affix.on_hit:
					weapon.on_hit = affix.on_hit
					break
	return item


# --- Saving -------------------------------------------------------------------

## Plain items save as their path, rolled ones as { base, rarity, affixes, runes }.
static func to_data(item: ItemDef) -> Variant:
	var equipment := item as EquipmentDef
	if equipment and equipment.is_rolled():
		return { "base": RunSave.ref(equipment.base_item), "rarity": equipment.rarity, "affixes": RunSave.refs(equipment.affixes), "runes": RunSave.refs(equipment.runes) }
	return RunSave.ref(item)


static func from_data(data: Variant) -> ItemDef:
	if data is Dictionary:
		var base := RunSave.load_ref(data.get("base")) as EquipmentDef
		if base == null:
			return null
		var affixes: Array[ItemAffixDef] = []
		for reference: Variant in data.get("affixes", []):
			var affix := RunSave.load_ref(reference) as ItemAffixDef
			if affix:
				affixes.append(affix)
		var runes: Array[RuneDef] = []
		for reference: Variant in data.get("runes", []):
			var rune := RunSave.load_ref(reference) as RuneDef
			if rune:
				runes.append(rune)
		return make(base, clampi(int(data.get("rarity", 1)), ItemRarity.COMMON, ItemRarity.EPIC), affixes, runes)
	return RunSave.load_ref(data) as ItemDef
