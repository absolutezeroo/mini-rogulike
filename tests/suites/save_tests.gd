class_name SaveTests
extends TestSuite
## In the game: a run put away and picked up again (RunSave, World.spent_data()). The things a
## floor's seed lays and the hero used up stay used up (items taken, props broken, encounters
## used, an ambush cleared, the merchant's stock), on normal floors and on the hidden floor; a
## floor saved by another build is laid fresh (the hero and the run kept); an old save is migrated;
## a damaged one never stops the game. Played by GameTests on its game.


func run_game(game: Game) -> void:
	var config := CONTENT.dungeon
	var kept := {
		"merchant_chance": config.merchant_chance, "encounters_min": config.encounters_min,
		"encounters_max": config.encounters_max, "ambush_chance": config.ambush_chance,
	}
	config.merchant_chance = 1.0
	config.encounters_min = 1
	config.encounters_max = 2
	config.ambush_chance = 1.0
	await _test_floor_kept(game)
	for key: String in kept:
		config.set(key, kept[key])
	await _test_hidden_floor_kept(game)
	await _test_other_build(game)
	await _test_old_and_damaged_saves(game)


## The things of a world's own floor (not the Threshold's, the Deeps').
func _of(world: World, group: StringName) -> Array[Node]:
	var result: Array[Node] = []
	for node in get_tree().get_nodes_in_group(group):
		if world.is_ancestor_of(node) and not node.is_queued_for_deletion():
			result.append(node)
	return result


## A floor with a merchant, an encounter, an ambush, items lying around and props, built by its
## seed at some depth (the chances are raised by run_game()).
func _full_floor(game: Game) -> bool:
	for target in range(2, 12):
		game.depth = target
		game._enter_floor()
		await _frames(3)
		var world := game.world
		if world.ambush and world.floor_merchant() and not _of(world, &"encounters").is_empty() \
				and not _of(world, &"pickups").is_empty() and not world.get_breakable_props().is_empty():
			return true
	return false


