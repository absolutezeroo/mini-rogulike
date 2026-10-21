class_name GameTests
extends TestSuite
## The real game, played: sets the game up, a bot plays, then runs the other game suites on it
## (CombatTests, FloorTests, SecretTests, BossTests).


func run() -> void:
	# The other game suites play on the same game, one after the other.
	var combat := CombatTests.new()
	var floor := FloorTests.new()
	var boss := BossTests.new()
	var secrets := SecretTests.new()
	for suite: Node in [combat, floor, boss, secrets]:
		add_child(suite)
	# No merchant, encounter, ambush or special floor popping up in the middle of other tests (they have their own).
	var merchant_chance := CONTENT.dungeon.merchant_chance
	var encounters_max := CONTENT.dungeon.encounters_max
	var ambush_chance := CONTENT.dungeon.ambush_chance
	var event_chance := CONTENT.dungeon.floor_event_chance
	var pact_chance := CONTENT.dungeon.pact_chance
	CONTENT.dungeon.ambush_chance = 0.0
	CONTENT.dungeon.floor_event_chance = 0.0
	CONTENT.dungeon.pact_chance = 0.0
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
	await combat._test_threshold(game, world, player)
	await combat._test_synergies_in_game(game, world, player)
	await combat._test_sustain_in_game(world, player)
	await floor._test_world_objects(game, world, player)
	await floor._test_hazards(game, world, player)
	await floor._test_abyss(game, world, player)
	await floor._test_abyss_rules(game, world, player)
	await floor._test_forge(game, world, player)
	await floor._test_feel(game, world, player)
	await floor._test_screen_pass(game, world, player)
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
	var cap: ItemDef = load("res://data/items/armors/leather_cap.tres")
	while player.inventory.is_full():
		player.inventory.items.pop_back()  # (loot picked up on the way may have filled it)
	player.inventory.add(cap)
	game.open_inventory()
	await _frames(2)
	check(get_tree().paused, "inventory pauses the game")
	var grid: GridContainer = game.inventory_panel.get_node("%ItemGrid")
	var cap_slot: ItemSlot = null
	for child in grid.get_children():
		if (child as ItemSlot).item and (child as ItemSlot).item.id == cap.id:  # (or a cap picked up on the way)
			cap_slot = child
	# A stack takes one place: as many slots as the bag has places.
	check(grid.get_child_count() == player.inventory.capacity and cap_slot != null, "inventory shows the bag as slots (%d of %d)" % [grid.get_child_count(), player.inventory.capacity])
	cap_slot.pressed.emit()
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

	# Fixed joystick (an option): it starts only when touched in its corner.
	Settings.set_option(&"fixed_joystick", true)
	var stick: TouchJoystick = game.hud.get_node("%Joystick")
	check(stick.fixed, "the fixed joystick option reaches the HUD")
	var corner := stick.get_global_transform_with_canvas() * stick.home()
	_touch(0, corner + Vector2(0, -260), true)
	await _frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down") == Vector2.ZERO, "fixed: a touch away from its corner does nothing")
	_touch(0, corner + Vector2(0, -260), false)
	_touch(0, corner + Vector2(70, 0), true)
	await _frames(2)
	check(Input.get_vector("move_left", "move_right", "move_up", "move_down").x > 0.5, "fixed: a touch on it pushes that way at once")
	_touch(0, corner + Vector2(70, 0), false)
	await _frames(2)
	Settings.set_option(&"fixed_joystick", false)
	var bag: Button = game.hud.get_node("%BagButton")
	_touch(0, bag.get_global_rect().get_center(), true)
	await _frames(1)
	_touch(0, bag.get_global_rect().get_center(), false)
	await _frames(2)
	check(game.inventory_panel.visible, "tapping the bag button opens the inventory")
	game.inventory_panel.close()
	await _frames(2)

	await _test_run_timer(game)

	# Play: hunt monsters for a while (god mode so the run lasts).
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _bot_play(game, 60 * 40)
	print("bot: %d kills, level %d, depth %d" % [kills[0], player.level, game.depth])
	check(kills[0] >= 3, "bot killed monsters (%d)" % kills[0])
	check(player.level > 1, "player gained levels")

	# Sealed stairs first; then, open, they take you deeper.
	await floor._test_stairs_seal(game)
	world = game.world
	var depth_before: int = game.depth
	player.global_position = world.map.cell_to_world(world.map.stairs_cell)
	await _frames(int(game.FADE_TIME * 60.0) + 12)  # the depth changes once the screen is black
	check(game.depth == depth_before + 1, "stairs lead to the next depth")
	check(game.run.splits.size() == depth_before and game.run.splits[depth_before - 1] > 0.0, "the floor's split is taken (%s)" % [game.run.splits])
	check(game.hud.split_text().begins_with("Floor %d" % depth_before), "and shown: %s" % game.hud.split_text())
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
	await floor._test_bag_room(game)
	await combat._test_weapon_kits(game)
	await combat._test_charged_attacks(game)
	await combat._test_own_effects(game)
	await combat._test_elemental_attacks(game)
	await floor._test_encounters(game)
	await floor._test_pacts(game)
	await floor._test_variety(game)
	await floor._test_floor_size(game)
	await floor._test_routes(game)
	await floor._test_soul_tree_run(game)
	await floor._test_status_looks(game)
	await floor._test_biomes(game)
	await floor._test_details(game)
	await floor._test_belt_and_balance(game)
	await combat._test_monster_behaviours(game)
	await combat._test_ai_movement(game)
	await floor._test_climate(game)
	await combat._test_review_fixes(game)
	await floor._test_debug_panel(game)

	await secrets._test_secret_rooms(game)
	await secrets._test_hidden_floor(game)
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
	check(not game.threshold.is_open(), "no second life, no Threshold")
	await get_tree().create_timer(1.5).timeout
	check(game.game_over_panel.visible, "game over screen shown")
	check(not RunSave.exists(), "dying ends the saved run")
	check(not Profile.history.is_empty() and not str(Profile.history[0].cause).is_empty(), "the run goes to the history, with what ended it")
	check(Profile.stat_value("kills") > 0 and Profile.stat_value("species") > 0, "kills count in the bestiary")
	check(Profile.is_achieved(&"first_blood"), "first kill, first achievement")
	var summary := (game.game_over_panel.get_node("%Summary") as Label).text
	var end_text := game.game_over_panel.shown_text()
	check(Profile.souls >= souls_before_death and end_text.contains("souls") and end_text.contains("Shrine"), "the end of a run shows its souls and what they are for")
	check(end_text.contains("Monsters slain") and end_text.contains("Time"), "and the run's numbers")
	check(Array(CONTENT.story.death_lines).any(func(line: String) -> bool: return summary.begins_with(line)), "and a line of the story")
	# Shrine upgrades apply to the next run.
	Profile.levels = { "vitality": 2, "provisions": 1, "second_chance": 1, "paladin_oath": 1 }
	Profile.difficulty = &"easy"
	game.start_run()
	await _frames(5)
	check(game.difficulty.id == &"easy" and game.world.difficulty == game.difficulty, "the run uses the chosen difficulty")
	check((game.hud.get_node("%InfoLabel") as Label).text.contains("Pilgrim"), "the HUD shows the difficulty")
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

	# The daily run: the same floors, weapon and relic all day; the first attempt counts.
	var day := DailyRun.today()
	game.start_run(true)
	await _frames(3)
	check(game.run.is_daily() and game.run.daily_official and Profile.daily_played(day), "today's daily run is the official attempt")
	check(game.difficulty == CONTENT.default_difficulty, "on Normal")
	check(game.player.get_weapon() == DailyRun.weapon(CONTENT, day) and game.player.perks.stacks_of(DailyRun.relic(CONTENT, day)) == 1, "with the day's weapon and relic")
	var rooms := game.world.map.rooms.duplicate()
	game._enter_floor()
	await _frames(2)
	check(game.world.map.rooms == rooms, "the same floor every time that day")
	game.run.kills = 10
	game.depth = 3
	game.run.depth = 3
	game._award_souls(false)
	check(Profile.daily_score == DailyRun.score(game.run) and Profile.daily_best == Profile.daily_score and Profile.daily_score >= 10 + 2 * DailyRun.POINTS_PER_FLOOR, "its score is kept (%d)" % Profile.daily_score)
	game.start_run(true)
	await _frames(3)
	check(game.run.is_daily() and not game.run.daily_official, "a second daily run that day is practice")
	game._save_run()
	check(int(RunSave.read().get("daily_day", -1)) == day, "a saved daily run stays a daily run")
	game.start_run()
	await _frames(3)
	check(not game.run.is_daily(), "Play starts a normal run")
	Profile.reset()

	# The run in progress is saved, and picked up again as it was.
	check(RunSave.exists(), "the run in progress is saved")
	var hero: Player = game.player
	var wand: ItemDef = load("res://data/items/weapons/magic_wand.tres")
	var frenzy := _perk("frenzy")
	# Perk choices wait across floors, and are saved with the run (the one on screen with its cards).
	hero.gain_xp(hero.xp_to_next_level())
	hero.gain_xp(hero.xp_to_next_level())
	await _frames(2)
	check(game.pending_offers() == 2 and not game.perk_panel.visible, "two level ups: two choices wait")
	game.depth = 4
	game._enter_floor()
	await _frames(3)
	check(game.pending_offers() == 2 and (game.hud.get_node("%OffersButton") as OffersButton).count == 2, "they wait across floors")
	check(game.open_offers(), "the perk button opens them")
	var on_screen := game.perk_panel.get_offered().duplicate()
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
	check(not game.perk_panel.visible and not get_tree().paused, "a resumed run opens no perk choice by itself")
	check(game.pending_offers() == 2 and (game.hud.get_node("%OffersButton") as OffersButton).count == 2, "the waiting choices survive save and resume, behind the perk button")
	check(await _tap_offers(game) and game.perk_panel.visible and game.perk_panel.get_offered() == on_screen, "the choice that was on screen comes back with its cards")
	game.perk_panel.choose(0)
	await _frames(2)
	check(game.perk_panel.visible, "then the other one")
	game.perk_panel.choose(0)
	await _frames(2)
	check(not get_tree().paused and game.pending_offers() == 0, "both taken, back to the game")

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
	await combat._test_threshold_lost(game)
	await floor._test_abyss_death(game)
	var off_grid := _off_grid_texts(game)
	check(off_grid.is_empty(), "every text of the HUD and the in-run panels is on the font's grid (Fonts.SIZES, a one-pixel outline): %s" % ", ".join(off_grid.slice(0, 6)))
	game.queue_free()
	CONTENT.dungeon.merchant_chance = merchant_chance
	CONTENT.dungeon.encounters_max = encounters_max
	CONTENT.dungeon.ambush_chance = ambush_chance
	CONTENT.dungeon.floor_event_chance = event_chance
	CONTENT.dungeon.pact_chance = pact_chance
	for difficulty in curse_chances:
		difficulty.curse_chance = curse_chances[difficulty]
	await _frames(2)


