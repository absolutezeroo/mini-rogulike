extends Node
## Headless test suite. Run from a terminal at the project root:
##   godot --headless --fixed-fps 60 res://tests/run_tests.tscn
## Unit checks first, then a bot plays the real game for a while.
## Exit code is the number of failed checks (0 = all good).

var CONTENT: ContentDB  # loaded at runtime: preloading here would load the whole game at parse time
var GAME_SCENE: PackedScene

var _failures := 0
var _checks := 0


func _ready() -> void:
	# Without a sound card, playbacks are never released; keep the output clean.
	Sfx.enabled = false
	# Never touch the player's real save.
	Profile.save_path = ""
	Profile.reset()
	CONTENT = load("res://data/content_db.tres")
	GAME_SCENE = load("res://src/game/game.tscn")
	_test_stat_block()
	_test_combat_rules()
	_test_content()
	_test_generation()
	_test_inventory_and_equipment()
	_test_perks()
	_test_bosses()
	_test_profile()
	await _test_title_screen()
	await _test_gameplay()
	print("\n%d checks, %d failed" % [_checks, _failures])
	Sfx.stop_all()
	HitStop.reset()
	await _frames(2)
	get_tree().quit(_failures)


func check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: " + message)


# --- Unit tests --------------------------------------------------------------

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


func _test_content() -> void:
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
	check(CONTENT.props.size() >= 3 and CONTENT.traps.size() >= 2, "props and traps listed")
	for prop in CONTENT.props:
		check(prop.icon != null and prop.is_breakable(), "%s is a breakable prop with a sprite" % prop.id)
	check(CONTENT.props.any(func(p: PropDef) -> bool: return p.is_explosive()), "there is an explosive prop")
	for trap in CONTENT.traps:
		check(trap.active_sheet != null and trap.damage > 0, "%s has art and damage" % trap.id)
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


func _perk(id: String) -> PerkDef:
	for perk in CONTENT.perks:
		if perk.id == StringName(id):
			return perk
	push_error("no perk " + id)
	return null


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


func _upgrade(id: String) -> UpgradeDef:
	for upgrade in CONTENT.upgrades:
		if upgrade.id == StringName(id):
			return upgrade
	push_error("no upgrade " + id)
	return null


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


func _test_title_screen() -> void:
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	check(title.get_node("%PlayButton").visible, "the title screen has a Play button")
	(title.get_node("%PlayButton") as Button).pressed.emit()
	await _frames(2)
	var cards: HBoxContainer = title.get_node("%DifficultyCards")
	check(title.get_node("%DifficultyPanel").visible and cards.get_child_count() == 4, "Play asks for a difficulty")
	check((cards.get_child(3) as Button).disabled and not (cards.get_child(2) as Button).disabled, "Nightmare locked, Hard open")
	(title.get_node("%BackButton") as Button).pressed.emit()
	await _frames(1)
	check(not title.get_node("%DifficultyPanel").visible, "back to the title")
	Profile.souls = 500
	(title.get_node("%ShrineButton") as Button).pressed.emit()
	await _frames(2)
	var shrine: ShrinePanel = title.get_node("%ShrinePanel")
	var rows: VBoxContainer = title.get_node("%Rows")
	check(shrine.visible and rows.get_child_count() == CONTENT.upgrades.size(), "the shrine lists every upgrade")
	var first: UpgradeRow = rows.get_child(0)
	(first.get_node("%BuyButton") as Button).pressed.emit()
	await _frames(1)
	check(Profile.level_of(first.upgrade) == 1 and Profile.souls < 500, "buying at the shrine")
	check((title.get_node("%Souls") as Label).text.contains(str(Profile.souls)), "the shrine shows the souls left")
	title.queue_free()
	Profile.reset()
	await _frames(2)


# --- Gameplay (bot) ----------------------------------------------------------

