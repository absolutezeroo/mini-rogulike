class_name UnitTests
extends TestSuite
## Rules and data, no game running: stats, combat, content, generation, items, perks, bosses, profile.

func run() -> void:
	_test_stat_block()
	_test_combat_rules()
	_test_content()
	_test_generation()
	_test_inventory_and_equipment()
	_test_perks()
	_test_bosses()
	_test_profile()


func _test_stat_block() -> void:
	var a := StatBlock.new()
	a.max_hp = 10
	a.attack = 2
	var b := StatBlock.new()
	b.attack = 3
	b.defense = 1
	var sum := a.plus(b)
	check(sum.max_hp == 10 and sum.attack == 5 and sum.defense == 1, "StatBlock.plus adds every stat")
	check(a.attack == 2, "StatBlock.plus does not modify its operands")
	check(b.describe() == "+3 ATK  +1 DEF", "StatBlock.describe: got '%s'" % b.describe())
	var tripled := b.times(3)
	check(tripled.attack == 9 and tripled.defense == 3 and b.attack == 3, "StatBlock.times multiplies a copy")
	var fast := StatBlock.new()
	fast.attack_speed = 0.25
	check(is_equal_approx(a.plus(fast).attack_speed, 0.25), "attack speed adds up")
	check(fast.describe() == "+25% ATK SPEED", "attack speed is described: got '%s'" % fast.describe())


func _test_combat_rules() -> void:
	check(Combat.mitigate(10, 3) == 7, "defense removes damage")
	check(Combat.mitigate(2, 50) == 1, "a hit always deals at least 1")
	# Floor rules: difficulty x event x depth, in one place.
	var nightmare := CONTENT.get_difficulty(&"nightmare")
	var blood_moon: FloorEventDef = load("res://data/floor_events/blood_moon.tres")
	var plain := FloorRules.make(CONTENT.dungeon, null, null, 1)
	var hard := FloorRules.make(CONTENT.dungeon, nightmare, blood_moon, 5)
	check(plain.monster_damage() == 1.0 and plain.dungeon_damage(4) == 5, "no difficulty: neutral rules (trap 4 + depth 1)")
	check(is_equal_approx(hard.monster_damage(), nightmare.monster_damage * blood_moon.monster_damage), "difficulty and event multiply")
	check(hard.dungeon_damage(4) == roundi(9 * hard.monster_damage()), "dungeon damage grows with depth and the multipliers")
	check(hard.gold(10) == roundi(10 * blood_moon.gold), "the event changes the gold")
	var slime: MonsterDef = load("res://data/monsters/slime.tres")
	check(hard.scale_monster(slime.stats, false).max_hp > plain.scale_monster(slime.stats, false).max_hp and slime.stats.max_hp == plain.scale_monster(slime.stats, false).max_hp, "monster stats scale without touching the def")


