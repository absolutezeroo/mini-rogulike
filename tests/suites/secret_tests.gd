class_name SecretTests
extends TestSuite
## In the game: secret rooms behind cracked walls (break, reward, save), the hidden floor's key,
## the sealed way after its act's boss, the hidden floor and its boss, then the next act.


## A floor at `depth` with a secret room, built the way the game builds it (a few run seeds:
## some floors have no room for one). Null if none was found.
## (DungeonConfig.secret_room_chance must be 1 meanwhile: the caller sets it, and keeps it while
## the floor is built again.)
func _floor_with_secret(game: Game, depth: int) -> SecretRoom:
	var found: SecretRoom = null
	for attempt in 10:
		game.depth = depth
		game._enter_floor()
		await _frames(3)
		if not game.world.secrets.is_empty():
			found = game.world.secrets[0]
			break
		game.run.run_seed += 1
	return found


func _close_offers(game: Game) -> void:
	for i in 6:
		if not game.perk_panel.visible:
			return
		game.perk_panel.choose(0)
		await _frames(2)


## A cracked wall: monsters' blows leave it, the hero's break it; the room opens, shows on the map,
## holds its reward, counts; a save keeps it open. Blasts break cracks too.
func _test_secret_rooms(game: Game) -> void:
	var chance := CONTENT.dungeon.secret_room_chance
	CONTENT.dungeon.secret_room_chance = 1.0
	await _secret_room_in_game(game)
	CONTENT.dungeon.secret_room_chance = chance


func _secret_room_in_game(game: Game) -> void:
	var player: Player = game.player
	player.xp = -1000000  # no level up (and its pause) from these kills
	var room := await _floor_with_secret(game, 2)
	check(room != null, "a floor hides a secret room behind a cracked wall")
	if room == null:
		return
	var world: World = game.world
	await _clear_monsters(world)
	var plan := room.plan
	var crack := room.crack
	var center := plan.room.get_center()
	check(is_instance_valid(crack) and crack.is_in_group("cracked_walls") and crack.def.hits == CONTENT.dungeon.cracked_wall.hits, "a cracked wall stands at its mouth")
	check(not world.map.is_floor(center) and world.nav.is_blocked(center) and not world.is_explored(center), "the room is rock until then: not walked, not on the map")
	check(CONTENT.dungeon.hidden_floor.key_for(world) == null, "no key in the secret rooms of Act I")
	# Monsters can't open it (they would give it away).
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), crack.sight_point())
	crack.take_hit(Combat.make_hit_from(rat, 50))
	await _frames(2)
	check(is_instance_valid(crack) and not crack.is_broken and room.state == SecretRoom.State.HIDDEN, "a monster's blow doesn't break it")
	rat.queue_free()
	# The hero's blows do.
	var found_before := game.run.secrets_found
	var stat_before := Profile.stat_value("secrets")
	player.global_position = crack.sight_point()
	for i in 6:
		if room.state != SecretRoom.State.HIDDEN:
			break
		player._attack_cooldown = 0.0
		player.attack(crack.facing * -1.0)
		await _frames(40)
	check(room.state != SecretRoom.State.HIDDEN and (not is_instance_valid(crack) or crack.is_broken), "the hero's attacks break the cracked wall")
	await _frames(2)
	check(plan.cells().all(func(c: Vector2i) -> bool: return world.map.is_floor(c)) and plan.passage.all(func(c: Vector2i) -> bool: return not world.nav.is_blocked(c)), "the passage and the room are floor now")
	var path := world.find_path(player.global_position, world.map.cell_to_world(center + Vector2i(1, 1)))
	check(not path.is_empty() and world.map.world_to_cell(path[path.size() - 1]).distance_to(center + Vector2i(1, 1)) <= 1.0, "monsters and the hero can walk in")
	check(world.is_explored(center) and world.is_explored(plan.crack[0]), "it shows on the minimap")
	check(room.key != null or room.reward != null, "it holds its reward (%s)" % (room.reward.id if room.reward else &"key"))
	check(game.run.secrets_found == found_before + 1 and Profile.stat_value("secrets") == stat_before + 1, "the secret counts for the run and the profile")
	check(game.run.summary_rows(CONTENT, player.level).any(func(row: Array) -> bool: return row[0] == "Secret rooms found"), "and shows at the end of the run")
	# A save keeps it open: the same floor comes back with the wall broken (what resuming does:
	# the run from the save, the floor built again from its seed with what was spent on it; the
	# hero stays, the other game tests go on with them).
	var room_rect := plan.room
	game._save_run()
	var saved := RunSave.read()
	check((saved.get("floor", {}) as Dictionary).get("secrets", []).size() >= 1, "the save keeps the secret rooms' state")
	var resumed := RunState.create(CONTENT, saved, RandomNumberGenerator.new())
	check(resumed.secrets_found == found_before + 1 and resumed.depth == game.depth, "and the run its count")
	world.restore_spent(saved.get("floor", {}))
	game._enter_floor(true)
	await _frames(5)
	world = game.world
	check(not world.secrets.is_empty() and world.secrets[0].plan.room == room_rect, "a resumed run rebuilds the same secret room (same seed)")
	if world.secrets.is_empty():
		return
	var back: SecretRoom = world.secrets[0]
	check(back.state != SecretRoom.State.HIDDEN and world.map.is_floor(center) and (not is_instance_valid(back.crack) or back.crack.is_queued_for_deletion()), "and its wall stays broken")
	check(game.run.secrets_found == found_before + 1, "without counting it twice")