func _test_gameplay() -> void:
	var game := GAME_SCENE.instantiate()
	add_child(game)
	await _frames(5)
	var world: World = game.world
	var player: Player = game.player
	check(player != null and player.world == world, "player spawned in world")
	check(world.monster_count() > 0, "monsters spawned (%d)" % world.monster_count())
	check(player.get_weapon() != null, "player starts with a weapon")

	await _test_projectiles(world, player)
	await _test_perks_in_game(game, world, player)
	await _test_world_objects(game, world, player)
	await _test_skills(game, world, player)
	await _test_bestiary(world, player)
	await _test_difficulty_in_game(game, world, player)

	var kills := [0]
	var depth_changes := [0]
	Events.monster_killed.connect(func(_m: Monster) -> void: kills[0] += 1)
	Events.depth_changed.connect(func(_d: int) -> void: depth_changes[0] += 1)

	# Every consumable must work without errors.
	player.hp = 10
	for item in CONTENT.items:
		if item is ConsumableDef:
			player.inventory.add(item)
			player.use_item(item)
	check(player.hp > 10, "potions heal")
	await _frames(30)

	# Equip / unequip / drop round trip.
	var bow: WeaponDef = load("res://data/items/weapons/magic_wand.tres")
	check(player.pick_up(bow), "pick up a bow")
	player.use_item(bow)
	check(player.get_weapon() == bow, "bow equipped")
	check(player.inventory.items.size() > 0, "old weapon went to the bag")
	player.unequip(EquipmentDef.Slot.WEAPON)
	check(player.get_weapon() == null, "weapon unequipped")
	player.use_item(load("res://data/items/weapons/katana.tres"))
	check(player.get_weapon() != null, "re-equipped a weapon")
	var count := player.inventory.items.size()
	player.drop_item(bow)
	check(player.inventory.items.size() == count - 1, "dropped item left the bag")
	await _frames(5)

	# Animations: frame-by-frame attack in the aimed direction, weapon in hand synced with the body.
	var rig := player.rig
	check(rig != null and rig.visible, "player has a visible rig")
	player._attack_cooldown = 0.0
	player.attack(Vector2.LEFT)
	check(rig.direction == &"left", "the rig turns toward the attack")
	check(rig.body.animation == &"attack_left", "the body plays attack_left (got %s)" % rig.body.animation)
	check(rig.weapon.visible and rig.weapon.animation == &"attack_left", "the katana is drawn in hand, synced")
	await _frames(40)
	check(not rig.weapon.visible, "the weapon is put away after the attack")
	check(String(rig.body.animation).begins_with("idle") or String(rig.body.animation).begins_with("walk"), "back to idle/walk")
	player._attack_cooldown = 0.0
	player.attack(Vector2.UP)
	check(rig.weapon.get_index() < rig.body.get_index(), "facing up: weapon drawn behind the body")
	await _frames(40)
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position + Vector2(200, 0))
	await _frames(1)
	check(rat.rig.body.animation.begins_with("idle") or rat.rig.body.animation.begins_with("walk"), "monsters animate")
	rat.attack(Vector2.LEFT)
	check(not rat.rig.weapon.visible, "a bite shows no weapon sprite")
	rat.queue_free()
	var spear: WeaponDef = load("res://data/items/weapons/lance.tres")
	player.inventory.add(spear)
	player.use_item(spear)
	player._attack_cooldown = 0.0
	player.attack(Vector2.RIGHT)
	check(rig.weapon.visible and rig.weapon.animation == &"attack_right", "the lance has baked attack frames")
	player.use_item(load("res://data/items/weapons/katana.tres"))
	await _frames(30)

	# Armor is drawn on the hero (paper doll), frame by frame with the body.
	for armor_id in ["leather_cap", "iron_helm", "leather_armor", "chain_mail", "plate_armor", "shadow_cloak"]:
		var armor: ArmorDef = load("res://data/items/armors/%s.tres" % armor_id)
		check(armor.wear_frames != null, "%s has a worn look" % armor_id)
		for animation in rig.body.sprite_frames.get_animation_names():
			check(armor.wear_frames.has_animation(animation), "%s covers %s" % [armor_id, animation])
	var helm: ArmorDef = load("res://data/items/armors/iron_helm.tres")
	var mail: ArmorDef = load("res://data/items/armors/chain_mail.tres")
	player.equipment.equip(helm)
	player.equipment.equip(mail)
	check(rig.helmet.visible and rig.body_armor.visible, "worn armor is visible")
	check(rig.helmet.self_modulate == helm.wear_color, "the helmet takes the armor's color")
	_set_move(Vector2.LEFT)
	await _frames(13)
	check(rig.body_armor.animation == rig.body.animation and rig.body_armor.frame == rig.body.frame, "body armor follows the walk frame by frame")
	check(rig.helmet.animation == rig.body.animation and rig.helmet.frame == rig.body.frame, "helmet follows the walk frame by frame")
	_set_move(Vector2.ZERO)
	player._attack_cooldown = 0.0
	player.attack(Vector2.UP)
	await _frames(3)
	check(rig.helmet.animation == &"attack_up" and rig.helmet.frame == rig.body.frame, "armor follows the attack")
	check(rig.weapon.get_index() < rig.body_armor.get_index(), "facing up: weapon behind the armor too")
	await _frames(40)
	player.equipment.unequip(EquipmentDef.Slot.HEAD)
	player.equipment.unequip(EquipmentDef.Slot.BODY)
	check(not rig.helmet.visible and not rig.body_armor.visible, "removed armor disappears")

	# Inventory screen opens, lists items, uses them, pauses, and closes.
	player.inventory.add(load("res://data/items/armors/leather_cap.tres"))
	game.open_inventory()
	await _frames(2)
	check(get_tree().paused, "inventory pauses the game")
	var grid: GridContainer = game.inventory_panel.get_node("%ItemGrid")
	check(grid.get_child_count() > 0, "inventory lists items")
	(grid.get_child(grid.get_child_count() - 1) as Button).pressed.emit()
	(game.inventory_panel.get_node("%UseButton") as Button).pressed.emit()
	check(player.equipment.get_item(EquipmentDef.Slot.HEAD) != null, "equip from the inventory screen")
	game.inventory_panel.close()
	await _frames(2)
	check(not get_tree().paused, "closing the inventory resumes the game")

	# Touch controls feed the same input actions as keyboard and gamepad.
	var screen := get_viewport().get_visible_rect().size
	_touch(0, Vector2(200, screen.y - 200), true)
	_drag(0, Vector2(290, screen.y - 200))
	await _frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").x > 0.5, "joystick drag moves right")
	var attack_button: ActionButton = game.hud.get_node("%AttackButton")
	_touch(1, attack_button.global_position, true)
	await _frames(2)
	check(Input.is_action_pressed("attack"), "attack button presses attack (while moving: multi-touch)")
	_touch(1, attack_button.global_position, false)
	_touch(0, Vector2(290, screen.y - 200), false)
	await _frames(2)
	check(not Input.is_action_pressed("attack"), "attack released")
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "joystick released")
	var bag: Button = game.hud.get_node("%BagButton")
	_touch(0, bag.get_global_rect().get_center(), true)
	await _frames(1)
	_touch(0, bag.get_global_rect().get_center(), false)
	await _frames(2)
	check(game.inventory_panel.visible, "tapping the bag button opens the inventory")
	game.inventory_panel.close()
	await _frames(2)

	# Play: hunt monsters for a while (god mode so the run lasts).
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _bot_play(game, 60 * 40)
	print("bot: %d kills, level %d, depth %d" % [kills[0], player.level, game.depth])
	check(kills[0] >= 5, "bot killed monsters (%d)" % kills[0])
	check(player.level > 1, "player gained levels")

	# Stairs take you deeper.
	var depth_before: int = game.depth
	player.global_position = world.map.cell_to_world(world.map.stairs_cell)
	await _frames(10)
	check(game.depth == depth_before + 1, "stairs lead to the next depth")
	check(depth_changes[0] >= 1, "depth_changed emitted")
	check(world.monster_count() > 0, "new floor populated")

	await _test_boss_fight(game)

	# Death and restart (without perks: a Phoenix Feather from the boss would save the hero).
	var souls_before_death := Profile.souls
	player.perks.clear()
	player.base_stats.defense = 0
	player.invalidate_stats()
	var hit := HitInfo.new()
	hit.amount = 99999
	player._invulnerable_time = 0.0
	player.take_hit(hit)
	check(player.is_dead, "player can die")
	await get_tree().create_timer(1.5).timeout
	check(game.game_over_panel.visible, "game over screen shown")
	check(Profile.souls >= souls_before_death and (game.game_over_panel.get_node("%Summary") as Label).text.contains("souls"), "the end of a run shows its souls")
	# Shrine upgrades apply to the next run.
	Profile.levels = { "vitality": 2, "provisions": 1, "second_chance": 1, "paladin_oath": 1 }
	Profile.difficulty = &"easy"
	game.start_run()
	await _frames(5)
	check(game.difficulty.id == &"easy" and game.world.difficulty == game.difficulty, "the run uses the chosen difficulty")
	check((game.hud.get_node("%InfoLabel") as Label).text.contains("Easy"), "the HUD shows the difficulty")
	Profile.difficulty = &"nightmare"
	game.start_run()
	await _frames(3)
	check(game.difficulty == CONTENT.default_difficulty, "a locked difficulty falls back to Normal")
	Profile.difficulty = &"normal"
	game.start_run()
	await _frames(3)
	check(game.player != player and not game.player.is_dead, "restart creates a fresh player")
	check(game.player.get_max_hp() == CONTENT.player.base_stats.max_hp + 2 * _upgrade("vitality").bonuses.max_hp, "Vitality raises max HP")
	check(game.player.inventory.count_of(load("res://data/items/consumables/health_potion.tres")) == CONTENT.player.starting_items.size() + 1, "Provisions add a potion")
	check(game.player.perks.stacks_of(load("res://data/perks/relics/phoenix_feather.tres")) == 1, "Second Chance gives a Phoenix Feather")
	check(CONTENT.unlocked_items.has(load("res://data/items/weapons/templar_sword.tres")), "Paladin's Oath unlocks the Templar Sword")
	Profile.reset()
	check(game.depth == 1, "restart goes back to depth 1")

	# A second bot run on the fresh character at higher depths, mortal this time.
	# Monsters must be able to hurt a player who just stands there.
	var victim: Player = game.player
	var hp_before := victim.hp
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	game.world.spawn_monster(skeleton, victim.global_position + Vector2(40, 0))
	await _frames(60 * 4)
	check(victim.hp < hp_before, "monsters damage the player")

	game.depth = 4
	game._enter_floor()
	await _bot_play(game, 60 * 20)
	print("bot (depth 4, mortal): hp %d/%d, dead=%s" % [game.player.hp, game.player.get_max_hp(), game.player.is_dead])
	game.queue_free()
	await _frames(2)