func _test_content() -> void:
	var chances: Array = []
	for id in [&"easy", &"normal", &"hard", &"nightmare"]:
		chances.append(CONTENT.get_difficulty(id).curse_chance)
	check(chances[0] < chances[1] and chances[1] < chances[2] and chances[2] < chances[3], "curses: rare on Easy, often on Nightmare %s" % str(chances))
	check(CONTENT.player != null and CONTENT.dungeon != null, "content db has player and dungeon config")
	check(CONTENT.all_monsters().size() >= 20, "a big bestiary (%d monsters)" % CONTENT.all_monsters().size())
	var ids := {}
	for monster in CONTENT.all_monsters():
		check(monster.weapon != null, "%s has a weapon" % monster.id)
		check(monster.stats != null and monster.stats.max_hp > 0, "%s has HP" % monster.id)
		check(not ids.has(monster.id), "duplicate id %s" % monster.id)
		ids[monster.id] = true
	for item in CONTENT.items:
		check(not item.display_name.is_empty(), "%s has a name" % item.id)
		check(not ids.has(item.id), "duplicate id %s" % item.id)
		ids[item.id] = true
	var rng := RandomNumberGenerator.new()
	for depth in range(1, 8):
		check(CONTENT.pick_monster(depth, rng) != null, "a monster can spawn at depth %d" % depth)
		check(CONTENT.pick_item(depth, rng) != null, "an item can spawn at depth %d" % depth)
	var act_one := CONTENT.dungeon.acts[0]
	check(act_one.monsters.has(CONTENT.pick_monster(1, rng)), "floors spawn monsters of their act")
	check(CONTENT.dungeon.acts[2].monsters.has(CONTENT.pick_monster(8, rng)), "act 3 floors spawn act 3 monsters")
	check(CONTENT.sounds != null, "content db has a sound bank")
	for property in CONTENT.sounds.get_property_list():
		if property.type == TYPE_OBJECT and property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			check(CONTENT.sounds.get(property.name) != null, "sound bank: %s is set" % property.name)
	for item in CONTENT.items:
		if item is WeaponDef:
			check(item.attack_sound != null, "%s has an attack sound" % item.id)
		check(item.icon != null, "%s has an icon" % item.id)
	for monster in CONTENT.all_monsters():
		check(monster.frames != null and monster.frames.has_animation(&"walk_down"), "%s is animated" % monster.id)
		check(monster.icon != null, "%s has a sprite" % monster.id)
	for item in CONTENT.items:
		if item is WeaponDef:
			check(item.skills.size() == 2, "%s grants 2 skills" % item.id)
			for skill in item.skills:
				check(skill != null and skill.icon != null and skill.cooldown > 0.0 and not skill.effects.is_empty(), "%s: skill set up" % item.id)
		if item is SkillTomeDef:
			check(item.skill != null and item.skill.icon != null, "%s teaches a skill" % item.id)
	check(CONTENT.items.any(func(i: ItemDef) -> bool: return i is SkillTomeDef), "tomes can be found")
	for item in CONTENT.items + CONTENT.locked_items:
		check(item.resource_path.begins_with("res://data/items/") and not item.resource_path.contains("::"), "%s is its own file (saves point to it)" % item.id)
		check(item.value > 0, "%s has a price" % item.id)
	check(CONTENT.item_affixes.size() >= 10 and CONTENT.dungeon.merchant != null, "affixes and the merchant are set")
	check(CONTENT.props.size() >= 3, "props listed")
	for prop in CONTENT.props:
		check(prop.icon != null and prop.is_breakable(), "%s is a breakable prop with a sprite" % prop.id)
	check(CONTENT.props.any(func(p: PropDef) -> bool: return p.is_explosive()), "there is an explosive prop")
	for act in CONTENT.dungeon.acts:
		check(act.hazards.size() >= 4, "%s has its hazards" % act.title)
		check(act.hazards.any(func(h: HazardDef) -> bool: return h.min_depth <= 1), "%s has hazards from its first floor" % act.title)
	var hazards := CONTENT.all_hazards()
	for hazard in hazards:
		if hazard is ArrowTrapDef:
			check(hazard.launcher_texture != null and hazard.arrow_texture != null and hazard.damage > 0, "%s has a slit, arrows and damage" % hazard.id)
		elif hazard is TrapDef:
			check(hazard.active_sheet != null and hazard.damage > 0, "%s has art and damage" % hazard.id)
		elif hazard is PitDef:
			check(hazard.tileset != null and hazard.fall_damage > 0.0, "%s has art and hurts" % hazard.id)
			check(not hazard.is_crumbling() or hazard.crack_texture != null, "%s shows its cracks" % hazard.id)
		elif hazard is QuicksandDef:
			check(hazard.sheet != null and hazard.slow > 0.0, "%s has art and slows" % hazard.id)
	for kind: Script in [TrapDef, ArrowTrapDef, PitDef, QuicksandDef]:
		check(hazards.any(func(h: HazardDef) -> bool: return h.get_script() == kind), "a hazard of each kind (%s)" % kind.get_global_name())
	check(hazards.any(func(h: HazardDef) -> bool: return h is PitDef and h.is_crumbling()), "there is crumbling floor")
	check(CONTENT.elite_affixes.size() >= 5, "elite affixes listed")
	for affix in CONTENT.elite_affixes:
		check(affix.perk != null and not affix.display_name.is_empty(), "%s elite affix has a perk" % affix.id)
	check(CONTENT.dungeon.chest != null and CONTENT.dungeon.chest.trapped_chance > 0.0 and CONTENT.dungeon.ambush_chest != null, "chests and ambush rewards set")
	check(CONTENT.all_monsters().any(func(m: MonsterDef) -> bool: return m.flies), "some monsters fly")
	check(CONTENT.sounds.fall != null and CONTENT.sounds.ambush != null and CONTENT.sounds.soul != null, "falls, ambushes and souls have sounds")
	var story := CONTENT.story
	check(story != null and story.title == "Le Puits des Âmes" and not story.tagline.is_empty(), "the game has its name")
	check(story.intro_pages.size() >= 4 and not story.victory_text.is_empty() and story.death_lines.size() >= 2, "the story is written")
	check(CONTENT.floor_events.size() >= 5, "special floors listed")
	for act in CONTENT.dungeon.acts:
		check(act.all_bosses().size() >= 2, "%s has two possible bosses" % act.title)
		for boss in act.all_bosses():
			check(boss.portrait != null and boss.frames != null and boss.frames.has_animation(&"idle"), "%s has a portrait and animations" % boss.id)
			check(not boss.skills.is_empty() and boss.phases.size() >= 1 and not boss.title.is_empty(), "%s has skills, phases and a title" % boss.id)
	for act in CONTENT.dungeon.acts:
		check(not act.lore.is_empty(), "%s has its story line" % act.title)
		check(act.boss and not act.boss.title.is_empty(), "%s's boss has a title" % act.title)
	check(CONTENT.dungeon.room_light != null and CONTENT.dungeon.room_light.light_color.a > 0.0, "rooms get lanterns")


