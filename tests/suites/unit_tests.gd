class_name UnitTests
extends TestSuite
## Rules and data, no game running: stats, combat, content, generation, items, perks, bosses, profile.

func run() -> void:
	_test_stat_block()
	_test_combat_rules()
	_test_content()
	_test_biome_content()
	_test_quests()
	_test_generation()
	_test_stairs_seal()
	_test_inventory_and_equipment()
	_test_perks()
	_test_synergies()
	_test_bestiary()
	_test_monster_ranks()
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
		# Only solid-looking walls: none thinner than DungeonGenerator.MIN_WALL_THICKNESS between floors, no corner-only contact.
		var bad := _bad_wall_cells(map)
		check(bad.is_empty(), "no thin walls or pinches (%s)" % str(bad.slice(0, 3)))
		# Border must stay solid so nothing can leave the map.
		for x in map.width:
			check(not map.is_floor(Vector2i(x, 0)) and not map.is_floor(Vector2i(x, map.height - 1)), "closed border")
			break


## The stairs' seal: a share of the floor's monsters, the last few shown, broken once.
func _test_stairs_seal() -> void:
	var seal := StairsSeal.new()
	var broken := [0]
	seal.broken.connect(func() -> void: broken[0] += 1)
	seal.reset(10, 0.7, 4)
	check(seal.needed == 7 and seal.is_sealed() and not seal.reveals_monsters(), "a floor of 10 monsters asks for 7 kills")
	for i in 3:
		seal.add_kill()
	check(seal.left() == 4 and seal.reveals_monsters(), "the last few kills show the monsters left")
	for i in 3:
		check(not seal.add_kill(), "still sealed")
	check(seal.add_kill() and not seal.is_sealed() and broken[0] == 1, "the 7th kill breaks the seal")
	check(not seal.add_kill() and broken[0] == 1 and not seal.reveals_monsters(), "it breaks only once")
	seal.reset(0, 0.7, 4)
	check(not seal.is_sealed(), "no monsters: no seal")
	seal.reset(9, 0.7, 4)
	seal.break_now()
	check(not seal.is_sealed() and broken[0] == 2, "debug: break it at once")
	var config := CONTENT.dungeon
	check(config.seal_share >= 0.5 and config.seal_share < 1.0, "the seal wants most monsters, not every last one")


## Biomes: every act has 2 or more, each complete; scenes are sound plans.
func _test_biome_content() -> void:
	var seen := {}
	for act in CONTENT.dungeon.acts:
		check(act.biomes.size() >= 2, "%s has several biomes (%d)" % [act.title, act.biomes.size()])
		for biome in act.biomes:
			check(not seen.has(biome), "%s belongs to one act only" % biome.id)
			seen[biome] = true
			check(biome.theme != null and biome.theme.floor_atlas != null and biome.theme.wall_atlas != null, "%s has its tiles" % biome.id)
			check(not biome.display_name.is_empty() and not biome.description.is_empty(), "%s has a name and a line" % biome.id)
			check(biome.scenes.size() >= 5, "%s has its scenes (%d)" % [biome.id, biome.scenes.size()])
			check(not biome.grounds.is_empty() and not biome.decor.is_empty(), "%s has grounds and decor" % biome.id)
			for layer in biome.grounds:
				check(layer.texture != null and layer.coverage > 0.0, "%s: a ground with a look" % biome.id)
			for scene in biome.scenes:
				_check_scene(biome, scene)
	var rng := RandomNumberGenerator.new()
	var act: ActDef = CONTENT.dungeon.acts[0]
	check(act.pick_biome(3, true, rng) == act.main_biome(), "the boss arena has its biome")
	var picked := {}
	for i in 60:
		picked[act.pick_biome(2, false, rng)] = true
	check(picked.size() == act.biomes.size(), "every biome of an act comes up (%d)" % picked.size())