## Each kind of perk does its job in the real game, then the level-up screen works.
func _test_perks_in_game(game: Node, world: World, player: Player) -> void:
	var weapon := player.get_weapon()
	player.perks.add(_perk("frenzy"))
	check(player.get_attack_cooldown(weapon) < weapon.cooldown, "Frenzy makes attacks faster")
	check(player.get_stats().attack_speed > 0.0, "perk stats count in the player's stats")

	var free_spot := world.find_open_point_near(player.global_position, 90.0)
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), free_spot)
	await _frames(1)
	player.perks.add(_perk("vampirism"))
	player.hp = 10
	var kill := Combat.make_secondary_hit(player, 9999)
	kill.is_secondary = false
	rat.take_hit(kill)
	check(rat.is_dead and player.hp > 10, "Vampirism heals on kill")

	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), free_spot)
	await _frames(1)
	player.perks.add(_perk("ignite"))
	var poke := HitInfo.new()
	poke.amount = 1
	poke.source = player
	slime.take_hit(poke)
	check(slime.statuses.has(&"burn"), "Ignite sets enemies on fire")
	var hp_burning := slime.hp
	await _frames(70)
	check(slime.hp < hp_burning, "burning enemies lose HP over time")

	player.perks.add(_perk("executioner"))
	slime.hp = 1
	slime.base_stats.max_hp = 100
	slime.invalidate_stats()
	slime.hp = 20
	var finisher := HitInfo.new()
	finisher.amount = 10
	finisher.source = player
	var before := slime.hp
	slime.take_hit(finisher)
	check(before - slime.hp > 10 - slime.get_stats().defense, "Executioner hits wounded enemies harder")
	slime.die(null)

	player.perks.add(_perk("thorns"))
	var skeleton := world.spawn_monster(load("res://data/monsters/skeleton.tres"), free_spot)
	await _frames(1)
	var skeleton_hp := skeleton.hp
	var stab := HitInfo.new()
	stab.amount = 1
	stab.source = skeleton
	player._invulnerable_time = 0.0
	player.take_hit(stab)
	check(skeleton.hp < skeleton_hp, "Thorns hurt melee attackers")
	skeleton.die(null)

	player.perks.add(_perk("multishot"))
	var volley := ProjectileSpec.new()
	volley.max_distance = 10.0
	world.fire_projectiles(player, Vector2.RIGHT, volley)
	check(volley.count == 2 and volley.spread_degrees > 0.0, "Multishot adds a projectile")

	var phoenix := _perk("phoenix_feather")
	player.perks.add(phoenix)
	player._invulnerable_time = 0.0
	var lethal := HitInfo.new()
	lethal.amount = 99999
	player.take_hit(lethal)
	check(not player.is_dead and player.hp >= player.get_max_hp() / 3, "Phoenix Feather survives a killing blow")
	check(player.perks.get_entry(phoenix).memory.get(&"used", 0) == 1, "the feather is used up")
	player.perks.clear()
	player.hp = player.get_max_hp()
	await _frames(10)

	# Level up: the game pauses and offers 3 perks; two level ups = two choices in a row.
	player.gain_xp(player.xp_to_next_level())
	await _frames(2)
	check(game.perk_panel.visible and get_tree().paused, "level up pauses and shows the perk choice")
	var cards: HBoxContainer = game.perk_panel.get_node("%Cards")
	check(cards.get_child_count() == 3, "three cards")
	check((cards.get_child(0) as Button).disabled, "cards ignore taps for a moment (no accidental pick)")
	await get_tree().create_timer(0.6, true).timeout
	check(not (cards.get_child(0) as Button).disabled, "cards become pickable")
	var offered: PerkDef = game.perk_panel.get_offered()[1]
	(cards.get_child(1) as Button).pressed.emit()
	await _frames(2)
	check(player.perks.stacks_of(offered) == 1, "tapping a card gives its perk")
	check(not game.perk_panel.visible and not get_tree().paused, "the game resumes after choosing")
	check(game.hud.get_node("%PerkTray").get_child_count() == 1, "the HUD shows collected perks")

	player.gain_xp(player.xp_to_next_level() + player.def.xp_to_next_level(player.level + 1))
	await _frames(2)
	check(game.perk_panel.visible, "first of two choices")
	game.perk_panel.choose(0)
	await _frames(2)
	check(game.perk_panel.visible, "second choice follows right away")
	game.perk_panel.choose(0)
	await _frames(2)
	var total_levels := 0
	for entry in player.perks.entries:
		total_levels += entry.stacks
	check(not get_tree().paused and total_levels == 3, "both perks taken (%d perk levels), game resumed" % total_levels)