func _test_generation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for i in 100:
		var map := DungeonGenerator.generate(CONTENT.dungeon, rng)
		check(map.rooms.size() >= 4, "enough rooms (%d)" % map.rooms.size())
		var reachable := _flood(map, map.start_cell)
		for room in map.rooms:
			check(reachable.has(room.get_center()), "room %s reachable" % room)
		check(reachable.has(map.stairs_cell), "stairs reachable")
		check(map.start_cell != map.stairs_cell, "stairs not on start")
		# Only wall shapes the cliff tiles can draw: no wall one cell thick, no corner-only contact.
		var bad := _bad_wall_cells(map)
		check(bad.is_empty(), "no thin walls or pinches (%s)" % str(bad.slice(0, 3)))
		# Border must stay solid so nothing can leave the map.
		for x in map.width:
			check(not map.is_floor(Vector2i(x, 0)) and not map.is_floor(Vector2i(x, map.height - 1)), "closed border")
			break


func _bad_wall_cells(map: DungeonMap) -> Array[Vector2i]:
	var bad: Array[Vector2i] = []
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			var c := Vector2i(x, y)
			if map.is_floor(c):
				continue
			if (map.is_floor(c + Vector2i.LEFT) and map.is_floor(c + Vector2i.RIGHT)) \
					or (map.is_floor(c + Vector2i.UP) and map.is_floor(c + Vector2i.DOWN)) \
					or DungeonGenerator._is_pinch(map, c):
				bad.append(c)
	return bad