## The key in an Act II secret room; the boss of the act opens a third way with it; down it, the
## hidden floor and its boss; saved and resumed there; after it, the next act's first floor.
func _test_hidden_floor(game: Game) -> void:
	var chance := CONTENT.dungeon.secret_room_chance
	var key_chance := CONTENT.dungeon.hidden_floor.key_chance
	CONTENT.dungeon.secret_room_chance = 1.0
	CONTENT.dungeon.hidden_floor.key_chance = 1.0
	await _hidden_floor_in_game(game)
	CONTENT.dungeon.secret_room_chance = chance
	CONTENT.dungeon.hidden_floor.key_chance = key_chance
	# Whatever happened, the next tests start off the hidden floor.
	game.run.hidden_floor = false
	game.run.hidden_done = false
	game.player.inventory.remove(CONTENT.dungeon.hidden_floor.key)


func _hidden_floor_in_game(game: Game) -> void:
	var config := CONTENT.dungeon
	var hidden := config.hidden_floor
	var act := hidden.key_acts[0]
	var boss_depth := config.first_depth(act) + config.acts[act].floors - 1
	game.player.xp = -1000000
	game.player.inventory.remove(hidden.key)
	game.run.hidden_done = false
	var room := await _floor_with_secret(game, config.first_depth(act))
	check(room != null, "an Act II floor with a secret room")
	if room == null:
		return
	var world: World = game.world
	var player: Player = game.player
	await _clear_monsters(world)
	check(hidden.key_for(world) == hidden.key, "its secret rooms may hold the key")
	# A blast opens it too.
	Combat.blast(world, room.crack.sight_point(), 40.0, 0, 0.0)
	await _frames(3)
	check(room.state != SecretRoom.State.HIDDEN, "a blast breaks a cracked wall")
	check(room.key == hidden.key, "the room holds the key")
	player.global_position = world.map.cell_to_world(room.plan.room.get_center())
	await _frames(10)
	check(hidden.carries_key(player), "the hero picks the key up (%s)" % hidden.key.display_name)
	check(hidden.key_for(world) == null, "one key at a time")

	# Without it, the act's boss opens only the usual ways.
	player.inventory.remove(hidden.key)
	game.depth = boss_depth
	game._enter_floor()
	await _frames(5)
	world = game.world
	world.arena.boss.take_hit(Combat.make_secondary_hit(player, 9999999))
	await _frames(int(Game.RELIC_DELAY * 60.0) + 20)
	await _close_offers(game)
	check(world.stairs_cells.size() >= 1 and not world.get_node("Entities").get_children().any(func(n: Node) -> bool: return n is HiddenWay), "without the key: no hidden way")
	# With it, a third way.
	player.inventory.add(hidden.key)
	game._enter_floor()
	await _frames(5)
	world = game.world
	var exits := 0
	check(not world.arena.boss.is_dead, "the act's boss again, the key in the bag")
	world.arena.boss.take_hit(Combat.make_secondary_hit(player, 9999999))
	await _frames(int(Game.RELIC_DELAY * 60.0) + 20)
	await _close_offers(game)
	exits = world.stairs_cells.size()
	var way := game.hidden.way
	check(is_instance_valid(way) and world.map.boss_room.has_point(world.map.world_to_cell(way.global_position)), "with the key, the boss's fall opens a sealed way in the arena")
	check(exits >= 1 and exits == world.stairs_cells.size(), "beside the usual stairs (%d)" % exits)
	if not is_instance_valid(way):
		return
	check(way.route != null and way.route.title() == hidden.biome.display_name, "its sign names the hidden floor")
	player.global_position = way.global_position
	for i in 600:
		await _frames(1)
		if game.run.hidden_floor and not game._transitioning:
			break
	world = game.world
	check(game.run.hidden_floor and game.depth == boss_depth, "down the sealed way: the hidden floor, at the same depth")
	check(game.run.splits.size() >= boss_depth and game.run.splits[boss_depth - 1] > 0.0, "the boss floor's split is taken")
	check(world.hidden_floor == hidden and world.biome == hidden.biome and world.arena != null and world.arena.boss.def == hidden.boss, "its own world and its own boss")
	check(not hidden.carries_key(player), "the key is spent")
	var others := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Actor) -> bool: return not (m as Monster).is_boss())
	check(not others.is_empty() and others.all(func(m: Actor) -> bool: return hidden.monsters.has((m as Monster).def)), "its own monsters (%d)" % others.size())
	check(world.map.rooms.size() == hidden.rooms + 2, "rooms before its arena")

	# Saved and resumed on the hidden floor (the run from the save, the floor built again).
	game._save_run()
	var saved := RunSave.read()
	check(bool(saved.get("hidden_floor", false)) and int(saved.get("depth", 0)) == boss_depth, "the save knows the run is on the hidden floor")
	var resumed := RunState.create(CONTENT, saved, RandomNumberGenerator.new())
	check(resumed.hidden_floor and resumed.depth == boss_depth and not resumed.hidden_done, "a resumed run is on the hidden floor")
	game.run.hidden_floor = resumed.hidden_floor
	world.restore_spent(saved.get("floor", {}))
	game._enter_floor(true)
	await _frames(5)
	world = game.world
	check(game.run.hidden_floor and game.depth == boss_depth and world.hidden_floor == hidden and world.arena != null and world.arena.boss.def == hidden.boss, "resumed, the run is back on the hidden floor")

	# Its boss: the hoard, the souls, the feat; the way on to the next act.
	var split_before: float = game.run.splits[boss_depth - 1]
	var splits_before := game.run.splits.size()
	var souls_before := game.run.souls()
	var bosses_before := Profile.stat_value("hidden_bosses")
	world.arena.boss.take_hit(Combat.make_secondary_hit(player, 9999999))
	await _frames(int(Game.RELIC_DELAY * 60.0) + 20)
	await _close_offers(game)
	check(game.run.hidden_done and game.run.bonus_souls == hidden.bonus_souls and game.run.souls() >= souls_before + hidden.bonus_souls, "its boss pays its souls")
	check(Profile.stat_value("hidden_bosses") == bosses_before + 1 and Profile.is_achieved(&"he_who_does_not_rest"), "and its feat")
	check(world.get_node("Entities").get_children().any(func(n: Node) -> bool: return n is Chest and (n as Chest).def == hidden.chest), "its hoard appears in the arena")
	check(world.stairs_cells.size() >= 1 and not world.get_node("Entities").get_children().any(func(n: Node) -> bool: return n is HiddenWay), "then the usual stairs, no hidden way")
	if world.stairs_cells.is_empty():
		return
	game._save_run()
	var after := RunState.create(CONTENT, RunSave.read(), RandomNumberGenerator.new())
	var saved_after := RunSave.read()
	check(after.depth == boss_depth and after.hidden_floor and after.hidden_done and bool(saved_after.floor.get("arena_cleared", false)), "saved after its boss: picked up in its cleared arena, its hoard paid once")
	world.player.global_position = world.map.cell_to_world(world.stairs_cells[0])
	for i in 600:
		await _frames(1)
		if game.depth == boss_depth + 1 and not game._transitioning:
			break
	world = game.world
	check(game.depth == boss_depth + 1 and not game.run.hidden_floor and world.hidden_floor == null, "its stairs lead to the next floor")
	check(config.act_index(game.depth) == act + 1 and config.floor_in_act(game.depth) == 1, "the first floor of the next act")
	check(game.run.splits.size() == splits_before and is_equal_approx(game.run.splits[boss_depth - 1], split_before), "the hidden floor takes no split of its own (its time is the next floor's)")
	check(hidden.key_for(world) == null and world.hidden_floor_done, "once a run: no more keys")