## Difficulty multipliers reach monsters; the run uses the difficulty picked on the title screen.
func _test_difficulty_in_game(game: Node, world: World, player: Player) -> void:
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	var spot := world.find_open_point_near(player.global_position, 150.0)
	check(world.difficulty == CONTENT.default_difficulty, "a run without choice is Normal")
	var normal_one := world.spawn_monster(skeleton, spot)
	world.difficulty = CONTENT.get_difficulty(&"nightmare")
	var nightmare_one := world.spawn_monster(skeleton, spot)
	world.difficulty = CONTENT.get_difficulty(&"easy")
	var easy_one := world.spawn_monster(skeleton, spot)
	world.difficulty = CONTENT.default_difficulty
	await _frames(1)
	check(nightmare_one.get_max_hp() > normal_one.get_max_hp() and easy_one.get_max_hp() < normal_one.get_max_hp(), "monster HP follows the difficulty")
	check(nightmare_one.get_power() > normal_one.get_power() and easy_one.get_power() < normal_one.get_power(), "monster damage follows the difficulty")
	check(nightmare_one.get_attack_windup() < normal_one.get_attack_windup() and easy_one.get_attack_windup() > normal_one.get_attack_windup(), "less time to dodge on harder difficulties")
	for monster in [normal_one, nightmare_one, easy_one]:
		monster.queue_free()
	await _frames(2)


