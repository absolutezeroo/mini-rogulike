class_name GameTests
extends TestSuite
## The real game, played: sets the game up, a bot plays, then runs the other game suites on it
## (CombatTests, FloorTests, BossTests).


func run() -> void:
	# The other game suites play on the same game, one after the other.
	var combat := CombatTests.new()
	var floor := FloorTests.new()
	var boss := BossTests.new()
	for suite: Node in [combat, floor, boss]:
		add_child(suite)
	# No merchant, encounter, ambush or special floor popping up in the middle of other tests (they have their own).
	var merchant_chance := CONTENT.dungeon.merchant_chance
	var encounters_max := CONTENT.dungeon.encounters_max
	var ambush_chance := CONTENT.dungeon.ambush_chance
	var event_chance := CONTENT.dungeon.floor_event_chance
	CONTENT.dungeon.ambush_chance = 0.0
	CONTENT.dungeon.floor_event_chance = 0.0
	# No curses either (they have their own test).
	var curse_chances := {}
	for difficulty in CONTENT.difficulties:
		curse_chances[difficulty] = difficulty.curse_chance
		difficulty.curse_chance = 0.0
	CONTENT.dungeon.merchant_chance = 0.0
	CONTENT.dungeon.encounters_max = 0
	var game := GAME_SCENE.instantiate() as Game
	game.show_act_cards = false  # tested on their own (see _test_act_card)
	add_child(game)
	await _frames(5)
	var world: World = game.world
	var player: Player = game.player
	check(player != null and player.world == world, "player spawned in world")
	check(world.monster_count() > 0, "monsters spawned (%d)" % world.monster_count())
	check(player.get_weapon() != null, "player starts with a weapon")

	await combat._test_projectiles(world, player)
	await combat._test_perks_in_game(game, world, player)
	await floor._test_world_objects(game, world, player)
	await floor._test_hazards(game, world, player)
	await combat._test_skills(game, world, player)
	await combat._test_bestiary(world, player)
	await combat._test_difficulty_in_game(game, world, player)

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
	player._invulnerable_time = 2.0  # a monster's hit would play the hurt animation
	player._attack_cooldown = 0.0
	player.attack(Vector2.LEFT)
	check(rig.direction == &"left", "the rig turns toward the attack")
	check(rig.body.animation == &"attack_left", "the body plays attack_left (got %s)" % rig.body.animation)
	check(rig.weapon.visible and rig.weapon.animation == &"attack_left", "the katana is drawn in hand, synced")
	await _frames(40)
	check(not rig.weapon.visible, "the weapon is put away after the attack")
	check(String(rig.body.animation).begins_with("idle") or String(rig.body.animation).begins_with("walk"), "back to idle/walk (%s)" % rig.body.animation)
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
	player._invulnerable_time = 1.0  # a hit mid-walk would play the hurt animation
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
	check(kills[0] >= 3, "bot killed monsters (%d)" % kills[0])
	check(player.level > 1, "player gained levels")

	# Stairs take you deeper.
	var depth_before: int = game.depth
	player.global_position = world.map.cell_to_world(world.map.stairs_cell)
	await _frames(int(game.FADE_TIME * 60.0) + 12)  # the depth changes once the screen is black
	check(game.depth == depth_before + 1, "stairs lead to the next depth")
	check(game._fade.color.a > 0.0, "taking the stairs fades to black")
	await _frames(60)
	check(depth_changes[0] >= 1, "depth_changed emitted")
	check(world.monster_count() > 0, "new floor populated")
	check(not get_tree().paused and game._fade.color.a < 0.05, "the fade clears on the new floor")
	await floor._test_ambience(game)
	await floor._test_act_card(game)
	await floor._test_souls(game)
	await floor._test_comfort(game)
	await floor._test_loot_and_gold(game)
	await combat._test_weapon_kits(game)
	await floor._test_encounters(game)
	await floor._test_variety(game)
	await floor._test_belt_and_balance(game)
	await combat._test_monster_behaviours(game)
	await floor._test_climate(game)
	await combat._test_review_fixes(game)

	await boss._test_boss_fight(game)

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
	check(not RunSave.exists(), "dying ends the saved run")
	check(not Profile.history.is_empty() and not str(Profile.history[0].cause).is_empty(), "the run goes to the history, with what ended it")
	check(Profile.stat_value("kills") > 0 and Profile.stat_value("species") > 0, "kills count in the bestiary")
	check(Profile.is_achieved(&"first_blood"), "first kill, first achievement")
	var summary := (game.game_over_panel.get_node("%Summary") as Label).text
	check(Profile.souls >= souls_before_death and summary.contains("souls"), "the end of a run shows its souls")
	check(Array(CONTENT.story.death_lines).any(func(line: String) -> bool: return summary.begins_with(line)), "and a line of the story")
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
	var base_hp: int = game.player.get_max_hp()
	Profile.wins = { "hard": 1, "nightmare": 1 }
	Profile.ascension_unlocked = 9
	Profile.ascension = 9
	game.start_run()
	await _frames(3)
	check(game.difficulty.ascension == 9 and game.world.difficulty.display_name == "Nightmare +9", "a run on Nightmare +9")
	check(game.player.get_max_hp() < base_hp, "Frail: less max HP")
	var merchant: Merchant = game.world.spawn_merchant(CONTENT.dungeon.merchant, game.world.map.start_cell + Vector2i(3, 0))
	var potion_price: int = CONTENT.dungeon.merchant.buy_price(load("res://data/items/consumables/health_potion.tres"), game.depth)
	merchant._add(load("res://data/items/consumables/health_potion.tres"))
	check(merchant.stock.back().price > potion_price, "Thin Purse: higher prices")
	merchant.queue_free()
	game._save_run()
	check(int(RunSave.read().get("ascension", 0)) == 9, "the saved run keeps its ascension")
	Profile.wins = {}
	Profile.ascension_unlocked = 0
	Profile.ascension = 0
	Profile.difficulty = &"normal"
	game.start_run()
	await _frames(3)
	check(game.player != player and not game.player.is_dead, "restart creates a fresh player")
	check(game.player.get_max_hp() == CONTENT.player.base_stats.max_hp + 2 * _upgrade("vitality").bonuses.max_hp, "Vitality raises max HP")
	var potion_def: ConsumableDef = load("res://data/items/consumables/health_potion.tres")
	check(game.player.belt.count_of(potion_def) + game.player.inventory.count_of(potion_def) == CONTENT.player.starting_items.size() + 1, "Provisions add a potion")
	check(game.player.perks.stacks_of(load("res://data/perks/relics/phoenix_feather.tres")) == 1, "Second Chance gives a Phoenix Feather")
	check(CONTENT.unlocked_items.has(load("res://data/items/weapons/templar_sword.tres")), "Paladin's Oath unlocks the Templar Sword")
	Profile.reset()
	check(game.depth == 1, "restart goes back to depth 1")

	# The run in progress is saved, and picked up again as it was.
	check(RunSave.exists(), "the run in progress is saved")
	var hero: Player = game.player
	var wand: ItemDef = load("res://data/items/weapons/magic_wand.tres")
	var frenzy := _perk("frenzy")
	hero.level = 3
	hero.xp = 7
	hero.inventory.add(wand)
	hero.perks.add(frenzy)
	var weapon_before := hero.get_weapon()
	game.depth = 5
	game.kills = 12
	game._save_run()
	var saved := RunSave.read()
	check(int(saved.get("depth", 0)) == 5 and int(saved.player.level) == 3, "the save holds the run")
	game.resume_run(saved)
	await _frames(5)
	var back: Player = game.player
	check(back != hero and game.depth == 5 and game.kills == 12 and game.world.depth == 5, "resuming goes back to the same depth")
	check(back.level == 3 and back.xp == 7 and back.perks.stacks_of(frenzy) == 1, "the hero comes back as saved")
	check(back.inventory.count_of(wand) >= 1 and back.get_weapon() == weapon_before, "with their gear")

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
	CONTENT.dungeon.merchant_chance = merchant_chance
	CONTENT.dungeon.encounters_max = encounters_max
	CONTENT.dungeon.ambush_chance = ambush_chance
	CONTENT.dungeon.floor_event_chance = event_chance
	for difficulty in curse_chances:
		difficulty.curse_chance = curse_chances[difficulty]
	await _frames(2)
