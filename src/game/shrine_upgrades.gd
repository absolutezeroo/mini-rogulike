class_name ShrineUpgrades
## What the shrine's upgrades (bought with souls, see UpgradeDef and Profile) do to a run.


## Items the shrine unlocked: they can be found in the dungeon.
static func unlocked_items(content: ContentDB) -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for upgrade in content.upgrades:
		if upgrade.kind == UpgradeDef.Kind.UNLOCK and Profile.level_of(upgrade) > 0:
			items.append_array(upgrade.items)
	return items


## Rerolls (`kind` REROLLS) or banishes (BANISHES) the shrine adds to every run.
static func extra_charges(content: ContentDB, kind: UpgradeDef.Kind) -> int:
	var total := 0
	for upgrade in content.upgrades:
		if upgrade.kind == kind:
			total += Profile.level_of(upgrade)
	return total


## A new hero: stats, starting items and perks from the shrine, then the difficulty's max HP.
static func apply_to(player: Player, content: ContentDB, difficulty: DifficultyDef) -> void:
	for upgrade in content.upgrades:
		var level := Profile.level_of(upgrade)
		if level <= 0:
			continue
		match upgrade.kind:
			UpgradeDef.Kind.STATS:
				if upgrade.bonuses:
					player.base_stats = player.base_stats.plus(upgrade.bonuses.times(level))
			UpgradeDef.Kind.STARTING_ITEMS:
				for i in level:
					for item in upgrade.items:
						player.store(item)
			UpgradeDef.Kind.STARTING_PERK:
				if upgrade.perk:
					player.perks.add(upgrade.perk)
	if difficulty.hero_max_hp != 1.0:
		player.base_stats.max_hp = roundi(player.base_stats.max_hp * difficulty.hero_max_hp)
	player.invalidate_stats()
	player.hp = player.get_max_hp()