## New monster abilities: poison, death bursts, splitting, charges.
func _test_bestiary(world: World, player: Player) -> void:
	player.base_stats.defense = 0
	player.invalidate_stats()
	# Poison bite.
	var snake := world.spawn_monster(load("res://data/monsters/snake.tres"), world.find_open_point_near(player.global_position, 30.0))
	await _frames(1)
	player._invulnerable_time = 0.0
	snake._attack_cooldown = 0.0
	snake.attack(snake.global_position.direction_to(player.global_position))
	check(player.statuses.has(&"poison"), "a viper bite poisons")
	var hp_poisoned := player.hp
	await _frames(70)
	check(player.hp < hp_poisoned, "poison hurts over time")
	player.statuses.clear()
	snake.die(null)

	# A giant slime splits in two.
	var big: MonsterDef = load("res://data/monsters/big_slime.tres")
	var already_there := world.get_hostiles(player.faction)
	var giant := world.spawn_monster(big, world.find_open_point_near(player.global_position, 120.0))
	await _frames(1)
	giant.die(null)
	await _frames(3)
	var newcomers := world.get_hostiles(player.faction).filter(func(m: Actor) -> bool: return not already_there.has(m))
	check(newcomers.size() == big.death_spawn_count, "a giant slime splits when it dies")
	for monster in newcomers:
		monster.queue_free()
	await _frames(2)

	# A flame spirit explodes a moment after dying.
	player.hp = player.get_max_hp()
	var flam := world.spawn_monster(load("res://data/monsters/flam.tres"), world.find_open_point_near(player.global_position, 30.0))
	await _frames(1)
	var hp_before := player.hp
	player._invulnerable_time = 0.0
	flam.die(null)
	check(player.hp == hp_before, "the burst waits (time to step away)")
	await _frames(int(Monster.DEATH_BURST_FUSE * 60.0) + 4)
	check(player.hp < hp_before, "a dying flame spirit explodes")
	player.statuses.clear()

	# Charges are telegraphed casts that cross the room.
	var beast: MonsterDef = load("res://data/monsters/beast.tres")
	check(beast.skills.any(func(skill: SkillDef) -> bool: return skill.cast_time > 0.0 and skill.effects[0] is DashStrikeEffect), "the beast charges (telegraphed)")
	player.hp = player.get_max_hp()
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _frames(5)


## Skills come from the weapon and from tomes; statuses, delays, dash strikes, skill stats.
func _test_skills(game: Node, world: World, player: Player) -> void:
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var book: WeaponDef = load("res://data/items/weapons/book.tres")
	player.equipment.equip(katana)
	await _frames(1)
	var slots := player.skills.skills
	check(slots.size() == Player.SKILL_COUNT, "4 skill slots")
	check(slots[0] == player.def.innate_skills[0], "slot 1: the roll, always")
	check(slots[1] == katana.skills[0] and slots[2] == katana.skills[1], "slots 2-3: the weapon's skills")
	check(slots[3] == null and not game.hud.get_node("%Skill4Button").visible, "no spell learned yet: last button hidden")
	player.equipment.equip(book)
	await _frames(1)
	check(player.skills.skills[1] == book.skills[0] and player.skills.skills[2] == book.skills[1], "a tome-wielder gets fire skills")
	check(not player.skills.is_ready(1) and player.skills.is_ready(0), "swapping weapons: new skills on a short cooldown, the roll is kept")
	check((game.hud.get_node("%Skill2Button") as ActionButton).icon == book.skills[0].icon, "the HUD shows the new skills")

	var tome: SkillTomeDef = load("res://data/items/tomes/tome_frost.tres")
	player.inventory.add(tome)
	player.use_item(tome)
	await _frames(1)
	check(player.learned_skill == tome.skill and player.skills.skills[3] == tome.skill, "a tome teaches a spell (last slot)")
	check(game.hud.get_node("%Skill4Button").visible, "the spell button appears")
	player.equipment.equip(katana)
	await _frames(1)
	check(player.skills.skills[3] == tome.skill, "the spell stays when changing weapons")

	# Frost Nova slows; Ice Shards would too.
	var spot := world.find_open_point_near(player.global_position, 60.0)
	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), spot)
	slime.dormant = true
	await _frames(70)
	var speed_before := slime.get_move_speed()
	check(player.skills.try_use(3, player, player.global_position.direction_to(slime.global_position)), "cast the learned spell")
	check(slime.statuses.is_slowed() and slime.get_move_speed() < speed_before, "Frost Nova slows enemies")
	slime.die(null)

	# Flurry: three stabs over time (effect delays).
	var sai: WeaponDef = load("res://data/items/weapons/sai.tres")
	player.equipment.equip(sai)
	await _frames(100)
	var dummy := world.spawn_monster(load("res://data/monsters/cyclops.tres"), player.global_position + Vector2(40, 0))
	dummy.dormant = true
	await _frames(1)
	var hp_start := dummy.hp
	player.skills.try_use(1, player, Vector2.RIGHT)
	await _frames(2)
	var hp_first := dummy.hp
	await _frames(20)
	check(hp_first < hp_start and dummy.hp < hp_first, "Flurry keeps stabbing after the first hit")
	dummy.die(null)

	# Dash strike: moves the hero and cuts what is on the way.
	player.equipment.equip(katana)
	await _frames(100)
	var free := world.find_open_point_near(player.global_position, 1.0)
	player.global_position = free
	var dir := Vector2.RIGHT
	for candidate: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if world.has_line_of_sight(free, free + candidate * 200.0):
			dir = candidate
			break
	var target := world.spawn_monster(load("res://data/monsters/cyclops.tres"), free + dir * 90.0)
	target.dormant = true
	await _frames(1)
	var target_hp := target.hp
	var before := player.global_position
	player.skills.try_use(2, player, dir)
	await _frames(15)
	check(target.hp < target_hp, "Iaido Dash cuts enemies on the way")
	check(player.global_position.distance_to(before) > 60.0, "Iaido Dash moves the hero")
	target.die(null)

	# Skill stats from perks.
	var power_before := player.get_skill_power()
	player.perks.add(_perk("arcane_power"))
	check(player.get_skill_power() > power_before, "Arcane Power raises skill damage")
	player.perks.add(_perk("arcane_focus"))
	await _frames(400)
	player.skills.try_use(1, player, Vector2.RIGHT)
	check(player.skills._durations[1] < katana.skills[0].cooldown, "Arcane Focus shortens cooldowns")
	player.perks.clear()
	player.learned_skill = null
	player.equipment.equip(katana)
	await _frames(20)