func _check_scene(biome: BiomeDef, scene: SceneDef) -> void:
	var name := "%s/%s" % [biome.id, scene.id]
	check(not scene.rows.is_empty() and scene.size().x > 0, "%s has a plan" % name)
	for row in scene.rows:
		for symbol in row:
			if symbol != " " and symbol != ".":
				check(scene.key(symbol) != null, "%s: '%s' means something" % [name, symbol])
	for k in scene.keys:
		match k.kind:
			SceneKey.Kind.PROP:
				check(not k.props.is_empty(), "%s: '%s' has props" % [name, k.symbol])
				var foot := k.props[0].footprint if not k.props.is_empty() else Vector2i.ONE
				for prop in k.props:
					check(prop.icon != null and prop.footprint == foot, "%s: %s drawn, same footprint as its kin" % [name, prop.id])
				# A footprint bigger than a cell: the symbol covers it whole, every time (read
				# row by row, as the scene is built).
				var cells := scene.plan(false)
				var ordered := cells.keys().filter(func(offset: Vector2i) -> bool: return cells[offset] == k.symbol)
				ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
				var used := {}
				for offset: Vector2i in ordered:
					if used.has(offset):
						continue
					for y in foot.y:
						for x in foot.x:
							used[offset + Vector2i(x, y)] = true
							check(cells.get(offset + Vector2i(x, y), "") == k.symbol, "%s: '%s' covers its %s footprint" % [name, k.symbol, foot])
			SceneKey.Kind.DECOR:
				check(not k.pieces.is_empty(), "%s: '%s' has pieces" % [name, k.symbol])
			SceneKey.Kind.CARPET:
				check(k.carpet != null, "%s: '%s' has a carpet" % [name, k.symbol])
			SceneKey.Kind.POND:
				check(k.pond != null and k.pond.pond != null and k.pond.heat == 0.0, "%s: '%s' is plain water" % [name, k.symbol])
				# Water fills the rectangle around its cells: the plan shows it whole.
				var cells := scene.plan(false)
				var rect := SceneDef._span_of(cells, k.symbol)
				var whole := true
				for y in range(rect.position.y, rect.end.y):
					for x in range(rect.position.x, rect.end.x):
						whole = whole and cells.get(Vector2i(x, y), "") == k.symbol
				check(whole, "%s: its water is a rectangle in the plan" % name)


## Daily and weekly quests: the same for everyone on a given day, counted, paid once.
func _test_quests() -> void:
	var quests := CONTENT.quests
	check(quests.filter(func(q: QuestDef) -> bool: return q.period == QuestDef.Period.DAILY).size() >= 6, "a pool of daily quests")
	check(quests.filter(func(q: QuestDef) -> bool: return q.period == QuestDef.Period.WEEKLY).size() >= 5, "a pool of weekly quests")
	var monday := 1760918400  # 2025-10-20 00:00 UTC, a Monday
	var daily := QuestBoard.current(quests, QuestDef.Period.DAILY, monday + 3600)
	var again := QuestBoard.current(quests, QuestDef.Period.DAILY, monday + 80000)
	check(daily.size() == QuestBoard.DAILY_COUNT, "%d daily quests" % daily.size())
	check(daily.map(func(q: Dictionary) -> StringName: return q.def.id) == again.map(func(q: Dictionary) -> StringName: return q.def.id) \
		and daily.map(func(q: Dictionary) -> int: return q.target) == again.map(func(q: Dictionary) -> int: return q.target), "the same quests all day long (and for everyone)")
	var ids := {}
	for q in daily:
		ids[q.def.id] = true
	check(ids.size() == daily.size(), "three different quests")
	var days_differ := false
	for d in range(1, 6):
		var other := QuestBoard.current(quests, QuestDef.Period.DAILY, monday + d * QuestBoard.DAY + 10)
		days_differ = days_differ or other.map(func(q: Dictionary) -> StringName: return q.def.id) != daily.map(func(q: Dictionary) -> StringName: return q.def.id)
	check(days_differ, "new quests on other days")
	check(QuestBoard.period_key(QuestDef.Period.WEEKLY, monday + 10) == QuestBoard.period_key(QuestDef.Period.WEEKLY, monday + 6 * QuestBoard.DAY + 80000)
		and QuestBoard.period_key(QuestDef.Period.WEEKLY, monday - 10) != QuestBoard.period_key(QuestDef.Period.WEEKLY, monday + 10), "weeks start on Monday")
	check(QuestBoard.seconds_left(QuestDef.Period.DAILY, monday + 3600) == QuestBoard.DAY - 3600, "time left until the next daily quests")
	for q in daily:
		var def: QuestDef = q.def
		check(q.target >= def.target.x - def.step and q.target <= def.target.y + def.step and q.reward >= def.reward.x and q.reward <= def.reward.y, "%s: goal and reward in range" % def.id)
	# Counting and paying, on today's quests.
	var today := QuestBoard.current(quests, QuestDef.Period.DAILY)
	var quest: Dictionary = today[0]
	var def: QuestDef = quest.def
	var souls := Profile.souls
	if def.best:
		Profile.raise_stat(def.stat, quest.target)
	else:
		Profile.add_stat(def.stat, quest.target)
	check(QuestBoard.is_done(quest), "doing it fills the quest (%s)" % def.id)
	var paid := QuestBoard.claim_finished(quests)
	check(paid.any(func(q: Dictionary) -> bool: return q.def == def) and Profile.souls >= souls + int(quest.reward), "a finished quest pays its souls")
	check(QuestBoard.claim_finished(quests).filter(func(q: Dictionary) -> bool: return q.def == def).is_empty(), "only once")