func _test_floor_kept(game: Game) -> void:
	game.start_run()
	await _frames(3)
	var player: Player = game.player
	player.invincible = true
	player.xp = -1000000  # no level up (and its choice) from the kills below
	check(await _full_floor(game), "a floor with a merchant, an encounter, an ambush, items and props (depth %d)" % game.depth)
	var world: World = game.world
	player = game.player
	player.gold = 99999
	var pickups_before := _of(world, &"pickups").size()
	var props_before := world.get_breakable_props().size()

	# An item lying around, taken.
	var pickup := _of(world, &"pickups")[0] as ItemPickup
	var item_at := pickup.global_position
	check(pickup.take(player), "the hero takes an item lying on the floor")
	# A prop broken (not a keg: its blast would break others).
	var prop: Prop = null
	for candidate in world.get_breakable_props():
		if not candidate.def.is_explosive():
			prop = candidate
			break
	var prop_cells: Array[Vector2i] = prop.cells() if prop else []
	var hit := HitInfo.new()
	hit.source = player
	for i in (prop.def.hits if prop else 0):
		prop.take_hit(hit)
	check(prop != null and prop.is_broken, "a prop broken")
	# An encounter used.
	var encounter := _of(world, &"encounters")[0] as Encounter
	var encounter_at := encounter.global_position
	for choice in encounter.def.choices.size():
		if encounter.used:
			break
		encounter.resolve(choice, player)
	check(encounter.used, "an encounter used")
	# The ambush, cleared.
	var ambush := world.ambush
	ambush.start()
	for i in 60 * 60:
		if ambush.state == AmbushRoom.State.CLEARED:
			break
		# A gift of the encounter, or a level up, may have opened the perk choice: the game waits
		# behind it (paused) and so would the ambush's waves.
		if game.perk_panel.visible:
			game.perk_panel.choose(0)
		for monster: Variant in ambush._wave:  # (its waves, wherever they stand)
			if is_instance_valid(monster) and not (monster as Monster).is_dead:
				(monster as Monster).take_hit(Combat.make_secondary_hit(player, 99999))
		await _frames(1)
	check(ambush.state == AmbushRoom.State.CLEARED and ambush.reward_cell != DungeonMap.NO_CELL, "the ambush cleared, its chest put down (%s, %d waves left)" % [ambush.state, ambush.waves_left])
	var chest_cell := ambush.reward_cell
	# The merchant: an entry locked, one bought, the rest rerolled.
	var merchant := world.floor_merchant()
	merchant.toggle_lock(0)
	var locked_key := Merchant._key(LootRoller.to_data(merchant.stock[0].item))
	check(merchant.sell_to(player, merchant.stock.size() - 1) and merchant.reroll(player), "bought from the merchant, then rerolled")
	var stock_before := _stock_keys(merchant)
	await _frames(2)

	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	player = game.player
	check(_of(world, &"pickups").size() == pickups_before - 1, "resumed, the item taken isn't lying there again (%d of %d)" % [_of(world, &"pickups").size(), pickups_before])
	check(not _of(world, &"pickups").any(func(n: Node) -> bool: return (n as Node2D).global_position.distance_to(item_at) < 1.0), "...not where it lay")
	check(world.get_breakable_props().size() == props_before - 1, "the prop broken stays broken (%d of %d)" % [world.get_breakable_props().size(), props_before])
	check(prop_cells.all(func(cell: Vector2i) -> bool: return not world.nav.is_blocked(cell)), "...its cells free")
	var back_encounter := _of(world, &"encounters").filter(func(n: Node) -> bool: return (n as Node2D).global_position == encounter_at)
	check(back_encounter.size() == 1 and (back_encounter[0] as Encounter).used, "the encounter used stays used")
	check(world.ambush != null and world.ambush.state == AmbushRoom.State.CLEARED, "the ambush cleared stays cleared (no waves again)")
	var chests := _chests_at(world, chest_cell)
	check(chests.size() == 1 and not chests[0].is_open, "its chest is back where it was put down, still closed")
	if chests.is_empty():
		return
	merchant = world.floor_merchant()
	check(merchant != null and _stock_keys(merchant) == stock_before and merchant.rerolls_done == 1, "the merchant's stock as it was: rerolled, less what was bought, the rerolls paid")
	check(merchant.stock.filter(func(e: Dictionary) -> bool: return Merchant._key(LootRoller.to_data(e.item)) == locked_key).size() == 1, "the entry locked there is in it once")
	check(world.kept_stock.is_empty(), "and not waiting for the next merchant too")
	check(world.ledger.spent_count(FloorLedger.ITEM) == 1 and world.ledger.spent_count(FloorLedger.PROP) >= 1 and world.ledger.spent_count(FloorLedger.ENCOUNTER) == 1, "kept for the next save too")

	# A save from before the stock was kept: the seed's stock again, the entry locked there once
	# (kept, and not rolled a second time beside it).
	var older := RunSave.read()
	(older.floor as Dictionary).erase("merchant")
	game.resume_run(older)
	await _frames(5)
	world = game.world
	merchant = world.floor_merchant()
	check(merchant != null and merchant.stock.filter(func(e: Dictionary) -> bool: return Merchant._key(LootRoller.to_data(e.item)) == locked_key).size() == 1, "an older save: the entry locked there is in the merchant's stock once")
	chests = _chests_at(world, chest_cell)
	if chests.is_empty():
		return

	# Its chest opened, then put away again: open.
	chests[0].open()
	await _frames(2)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	chests = _chests_at(world, chest_cell)
	check(chests.size() == 1 and chests[0].is_open, "the ambush's chest opened stays opened")
	check(_of(world, &"pickups").size() == pickups_before - 1 and world.get_breakable_props().size() == props_before - 1, "a second resume keeps it all as it was")
	game.player.invincible = false
	game.player.xp = 0


static func _stock_keys(merchant: Merchant) -> Array[String]:
	var keys: Array[String] = []
	for entry in merchant.stock:
		keys.append("%s/%d/%s" % [Merchant._key(LootRoller.to_data(entry.item)), entry.price, entry.get("locked", false)])
	return keys


func _chests_at(world: World, cell: Vector2i) -> Array[Chest]:
	var result: Array[Chest] = []
	for node in world.get_node("Entities").get_children():
		if node is Chest and not node.is_queued_for_deletion() and world.map.world_to_cell((node as Chest).global_position) == cell:
			result.append(node as Chest)
	return result


## The hidden floor is laid from its seed too (a boss floor): its monsters slain before quitting
## stay slain.
func _test_hidden_floor_kept(game: Game) -> void:
	game.start_run()
	await _frames(3)
	if CONTENT.dungeon.hidden_floor == null:
		return
	await game.debug.enter_hidden()
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	player.xp = -1000000
	var own := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Actor) -> bool: return m is Monster and (m as Monster).floor_index >= 0)
	var all_before := world.monster_count()
	check(world.hidden_floor != null and own.size() >= 2 and own.size() == all_before - 1, "the hidden floor's monsters have their numbers, all but its boss (%d of %d)" % [own.size(), all_before])
	if own.size() < 2:
		return
	var slain: Array[int] = [(own[0] as Monster).floor_index, (own[own.size() - 1] as Monster).floor_index]
	for monster: Actor in [own[0], own[own.size() - 1]]:
		monster.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	game._save_run()
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	var back := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Actor) -> bool: return m is Monster and (m as Monster).floor_index >= 0) \
		.map(func(m: Actor) -> int: return (m as Monster).floor_index)
	check(game.run.hidden_floor and world.hidden_floor != null, "resumed on the hidden floor")
	check(not slain.any(func(i: int) -> bool: return back.has(i)) and back.size() == own.size() - 2, "its monsters slain stay slain, the others are back (%s, slain %s)" % [back, slain])
	check(world.arena != null and is_instance_valid(world.arena.boss), "its warden waits as before")
	game.player.invincible = false