## Lights, props, explosive barrels, traps and the death dissolve.
func _test_world_objects(game: Node, world: World, player: Player) -> void:
	check((player.get_node("Torch") as PointLight2D).enabled, "the hero carries a torch")
	check((world.get_node("Ambient") as CanvasModulate).color == world.theme.ambient, "the floor is as dark as its theme")
	check(get_tree().get_nodes_in_group("props").size() > 0, "the floor has props")
	var lanterns := get_tree().get_nodes_in_group("props").filter(func(p: Node) -> bool: return (p as Prop).def == CONTENT.dungeon.room_light)
	check(lanterns.size() >= world.map.rooms.size(), "every room has lanterns (%d)" % lanterns.size())

	# A crate in front of the hero breaks under the katana.
	var crate_def: PropDef = load("res://data/props/crate.tres")
	var spot := world.map.world_to_cell(world.find_open_point_near(player.global_position, 40.0))
	var crate := world.spawn_prop(crate_def, spot)
	await _frames(1)
	for i in crate_def.hits:
		player._attack_cooldown = 0.0
		player.attack(player.global_position.direction_to(crate.global_position))
		await _frames(2)
	check(not is_instance_valid(crate) or crate.is_broken, "a crate breaks after %d hits" % crate_def.hits)
	await _frames(5)

	# Powder kegs: one explodes, sets off its neighbour, hurts a monster nearby, credits the hero.
	var keg_def: PropDef = load("res://data/props/tnt.tres")
	var base := world.map.world_to_cell(world.find_open_point_near(player.global_position, 150.0))
	var keg := world.spawn_prop(keg_def, base)
	var keg2 := world.spawn_prop(keg_def, base + Vector2i(1, 0))
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), world.map.cell_to_world(base) + Vector2(0, 30))
	rat.dormant = true
	await _frames(1)
	var rat_hp := rat.hp
	var spark := HitInfo.new()
	spark.source = player
	keg.take_hit(spark)
	check(not keg.is_broken, "a keg has a fuse")
	await _frames(int(keg_def.fuse_time * 60.0) + 4)
	check(not is_instance_valid(keg) or keg.is_broken, "the keg explodes after its fuse")
	check(not is_instance_valid(rat) or rat.is_dead or rat.hp < rat_hp, "the blast hurts monsters")
	await _frames(int(keg_def.fuse_time * 60.0) + 4)
	check(not is_instance_valid(keg2) or keg2.is_broken, "explosions set off other kegs")
	await _frames(30)
	check(not is_instance_valid(rat), "dead monsters dissolve and disappear")

	# A spike trap hurts whoever stands on it, monsters included.
	var spikes: TrapDef = load("res://data/traps/spikes.tres")
	var trap_cell := world.map.world_to_cell(world.find_open_point_near(player.global_position, 120.0))
	var trap := world.spawn_trap(spikes, trap_cell)
	var victim := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(trap_cell))
	victim.dormant = true
	await _frames(1)
	var victim_hp := victim.hp
	var cycle := spikes.idle_time + spikes.warning_time + 0.2
	var saw_warning := false
	for i in int(cycle * 60.0):
		saw_warning = saw_warning or trap.phase == Trap.Phase.WARNING
		await get_tree().physics_frame
	check(saw_warning, "spikes warn before they strike")
	check(victim.hp < victim_hp, "spikes hurt monsters standing on them")
	trap.queue_free()
	if is_instance_valid(victim):
		victim.queue_free()

	# A pressure plate waits for someone to step on it.
	var plate: TrapDef = load("res://data/traps/spike_plate.tres")
	var plate_cell := world.map.world_to_cell(world.find_open_point_near(player.global_position, 120.0))
	var plate_trap := world.spawn_trap(plate, plate_cell)
	await _frames(60)
	check(plate_trap.phase == Trap.Phase.IDLE, "a plate stays still while nobody is on it")
	var hp_before := player.hp
	player.base_stats.defense = 0
	player.invalidate_stats()
	player._invulnerable_time = 0.0
	player.global_position = plate_trap.global_position
	await _frames(int((plate.warning_time + 0.1) * 60.0) + 2)
	check(player.hp < hp_before, "stepping on a plate fires its spikes")
	player.hp = player.get_max_hp()
	plate_trap.queue_free()
	await _frames(5)