func _flood(map: DungeonMap, from: Vector2i) -> Dictionary:
	var seen := { from: true }
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if map.is_floor(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen


func _test_inventory_and_equipment() -> void:
	var inventory := Inventory.new(2)
	var potion: ItemDef = load("res://data/items/consumables/health_potion.tres")
	check(inventory.add(potion) and inventory.add(potion), "inventory accepts items")
	check(not inventory.add(potion), "inventory refuses items when full")
	check(inventory.grouped().size() == 1 and inventory.grouped()[0].count == 2, "identical items are grouped")

	var equipment := Equipment.new()
	var cap: EquipmentDef = load("res://data/items/armors/leather_cap.tres")
	var helm: EquipmentDef = load("res://data/items/armors/iron_helm.tres")
	check(equipment.equip(cap) == null, "equip into empty slot")
	check(equipment.equip(helm) == cap, "equip returns the replaced item")
	check(equipment.total_bonuses().defense == helm.bonuses.defense, "bonuses come from equipped items")


func _test_perks() -> void:
	check(CONTENT.perks.size() >= 12, "content db lists perks (%d)" % CONTENT.perks.size())
	var ids := {}
	var rares := 0
	for perk in CONTENT.perks:
		check(perk.icon != null and not perk.display_name.is_empty(), "%s has an icon and a name" % perk.id)
		check(not perk.describe().is_empty(), "%s describes itself" % perk.id)
		check(not ids.has(perk.id), "duplicate perk id %s" % perk.id)
		ids[perk.id] = true
		if perk.rarity == PerkDef.Rarity.RARE:
			rares += 1
	check(rares >= 3, "enough relics for a boss reward (%d)" % rares)

	var owned := PerkSet.new()
	var vitality := _perk("vitality")
	owned.add(vitality)
	owned.add(vitality)
	check(owned.stacks_of(vitality) == 2 and owned.entries.size() == 1, "taking a perk again stacks it")
	check(owned.total_bonuses().max_hp == vitality.bonuses.max_hp * 2, "stacked perks add their stats per level")
	for i in 10:
		owned.add(vitality)
	check(owned.stacks_of(vitality) == vitality.max_stacks, "stacks are capped")
	check(not owned.can_take(vitality), "a maxed perk can't be taken again")

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 30:
		var offer := CONTENT.pick_perks(owned, 3, PerkDef.Rarity.COMMON, rng)
		check(offer.size() == 3, "level up offers 3 perks")
		check(not offer.has(vitality), "maxed perks are not offered")
		check(offer[0] != offer[1] and offer[1] != offer[2] and offer[0] != offer[2], "offered perks are all different")
		check(offer.all(func(p: PerkDef) -> bool: return p.rarity == PerkDef.Rarity.COMMON), "level up offers common perks")
	var relics := CONTENT.pick_perks(owned, 3, PerkDef.Rarity.RARE, rng)
	check(relics.all(func(p: PerkDef) -> bool: return p.rarity == PerkDef.Rarity.RARE), "bosses offer relics")
	var everything := PerkSet.new()
	for perk in CONTENT.perks:
		if perk.rarity == PerkDef.Rarity.RARE:
			for i in perk.max_stacks:
				everything.add(perk)
	var fallback := CONTENT.pick_perks(everything, 3, PerkDef.Rarity.RARE, rng)
	check(fallback.size() == 3, "with every relic maxed, common perks fill the offer")


func _test_bosses() -> void:
	var config := CONTENT.dungeon
	check(config.acts.size() == 3 and config.total_floors() == 9, "3 acts of 3 floors")
	var bosses: Array[BossDef] = []
	for act in config.acts:
		check(act.boss != null and act.theme != null and act.monsters.size() >= 6, "%s has a boss, a look and monsters" % act.title)
		bosses.append(act.boss)
	check(config.boss_for_depth(1) == null and config.boss_for_depth(2) == null and config.boss_for_depth(4) == null, "normal floors have no boss")
	check(config.boss_for_depth(3) == bosses[0] and config.boss_for_depth(6) == bosses[1] and config.boss_for_depth(9) == bosses[2], "each act ends with its boss")
	check(config.act_for_depth(4) == config.acts[1] and config.floor_in_act(4) == 1, "floor 4 starts act 2")
	check(config.is_final_floor(9) and not config.is_final_floor(6), "floor 9 ends the run")
	check(config.act_for_depth(10) == config.acts[0] and config.boss_for_depth(12) == bosses[0], "endless mode loops the acts")
	for boss in bosses:
		check(boss.frames != null and boss.frames.has_animation(&"idle"), "%s has animations" % boss.id)
		check(boss.portrait != null, "%s has a portrait" % boss.id)
		check(boss.weapon != null and boss.loot != null, "%s has a weapon and loot" % boss.id)
		check(not boss.phases.is_empty(), "%s has phases" % boss.id)
		var last := 1.0
		for phase in boss.phases:
			check(phase.hp_ratio < last, "%s phases go down in HP" % boss.id)
			last = phase.hp_ratio
		for skill in boss.skills:
			check(skill.cooldown > 0.0, "%s: %s has a cooldown" % [boss.id, skill.id])

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 40:
		var map := DungeonGenerator.generate_arena(config, rng)
		check(map.boss_room.size == config.arena_size, "arena has the configured size")
		check(not map.boss_room.has_point(map.start_cell), "the player starts outside the arena")
		var reachable := _flood(map, map.start_cell)
		check(reachable.has(map.boss_room.get_center()), "arena reachable from the start")
		# Exits of the arena: floor cells right around it. They must all be closable spikes.
		var ring := map.boss_room.grow(1)
		var exits := 0
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				if not map.boss_room.has_point(Vector2i(x, y)) and map.is_floor(Vector2i(x, y)):
					exits += 1
		check(exits >= 1 and exits <= ring.size.x + ring.size.y, "arena has a closable entrance (%d cells)" % exits)
		check(_bad_wall_cells(map).is_empty(), "arena floors have clean walls")


func _test_profile() -> void:
	check(CONTENT.upgrades.size() >= 8, "the shrine sells upgrades")
	check(Profile.souls_for_run(10, 4, 1, false) == 10 + 15 + 20, "souls: kills + depth + bosses")
	check(Profile.souls_for_run(0, 9, 3, true) > Profile.souls_for_run(0, 9, 3, false), "winning gives a big bonus")
	var vitality := _upgrade("vitality")
	Profile.reset()
	check(not Profile.buy(vitality), "no souls, no upgrade")
	Profile.souls = 1000
	check(Profile.buy(vitality) and Profile.level_of(vitality) == 1, "buying an upgrade")
	check(Profile.souls == 1000 - vitality.cost_for_level(0), "it costs souls")
	check(vitality.cost_for_level(1) > vitality.cost_for_level(0), "each level costs more")
	for i in 10:
		Profile.buy(vitality)
	check(Profile.level_of(vitality) == vitality.max_level and not Profile.can_buy(vitality), "levels are capped")

	# Locked items only appear once unlocked.
	check(not CONTENT.locked_items.is_empty(), "some items must be unlocked first")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	CONTENT.unlocked_items.clear()
	var seen_locked := false
	for i in 400:
		seen_locked = seen_locked or CONTENT.locked_items.has(CONTENT.pick_item(9, rng))
	check(not seen_locked, "locked items never spawn")
	CONTENT.unlocked_items.append_array(CONTENT.locked_items)
	var seen_unlocked := false
	for i in 400:
		seen_unlocked = seen_unlocked or CONTENT.locked_items.has(CONTENT.pick_item(9, rng))
	check(seen_unlocked, "unlocked items do spawn")
	CONTENT.unlocked_items.clear()
	Profile.reset()

	# Difficulties
	check(CONTENT.difficulties.size() == 4 and CONTENT.default_difficulty.id == &"normal", "4 difficulties, Normal by default")
	var hard := CONTENT.get_difficulty(&"hard")
	var nightmare := CONTENT.get_difficulty(&"nightmare")
	check(Profile.is_unlocked(CONTENT.get_difficulty(&"easy")) and Profile.is_unlocked(hard), "Easy to Hard are open")
	check(not Profile.is_unlocked(nightmare), "Nightmare starts locked")
	Profile.record_run(0, 9, true, &"normal")
	check(not Profile.is_unlocked(nightmare), "a Normal win doesn't unlock Nightmare")
	Profile.record_run(0, 9, true, &"hard")
	check(Profile.is_unlocked(nightmare), "a Hard win unlocks Nightmare")
	check(Profile.souls_for_run(10, 5, 1, false, nightmare.souls) > Profile.souls_for_run(10, 5, 1, false), "harder difficulties give more souls")
	var previous := 0.0
	for difficulty in CONTENT.difficulties:
		check(difficulty.monster_hp >= previous, "difficulties get harder in order (%s)" % difficulty.id)
		previous = difficulty.monster_hp
	Profile.reset()

	# Ascension: Nightmare +1, +2... each level stacks its twist.
	check(CONTENT.ascensions.size() >= 10 and nightmare.has_ascensions, "Nightmare has ascension levels")
	var climbed := AscensionDef.apply_levels(nightmare, CONTENT.ascensions, 3)
	check(climbed.display_name == "Nightmare +3" and climbed.id == nightmare.id and climbed.ascension == 3, "Nightmare +3 is still Nightmare")
	check(climbed.monster_hp > nightmare.monster_hp and climbed.elite_chance > nightmare.elite_chance and climbed.souls > nightmare.souls, "each level makes it harder (and pays more souls)")
	check(nightmare.ascension == 0 and nightmare.display_name == "Nightmare", "the Nightmare file is untouched")
	var top := AscensionDef.apply_levels(nightmare, CONTENT.ascensions, 99)
	check(top.ascension == CONTENT.ascensions.size() and top.hero_max_hp < 1.0 and top.shop_prices > 1.0 and top.extra_monsters > nightmare.extra_monsters, "the last level has every twist")
	Profile.select_ascension(4)
	check(Profile.ascension == 0, "no ascension before a Nightmare win")
	Profile.win_ascension(0, CONTENT.ascensions.size())
	check(Profile.ascension_unlocked == 1 and Profile.stat_value("ascension") == 0, "a Nightmare win opens +1")
	Profile.win_ascension(5, CONTENT.ascensions.size())
	Profile.select_ascension(99)
	check(Profile.ascension == 6 and Profile.stat_value("ascension") == 5, "winning +5 opens +6")
	Profile.reset()

	# Records: the bestiary, counters, achievements, the run history; all saved.
	Profile.record_kill(&"slime")
	Profile.record_kill(&"slime")
	Profile.add_stat("kills", 2)
	Profile.raise_stat("run_gold", 50)
	Profile.raise_stat("run_gold", 20)
	check(Profile.kill_count(&"slime") == 2 and Profile.stat_value("species") == 1, "the bestiary counts kills per monster")
	check(Profile.stat_value("kills") == 2 and Profile.stat_value("run_gold") == 50, "counters add up, bests stay the best")
	check(CONTENT.achievements.size() >= 15, "achievements listed")
	var ids := {}
	for achievement in CONTENT.achievements:
		check(achievement.icon != null and achievement.target > 0 and achievement.reward_souls > 0, "%s is set up" % achievement.id)
		check(not ids.has(achievement.id), "%s is unique" % achievement.id)
		ids[achievement.id] = true
	var first: AchievementDef = load("res://data/achievements/first_blood.tres")
	check(first.is_met() and not first.is_unlocked(), "an achievement knows when its goal is reached")
	var souls_before := Profile.souls
	check(Profile.unlock_achievement(first) and Profile.souls == souls_before + first.reward_souls, "unlocking pays souls")
	check(not Profile.unlock_achievement(first) and Profile.souls == souls_before + first.reward_souls, "only once")
	for i in Profile.HISTORY_SIZE + 5:
		Profile.add_history({ "depth": i })
	check(Profile.history.size() == Profile.HISTORY_SIZE and int(Profile.history[0].depth) == Profile.HISTORY_SIZE + 4, "the history keeps the last runs, newest first")
	Profile.save_path = "user://test_profile_%d.json" % OS.get_process_id()
	Profile.save_profile()
	Profile.kills_by_monster = {}
	Profile.achievements = {}
	Profile.load_profile()
	check(Profile.kill_count(&"slime") == 2 and Profile.is_achieved(&"first_blood") and Profile.history.size() == Profile.HISTORY_SIZE, "records survive a save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.save_path))
	Profile.save_path = ""
	Profile.reset()