func _bad_wall_cells(map: DungeonMap) -> Array[Vector2i]:
	var bad: Array[Vector2i] = []
	for y in range(1, map.height - 1):
		for x in range(1, map.width - 1):
			var c := Vector2i(x, y)
			if map.is_floor(c):
				continue
			if DungeonGenerator.is_thin_wall(map, c, Vector2i.RIGHT) or DungeonGenerator.is_thin_wall(map, c, Vector2i.DOWN) \
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


## Monster ranks: rarer is rarer, and only from their depth.
func _test_monster_ranks() -> void:
	var config := CONTENT.dungeon
	check(config.elite_rank != null and config.rare_ranks.size() >= 3, "elite, epic, legendary and shiny ranks")
	for rank in config.rare_ranks:
		check(rank.chance_at(rank.min_depth - 1) == 0.0 and rank.chance_at(40) <= rank.max_chance, "%s: from its depth, capped" % rank.id)
		check(rank.boss_chance > 0.0, "%s: bosses can come at it" % rank.id)
	var ids := config.rare_ranks.map(func(r: MonsterRankDef) -> StringName: return r.id)
	check(ids.find(&"shiny") < ids.find(&"legendary") and ids.find(&"legendary") < ids.find(&"epic"), "rarest first")


## The bestiary: ranks paid once, challenges met by the right kills, mastery.
func _test_bestiary() -> void:
	var rules := CONTENT.bestiary
	check(rules != null and rules.monster_kills.size() == rules.rank_count() and rules.monster_souls.size() == rules.rank_count() and rules.boss_kills.size() == rules.boss_souls.size(), "the bestiary's ranks are complete")
	var slime: MonsterDef = load("res://data/monsters/slime.tres")
	var frog: MonsterDef = load("res://data/monsters/bosses/giant_frog.tres")
	var bat: MonsterDef = load("res://data/monsters/bat.tres")
	Profile.reset()
	check(Bestiary.rank_of(slime, rules) == Bestiary.UNSEEN, "never met: unknown")
	Profile.mark_seen(slime.id)
	check(Bestiary.rank_of(slime, rules) == Bestiary.SEEN, "met: seen")
	for i in rules.monster_kills[1]:
		Profile.record_kill(slime.id)
	var paid := Bestiary.claim(slime, rules)
	check(paid.size() == 2 and Profile.souls == rules.monster_souls[0] + rules.monster_souls[1], "two ranks reached, both paid (%d souls)" % Profile.souls)
	check(Bestiary.claim(slime, rules).is_empty(), "paid once")
	check(Bestiary.damage_multiplier(slime, rules) == 1.0, "not mastered yet")
	for i in rules.monster_kills[2]:
		Profile.record_kill(slime.id)
	Bestiary.claim(slime, rules)
	check(Bestiary.is_mastered(slime, rules) and is_equal_approx(Bestiary.damage_multiplier(slime, rules), 1.0 + rules.mastery_damage), "mastered: more damage to it")
	# Challenges: the common ones that apply, and a boss' own.
	var ids := rules.challenges_for(slime).map(func(c: HuntChallenge) -> StringName: return c.id)
	check(ids.has(&"elite") and ids.has(&"pit") and not ids.has(&"fast"), "a monster gets the monster challenges")
	check(not rules.challenges_for(bat).any(func(c: HuntChallenge) -> bool: return c.goal == HuntChallenge.Goal.PIT), "no hole challenge for flyers")
	var boss_list := rules.challenges_for(frog)
	check(boss_list.any(func(c: HuntChallenge) -> bool: return c.goal == HuntChallenge.Goal.FAST) and boss_list.any(func(c: HuntChallenge) -> bool: return c.goal == HuntChallenge.Goal.WEAPON and c.weapon != null), "a boss gets the boss challenges and its own")
	for monster in CONTENT.all_monsters():
		for challenge in rules.challenges_for(monster):
			check(not challenge.describe(monster).is_empty() and challenge.souls > 0, "%s/%s is described and paid" % [monster.id, challenge.id])
	var kill := { "elite": true, "pushed_in": false, "crit": false, "weapon": null, "weapon_base": null, "untouched": false,
		"kill_times": [1.0, 2.0, 4.0], "now": 4.5, "fight_time": 70.0, "potions_in_fight": 1, "hp_lost_in_fight": 0.1 }
	var by_goal := func(goal: HuntChallenge.Goal, list: Array) -> HuntChallenge:
		for c: HuntChallenge in list:
			if c.goal == goal:
				return c
		return null
	var slime_list := rules.challenges_for(slime)
	check(by_goal.call(HuntChallenge.Goal.ELITE, slime_list).met(kill) and not by_goal.call(HuntChallenge.Goal.PIT, slime_list).met(kill), "an elite kill meets the elite challenge only")
	check(by_goal.call(HuntChallenge.Goal.STREAK, slime_list).met(kill), "three kills within 5 s: a streak")
	kill.kill_times = [0.5, 4.0]
	check(not by_goal.call(HuntChallenge.Goal.STREAK, slime_list).met(kill), "two are not a streak")
	check(by_goal.call(HuntChallenge.Goal.FAST, boss_list).met(kill) and by_goal.call(HuntChallenge.Goal.HEALTHY, boss_list).met(kill) and not by_goal.call(HuntChallenge.Goal.NO_POTION, boss_list).met(kill), "boss fight: fast and healthy, but a potion was drunk")
	var own: HuntChallenge = by_goal.call(HuntChallenge.Goal.WEAPON, boss_list)
	kill.weapon_base = own.weapon
	check(own.met(kill), "its own challenge: with the right weapon")
	check(Profile.complete_challenge(frog.id, own.id, own.souls) and not Profile.complete_challenge(frog.id, own.id, own.souls) and Profile.is_challenge_done(frog.id, own.id), "a challenge is done (and paid) once")
	Profile.reset()