## A boss floor from start to finish: arena, spikes, phases, skills, death, stairs and relic.
func _test_boss_fight(game: Node) -> void:
	game.depth = 3
	game._enter_floor()
	await _frames(5)
	var world: World = game.world
	var player: Player = game.player
	var arena := world.arena
	check(arena != null and arena.boss != null, "floor 3 is a boss arena")
	if arena == null:
		return
	var boss := arena.boss
	check(boss.is_boss() and boss.dormant, "the boss sleeps until you come in")
	check(world.monster_count() == 1, "only the boss on its floor")
	check(world.get_node("Entities").get_children().all(func(n: Node) -> bool: return not n is Stairs), "no stairs before the boss dies")
	await _frames(30)
	check(boss.target == null, "a dormant boss ignores the player")

	player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 4))
	await _frames(5)
	check(arena.is_started and arena.is_closed(), "walking in starts the fight and closes the exits")
	check(not boss.dormant and boss.target == player, "the boss wakes up")
	check(game.hud.get_node("%BossBar").visible, "boss health bar shown")
	check(not arena.get_gate_cells().is_empty(), "the arena has spikes on its exits")

	# Phase 2 at half HP: new skills.
	var def := boss.def as BossDef
	var hurt := HitInfo.new()
	hurt.amount = boss.hp - roundi(boss.get_max_hp() * def.phases[0].hp_ratio) + 1 + boss.get_stats().defense
	boss.take_hit(hurt)
	check(boss.skills.skills == def.phases[0].skills, "below %d%% HP the boss enters its next phase" % roundi(def.phases[0].hp_ratio * 100))

	# Telegraphed skill: cast, then a ring of projectiles.
	world.get_node("Projectiles").get_children().map(func(n: Node) -> void: n.queue_free())
	await _frames(2)
	boss.casting_index = 0
	boss.get_node("StateMachine").transition_to(&"Cast")
	await _frames(2)
	check(boss.telegraph > 0.0, "the boss telegraphs its skill")
	await _frames(int(boss.skills.skills[0].cast_time * 60.0) + 6)
	check(world.get_node("Projectiles").get_child_count() >= 8, "the skill fires a ring of projectiles")

	var summon := SummonEffect.new()
	summon.monsters = [load("res://data/monsters/slime.tres")]
	summon.count = 2
	var count_before := world.monster_count()
	summon.apply(boss, Vector2.RIGHT)
	check(world.monster_count() == count_before + 2, "summons appear")
	for monster in world.get_hostiles(player.faction):
		if monster != boss:
			monster.die(null)

	# Kill it: exits open, stairs appear, a relic is offered.
	var finish := HitInfo.new()
	finish.amount = 999999
	finish.source = player
	boss.take_hit(finish)
	check(boss.is_dead, "the boss can die")
	await _frames(5)
	check(arena.is_defeated and not arena.is_closed(), "the exits open again")
	check(world.get_node("Entities").get_children().any(func(n: Node) -> bool: return n is Stairs), "stairs appear after the boss")
	# The boss' XP may level the player up first: take those perks until the relic shows up.
	var relics: Array[PerkDef] = []
	for attempt in 10:
		await get_tree().create_timer(game.RELIC_DELAY * 0.5, true).timeout
		if not game.perk_panel.visible:
			continue
		var offered: Array[PerkDef] = game.perk_panel.get_offered()
		if offered.all(func(p: PerkDef) -> bool: return p.rarity == PerkDef.Rarity.RARE):
			relics = offered
			break
		game.perk_panel.choose(0)
	check(not relics.is_empty(), "the boss offers relics after the victory")
	if relics.is_empty():
		return
	game.perk_panel.choose(0)
	await _frames(2)
	check(player.perks.stacks_of(relics[0]) == 1 and not get_tree().paused, "relic taken, game resumed")

	# The last act's boss wins the run; you may keep going (endless).
	game.depth = 9
	game._enter_floor()
	await _frames(5)
	check(world.arena != null and world.arena.boss.def == CONTENT.dungeon.acts[2].boss, "floor 9: the final boss")
	player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 4))
	await _frames(5)
	var final_hit := HitInfo.new()
	final_hit.amount = 999999
	world.arena.boss.take_hit(final_hit)
	for attempt in 10:
		await get_tree().create_timer(game.RELIC_DELAY * 0.5, true).timeout
		if game.game_over_panel.visible:
			break
		if game.perk_panel.visible:
			game.perk_panel.choose(0)
	check(game.has_won and game.game_over_panel.visible and game.game_over_panel.get_node("%ContinueButton").visible, "beating the final boss wins the run")
	check(Profile.victories == 1 and Profile.souls > 0, "a victory is recorded with its souls")
	(game.game_over_panel.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	check(not game.game_over_panel.visible, "keep going: endless mode")
	if game.perk_panel.visible:
		game.perk_panel.choose(0)
	await _frames(3)
	check(not get_tree().paused, "the game resumes after the victory")


## Projectiles must stop on walls and hurt enemies.
func _test_projectiles(world: World, player: Player) -> void:
	var map := world.map
	var start := map.world_to_cell(player.global_position)
	# Closest wall in a straight line from the player.
	var best_dir := Vector2i.ZERO
	var best_distance := 999
	for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var distance := 1
		while map.is_floor(start + dir * distance):
			distance += 1
		if distance < best_distance:
			best_distance = distance
			best_dir = dir
	var wall_cell := start + best_dir * best_distance
	var wall_center := map.cell_to_world(wall_cell)

	var spec := ProjectileSpec.new()
	spec.speed = 400.0
	spec.max_distance = 5000.0
	world.fire_projectiles(player, Vector2(best_dir), spec)
	var crossed := false
	for i in 120:
		await get_tree().physics_frame
		for shot in world.get_node("Projectiles").get_children():
			var past: float = ((shot as Node2D).global_position - wall_center).dot(Vector2(best_dir))
			crossed = crossed or past > map.tile_size * 0.5
	check(not crossed, "projectiles stop on walls")
	check(world.get_node("Projectiles").get_child_count() == 0, "projectile removed after hitting a wall")

	# Shoot a monster standing in the open.
	var free_dir := -best_dir
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), player.global_position + Vector2(free_dir) * 60.0)
	var hp_before := target.hp
	spec.damage = 5
	world.fire_projectiles(player, Vector2(free_dir), spec)
	await _frames(20)
	check(target.hp < hp_before, "projectiles damage enemies")
	target.queue_free()
	await _frames(2)