## The run's clock: counts in play and in the bag, not in the pause menu; on the HUD.
func _test_run_timer(game: Game) -> void:
	var run := game.run
	var start := run.time
	await _frames(60)
	check(run.time - start > 0.9 and run.time - start < 1.2, "the clock counts real seconds (%.2f)" % (run.time - start))
	game.open_pause_menu()
	var paused := run.time
	await _frames(60)
	check(is_equal_approx(run.time, paused), "it stops in the pause menu")
	game.pause_menu.resume_requested.emit()
	await _frames(2)
	game.open_inventory()
	var in_bag := run.time
	await _frames(30)
	check(run.time > in_bag + 0.4, "it runs in the bag (deciding is part of the run)")
	game.inventory_panel.close()
	HitStop.slow(1.0, 0.25)
	var slow := run.time
	await _frames(30)
	check(run.time - slow > 0.4, "slow motion doesn't slow the clock (%.2f)" % (run.time - slow))
	HitStop.reset()
	var label := game.hud.get_node("%TimerLabel") as Label
	await _frames(1)
	check(label.visible and label.text == TimeText.of(run.time, 1), "the time is under the map: %s" % label.text)
	Settings.set_option(&"run_timer", false)
	await _frames(1)
	check(not label.visible, "the run timer can be hidden")
	Settings.set_option(&"run_timer", true)