## Perk families: sound data, waking at 3 different perks, saved and loaded.
func _test_synergies() -> void:
	check(CONTENT.synergies.size() >= 5, "at least 5 perk families")
	# Choices that change how you play, not just numbers.
	var doers := CONTENT.perks.filter(func(p: PerkDef) -> bool: return not p.passives.is_empty())
	check(doers.size() * 3 >= CONTENT.perks.size() * 2, "two perks in three do something (%d/%d)" % [doers.size(), CONTENT.perks.size()])
	var active_affixes := CONTENT.item_affixes.filter(func(a: ItemAffixDef) -> bool: return a.on_hit != null or not a.passives.is_empty())
	check(active_affixes.size() * 3 >= CONTENT.item_affixes.size(), "a third of the affixes do something (%d/%d)" % [active_affixes.size(), CONTENT.item_affixes.size()])
	for affix in CONTENT.item_affixes:
		if not affix.passives.is_empty():
			check(not affix.description.is_empty(), "%s says what it does" % affix.id)
	var members := {}
	for perk in CONTENT.perks:
		for synergy in perk.synergies:
			check(CONTENT.synergies.has(synergy), "%s: its family %s is listed" % [perk.id, synergy.id if synergy else &"null"])
			members[synergy] = members.get(synergy, 0) + 1
	for synergy in CONTENT.synergies:
		check(synergy.icon != null and not synergy.description.is_empty() and not synergy.passives.is_empty(), "%s: icon, text and a bonus that does something" % synergy.id)
		check(members.get(synergy, 0) >= synergy.pieces + 1, "%s: enough perks to choose from (%d)" % [synergy.id, members.get(synergy, 0)])
	var inferno: SynergyDef = _perk("ignite").synergies[0]
	var set := PerkSet.new()
	var woke: Array[SynergyDef] = []
	set.synergy_awakened.connect(func(synergy: SynergyDef) -> void: woke.append(synergy))
	set.add(_perk("ignite"))
	set.add(_perk("ignite"))
	set.add(_perk("frenzy"))
	check(set.pieces_of(inferno) == 2 and not set.is_awake(inferno), "two stacks of one perk count once")
	check(set.would_complete(_perk("kindling"), inferno) and not set.would_complete(_perk("ignite"), inferno), "a third different perk would wake the family")
	set.add(_perk("kindling"))
	check(set.is_awake(inferno) and woke == [inferno], "three different perks wake it, once")
	check(set.awakened() == [inferno] and set.families().has(inferno), "awake families are listed")
	var copy := PerkSet.new()
	copy.synergy_awakened.connect(func(synergy: SynergyDef) -> void: woke.append(synergy))
	copy.load_data(set.to_data())
	check(copy.is_awake(inferno) and woke.size() == 1, "a loaded run keeps it awake (without announcing it again)")
	set.clear()
	check(not set.is_awake(inferno), "a new run starts asleep")
	var skills := SkillSet.new()
	var skill := SkillDef.new()
	skill.cooldown = 5.0
	var list: Array[SkillDef] = [skill]
	skills.set_skills(list)
	skills._cooldowns[0] = 4.0
	skills.reset_cooldown(skill)
	check(skills.is_ready(0), "an echo leaves the skill ready again")

	# Offers: banished perks never come back; started families come more often.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var owned := PerkSet.new()
	var banished: Array[PerkDef] = [_perk("strength")]
	var never := true
	for i in 200:
		if CONTENT.pick_perks(owned, 3, PerkDef.Rarity.COMMON, rng, banished).has(_perk("strength")):
			never = false
	check(never, "a banished perk is never offered")
	owned.add(_perk("ignite"))
	owned.add(_perk("frenzy"))
	var inferno_count := [0, 0]
	for bias_index in 2:
		for i in 400:
			var picked: PerkDef = CONTENT.pick_perks(owned, 1, PerkDef.Rarity.COMMON, rng, [], [0.0, 1.0][bias_index])[0]
			if picked.synergies.has(inferno):
				inferno_count[bias_index] += 1
	check(inferno_count[1] > inferno_count[0] * 1.4, "offers lean toward a started family (%d vs %d of 400)" % [inferno_count[1], inferno_count[0]])
	var shop: ShopDef = CONTENT.dungeon.merchant
	check(shop.reroll_price(1, 1) > shop.reroll_price(0, 1) and shop.reroll_price(0, 8) > shop.reroll_price(0, 1), "shop rerolls cost more each time and deeper")
	# The daily run: the same day gives the same start; scores; the streak.
	check(DailyRun.weapon(CONTENT, 20000) == DailyRun.weapon(CONTENT, 20000) and DailyRun.relic(CONTENT, 20000) == DailyRun.relic(CONTENT, 20000), "a day always gives the same weapon and relic")
	var weapons := {}
	for d in 20:
		weapons[DailyRun.weapon(CONTENT, 20000 + d)] = true
	check(weapons.size() >= 3, "days differ (%d weapons in 20 days)" % weapons.size())
	check(DailyRun.floor_seed(20000, 2) != DailyRun.floor_seed(20000, 3) and DailyRun.floor_seed(20000, 2) == DailyRun.floor_seed(20000, 2), "one seed per floor")
	Profile.reset()
	Profile.start_daily(20000)
	Profile.finish_daily(20000, 120)
	Profile.start_daily(20001)
	check(Profile.daily_streak == 2 and Profile.daily_score == 0 and Profile.daily_best == 120, "two days in a row")
	Profile.finish_daily(20001, 80)
	Profile.finish_daily(20000, 999)
	check(Profile.daily_score == 80 and Profile.daily_best == 120, "only today's attempt counts")
	Profile.start_daily(20005)
	check(Profile.daily_streak == 1, "a day missed: the streak starts over")
	Profile.reset()
	var daily := RunState.create(CONTENT, {}, rng, 20000)
	check(daily.is_daily() and daily.difficulty == CONTENT.default_difficulty, "a daily run is on Normal")
	daily.daily_official = true
	var daily_again := RunState.create(CONTENT, daily.to_data(), rng)
	check(daily_again.daily_day == 20000 and daily_again.daily_official, "a saved daily run stays one")

	var run := RunState.create(CONTENT, {}, rng)
	check(run.rerolls >= CONTENT.dungeon.base_rerolls and run.banishes >= CONTENT.dungeon.base_banishes, "a new run starts with its rerolls and banishes")
	run.rerolls = 2
	run.banished.append(_perk("strength"))
	var again := RunState.create(CONTENT, run.to_data(), rng)
	check(again.rerolls == 2 and again.banished == banished, "a saved run keeps its rerolls and banished perks")