func _bot_play(game: Node, frames: int) -> void:
	var path_timer := 0
	var path := PackedVector2Array()
	for frame in frames:
		var player: Player = game.player
		var world: World = game.world
		if player.is_dead:
			break
		if game.perk_panel.visible:
			# Level up: take the first card, like a player tapping it.
			await get_tree().create_timer(0.2, true).timeout
			game.perk_panel.choose(0)
			await get_tree().physics_frame
			continue
		var target := _nearest_monster(world, player)
		var direction := Vector2.ZERO
		if target:
			var distance := player.global_position.distance_to(target.global_position)
			if world.has_line_of_sight(player.global_position, target.global_position):
				direction = player.global_position.direction_to(target.global_position)
				if distance < 40.0:
					direction = direction.orthogonal() * 0.5  # circle around while fighting
			else:
				path_timer -= 1
				if path_timer <= 0:
					path = world.find_path(player.global_position, target.global_position)
					path_timer = 20
				while path.size() > 0 and player.global_position.distance_to(path[0]) < 10.0:
					path.remove_at(0)
				if path.size() > 0:
					direction = player.global_position.direction_to(path[0])
		_set_move(direction)
		_set_action(&"attack", target != null)
		_set_action(&"skill_%d" % (frame / 30 % 3 + 1), frame % 30 == 0)
		_set_action(&"quick_item", player.hp < player.get_max_hp() / 3 and frame % 20 == 0)
		await get_tree().physics_frame
	_set_move(Vector2.ZERO)
	for action: StringName in [&"attack", &"skill_1", &"skill_2", &"skill_3", &"quick_item"]:
		Input.action_release(action)


func _nearest_monster(world: World, player: Player) -> Actor:
	var best: Actor = null
	var best_distance := INF
	for monster in world.get_hostiles(player.faction):
		var distance := player.global_position.distance_to(monster.global_position)
		if distance < best_distance:
			best = monster
			best_distance = distance
	return best


func _set_move(direction: Vector2) -> void:
	_set_strength(&"move_left", maxf(-direction.x, 0.0))
	_set_strength(&"move_right", maxf(direction.x, 0.0))
	_set_strength(&"move_up", maxf(-direction.y, 0.0))
	_set_strength(&"move_down", maxf(direction.y, 0.0))


func _set_strength(action: StringName, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _set_action(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Positions are in game (viewport) coordinates; converted to window coordinates like a real screen.
func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * at
	event.pressed = pressed
	Input.parse_input_event(event)


func _drag(index: int, at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = get_viewport().get_final_transform() * at
	Input.parse_input_event(event)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame
