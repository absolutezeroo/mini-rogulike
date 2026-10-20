class_name LootRoller
## Turns found equipment into copies of the floor's item level (ItemLevelRules), Magic, Rare or
## Epic ones with random affixes. Rarity chances grow with depth (DungeonConfig > Loot) and with
## the source: a boss or an elite drops better than a crate (`quality`). Consumables and tomes
## are never rolled.

const LEVELS: ItemLevelRules = preload("res://data/items/item_levels.tres")


## `item` at the level of `depth` (itself on floor 1 if Common), or a better rolled copy of it.
## `min_rarity`: never below it (the Trophy Hunter node's Magic).
static func roll(item: ItemDef, depth: int, quality: float, config: DungeonConfig, affixes: Array[ItemAffixDef], rng: RandomNumberGenerator, min_rarity: int = ItemRarity.COMMON) -> ItemDef:
	var equipment := item as EquipmentDef
	if equipment == null or equipment.is_rolled():
		return item
	var level := maxi(depth, 1)
	var rarity := maxi(pick_rarity(depth, quality, config, rng), min_rarity)
	if rarity == ItemRarity.COMMON:
		return item if level <= 1 else make(equipment, rarity, [], [], level)
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
	return make(equipment, rarity, picked, [], level)


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


## A copy of `base` with that rarity, those affixes and runes, at item `level` (also how saved
## items come back, and how a plain weapon becomes its own copy when a rune goes in).
static func make(base: EquipmentDef, rarity: int, affixes: Array[ItemAffixDef], runes: Array[RuneDef] = [], level: int = 1) -> EquipmentDef:
	var item := base.duplicate() as EquipmentDef
	item.base_item = base
	item.rarity = rarity
	item.affixes = affixes
	item.runes = runes.duplicate()  # its own list, never the plain item's
	item.item_level = maxi(level, 1)
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
	var health := LEVELS.armor_health(base.slot, item.item_level) if base.slot != EquipmentDef.Slot.WEAPON else 0
	if health > 0:
		total.max_hp += health
	item.bonuses = total
	item.display_name = prefix + base.display_name + suffix
	var weapon := item as WeaponDef
	if weapon:
		var base_damage := (base as WeaponDef).damage
		# Better than common: at least one more damage. A common copy (a rune set in a plain weapon) keeps it.
		weapon.damage = base_damage if rarity == ItemRarity.COMMON else maxi(base_damage + 1, roundi(base_damage * power))
		weapon.damage += LEVELS.weapon_damage(base as WeaponDef, item.item_level)
		if weapon.on_hit == null:
			for affix in affixes:
				if affix.on_hit:
					weapon.on_hit = affix.on_hit
					break
	return item


# --- Saving -------------------------------------------------------------------

## Plain items save as their path, rolled ones as { base, rarity, affixes, runes, level }.
static func to_data(item: ItemDef) -> Variant:
	var equipment := item as EquipmentDef
	if equipment and equipment.is_rolled():
		return { "base": RunSave.ref(equipment.base_item), "rarity": equipment.rarity, "affixes": RunSave.refs(equipment.affixes), "runes": RunSave.refs(equipment.runes), "level": equipment.item_level }
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
		return make(base, clampi(int(data.get("rarity", 1)), ItemRarity.COMMON, ItemRarity.EPIC), affixes, runes, maxi(int(data.get("level", 1)), 1))
	return RunSave.load_ref(data) as ItemDef