func _test_bosses() -> void:
	var config := CONTENT.dungeon
	check(config.acts.size() == 4 and config.total_floors() == 12, "4 acts of 3 floors")
	var bosses: Array[BossDef] = []
	for act in config.acts:
		check(act.boss != null and act.main_biome() != null and act.monsters.size() >= 6, "%s has a boss, a look and monsters" % act.title)
		bosses.append(act.boss)
	check(config.boss_for_depth(1) == null and config.boss_for_depth(2) == null and config.boss_for_depth(4) == null, "normal floors have no boss")
	check(config.boss_for_depth(3) == bosses[0] and config.boss_for_depth(6) == bosses[1] and config.boss_for_depth(9) == bosses[2] and config.boss_for_depth(12) == bosses[3], "each act ends with its boss")
	check(config.act_for_depth(4) == config.acts[1] and config.floor_in_act(4) == 1, "floor 4 starts act 2")
	check(config.act_for_depth(10) == config.acts[3] and config.first_depth(3) == 10, "floor 10 starts act 4")
	check(config.is_final_floor(12) and not config.is_final_floor(9), "floor 12 ends the run")
	check(config.act_for_depth(13) == config.acts[0] and config.boss_for_depth(15) == bosses[0], "endless mode loops the acts")
	for boss in bosses:
		check(boss.frames != null and boss.frames.has_animation(&"idle"), "%s has animations" % boss.id)
		check(boss.portrait != null, "%s has a portrait" % boss.id)
		check(boss.weapon != null and boss.loot != null, "%s has a weapon and loot" % boss.id)
		check(boss.phases.size() == 2 and is_equal_approx(boss.phases[0].hp_ratio, 0.66) and is_equal_approx(boss.phases[1].hp_ratio, 0.33), "%s: three phases (full, two thirds, one third)" % boss.id)
		check(boss.shockwave_after_hits > 0, "%s answers a hail of hits" % boss.id)
		if boss.phases.size() == 2:
			var fierce := boss.phases[1].skills.filter(func(s: SkillDef) -> bool: return String(s.id).ends_with("_fierce"))
			check(not fierce.is_empty() and boss.phases[1].skills != boss.phases[0].skills, "%s: new patterns in its last phase" % boss.id)
			check(boss.phases[1].windup_multiplier < boss.phases[0].windup_multiplier and boss.phases[1].cooldown_multiplier < 1.0, "%s: each phase faster" % boss.id)
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