## A floor saved by another build (a game update in between) may come out otherwise from the
## same seed: it is laid fresh, said in a note, while the hero and the run come back whole.
func _test_other_build(game: Game) -> void:
	game.start_run()
	await _frames(3)
	game.depth = 2
	game._enter_floor()
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	check(world.arena == null and world.monster_count() > 0, "a normal floor (%d monsters)" % world.monster_count())
	player.invincible = true
	player.xp = -1000000
	var monsters_before := world.monster_count()
	var pickups_before := _of(world, &"pickups").size()
	for pickup in _of(world, &"pickups").slice(0, 1):
		(pickup as ItemPickup).take(player)
	world.get_hostiles(Actor.Faction.PLAYER)[0].take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	player.gold = 321
	player.level = 4
	game._save_run()
	var saved := RunSave.read()
	saved.floor.stamp = "0.0.1/1"  # as an older build would have written it
	RunSave.write(saved)
	game.resume_run(RunSave.read())
	await _frames(5)
	world = game.world
	var note := tr("The Well has shifted since you left: this floor is laid anew.")
	check((game.hud.get_node("%ToastLabel") as Label).text == note or game.hud._toasts.has(note), "a note says the floor is laid anew")
	check(game.depth == 2 and game.player.gold == 321 and game.player.level == 4, "the run and the hero come back whole")
	check(world.monster_count() == monsters_before and _of(world, &"pickups").size() == pickups_before and world.seal.kills == 0, "the floor is laid fresh: its monsters, its items, its seal (%d/%d monsters, %d/%d items)" % [world.monster_count(), monsters_before, _of(world, &"pickups").size(), pickups_before])
	check(world.ledger.spent_count(FloorLedger.ITEM) == 0 and world.floor_save.slain.is_empty(), "nothing of the old floor kept for the next save")
	game.player.invincible = false


## A save of the first version comes back (migrated); damaged fields never stop the game.
func _test_old_and_damaged_saves(game: Game) -> void:
	game.start_run()
	await _frames(3)
	game.depth = 2
	game._enter_floor()
	await _frames(3)
	game.player.gold = 77
	game._save_run()
	var data: Dictionary = SafeFile.read_json(RunSave.path)
	data.version = 1
	(data.floor as Dictionary).erase("stamp")
	(data.floor as Dictionary).erase("spent")
	SafeFile.write_json(RunSave.path, data)
	var old := RunSave.read()
	check(not old.is_empty() and int(old.version) == RunSave.VERSION, "a version 1 save is read, migrated")
	game.resume_run(old)
	await _frames(5)
	check(game.depth == 2 and game.player != null and game.player.gold == 77, "its run comes back")

	# Damaged everywhere the game reads (a hand-edited file, a disk gone bad): the game goes on.
	data = SafeFile.read_json(RunSave.path)
	data.kept_stock = "x"
	data.routes = [1]
	data.splits = { "a": 1 }
	data.marks = 3
	data.player.perks = [1, "x", { "perk": 3, "stacks": "a" }]
	data.player.equipment = []
	data.player.base_stats = { "max_hp": [1] }
	data.offers = "x"
	data.floor = { "stamp": RunSave.floor_stamp(), "chests": 5, "spent": "x", "merchant": 3, "ambush": [1], "slain": { "a": 1 }, "secrets": "x", "sealed": [[1]], "bought": 4 }
	SafeFile.write_json(RunSave.path, data)
	var damaged := RunSave.read()
	check(not damaged.is_empty(), "a damaged save is still a run")
	game.resume_run(damaged)
	await _frames(5)
	check(game.depth == 2 and game.player != null and not game.player.is_dead and game.world.map != null, "picked up again: the hero on his floor")
	# The floor's restore checks its own data too (it may be handed anything).
	game.world.restore_spent({
		"chests": [[1], "x", [1, "a"]], "spent": { "items": "x", "props": [[0]], "gold": [["a", 1]] },
		"merchant": { "stock": [1, { "item": 3, "price": "x" }], "rerolls": "x" }, "ambush": { "cleared": true, "room": "x" },
		"bought": [1], "secrets": [1, [2]], "slain": [[1]], "seal_kills": 2.5, "pact": "x", "collapsed": "x", "sealed": [["a", "b"]],
	})
	game._enter_floor(true)
	await _frames(3)
	check(game.world.map != null and game.player.world == game.world, "a floor restored from damaged data is built all the same")
	game.world.restore_spent("x")
	game._enter_floor(true)
	await _frames(3)
	check(game.world.map != null, "and from no data at all")
