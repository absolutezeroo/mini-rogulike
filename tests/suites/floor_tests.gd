class_name FloorTests
extends TestSuite
## In the game: what floors hold (props, hazards, chests, ambushes, encounters, the merchant,
## loot, curses...), act cards, souls, saving, the belt.


## Lights, props, explosive barrels, traps and the death dissolve.
func _test_world_objects(game: Game, world: World, player: Player) -> void:
	var torch := player.get_node("Torch") as LightSource
	check(torch.is_lit() and world.lights.level_at(player.global_position) >= torch.level, "the hero carries a torch")
	check(world.lights.ambient_level == world.theme.lighting.ambient_level, "the floor is as dark as its theme")
	check(get_tree().get_nodes_in_group("props").size() > 0, "the floor has props")
	var lanterns := get_tree().get_nodes_in_group("props").filter(func(p: Node) -> bool: return (p as Prop).def == CONTENT.dungeon.room_light)
	check(lanterns.size() >= world.map.rooms.size(), "every room has lanterns (%d)" % lanterns.size())
	var lantern := lanterns[0] as Prop
	check(world.lights.level_at(lantern.global_position) >= lantern.def.light_level, "a lantern lights its tile at its level")
	var flash_at := world.map.cell_to_world(_open_cell_near(world, player.global_position + Vector2(160, 0), 1))
	var before := world.lights.level_at(flash_at)
	world.flash_light(flash_at, Color.WHITE, 400.0)  # 10 levels above the floor's own light
	await _frames(1)
	check(world.lights.level_at(flash_at) >= mini(LightField.MAX_LEVEL, world.lights.ambient_level + 9), "a flash lights up the place")
	for i in 300:  # (hits on the hero meanwhile may freeze time a moment)
		if get_tree().get_nodes_in_group(LightSource.GROUP).all(func(n: Node) -> bool: return not n is LightFlash):
			break
		await _frames(1)
	check(get_tree().get_nodes_in_group(LightSource.GROUP).all(func(n: Node) -> bool: return not n is LightFlash), "...then fades")

	# A crate in front of the hero breaks under the katana.
	var crate_def: PropDef = load("res://data/props/crate.tres")
	var spot := world.map.world_to_cell(world.find_open_point_near(player.global_position, 40.0))
	var crate := world.spawn_prop(crate_def, spot)
	await _frames(1)
	# The nearest free cell may be a step away: stand right by it (from the side the hero came).
	var side := crate.global_position.direction_to(player.global_position)
	for i in crate_def.hits:
		if not is_instance_valid(crate) or crate.is_broken:
			break
		player.global_position = crate.global_position + side * 34.0
		player._attack_cooldown = 0.0
		player.attack(player.global_position.direction_to(crate.global_position))
		await _frames(4)
	check(not is_instance_valid(crate) or crate.is_broken, "a crate breaks after %d hits" % crate_def.hits)
	await _frames(5)

	# Powder kegs: one explodes, sets off its neighbour, hurts a monster nearby, credits the hero.
	var keg_def: PropDef = load("res://data/props/tnt.tres")
	var base := _open_cell_near(world, player.global_position + Vector2(120, 0), 2)  # room for both kegs and the rat
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
	# (A hit stop from an earlier blow may slow the first frames down: a little leeway.)
	for i in int(keg_def.fuse_time * 60.0) * 3:
		if not is_instance_valid(keg) or keg.is_broken:
			break
		await _frames(1)
	check(not is_instance_valid(keg) or keg.is_broken, "the keg explodes after its fuse")
	check(not is_instance_valid(rat) or rat.is_dead or rat.hp < rat_hp, "the blast hurts monsters")
	for i in int(keg_def.fuse_time * 60.0) * 3:
		if not is_instance_valid(keg2) or keg2.is_broken:
			break
		await _frames(1)
	check(not is_instance_valid(keg2) or keg2.is_broken, "explosions set off other kegs")
	await _frames(30)
	check(not is_instance_valid(rat), "dead monsters dissolve and disappear")

	# A spike trap hurts whoever stands on it, monsters included.
	var spikes: TrapDef = load("res://data/hazards/spikes.tres")
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
	var plate: TrapDef = load("res://data/hazards/spike_plate.tres")
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


## Holes, crumbling floor, quicksand, arrow traps, chests, elites, ambushes and how floors use them.
## The smith's forge: runes go into the worn weapon's sockets, come back out for gold.
func _test_forge(game: Game, world: World, player: Player) -> void:
	var worn := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	var ember: RuneDef = load("res://data/runes/ember.tres")
	var spark: RuneDef = load("res://data/runes/spark.tres")
	var bag := player.inventory.items.duplicate()  # an empty bag for the test (the bot's is put back)
	player.inventory.items.clear()
	player.inventory.add(ember)
	player.inventory.add(spark)
	var cell := world.map.world_to_cell(world.find_open_point_near(player.global_position + Vector2(90, 0), 40.0))
	var forge := world.spawn_forge(CONTENT.dungeon.forge, cell)
	await _frames(2)
	player.global_position = forge.global_position + Vector2(0, 30)
	await _frames(3)
	var panel := game.menus.forge
	check(panel.visible and get_tree().paused, "walking up to the smith opens the forge")
	var sockets := worn.socket_count()
	check(sockets >= 1, "a weapon has rune sockets (%d)" % sockets)
	var embers := player.inventory.count_of(ember)  # (the bot may have found some already)
	check(panel.set_rune(ember), "a rune goes into the weapon")
	var worked := player.equipment.get_item(EquipmentDef.Slot.WEAPON)
	check(worked.runes.has(ember) and player.inventory.count_of(ember) == embers - 1, "it is set, and gone from the bag")
	check(worked == worn or worked.base_item == (worn.base_item if worn.is_rolled() else worn), "...in the same weapon (a plain one becomes its own copy)")
	check(worn.is_rolled() or worn.runes.is_empty(), "the plain weapon itself stays bare")
	var burns := false
	for entry in player.perks._gear:
		for passive in entry.granted:
			burns = burns or passive is BurnOnHitPassive
	check(burns, "its power works while worn")
	for i in worked.free_sockets():
		player.inventory.add(spark)
		panel.set_rune(spark)
	check(worked.free_sockets() == 0 and not panel.set_rune(spark), "no rune past the last socket")
	player.gold = 0
	var index := worked.runes.find(ember)
	panel._select_socket(index)
	check(not panel.take_rune(), "taking a rune out costs gold")
	var price := forge.removal_cost()
	player.gold = price + 5
	check(panel.take_rune() and player.inventory.items.has(ember) and not worked.runes.has(ember), "paid: the rune comes back out, intact")
	check(player.gold == 5, "for its price (%d)" % price)
	var saved := LootRoller.from_data(LootRoller.to_data(worked)) as EquipmentDef
	check(saved.runes == worked.runes, "set runes are saved with the weapon")
	panel.close()
	await _frames(2)
	check(not get_tree().paused, "the game goes on when the forge closes")
	player.inventory.items.assign(bag)
	player.inventory.changed.emit()
	forge.queue_free()
	# Runes drop.
	var before := get_tree().get_nodes_in_group("pickups").filter(func(p: Node) -> bool: return (p as ItemPickup).item is RuneDef).size()
	world.drop_rune(player.global_position + Vector2(40, 0))
	await _frames(2)
	var after := get_tree().get_nodes_in_group("pickups").filter(func(p: Node) -> bool: return (p as ItemPickup).item is RuneDef).size()
	check(after == before + 1, "runes drop as pickups")
	for node in get_tree().get_nodes_in_group("pickups"):
		if (node as ItemPickup).item is RuneDef:
			node.queue_free()
	await _frames(1)


## How fights feel: what monsters are made of, chips left behind, the camera's kick, slow motion.
func _test_feel(_game: Game, world: World, player: Player) -> void:
	var rat: MonsterDef = load("res://data/monsters/rat.tres")
	check(rat.material != null and rat.material.sound != null, "monsters are made of something that sounds")
	var chips := world.debris_count()
	var monster := world.spawn_monster(rat, world.map.cell_to_world(_open_cell_near(world, player.global_position + Vector2(60, 0), 1)))
	monster.dormant = true
	await _frames(1)
	var hit := HitInfo.new()
	hit.source = player
	hit.amount = 9999
	hit.knockback = Vector2(200, 0)
	var xp_kept := player.xp
	player.xp = -1000000  # no level up (and its pause) from this kill
	monster.take_hit(hit)
	await _frames(2)
	player.xp = xp_kept
	check(world.debris_count() > chips, "a slain monster leaves chips of itself (%d)" % (world.debris_count() - chips))
	HitStop.reset()
	player.camera.kick(Vector2.RIGHT, 6.0)
	check(player.camera.kick_offset().x > 0.0, "the camera leans with a blow")
	await _frames(30)
	check(player.camera.kick_offset() == Vector2.ZERO, "...and springs back")
	# A hit lands during physics: its freeze must hold on the next frames.
	await get_tree().physics_frame
	HitStop.freeze(0.1)
	await get_tree().process_frame
	await get_tree().process_frame
	check(Engine.time_scale < 1.0, "a freeze asked during physics holds")
	HitStop.reset()
	var wall_point := world.map.cell_to_world(Vector2i.ZERO)
	check(world.is_free_cell(world.map.world_to_cell(world.nearest_free_point(player.global_position))), "after a fall the hero climbs out on free floor")
	check(world.nearest_free_point(wall_point) != wall_point or not world.map.is_floor(Vector2i.ZERO), "...even when the ground gave way")
	HitStop.slow(0.2, 0.5)
	check(is_equal_approx(Engine.time_scale, 0.5), "a strong kill slows the world")
	HitStop.reset()
	check(Engine.time_scale == 1.0, "...for a moment")


func _test_hazards(game: Game, world: World, player: Player) -> void:
	var pit: PitDef = load("res://data/hazards/pit.tres")
	var slime_def: MonsterDef = load("res://data/monsters/slime.tres")
	# Tough hero (hazards still do 1 damage), and the floor's own ambush out of the way.
	var defense_saved := player.base_stats.defense
	player.base_stats.defense = 999
	player.invalidate_stats()
	if world.ambush:
		world.ambush.queue_free()
		world.ambush = null
	player.hp = player.get_max_hp()
	var xp_saved := player.xp
	player.xp = -1000000  # no level up (and its pause) in the middle of this

	# A monster knocked into a hole is gone, and the hero gets the XP.
	var hole := _open_cell_near(world, player.global_position, 3)
	world.add_pit(hole, pit)
	check(world.has_pit(hole) and world.pit_under(world.map.cell_to_world(hole)) == pit, "a hole is a hole")
	check(world.pit_under(world.map.cell_to_world(hole) + Vector2(-14, 0)) == null, "the edge of a hole is forgiven")
	var slime := world.spawn_monster(slime_def, world.map.cell_to_world(hole + Vector2i.LEFT))
	slime.dormant = true
	slime.move_direction = Vector2.RIGHT
	check(slime._avoid_holes(Vector2.RIGHT) != Vector2.RIGHT, "walking monsters don't step into holes")
	slime.move_direction = Vector2.ZERO
	var xp_before := player.xp
	var push := Combat.make_hit(1, 0.0, player)
	push.knockback = Vector2.RIGHT * 700.0
	slime.take_hit(push)
	await _frames(45)
	check(not is_instance_valid(slime) or slime.is_dead, "a monster knocked into a hole falls")
	check(player.xp > xp_before, "the hero gets the XP of what they pushed in")
	var bat := world.spawn_monster(load("res://data/monsters/bat.tres"), world.map.cell_to_world(hole))
	bat.dormant = true
	await _frames(40)
	check(is_instance_valid(bat) and not bat.is_dead and not bat.is_falling, "flying monsters don't fall")
	bat.queue_free()

	# The hero falls too, and climbs back out where they last stood, hurt.
	var safe := world.map.cell_to_world(hole + Vector2i.LEFT * 2)
	player.global_position = safe
	await _frames(3)
	player._invulnerable_time = 0.0
	var hp_before := player.hp
	player.global_position = world.map.cell_to_world(hole)
	await _frames(3)
	check(player.is_falling, "the hero falls into a hole")
	await _frames(int(Actor.FALL_TIME * 60.0) + 6)
	check(not player.is_falling and player.global_position.distance_to(safe) < 24.0, "the hero climbs out where they stood")
	check(player.hp < hp_before and player.rig.scale == Vector2.ONE, "falling hurts")
	player.global_position = world.map.cell_to_world(hole)
	player.start_dash(Vector2.RIGHT * 10.0, 0.3, true)
	await _frames(5)
	check(not player.is_falling, "rolling carries you over a hole")
	player.global_position = safe
	await _frames(25)

	# Cracked floor gives way under your feet.
	var crumbling: PitDef = load("res://data/hazards/crumbling_floor.tres")
	var cracked := _open_cell_near(world, player.global_position, 2)
	var tile := world.spawn_crumbling_floor(crumbling, cracked)
	check(not world.is_solid_ground(world.map.cell_to_world(cracked)), "cracked floor is no safe ground")
	await _frames(30)
	check(not world.has_pit(cracked), "cracked floor holds while nobody is on it")
	player._invulnerable_time = 0.0
	player.global_position = world.map.cell_to_world(cracked)
	await _frames(int(crumbling.crumble_time * 60.0) + 4)
	check(world.has_pit(cracked) and not is_instance_valid(tile), "cracked floor gives way")
	await _frames(int(Actor.FALL_TIME * 60.0) + 10)
	check(not player.is_falling and world.is_solid_ground(player.global_position), "and the hero falls through")
	player.hp = player.get_max_hp()

	# Quicksand slows whoever wades in, then swallows them.
	var sand: QuicksandDef = load("res://data/hazards/quicksand.tres")
	var pool_cell := _open_cell_near(world, player.global_position, 2)
	var pool := world.spawn_quicksand(sand, Rect2i(pool_cell, Vector2i(2, 2)))
	var wader := world.spawn_monster(slime_def, pool.global_position)
	wader.dormant = true
	await _frames(5)
	check(wader.statuses.is_slowed(), "quicksand slows monsters down")
	var wader_hp := wader.hp
	var wading_at := wader.global_position
	for i in int((sand.sink_delay + 0.3) * 60.0):
		if is_instance_valid(wader):
			wader.global_position = wading_at  # (nudged out by a neighbour, it would stop sinking)
		await _frames(1)
	check(not is_instance_valid(wader) or wader.hp < wader_hp, "staying in quicksand hurts")
	var flyer := world.spawn_monster(load("res://data/monsters/bat.tres"), pool.global_position)
	flyer.dormant = true
	await _frames(5)
	check(not flyer.statuses.is_slowed(), "flying monsters skim over quicksand")
	for node: Node in [wader, flyer, pool]:
		if is_instance_valid(node):
			node.queue_free()

	# Arrow traps: the slit is in a wall, a plate shoots arrows across the room. Monsters set them off too.
	var arrows: ArrowTrapDef = load("res://data/hazards/arrow_trap.tres")
	var placed: Trap
	for room in world.map.rooms:
		var before := get_tree().get_nodes_in_group("traps")
		arrows.place(world, room, {})
		for node in get_tree().get_nodes_in_group("traps"):
			if not before.has(node):
				placed = node
		if placed:
			break
	check(placed != null and not world.map.is_floor(placed.launcher_cell) and placed.launcher_direction != Vector2.ZERO, "an arrow trap's slit is in a wall")
	if placed:
		placed.queue_free()
	# Nobody else around to step into the line of fire.
	await _clear_monsters(world)
	var plate_cell := _open_cell_near(world, player.global_position, 3)
	var arrow_trap := world.spawn_trap(arrows, plate_cell)
	arrow_trap.set_launcher(plate_cell + Vector2i.UP * 3, Vector2.DOWN)
	player.global_position = world.map.cell_to_world(plate_cell + Vector2i.RIGHT * 3)  # out of the line of fire
	var target := world.spawn_monster(slime_def, arrow_trap.global_position)
	target.dormant = true
	var target_hp := target.hp
	await _frames(int((arrows.warning_time + 0.2) * 60.0) + 40)
	check(not is_instance_valid(target) or target.hp < target_hp, "monsters on the plate get shot")
	if is_instance_valid(target):
		target.queue_free()
	arrow_trap.queue_free()

	# Chests spill items; trapped ones bite.
	var chest_def: ChestDef = CONTENT.dungeon.chest
	var bag_saved := player.inventory.items.duplicate()
	var chest_cell := _open_cell_near(world, player.global_position, 2)
	var chest := world.spawn_chest(chest_def, chest_cell, false)
	await _frames(2)
	check(not chest.is_open, "a chest stays shut until the hero comes")
	var loot_before := get_tree().get_nodes_in_group("pickups").size()
	chest.open()
	await _frames(2)
	check(get_tree().get_nodes_in_group("pickups").size() > loot_before, "a chest gives items")
	var trap_cell := _open_cell_near(world, player.global_position, 2)
	var monsters_before := world.monster_count()
	var trapped := world.spawn_chest(chest_def, trap_cell, true)
	player.global_position = world.map.cell_to_world(trap_cell + Vector2i.DOWN)
	await _frames(4)
	check(trapped.is_open, "walking up to a chest opens it")
	check(trapped.is_open and (trapped._fuse >= 0.0 or world.monster_count() > monsters_before), "a trapped chest springs its trap")
	await _frames(int(chest_def.fuse_time * 60.0) + 5)
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		if monster.global_position.distance_to(trapped.global_position) < 90.0:
			monster.queue_free()
	player.hp = player.get_max_hp()
	player.inventory.items = bag_saved
	player.inventory.changed.emit()
	await _frames(2)

	# Elites: an affix, more HP, a name, bigger, and their perk works.
	var elite := world.spawn_monster(slime_def, world.map.cell_to_world(_open_cell_near(world, player.global_position, 1)))
	elite.dormant = true
	var base_hp := elite.get_max_hp()
	var base_damage := elite._damage_multiplier
	var vampiric: EliteAffixDef = load("res://data/elites/vampiric.tres")
	elite.make_elite(vampiric, CONTENT.dungeon)
	check(elite.is_elite() and elite.get_max_hp() == roundi(base_hp * CONTENT.dungeon.elite_rank.hp_multiplier_at(world.depth) * vampiric.hp_multiplier), "elites are tougher (the rank's health at this depth)")
	check(is_equal_approx(elite._damage_multiplier, base_damage * CONTENT.dungeon.elite_rank.damage_multiplier), "elites hit harder")
	# Rarer ranks: Epic (2 affixes), Legendary (3), Shiny (other colors, a treasure).
	var ranked: Array[Monster] = []
	for rank in CONTENT.dungeon.rare_ranks:
		var rare := world.spawn_monster(load("res://data/monsters/skeleton.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 1)))
		rare.dormant = true
		world.make_ranked(rare, rank)
		ranked.append(rare)
		var names := {}
		for affix in rare.affixes:
			names[affix] = true
		check(rare.rank == rank and rare.affixes.size() == rank.affixes and names.size() == rank.affixes, "%s: %d different affixes" % [rank.id, rank.affixes])
		check(rare.display_name.begins_with(rank.display_name) and rare.get_max_hp() > base_hp, "%s: its name and toughness (%s)" % [rank.id, rare.display_name])
		if rank.hue_shift > 0.0:
			var look := rare.rig.visual.material as ShaderMaterial
			check(is_equal_approx(float(look.get_shader_parameter("hue_shift")), rank.hue_shift), "a Shiny has other colors")
	var by_id := {}
	for rare in ranked:
		by_id[rare.rank.id] = rare.rank
	check(by_id[&"legendary"].hp_multiplier > by_id[&"epic"].hp_multiplier and by_id[&"legendary"].loot_quality > by_id[&"epic"].loot_quality, "a Legendary is tougher and richer than an Epic")
	var shiny_mob: Monster = ranked.filter(func(m: Monster) -> bool: return m.rank.shimmer)[0]
	Profile.shinies = {}
	var xp_kept := player.xp
	player.xp = -1000000  # no level up (and its pause) from this kill
	var shiny_kill := HitInfo.new()
	shiny_kill.amount = 999999
	shiny_kill.source = player
	shiny_mob.take_hit(shiny_kill)
	await _frames(2)
	check(Profile.has_shiny(&"skeleton"), "a Shiny slain joins the bestiary's collection")
	player.xp = xp_kept
	for rare in ranked:
		if is_instance_valid(rare) and not rare.is_dead:
			rare.queue_free()
	check(elite.display_name.begins_with("Vampiric") and elite.rig.scale.x > 1.0, "elites have a name and are bigger")
	elite.hp = 1
	elite.perks.on_hit_dealt(elite, player, HitInfo.new(), 10)
	check(elite.hp > 1, "vampiric elites heal when they hit")
	var explosive: Monster = world.spawn_monster(slime_def, world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	explosive.dormant = true
	explosive.make_elite(load("res://data/elites/explosive.tres"), CONTENT.dungeon)
	var neighbour := world.spawn_monster(slime_def, explosive.global_position + Vector2(20, 0))
	neighbour.dormant = true
	var neighbour_hp := neighbour.hp
	var items_before := get_tree().get_nodes_in_group("pickups").size()
	var guaranteed_drops: int = explosive._bonus_drops
	explosive.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(90)  # its fuse, and the slow motion of a strong kill
	check(not is_instance_valid(neighbour) or neighbour.hp < neighbour_hp, "explosive elites blow up when they die")
	# (The hero may pick some up meanwhile: no fewer items, and a guaranteed drop.)
	check(guaranteed_drops >= 1 and get_tree().get_nodes_in_group("pickups").size() >= items_before, "elites always drop loot")
	if is_instance_valid(elite):
		elite.queue_free()
	if is_instance_valid(neighbour):
		neighbour.queue_free()
	var chances := 0
	for i in 400:
		var rolled := world.spawn_monster(slime_def, world.find_open_point_near(player.global_position, 300.0))
		world.roll_elite(rolled)
		chances += 1 if rolled.is_elite() else 0
		rolled.free()
	check(chances > 0 and chances < 200, "some monsters roll to be elites (%d / 400)" % chances)

	# Ambush: walking in closes the exits, waves come (the last with an elite), clearing opens it.
	var room_index := -1
	for i in range(1, world.map.rooms.size()):
		var r := world.map.rooms[i]
		if r.size.x >= 7 and r.size.y >= 7 and (world.ambush == null or world.ambush.room != r) and not world.map.exit_cells().any(func(c: Vector2i) -> bool: return r.grow(1).has_point(c)):
			room_index = i
			break
	if room_index >= 0:
		var room := world.map.rooms[room_index]
		var started := [0]
		var on_start := func(_r: AmbushRoom) -> void: started[0] += 1
		Events.ambush_started.connect(on_start)
		var ambush := world.spawn_ambush(room)
		var elites_seen := [0]
		var on_kill := func(m: Monster) -> void: elites_seen[0] += 1 if m.is_elite() else 0
		Events.monster_killed.connect(on_kill)
		player.global_position = _solid_point_in(world, room.grow(-2))
		await _frames(3)
		check(ambush.state == AmbushRoom.State.FIGHTING and ambush.is_closed() and started[0] == 1, "walking into an ambush closes the exits")
		check(game.hud._depth_banner.text == "Ambush!", "the HUD announces the ambush")
		for frame in 60 * 20:
			if ambush.state == AmbushRoom.State.CLEARED:
				break
			for monster in world.get_hostiles(Actor.Faction.PLAYER):
				if room.grow(1).has_point(world.map.world_to_cell(monster.global_position)) and not monster.is_falling:
					monster.take_hit(Combat.make_secondary_hit(player, 99999))
			await get_tree().physics_frame
		check(ambush.state == AmbushRoom.State.CLEARED and not ambush.is_closed(), "clearing the waves opens the exits")
		check(elites_seen[0] >= 1, "the last wave is led by an elite")
		var reward := get_tree().get_nodes_in_group("chests").filter(func(c: Node) -> bool: return (c as Chest).def == CONTENT.dungeon.ambush_chest and room.has_point(world.map.world_to_cell(c.global_position)))
		check(reward.size() == 1 and (reward[0] as Chest).def == CONTENT.dungeon.ambush_chest, "a big chest rewards the survivor (%d there, %d chests)" % [reward.size(), get_tree().get_nodes_in_group("chests").size()])
		Events.ambush_started.disconnect(on_start)
		Events.monster_killed.disconnect(on_kill)

	# Real floors: hazards everywhere, but the stairs can always be reached.
	CONTENT.dungeon.merchant_chance = 1.0
	CONTENT.dungeon.encounters_max = 2
	CONTENT.dungeon.encounters_min = 2
	var merchants := 0
	var encounters := 0
	var hazard_total := 0
	for depth in [1, 2, 4, 5, 7, 8]:
		world.build_floor(depth, CONTENT)
		merchants += get_tree().get_nodes_in_group("merchants").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
		encounters += get_tree().get_nodes_in_group("encounters").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).size()
		var start := world.map.cell_to_world(world.map.start_cell)
		check(not world.find_path(start, world.map.cell_to_world(world.map.stairs_cell)).is_empty(), "depth %d: the stairs can be reached" % depth)
		var count := get_tree().get_nodes_in_group("traps").size() + get_tree().get_nodes_in_group("crumbling_floors").size() \
			+ get_tree().get_nodes_in_group("quicksand").size() + world._pits.cells().size()
		hazard_total += count
	check(hazard_total >= 12, "floors have hazards (%d on 6 floors)" % hazard_total)
	check(merchants >= 4 and encounters >= 6, "floors get merchants and encounters (%d, %d)" % [merchants, encounters])
	CONTENT.dungeon.merchant_chance = 0.0
	CONTENT.dungeon.encounters_max = 0
	CONTENT.dungeon.encounters_min = 0
	world.build_floor(game.depth, CONTENT)
	world.place_player(player)
	player.base_stats.defense = defense_saved
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.xp = xp_saved
	await _frames(5)


## A new act begins with its title card, on black, game paused. A tap skips it.
func _test_act_card(game: Game) -> void:
	game.show_act_cards = true
	game.depth = 3  # _descend goes one floor down: the first floor of act II
	game._descend()
	await _frames(int(game.FADE_TIME * 60.0) + 40)
	var card: ActCard = game.act_card
	var act: ActDef = CONTENT.dungeon.act_for_depth(4)
	check(card.visible and (card.get_node("%Title") as Label).text == act.title, "a new act shows its card")
	check((card.get_node("%Lore") as Label).text == act.lore and get_tree().paused, "with its story, game paused")
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	Input.parse_input_event(tap)
	await _frames(int(ActCard.FADE_TIME * 60.0) + 10)
	check(not card.visible and not get_tree().paused, "a tap skips the card")
	game.show_act_cards = false
	await _frames(20)


## Kills set souls free: they fly into the hero's lantern and the HUD counts them.
func _test_souls(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.xp = -1000000  # no level up (and its pause) from this kill
	var monster := world.spawn_monster(load("res://data/monsters/slime.tres"), world.find_open_point_near(player.global_position, 100.0))
	monster.dormant = true
	var gathered := [0]
	var on_soul := func() -> void: gathered[0] += 1
	Events.soul_gathered.connect(on_soul)
	monster.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	check(world.get_node("Effects").get_children().any(func(n: Node) -> bool: return n is SoulWisp), "a kill sets a soul free")
	await _frames(90)
	check(gathered[0] >= 1, "the soul reaches the hero's lantern")
	var shown := int((game.hud.get_node("%SoulsLabel") as Label).text.trim_prefix("Souls "))
	check(shown > 0 and shown <= game.run_souls(), "the HUD counts the run's souls")
	Events.soul_gathered.disconnect(on_soul)


## A floor's stairs stay sealed until enough of its monsters are slain; then a light runs to
## them and the minimap shows them.
func _test_stairs_seal(game: Game) -> void:
	await game.debug_enter_floor(2)
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	var seal := world.seal
	var monsters := world.monster_count()
	check(seal.is_sealed() and seal.needed == ceili(monsters * CONTENT.dungeon.seal_share), "a new floor's stairs are sealed (%d of %d monsters)" % [seal.needed, monsters])
	var label: Label = game.hud.get_node("%SealLabel")
	check(label.visible and label.text.ends_with("0 / %d" % seal.needed), "the HUD shows what the seal wants (%s)" % label.text)
	var logged: Array[String] = []
	var on_log := func(text: String, _color: Color) -> void: logged.append(text)
	Events.message_logged.connect(on_log)
	var depth := game.depth
	world._blocked_note_at = -10.0  # (the bot may have bumped into them a moment ago: no repeat then)
	player.global_position = world.map.cell_to_world(world.map.stairs_cell)
	await _frames(int(game.FADE_TIME * 60.0) + 12)
	check(game.depth == depth and not game._transitioning, "sealed stairs don't lead down")
	check(logged.any(func(text: String) -> bool: return text.contains("Slay %d more" % seal.needed)), "stepping on them says what is missing (%s)" % str(logged))
	player.global_position = world.map.cell_to_world(world.map.start_cell)
	await _frames(3)

	player.xp = -1000000  # no level up (and its pause) from these kills
	while seal.left() > seal.reveal_left:
		_kill_one(world, player)
		await _frames(1)
	check(seal.reveals_monsters(), "the last kills show the monsters left on the minimap")
	check(label.text.ends_with("%d / %d" % [seal.kills, seal.needed]), "the HUD counts the kills")
	while seal.is_sealed() and world.monster_count() > 0:
		_kill_one(world, player)
		await _frames(1)
	check(not seal.is_sealed(), "enough kills break the seal")
	check(label.text == "Stairs open", "the HUD says the stairs are open")
	check(world.get_node("Effects").get_children().any(func(n: Node) -> bool: return n is GuideWisp), "a guiding light runs to the stairs")
	Events.message_logged.disconnect(on_log)


## Two ways down: each stairs leads to a different world of the next floor (FloorRoute), its sign
## says which; the way taken builds the next floor and is kept in the save.
func _test_routes(game: Game) -> void:
	game.run.routes.clear()
	await game.debug_enter_floor(1)
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	check(world.next_routes.size() == 2, "floor 1 offers two ways down (%d)" % world.next_routes.size())
	if world.next_routes.size() < 2:
		return
	check(world.next_routes[0].biome != world.next_routes[1].biome, "to two different worlds")
	check(world.map.second_stairs_cell != DungeonMap.NO_CELL and world.stairs_cells.size() == 2, "two stairs on the floor")
	var stairs := world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Stairs)
	check(stairs.size() == 2 and stairs.all(func(n: Node) -> bool: return (n as Stairs).route != null and n.get_children().any(func(c: Node) -> bool: return c is StairsSign)), "each with its sign")
	var again := FloorRoute.offer(CONTENT, 2, game.difficulty, game.run.route_seed(2))
	check(again.size() == 2 and again[1].biome == world.next_routes[1].biome and again[1].curse == world.next_routes[1].curse and again[1].floor_event == world.next_routes[1].floor_event, "the same run offers the same ways")
	var wanted: FloorRoute = world.next_routes[1]
	player.xp = -1000000
	while world.seal.is_sealed() and world.monster_count() > 0:
		_kill_one(world, player)
		await _frames(1)
	await _frames(2)
	player.global_position = world.map.cell_to_world(world.map.second_stairs_cell)
	for i in 600:
		await _frames(1)
		if game.depth == 2 and not game._transitioning:
			break
	check(game.depth == 2 and int(game.run.routes.get(2, -1)) == 1, "the second stairs lead down the second way")
	world = game.world
	check(world.biome == wanted.biome and world.curse == wanted.curse and world.floor_event == wanted.floor_event, "floor 2 is what its sign said (%s)" % wanted.summary())
	check(world.next_routes.is_empty() and world.stairs_cells.size() == 1, "before a boss: one way only")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(game.run.to_data()))
	var back := RunState.create(CONTENT, saved, RandomNumberGenerator.new())
	check(int(back.routes.get(2, -1)) == 1, "the way taken is kept in the save")
	check(game._route_to(2).biome == wanted.biome, "and a resumed run rebuilds the same floor")


## The Tree of Souls in a run: Regeneration, the Cartographer, the Trophy Hunter, the merchant.
func _test_soul_tree_run(game: Game) -> void:
	var saved_levels := Profile.levels.duplicate()
	Profile.levels = { "regeneration": 2, "cartographer": 1, "trophy_hunter": 1, "haggler": 1, "full_stalls": 1 }
	var boons := RunBoons.build(CONTENT)
	game.world.boons = boons
	await game.debug_enter_floor(2)
	await _frames(3)
	var world: World = game.world
	var player: Player = game.player
	check(world.stairs_cells.all(func(c: Vector2i) -> bool: return world.is_explored(c)), "Cartographer: the stairs are on the minimap from the start")
	player.hp = 10
	world.reward_clear()
	check(player.hp == 10 + roundi(player.get_max_hp() * 0.1) or player.hp == player.get_max_hp(), "Regeneration: a floor won heals 10%% at level 2 (%d)" % player.hp)
	var count_gear := func() -> int:
		return world.get_node("Entities").get_children().filter(func(n: Node) -> bool:
			return n is ItemPickup and (n as ItemPickup).item is EquipmentDef and ((n as ItemPickup).item as EquipmentDef).rarity >= ItemRarity.MAGIC).size()
	var before: int = count_gear.call()
	var elite := world.spawn_monster(load("res://data/monsters/rat.tres"), world.find_open_point_near(player.global_position + Vector2(90, 0), 40.0))
	elite.make_elite(CONTENT.elite_affixes[0], CONTENT.dungeon)
	elite.dormant = true
	await _frames(1)
	elite.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(3)
	check(count_gear.call() > before, "Trophy Hunter: an elite drops Magic gear")
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, world.map.world_to_cell(player.global_position) + Vector2i(3, 0))
	await _frames(1)
	var equipment := merchant.stock.filter(func(e: Dictionary) -> bool: return e.item is EquipmentDef)
	check(equipment.size() == CONTENT.dungeon.merchant.equipment_count + 2, "Full Stalls: two more pieces for sale (%d)" % equipment.size())
	var full_price := CONTENT.dungeon.merchant.buy_price(equipment[0].item, world.depth, world.rules.shop_prices())
	check(int(equipment[0].price) < full_price, "Haggler: lower prices (%d < %d)" % [int(equipment[0].price), full_price])
	merchant.queue_free()
	Profile.levels = saved_levels
	game.world.boons = RunBoons.new()
	await _clear_monsters(world)


## A status shows on the body: flames on a burning monster, its ticks in the fire's color.
func _test_status_looks(game: Game) -> void:
	var world: World = game.world
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), world.find_open_point_near(game.player.global_position + Vector2(80, 0), 40.0))
	rat.dormant = true
	rat.base_stats.max_hp = 9999
	rat.invalidate_stats()
	rat.hp = 9999
	rat.statuses.clear()  # (the floor may have slowed it: quicksand, the cold)
	await _frames(2)
	check(rat.status_fx != null and not rat.status_fx.visible, "a body with no status shows nothing over it")
	rat.statuses.apply_slow(0.5, 1.0, StatusSet.GROUND_SLOW)
	check(not rat.statuses.active_ids().has(&"slow"), "sinking in quicksand is no frost to show")
	rat.statuses.clear()
	var colors: Array[Color] = []
	var on_text := func(text: Node) -> void:
		if text is FloatingText:
			colors.append((text as FloatingText)._color)
	world.get_node("Effects").child_entered_tree.connect(on_text)
	rat.statuses.apply_dot(&"burn", 2, 0.5, 3.0, game.player, Palette.FIRE)
	await _frames(45)
	check(rat.status_fx.visible and rat.status_fx._bits.size() > 0, "a burning monster is on fire (%d flames)" % rat.status_fx._bits.size())
	var burn: StatusLookDef = StatusFx.LOOKS.look(&"burn")
	check(burn != null and StatusFx.LOOKS.look(&"poison") != null and StatusFx.LOOKS.look(&"slow") != null, "burn, poison and frost each have a look")
	check(colors.has(Palette.FIRE), "its burn damage shows in the fire's color")
	world.get_node("Effects").child_entered_tree.disconnect(on_text)
	rat.statuses.clear()
	await _frames(60)
	check(not rat.status_fx.visible and not rat.status_fx.is_processing(), "the fire out, the flames die down and it sleeps again")
	rat.queue_free()


func _kill_one(world: World, player: Player) -> void:
	for monster: Actor in world.get_hostiles(Actor.Faction.PLAYER):
		if not monster.is_dead:
			monster.take_hit(Combat.make_secondary_hit(player, 99999))
			return


## Pause menu, options, vibrations (no-op here), the minimap and the back button.
func _test_comfort(game: Game) -> void:
	var world: World = game.world
	var hud: Hud = game.hud
	(hud.get_node("%PauseButton") as Button).pressed.emit()
	await _frames(1)
	var pause: PauseMenu = game.pause_menu
	check(pause.visible and get_tree().paused, "the pause button pauses the game")
	# The bestiary from the pause menu: a page and its attack preview run while paused.
	(pause.get_node("%BestiaryButton") as Button).pressed.emit()
	var paused_codex: CodexPanel = pause.get_node("%CodexPanel")
	check(paused_codex.visible, "the bestiary opens from the pause menu")
	Profile.record_kill(&"skeleton")
	paused_codex.open_monster(load("res://data/monsters/skeleton.tres"))
	await _frames(3)
	var preview: AttackPreview = null
	var stack: Array[Node] = [paused_codex]
	while not stack.is_empty() and preview == null:
		var node: Node = stack.pop_back()
		if node is AttackPreview:
			preview = node
		stack.append_array(node.get_children())
	var before_time: float = preview._time if preview else 0.0
	await _frames(20)
	check(preview != null and preview._time > before_time, "the attack preview plays while the game is paused")
	game._back()
	game._back()
	check(not paused_codex.visible and pause.visible, "back closes the page, then the bestiary")
	(pause.get_node("%OptionsButton") as Button).pressed.emit()
	var options: OptionsPanel = pause.get_node("%OptionsPanel")
	check(options.visible, "options open from the pause menu")
	(options.get_node("%MusicSlider") as HSlider).value = 0.5
	check(is_equal_approx(Settings.music_volume, 0.5) and absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")) - linear_to_db(0.5)) < 0.01, "the music slider sets the music volume")
	(options.get_node("%ControlsSlider") as HSlider).value = 1.2
	check(is_equal_approx((hud.get_node("%Controls") as Control).scale.x, 1.2), "the buttons size option scales the controls")
	var battery: CheckButton = options.get_node("%BatteryCheck")
	battery.button_pressed = true
	check(Settings.battery_saver and Engine.max_fps == Settings.SAVER_FPS, "the battery saver caps the frame rate")
	battery.button_pressed = false
	check(Engine.max_fps == Settings.FPS, "and lifts it again")
	(options.get_node("%FewerEffectsCheck") as CheckButton).button_pressed = true
	Vfx.burst(world, Vfx.SPARKLES, game.player.global_position)
	var effects := world.get_node("Effects")
	var burst := effects.get_child(effects.get_child_count() - 1) as CPUParticles2D
	check(Settings.fewer_effects and burst.amount == maxi(1, (Vfx.SPARKLES.instantiate() as CPUParticles2D).amount / 2), "fewer effects: half the particles")
	(options.get_node("%FewerEffectsCheck") as CheckButton).button_pressed = false
	Settings.vibrate(1.0)  # must not fail on a computer
	game._back()
	check(not options.visible and pause.visible, "back closes the options first")
	var give_up: Button = pause.get_node("%AbandonButton")
	give_up.pressed.emit()
	check(not game.player.is_dead and give_up.text == PauseMenu.CONFIRM_TEXT, "giving up asks to confirm")
	game._back()
	await _frames(1)
	check(not pause.visible and not get_tree().paused, "back resumes the game")
	game._back()
	check(pause.visible, "back pauses the game")
	(pause.get_node("%ResumeButton") as Button).pressed.emit()
	await _frames(1)
	Settings.set_option(&"music_volume", 0.8)
	Settings.set_option(&"controls_scale", 1.0)

	# The minimap: the start room is known, walking reveals more, a tap shows the whole floor.
	check(world.is_explored(world.map.world_to_cell(game.player.global_position)), "the hero's surroundings are explored")
	var minimap: Minimap = hud.get_node("%Minimap")
	var full_map: Minimap = hud.get_node("%FullMap")
	check(minimap._texture != null and minimap._image.get_width() == world.map.width, "the minimap draws the floor")
	var seen := Array(world.fog.explored).count(1)
	var far_room := world.map.rooms.filter(func(r: Rect2i) -> bool:
		return not r.grow(1).has_point(world.map.stairs_cell) and not r.has_point(world.map.world_to_cell(game.player.global_position))).back() as Rect2i
	var depth_now: int = game.depth
	game.player.global_position = _solid_point_in(world, far_room.grow(-1))
	await _frames(3)
	check(Array(world.fog.explored).count(1) > seen and world.is_explored(far_room.get_center()), "exploring reveals the map")
	check(game.depth == depth_now, "(still on the same floor)")
	minimap.tapped.emit()
	check(full_map.visible, "tapping the minimap shows the whole floor")
	full_map.tapped.emit()
	check(not full_map.visible, "tapping again closes it")
	game.player.xp = 0


## Potions live on the belt, not in the bag. Bosses can't be juggled.
func _test_belt_and_balance(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var potion: ConsumableDef = load("res://data/items/consumables/health_potion.tres")
	var bomb: ConsumableDef = load("res://data/items/consumables/bomb.tres")
	var haste: ConsumableDef = load("res://data/items/consumables/haste_draught.tres")
	var rage: ConsumableDef = load("res://data/items/consumables/rage_elixir.tres")
	var saved_belt := player.belt.to_data()
	var saved_bag := player.inventory.items.duplicate()
	player.belt.load_data([])
	player.inventory.items.clear()
	for i in Belt.MAX_STACK + 1:
		player.pick_up(potion)
	check(player.belt.count_at(0) == Belt.MAX_STACK and player.belt.count_at(1) == 1, "potions stack on the belt (%d a slot)" % Belt.MAX_STACK)
	check(player.inventory.items.is_empty(), "they take no room in the bag")
	player.pick_up(bomb)
	player.pick_up(haste)
	check(player.belt.item_at(2) == bomb and player.inventory.items.size() == 1 and player.inventory.items[0] == haste, "a full belt sends the rest to the bag")
	await _frames(2)
	var buttons: Array = [game.hud.get_node("%QuickItemButton"), game.hud.get_node("%Belt2Button"), game.hud.get_node("%Belt3Button")]
	check(buttons.all(func(b: ActionButton) -> bool: return b.visible) and (buttons[0] as ActionButton).counter == Belt.MAX_STACK, "one button per belt slot, with its count")
	player.hp = 1
	player.use_belt(0)
	check(player.hp > 1 and player.belt.count_at(0) == Belt.MAX_STACK - 1, "a belt button uses its potion")
	var bombs_before := player.belt.count_of(bomb)
	player.use_belt(2)
	check(player.belt.item_at(2) == null and bombs_before == 1, "the last one empties the slot")
	check(player.move_to_belt(haste) and player.belt.item_at(2) == haste and player.inventory.items.is_empty(), "a consumable moves from the bag to the belt")
	check(player.move_to_bag(2) and player.inventory.items.has(haste), "and back")
	var data := player.save_state()
	var copy := player.belt.to_data()
	player.belt.load_data([])
	player.belt.load_data(JSON.parse_string(JSON.stringify(data.belt)))
	check(player.belt.to_data() == copy, "the belt is saved with the run")
	# The inventory screen shows the belt.
	game.open_inventory()
	var panel: InventoryPanel = game.inventory_panel
	panel._select_belt(0)
	check((panel.get_node("%BeltSlot1") as ItemSlot).count == player.belt.count_at(0) and panel.get_node("%BeltButton").visible, "the bag screen shows the belt")
	panel.close()
	await _frames(1)
	player.pick_up(rage)
	player.belt.load_data(saved_belt)
	player.inventory.items = saved_bag

	# Bosses stand their ground; elites and big monsters resist. (One at a time: they would push
	# each other.)
	var moved := []
	for path in ["res://data/monsters/bosses/king_slime.tres", "res://data/monsters/slime.tres"]:
		var monster := world.spawn_monster(load(path), world.map.cell_to_world(_open_cell_near(world, player.global_position, 3)))
		monster.dormant = true
		await _frames(2)
		var start := monster.global_position
		var shove := Combat.make_secondary_hit(null, 1)
		shove.knockback = Vector2.RIGHT * 600.0
		monster.take_hit(shove)
		await _frames(20)
		moved.append(monster.global_position.distance_to(start))
		if monster.is_boss():
			check(monster.get_max_hp() >= 800, "bosses are tough (%d HP)" % monster.get_max_hp())
		monster.queue_free()
		await _frames(2)
	check(moved[0] < 8.0 and moved[1] > 20.0, "bosses barely move when hit (%.1f vs %.1f)" % moved)
	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 3)))
	world.make_elite(slime)
	check(slime.get_knockback_resistance() >= 0.5, "elites resist knockback")
	slime.queue_free()
	await _frames(2)


## Frozen floors and campfires, scorching ground, dark rooms, and no bag full of potions.
func _test_climate(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var frostbound: CurseDef = load("res://data/curses/frostbound.tres")
	var ashen: CurseDef = load("res://data/curses/ashen_breath.tres")
	var lanternless: CurseDef = load("res://data/curses/lanternless.tres")
	var campfire: HeatSourceDef = load("res://data/hazards/campfire.tres")
	var oasis: HeatSourceDef = load("res://data/hazards/oasis.tres")
	check(CONTENT.curses.has(frostbound) and CONTENT.curses.has(ashen) and CONTENT.curses.has(lanternless), "three curses: frozen, burning, lightless")
	var start_depth: int = game.depth
	var saved_curses := CONTENT.curses.duplicate()
	var difficulty: DifficultyDef = world.difficulty
	var saved_chance := difficulty.curse_chance

	# The first floor is never cursed.
	difficulty.curse_chance = 1.0
	game.depth = 1
	game._enter_floor()
	await _frames(3)
	check(world.curse == null, "never on the first floor")

	# Frostbound: the whole floor is ice; the cold creeps in, slows, then hurts.
	CONTENT.curses = [frostbound]
	game.depth = 2
	game._enter_floor()
	await _frames(3)
	check(world.curse == frostbound and world.floor_event == null, "a cursed floor (and no floor event with it)")
	var sources := get_tree().get_nodes_in_group("heat_sources")
	var fires := sources.filter(func(f: Node) -> bool: return (f as HeatSource).def == campfire)
	var iced := sources.filter(func(f: Node) -> bool: return (f as HeatSource).def == frostbound.room_look)
	check(iced.size() == world.map.rooms.size(), "ice over every room (%d/%d)" % [iced.size(), world.map.rooms.size()])
	check(fires.size() >= 2 and fires.any(func(f: Node) -> bool: return world.map.rooms[0].grow(3).has_point(world.map.world_to_cell(f.global_position))), "campfires around the floor, one where you arrive (%d)" % fires.size())
	check(fires.size() <= 1 + frostbound.spot_count.y, "but only a few (%d)" % fires.size())
	var decor := (fires[0] as HeatSource).get_children().filter(func(n: Node) -> bool: return n is DecorLayer)
	check(not decor.is_empty() and (decor[0] as DecorLayer).pieces.size() <= campfire.decor_count.y, "logs and stones around the fire, never the same")
	for fire in fires:
		fire.free()
	player.temperature.reset()
	player.hp = player.get_max_hp()
	player._invulnerable_time = 0.0
	player.ward = 0  # a Guardian Ring taken earlier would soak the cold
	for i in 40:
		player.temperature.update(player, 0.5)
	check(player.temperature.value <= -BodyTemperature.LIMIT, "Frostbound chills the hero to the bone (%.0f)" % player.temperature.value)
	check(player.statuses.speed_multiplier() < 0.8, "the cold slows you down")
	check(player.hp < player.get_max_hp(), "freezing hurts")
	await _frames(2)
	check(game.hud._temp_bar.visible and game.hud._temp_bar.fill_color.b > 0.9, "the HUD shows how cold you are")
	check(game.hud._temp_overlay.visible and (game.hud._temp_overlay.material as ShaderMaterial).get_shader_parameter("cold") > 0.9, "frost creeps over the screen")
	var cell := world.map.world_to_cell(player.global_position)
	var fire := world.spawn_heat_source(campfire, Rect2i(cell, campfire.size))
	check(fire.reaches(player), "a campfire reaches the hero next to it")
	for i in 4:
		player.temperature.update(player, 0.5)
	check(player.temperature.value > -BodyTemperature.LIMIT * 0.1, "a campfire warms you back up (%.0f)" % player.temperature.value)
	# Camping by the fire draws monsters in.
	await _clear_monsters(world)
	var watch: CampWatch = fire.get_children().filter(func(n: Node) -> bool: return n is CampWatch)[0]
	var warnings := [false]
	var on_log := func(text: String, _color: Color) -> void: warnings[0] = warnings[0] or text == campfire.camp_warning
	Events.message_logged.connect(on_log)
	watch.camped = campfire.camp_limit * 0.7
	await _frames(2)
	check(warnings[0] and world.monster_count() == 0, "stay too long by the fire: a warning first")
	watch.camped = campfire.camp_limit - 0.01
	await _frames(3)
	var invaders := world.get_hostiles(Actor.Faction.PLAYER)
	check(invaders.size() >= campfire.invasion.x and invaders.all(func(m: Actor) -> bool: return (m as Monster).summoned and (m as Monster).target == player), "then monsters come for the fire (%d), and give nothing" % invaders.size())
	check(watch.camped < 1.0 and watch.waves == 1, "the watch starts over, the next wave bigger")
	Events.message_logged.disconnect(on_log)
	await _clear_monsters(world)
	fire.free()

	# Ashen Breath: it burns; the springs cool you down.
	CONTENT.curses = [ashen]
	game._enter_floor()
	await _frames(3)
	var oases := get_tree().get_nodes_in_group("heat_sources").filter(func(f: Node) -> bool: return (f as HeatSource).def == oasis)
	check(world.curse == ashen and not oases.is_empty(), "Ashen Breath: oases around the floor")
	var sizes := {}
	for spot: HeatSource in oases:
		sizes[spot.rect.size] = true
		check(world.nav.is_blocked(spot.rect.get_center()), "nobody walks on an oasis' water")
	check(oases.all(func(spot: HeatSource) -> bool: return spot.rect.size.x >= oasis.size.x and spot.rect.size.x <= oasis.size_max.x), "oases of different sizes (%d kinds)" % sizes.size())
	for node in get_tree().get_nodes_in_group("heat_sources"):
		node.free()
	player.temperature.reset()
	for i in 40:
		player.temperature.update(player, 0.5)
	check(player.temperature.value >= BodyTemperature.LIMIT, "Ashen Breath heats the hero up (%.0f)" % player.temperature.value)
	cell = world.map.world_to_cell(player.global_position)
	var pool := world.spawn_heat_source(oasis, Rect2i(cell + Vector2i(1, 0), oasis.size))
	check(pool.reaches(player), "the hero on the shore")
	for i in 4:
		player.temperature.update(player, 0.5)
	check(player.temperature.value < BodyTemperature.LIMIT * 0.1, "an oasis cools you down (%.0f)" % player.temperature.value)
	pool.free()

	# Lanternless: the whole floor in the dark, but around the hero.
	CONTENT.curses = [lanternless]
	game._enter_floor()
	await _frames(3)
	var darks := get_tree().get_nodes_in_group("dark_rooms")
	check(world.curse == lanternless and darks.size() == 1 and (darks[0] as DarkRoom).covers(world.map.cell_to_world(world.map.stairs_cell)) and (darks[0] as DarkRoom).covers(player.global_position), "Lanternless: the whole floor is dark")
	check((darks[0] as DarkRoom).z_index > 0 and (darks[0] as DarkRoom).material is ShaderMaterial, "the darkness covers the monsters")
	check(world.rules.loot_quality() > 1.0, "braving a curse pays: better loot")

	# The curse card: the sigil, the name, the story, the rule.
	game.curse_card.play(frostbound)
	await _frames(70)
	check(game.curse_card.visible and (game.curse_card.get_node("%Title") as Label).text == frostbound.display_name and (game.curse_card.get_node("%Rule") as Label).text == frostbound.description, "arriving on a cursed floor shows the curse's card")
	game.curse_card._skip = true
	await game.curse_card.finished
	check(not game.curse_card.visible, "a tap skips it")

	# The Blood Moon: its own look (red grade, the moon's glow, beating edges) over the biome.
	var moon: FloorEventDef = load("res://data/floor_events/blood_moon.tres")
	await game.debug_enter_floor(maxi(start_depth, 4), null, moon)
	await _frames(3)
	var screen := get_tree().get_first_node_in_group(&"screen_effects") as ScreenEffects
	var screen_look := screen.material as ShaderMaterial
	check(world.floor_event == moon and (screen_look.get_shader_parameter("moon_color") as Color).a > 0.0 and float(screen_look.get_shader_parameter("vignette_pulse")) > 0.0, "the Blood Moon hangs over the floor")
	var dim := world.lights.ambient_level
	check(world.lights.colors[dim].g < world.theme.lighting.color_of(dim).g * 0.9, "its light is red")
	await game.debug_enter_floor(maxi(start_depth, 4))
	await _frames(3)
	check((screen_look.get_shader_parameter("moon_color") as Color).a == 0.0, "gone on the next floor")

	# A boss at a rare rank: its name, its affixes on the boss bar.
	var legendary: MonsterRankDef = CONTENT.dungeon.rare_ranks.filter(func(r: MonsterRankDef) -> bool: return r.id == &"legendary")[0]
	world.forced_boss_rank = legendary
	var hall: ArenaDef = load("res://data/arenas/great_hall.tres")
	world.forced_arena = hall
	await game.debug_enter_floor(CONTENT.dungeon.acts[0].floors)
	await _frames(3)
	var rare_boss := world.arena.boss
	check(rare_boss.rank == legendary and rare_boss.affixes.size() == legendary.affixes and rare_boss.display_name.begins_with("Legendary"), "a boss can come Legendary (%s)" % rare_boss.display_name)
	world.arena.start()
	await _frames(2)
	var bar_name := (game.hud.get_node("%BossName") as Label).text
	check(bar_name.contains(rare_boss.affixes[0].display_name), "the boss bar shows its affixes (%s)" % bar_name)
	# Its arena: the plan's size, its pillars, and a change at the next phase.
	check(world.arena_plan == hall and world.map.boss_room.size == hall.size, "the boss fights in its arena (%s)" % hall.display_name)
	var columns := get_tree().get_nodes_in_group("props").filter(func(p: Node) -> bool: return (p as Prop).def == hall.pillar)
	check(columns.size() == hall.pillars.size(), "pillars stand in it (%d)" % columns.size())
	var cracks_before := world._cracks.size()
	rare_boss.skills.set_skills([] as Array[SkillDef])
	rare_boss.invincible = false
	var to_phase := HitInfo.new()
	to_phase.amount = Combat.hit_for(rare_boss.hp - roundi(rare_boss.get_max_hp() * 0.6), rare_boss.get_stats().defense)
	rare_boss.take_hit(to_phase)
	await _frames(5)
	check(get_tree().get_nodes_in_group("vfx").size() >= 0 and world.arena.shifts_done == 1, "the next phase changes the arena")
	await _frames(int(hall.shifts[0].warning_time * 60.0) + 10)
	check(world._cracks.size() > cracks_before, "after the warning, its edge cracks (%d)" % (world._cracks.size() - cracks_before))

	# Back to a normal floor for the next tests.
	CONTENT.curses = saved_curses
	difficulty.curse_chance = 0.0
	game.depth = start_depth
	game._enter_floor()
	await _frames(3)
	difficulty.curse_chance = saved_chance
	player.temperature.reset()
	player.hp = player.get_max_hp()
	await _frames(2)
	check(not game.hud._temp_bar.visible, "no thermometer when all is fine")
	await _clear_monsters(world)

	# Potions: past a few of the same, they come as gold.
	var potion: ConsumableDef = load("res://data/items/consumables/health_potion.tres")
	var saved_belt := player.belt.to_data()
	var saved_bag := player.inventory.items.duplicate()
	player.belt.load_data([])
	player.inventory.items.clear()
	check(world.spawn_loot(potion, player.global_position + Vector2(40, 0)) != null, "potions drop while you carry few")
	for i in CONTENT.dungeon.consumable_carry_cap:
		player.pick_up(potion)
	var coins_before := get_tree().get_nodes_in_group("gold").size()
	var gold_before := _gold_on_floor(world)
	check(world.spawn_loot(potion, player.global_position + Vector2(40, 0)) == null, "with %d potions on you, more turn into gold" % CONTENT.dungeon.consumable_carry_cap)
	await _frames(2)
	check(_gold_on_floor(world) > gold_before, "the gold is on the floor (%d coins before)" % coins_before)
	for node in world.get_node("Entities").get_children():
		if node is ItemPickup:
			node.queue_free()
	player.belt.load_data(saved_belt)
	player.inventory.items = saved_bag
	await _frames(2)


## Special floors, one boss per act drawn for the run, and the new bosses fighting.
func _test_variety(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.xp = -1000000
	check(world.run_bosses.size() == CONTENT.dungeon.acts.size(), "the run drew a boss for every act")
	for i in world.run_bosses.size():
		check(CONTENT.dungeon.acts[i].all_bosses().has(world.run_bosses[i]), "act %d: its boss is one of the act's" % (i + 1))
	game._save_run()
	check((RunSave.read().get("bosses", []) as Array).size() == world.run_bosses.size(), "the drawn bosses are saved with the run")

	# Special floors.
	var chance := CONTENT.dungeon.floor_event_chance
	var events := CONTENT.floor_events
	CONTENT.dungeon.floor_event_chance = 1.0
	world.build_floor(2, CONTENT)
	check(world.floor_event != null, "a floor can be special")
	world.build_floor(3, CONTENT)
	check(world.floor_event == null, "never on boss floors")
	CONTENT.floor_events = [load("res://data/floor_events/treasure_vault.tres")] as Array[FloorEventDef]
	world.build_floor(2, CONTENT)
	var chests := get_tree().get_nodes_in_group("chests").filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())
	check(world.floor_event.id == &"treasure_vault" and chests.size() >= 3, "a treasure vault is full of chests (%d)" % chests.size())
	CONTENT.floor_events = [load("res://data/floor_events/swarm.tres")] as Array[FloorEventDef]
	world.build_floor(2, CONTENT)
	var weakling := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(world.map.start_cell))
	check(weakling.get_max_hp() < roundi((load("res://data/monsters/slime.tres") as MonsterDef).stats.max_hp * (1.0 + CONTENT.dungeon.monster_hp_scale_per_depth)), "the swarm is weak")
	CONTENT.floor_events = events
	CONTENT.dungeon.floor_event_chance = chance
	game.depth = 2
	game._enter_floor()
	await _frames(3)

	# The new bosses use their skills and can be beaten.
	var defense := player.base_stats.defense
	player.base_stats.defense = 999
	player.invalidate_stats()
	for id in ["giant_frog", "weeping_spirit", "red_samurai"]:
		# In sight of the hero, at a distance where every skill may be used.
		var boss := world.spawn_monster(load("res://data/monsters/bosses/%s.tres" % id), world.find_open_point_near(player.global_position, 150.0))
		boss.wake_up(player)
		var used := false
		for frame in 60 * 10:
			for i in boss.skills.skills.size():
				used = used or boss.skills.cooldown_ratio(i) > 0.0
			if used:
				break
			await get_tree().physics_frame
		check(used, "%s uses its skills" % id)
		boss.die(player)
		check(boss.is_dead, "%s can be beaten" % id)
		await _frames(30)
	for monster in world.get_hostiles(Actor.Faction.PLAYER):
		monster.queue_free()
	player.base_stats.defense = defense
	player.invalidate_stats()
	player.hp = player.get_max_hp()
	player.xp = 0
	await _frames(3)


## Springs, altars, spirits and statues: costs, choices, outcomes.
func _test_encounters(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	player.xp = -1000000
	check(CONTENT.encounters.size() >= 4, "encounters listed")
	for def in CONTENT.encounters:
		check(def.icon != null and not def.choices.is_empty(), "%s has a sprite and choices" % def.id)
		for choice in def.choices:
			check(not choice.outcomes.is_empty(), "%s: '%s' leads somewhere" % [def.id, choice.label])
	var panel: EncounterPanel = game.encounter_panel

	# The spring: walking up asks, drinking does something, then it is spent.
	var spring := world.spawn_encounter(load("res://data/encounters/spirit_spring.tres"), _open_cell_near(world, player.global_position, 2))
	player.global_position = spring.global_position + Vector2(0, 40)
	await _frames(3)
	check(panel.visible and get_tree().paused, "walking up to an encounter asks what to do")
	panel._choose(0)
	check(spring.used and (panel.get_node("%Choices") as Control).get_child_count() == 1, "a choice was made, the spring is spent")
	check((panel.get_node("%Result") as Label).visible and not (panel.get_node("%Result") as Label).text.is_empty(), "what happened is spelled out")
	panel.close()
	await _frames(2)
	check(not get_tree().paused, "closing resumes the game")
	player.global_position = spring.global_position + Vector2(0, 160)
	await _frames(3)
	player.global_position = spring.global_position + Vector2(0, 40)
	await _frames(3)
	check(not panel.visible, "a spent encounter asks nothing")
	player.global_position = spring.global_position + Vector2(0, 160)

	# The blood altar: max HP for a relic.
	var max_hp := player.base_stats.max_hp
	var altar := world.spawn_encounter(load("res://data/encounters/blood_altar.tres"), _open_cell_near(world, player.global_position, 2))
	game.open_encounter(altar)
	panel._choose(0)
	check(player.base_stats.max_hp < max_hp, "the altar takes max HP")
	panel.close()
	await _frames(3)
	check(game.perk_panel.visible and (game.perk_panel.get_node("%Title") as Label).text == "Relic", "and gives a relic choice")
	game.perk_panel.choose(0)
	await _frames(2)
	player.base_stats.max_hp = max_hp
	player.invalidate_stats()

	# The grinning spirit wants gold.
	player.gold = 0
	var gambler := world.spawn_encounter(load("res://data/encounters/grinning_spirit.tres"), _open_cell_near(world, player.global_position, 2))
	game.open_encounter(gambler)
	var pay: Button = panel.choice_button(0)
	check(pay.disabled and pay.text.contains("gold"), "no gold, no gamble")
	check((panel.get_node("%Choices") as Control).get_child_count() == 2, "one card per choice")
	var odds := gambler.def.choices[0].chances()
	check(odds.size() == 3 and is_equal_approx(odds[0] + odds[1] + odds[2], 1.0) and is_equal_approx(odds[0], 0.45), "the odds of each outcome are shown (45%)")
	check(gambler.def.choices[0].outcomes[2].summary(player, true).begins_with("Nothing") and gambler.def.choices[0].outcomes[2].is_bad(), "losing the gold is spelled out, in red")
	check(gambler.def.choices[0].cost_text(player, world.depth).contains("gold"), "each choice says what it costs")
	check(gambler.resolve(0, player) == null and not gambler.used, "it can't be forced either")
	panel.close()
	await _frames(2)

	# The statue may call its servants: elites.
	var statue: EncounterDef = load("res://data/encounters/warden_statue.tres")
	var before := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Monster) -> bool: return m.is_elite()).size()
	statue.choices[0].outcomes[1].apply(player, player.global_position + Vector2(60, 0))
	await _frames(2)
	var elites := world.get_hostiles(Actor.Faction.PLAYER).filter(func(m: Monster) -> bool: return m.is_elite())
	check(elites.size() == before + 2, "the statue's servants are elites")
	for monster in elites:
		monster.queue_free()
	for node in get_tree().get_nodes_in_group("encounters"):
		node.queue_free()
	player.xp = 0
	player.hp = player.get_max_hp()
	await _frames(3)


## Magic, Rare and Epic equipment, gold, and the merchant.
func _test_loot_and_gold(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.xp = -1000000
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	var sharp: ItemAffixDef = load("res://data/affixes/sharp.tres")
	var bear: ItemAffixDef = load("res://data/affixes/of_the_bear.tres")
	var burning: ItemAffixDef = load("res://data/affixes/burning.tres")
	var damage_before := katana.damage
	var rare := LootRoller.make(katana, ItemRarity.RARE, [sharp, bear] as Array[ItemAffixDef]) as WeaponDef
	check(rare.display_name == "Sharp Katana of the Bear" and rare.rarity_color() == ItemRarity.COLORS[ItemRarity.RARE], "a rare item has its name and color")
	check(rare.damage > katana.damage and rare.bonuses.attack >= 2 and rare.bonuses.max_hp >= 12, "affixes and rarity make it stronger")
	check(katana.damage == damage_before and katana.base_item == null, "the plain item is untouched")
	check(rare.get_type_label().begins_with("Rare"), "the type says how rare it is")
	var magic := LootRoller.make(katana, ItemRarity.MAGIC, [burning] as Array[ItemAffixDef]) as WeaponDef
	check(magic.on_hit != null and magic.on_hit.burn_damage > 0, "a Burning weapon sets enemies on fire")
	var back := LootRoller.from_data(JSON.parse_string(JSON.stringify(LootRoller.to_data(rare)))) as WeaponDef
	check(back and back.display_name == rare.display_name and back.damage == rare.damage and back.rarity == ItemRarity.RARE, "rolled items survive a save")
	for affix in CONTENT.item_affixes:
		check(affix.bonuses != null or affix.on_hit != null or not affix.passives.is_empty(), "%s does something" % affix.id)
	var low := [0, 0, 0, 0]
	var high := [0, 0, 0, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		low[LootRoller.pick_rarity(1, 1.0, CONTENT.dungeon, rng)] += 1
		high[LootRoller.pick_rarity(9, CONTENT.dungeon.boss_loot_quality, CONTENT.dungeon, rng)] += 1
	check(low[0] > low[1] and low[1] > low[2] and low[2] >= low[3], "better items are rarer (%s)" % str(low))
	check(high[3] > low[3] and high[0] < low[0], "deeper and from bosses, loot gets better (%s)" % str(high))
	var potion: ItemDef = load("res://data/items/consumables/health_potion.tres")
	check(world.roll_item(potion, 10.0) == potion, "potions are never rolled")

	# Gold flies to the hero (no thief around to snatch it).
	await _clear_monsters(world)
	var gold_before := player.gold
	world.spawn_gold(player.global_position + Vector2(30, 0), 10)
	await _frames(60)
	check(player.gold >= gold_before + 10, "coins fly into the hero's purse")
	check((game.hud.get_node("%GoldLabel") as Label).text == "Gold %d" % player.gold, "the HUD shows the gold")
	var elite := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 1)))
	elite.dormant = true
	world.make_elite(elite)
	elite.take_hit(Combat.make_secondary_hit(player, 99999))
	await _frames(2)
	check(get_tree().get_nodes_in_group("gold").size() > 0, "elites always drop gold")

	# The merchant: buying, selling, the shop opening when walking up.
	var cell := _open_cell_near(world, player.global_position, 2)
	var merchant := world.spawn_merchant(CONTENT.dungeon.merchant, cell)
	world.kept_stock.clear()
	check(merchant.stock.size() >= CONTENT.dungeon.merchant.equipment_count, "the merchant has stock")
	player.gold = 0
	check(not merchant.sell_to(player, 0), "no gold, no deal")
	player.add_gold(9999)
	var bag_before := player.inventory.items.size()
	var bought: ItemDef = merchant.stock[0].item
	var price: int = merchant.stock[0].price
	check(merchant.sell_to(player, 0) and player.inventory.items.has(bought) and player.gold == 9999 - price, "buying puts the item in the bag")
	player.inventory.add(potion)
	var stock_before := merchant.stock.size()
	var gold_now := player.gold
	check(merchant.buy_from(player, potion) and player.gold > gold_now and merchant.stock.size() == stock_before + 1, "selling gives gold back")
	player.global_position = merchant.global_position + Vector2(0, 40)
	await _frames(3)
	check(game.shop_panel.visible and get_tree().paused, "walking up to the merchant opens the shop")
	check(game.shop_panel.get_node("%ForSale").get_child_count() == merchant.stock.size(), "the shop lists the stock")

	# The item card: what it is, its price, how it compares with what you wear, why you can't buy.
	var shop: ShopPanel = game.shop_panel
	shop.select_stock(0)
	var buy: Button = shop.get_node("%BuyButton")
	check(buy.visible and not buy.disabled and buy.text.contains(str(merchant.stock[0].price)), "the card's Buy button gives the price")
	check((shop.get_node("%Gold") as Label).text == "Gold %d" % player.gold, "the shop shows your gold")
	var gold_kept := player.gold
	player.gold = 0
	shop.select_stock(0)
	check(buy.disabled and buy.text.contains("Not enough gold"), "too poor: Buy is greyed and says why")
	player.gold = gold_kept
	var equipment_index := merchant.stock.find_custom(func(e: Dictionary) -> bool: return e.item is EquipmentDef)
	if equipment_index >= 0:
		shop.select_stock(equipment_index)
		check((shop.get_node("%Compare") as Control).get_child_count() > 0 or (shop.get_node("%Details") as Label).text != "", "equipment is compared with what you wear")
	var katana_like := WeaponDef.new()
	katana_like.damage = 2
	var better := WeaponDef.new()
	better.damage = 5
	check(ItemCompare.lines(better, katana_like)[0].text == "+3 damage" and ItemCompare.lines(better, katana_like)[0].good, "the comparison says '+3 damage'")
	player.inventory.add(potion)
	shop.select_own(potion)
	var sell: Button = shop.get_node("%SellButton")
	check(sell.visible and sell.text.contains(str(CONTENT.dungeon.merchant.sell_price(potion, world.depth))) and not shop.get_node("%BuyButton").visible, "an item of yours shows what the merchant pays")
	var gold_before_sale := player.gold
	check(shop.sell_selected() and player.gold > gold_before_sale, "Sell sells it")

	# Lock one, reroll the rest (dearer each time); the locked one stays.
	shop.select_stock(0)
	(shop.get_node("%LockButton") as Button).pressed.emit()
	check(merchant.stock[0].locked, "the lock button locks an entry")
	var kept: ItemDef = merchant.stock[0].item
	var kept_price: int = merchant.stock[0].price
	var reroll_price := merchant.reroll_price()
	var gold_before_reroll := player.gold
	var unlocked_before := merchant.stock.slice(1).map(func(e: Dictionary) -> ItemDef: return e.item)
	(game.shop_panel.get_node("%RerollButton") as Button).pressed.emit()
	check(player.gold == gold_before_reroll - reroll_price, "a reroll costs its price (%d)" % reroll_price)
	check(merchant.stock[0].item == kept and merchant.stock.size() > 1, "the locked entry stays, the rest is new")
	check(not merchant.stock.slice(1).all(func(e: Dictionary) -> bool: return unlocked_before.has(e.item)), "new stock after a reroll")
	check(merchant.reroll_price() > reroll_price, "each reroll costs more")
	game._back()
	await _frames(1)
	check(not game.shop_panel.visible and not get_tree().paused, "leaving the shop resumes the game")
	game._save_run()
	check((RunSave.read().get("kept_stock", []) as Array).size() == 1, "a saved run keeps the locked entry")

	# The locked entry waits at the next merchant, same price.
	await game.debug_enter_floor(game.depth)
	world = game.world
	check(world.kept_stock.size() == 1 and world.kept_stock[0].item == kept, "leaving the floor carries the locked entry")
	var next := world.spawn_merchant(CONTENT.dungeon.merchant, _open_cell_near(world, game.player.global_position, 2))
	check(next.stock[0].item == kept and next.stock[0].price == kept_price and next.stock[0].locked, "the next merchant sells it at the same price")
	check(world.kept_stock.is_empty(), "handed over once")
	next.queue_free()
	player.inventory.items.resize(bag_before)
	player.xp = 0
	await _frames(5)


## Floor ambience: data per theme, footprints, low health heartbeat and muffled music.
func _test_ambience(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	for theme_id in ["cave", "crypt", "ruins"]:
		var theme: DungeonTheme = load("res://data/dungeon/themes/%s.tres" % theme_id)
		check(theme.ambience != null and theme.ambience.footstep != null and theme.ambience.bed != null, "%s has an ambience" % theme_id)
		check(theme.ambience.one_shots.size() >= 3 and theme.ambience.particles != null, "%s ambience has sounds and particles" % theme_id)
	check(world.theme.ambience != null, "the floor plays its theme ambience")
	var reverb := AudioServer.get_bus_effect(AudioServer.get_bus_index(&"SFX"), 0) as AudioEffectReverb
	check(reverb != null and is_equal_approx(reverb.wet, world.theme.ambience.reverb_wet), "the floor sets the reverb")

	# Walking leaves footprints.
	var prints_before := _count_footprints(world)
	var dir := Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		if world.map.is_floor(world.map.world_to_cell(player.global_position + d * 48.0)):
			dir = d
			break
	_set_move(dir)
	await _frames(50)
	_set_move(Vector2.ZERO)
	check(_count_footprints(world) > prints_before, "walking leaves footprints")

	# Low health: heartbeat, muffled music. Back to normal when healed.
	var music_bus := AudioServer.get_bus_index(&"Music")
	player.hp = 1
	player.health_changed.emit(player.hp, player.get_max_hp())
	check(game.ambience.is_low_health() and AudioServer.is_bus_effect_enabled(music_bus, 0), "low health muffles the music")
	player.heal(player.get_max_hp())
	check(not game.ambience.is_low_health() and not AudioServer.is_bus_effect_enabled(music_bus, 0), "healing clears the muffle")


## The dev tools (debug builds): open, jump to a cursed floor, god mode, spawn, close.
## Every biome, a few floors each: its look, its scenes (and nobody else's), nothing walled off.
func _test_biomes(game: Game) -> void:
	var depth_before := game.depth
	var world := game.world
	var dungeon := CONTENT.dungeon
	var generic := {}
	for prop in CONTENT.props:
		generic[prop] = true
	generic[dungeon.room_light] = true
	generic[dungeon.cracked_wall] = true  # (a secret room's crack: any floor of any world)
	for a in dungeon.acts.size():
		for biome in dungeon.acts[a].biomes:
			var allowed := generic.duplicate() if biome.props.is_empty() else {dungeon.room_light: true, dungeon.cracked_wall: true}
			for prop in biome.props:
				allowed[prop] = true
			if biome.light:
				allowed[biome.light] = true
			for scene in biome.scenes:
				for k in scene.keys:
					for prop in k.props:
						allowed[prop] = true
			var scenes := 0
			for attempt in 2:
				world.forced_biome = biome
				await game.debug_enter_floor(dungeon.first_depth(a) + 1)
				world = game.world
				check(world.biome == biome and world.theme == biome.theme, "%s: the whole floor is it" % biome.id)
				for count: int in FloorDresser.last_scenes.values():
					scenes += count
				var strangers := get_tree().get_nodes_in_group("props").filter(func(node: Node) -> bool:
					return not allowed.has((node as Prop).def))
				check(strangers.is_empty(), "%s: nothing from another biome %s" % [biome.id, str(strangers.map(func(n: Node) -> StringName: return (n as Prop).def.id))])
				var cut := _walled_off_cells(world)
				check(cut.is_empty(), "%s: nothing walled off %s" % [biome.id, str(cut.slice(0, 4))])
				check(world.grounds.size() == biome.grounds.size(), "%s: its grounds laid" % biome.id)
			check(scenes >= 6, "%s: scenes in its rooms (%d on 2 floors)" % [biome.id, scenes])
	check(world.forced_biome == null, "a forced biome is used once")
	await _clear_monsters(world)
	for pickup in get_tree().get_nodes_in_group("pickups"):
		pickup.queue_free()  # nothing for the next tests to pick up by chance
	await _frames(1)
	game.depth = depth_before


## The small things: splats on the floor, plants that bend, the HP bar's trail, flames, the air.
func _test_details(game: Game) -> void:
	var depth_before := game.depth
	game.world.forced_biome = load("res://data/biomes/underground_garden.tres")
	await game.debug_enter_floor(2)
	var world := game.world
	var player := game.player
	await _clear_monsters(world)
	var spot := world.map.cell_to_world(_open_cell_near(world, player.global_position, 2))
	var before := world.splat_count()
	var slime := world.spawn_monster(load("res://data/monsters/slime.tres"), spot)
	slime.dormant = true
	await _frames(1)
	before = world.splat_count()  # (the hero's perks may have hurt it already: drops of slime)
	slime.die(null)
	check(world.splat_count() == before + 1, "a slime leaves a splat where it dies")
	var spirit := world.spawn_monster(load("res://data/monsters/spirit.tres"), spot)
	spirit.dormant = true
	await _frames(1)
	var after_slime := world.splat_count()
	spirit.die(null)
	check(world.splat_count() == after_slime, "a spirit leaves nothing")
	check((load("res://data/monsters/slime.tres") as MonsterDef).splat_color.g > 0.4, "slimes leave green slime, not blood")

	var plants: Array[DecorLayer] = []
	for node in world.get_node("Effects").get_children():
		if node is DecorLayer and (node as DecorLayer).sway:
			plants.append(node as DecorLayer)
	check(not plants.is_empty(), "the garden's plants sway")
	if not plants.is_empty():
		var layer := plants[0]
		var piece: Array = layer.pieces[0]
		player.global_position = DecorLayer._foot(piece) + Vector2(-8, 0)
		await _frames(20)
		check(absf(layer._lean[0]) > 0.1, "a plant bends when the hero walks through it")

	var bar := StatBar.new()
	add_child(bar)
	bar.set_values(100, 100)
	bar.set_values(60, 100)
	check(bar._trail == 100.0, "a hit leaves a pale trail on the bar")
	for i in 90:
		await get_tree().process_frame
	check(bar._trail == 60.0 and not bar.is_processing(), "then the trail drains away")
	bar.queue_free()

	check((load("res://data/props/furniture/brazier.tres") as PropDef).flame != null, "braziers burn")

	# Ranged weapons: a fan of three shurikens doesn't hit three times as hard; they don't glow.
	var shuriken: WeaponDef = load("res://data/items/weapons/shuriken.tres")
	var spec := Combat.spec_from_weapon(player, shuriken)
	check(spec.damage * shuriken.projectile_count <= player.get_power() * 1.5 and spec.glow == 0.0, "shurikens: each one weaker, and no glow")
	check(Combat.spec_from_weapon(player, load("res://data/items/weapons/magic_wand.tres")).glow > 0.0, "magic bolts glow")

	# Supports: a mender heals its hurt allies, a moth wards them.
	await _clear_monsters(world)
	var spot2 := world.map.cell_to_world(_open_cell_near(world, player.global_position + Vector2(200, 0), 3))
	var brute := world.spawn_monster(load("res://data/monsters/rat.tres"), spot2)
	var mender := world.spawn_monster(load("res://data/monsters/moss_heart.tres"), spot2 + Vector2(40, 0))
	await _frames(1)
	brute.dormant = true
	brute.hp = 1
	check(mender.pick_skill(150.0) == 0, "a mender wants to heal a hurt ally")
	mender.skills.skills[0].activate(mender, Vector2.RIGHT)
	check(brute.hp > 1, "and heals it")
	brute.hp = brute.get_max_hp()
	check(mender.pick_skill(150.0) == -1, "nobody hurt: it waits")
	var moth := world.spawn_monster(load("res://data/monsters/soul_moth.tres"), spot2 + Vector2(-40, 0))
	await _frames(1)
	moth.skills.skills[0].activate(moth, Vector2.RIGHT)
	check(brute.ward > 0, "a moth wards its allies")
	var before_hp := brute.hp
	var poke := HitInfo.new()
	poke.amount = Combat.hit_for(1, brute.get_stats().defense)
	brute.take_hit(poke)
	check(brute.hp == before_hp, "the ward soaks up the blow")
	await _clear_monsters(world)

	# Attack effects: a swing draws its arc, a hit its flash, a blast ripples the picture.
	var effects := world.get_node("Effects")
	var count_of := func(kind: Script) -> int: return effects.get_children().filter(func(n: Node) -> bool: return n.get_script() == kind).size()
	player.use_item(load("res://data/items/weapons/katana.tres"))
	player._attack_cooldown = 0.0
	player.attack(Vector2.RIGHT)
	check(count_of.call(SwingVfx) >= 1, "a sword swing draws its arc")
	Vfx.hit(world, player.global_position, Vector2.RIGHT, Color.RED)
	check(count_of.call(ImpactVfx) >= 1, "a hit flashes")
	Vfx.explosion(world, player.global_position + Vector2(200, 0), 60.0)
	check(count_of.call(ShockwaveVfx) >= 1, "a blast ripples the picture")
	var shroom := world.spawn_monster(load("res://data/monsters/mushroom.tres"), player.global_position + Vector2(80, 0))
	shroom.target = player
	await _frames(1)
	shroom.casting_index = 0
	shroom.get_node("StateMachine").transition_to(&"Cast")
	await _frames(6)
	var warning := shroom.get_node("Under").get_child(0) as TelegraphView
	check(warning != null and warning.visible, "a cast shows its warning zone")
	shroom.queue_free()
	var garden: BiomeDef = load("res://data/biomes/underground_garden.tres")
	check(garden.theme.ambience.particles.resource_path.ends_with("fireflies.tscn"), "fireflies in the garden")
	var air := world.get_node("Effects").get_children().filter(func(n: Node) -> bool: return n is AtmosphereLayer)
	check(air.size() == 1, "the garden has its air (light shafts, leaf shadows)")
	var screen := get_tree().get_first_node_in_group(&"screen_effects") as ScreenEffects
	check(screen != null and is_equal_approx(float((screen.material as ShaderMaterial).get_shader_parameter("grade")), garden.theme.ambience.grade_strength), "the picture takes the biome's colors")
	var biomes_with_air := 0
	for act in CONTENT.dungeon.acts:
		for biome in act.biomes:
			var mood := biome.theme.ambience
			if mood.grade_strength > 0.0 and (mood.rays_color.a > 0.0 or mood.mist_color.a > 0.0 or mood.caustics_color.a > 0.0 or mood.heat_haze > 0.0):
				biomes_with_air += 1
	check(biomes_with_air >= 9, "every biome has its atmosphere (%d)" % biomes_with_air)
	await _clear_monsters(world)
	game.depth = depth_before


## Free floor cells (not under furniture, water...) the hero can't get to from the start
## (crates and pots in the way don't count: they break).
func _walled_off_cells(world: World) -> Array[Vector2i]:
	var map := world.map
	var breakable := {}
	for node in get_tree().get_nodes_in_group("props"):
		var prop := node as Prop
		if prop.def.is_breakable() and not prop.is_queued_for_deletion():
			for cell in prop.cells():
				breakable[cell] = true
	var open := func(cell: Vector2i) -> bool:
		return map.is_floor(cell) and (not world.nav.is_blocked(cell) or breakable.has(cell))
	var seen := { map.start_cell: true }
	var queue: Array[Vector2i] = [map.start_cell]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + dir
			if open.call(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	var cut: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var cell := Vector2i(x, y)
			if open.call(cell) and not seen.has(cell):
				cut.append(cell)
	if not seen.has(map.stairs_cell):
		cut.push_front(map.stairs_cell)
	return cut


func _test_debug_panel(game: Game) -> void:
	var debug := game.menus.debug
	check(debug != null and game.hud.has_node("DebugButton"), "debug builds have the debug panel and its DBG button")
	if debug == null:
		return
	var depth_before := game.depth
	game.open_debug()
	await _frames(2)
	check(debug.visible and get_tree().paused, "DBG opens the panel, game paused")
	var frostbound: CurseDef = load("res://data/curses/frostbound.tres")
	debug._go(5, frostbound)
	await _frames(5)
	check(not debug.visible and game.depth == 5 and game.world.curse == frostbound and not get_tree().paused, "jump to floor 5, Frostbound")
	debug._go(5)
	await _frames(5)
	check(game.world.curse == null and game.world.floor_event == null, "a plain floor on demand")
	game.open_debug()
	await _frames(1)
	debug._god_button.pressed.emit()
	check(game.player.invincible, "god mode")
	var hp := game.player.hp
	game.player.take_hit(Combat.make_secondary_hit(null, 50))
	check(game.player.hp == hp, "nothing hurts in god mode")
	debug._god_button.pressed.emit()
	var before := game.world.monster_count()
	debug._spawn(true)
	check(game.world.monster_count() == before + 1, "spawn a monster (elite)")
	game.world.reveal_all()
	check(game.world.is_explored(game.world.map.stairs_cell), "reveal the map")
	debug.close()
	await _frames(2)
	check(not debug.visible and not get_tree().paused, "closing resumes the game")
	await _clear_monsters(game.world)
	game.depth = depth_before


## Floors grow with the difficulty; a crowded one keeps the phone's monster cap and the seal's.
func _test_floor_size(game: Game) -> void:
	var world: World = game.world
	var config := CONTENT.dungeon
	var before := world.difficulty
	world.difficulty = CONTENT.get_difficulty(&"easy")
	world.build_floor(2, CONTENT)
	var easy_rooms := world.map.rooms.size()
	var easy_width := world.map.width
	world.difficulty = AscensionDef.apply_levels(CONTENT.get_difficulty(&"nightmare"), CONTENT.ascensions, CONTENT.ascensions.size())
	world.build_floor(8, CONTENT)
	check(world.map.width > easy_width and world.map.rooms.size() > easy_rooms, "Nightmare floors are bigger (%d rooms, Easy %d)" % [world.map.rooms.size(), easy_rooms])
	check(world.monster_count() <= config.max_monsters_per_floor and world.monster_count() >= config.max_monsters_per_floor * 0.6, "crowded, within the cap (%d)" % world.monster_count())
	check(world.seal.needed == config.seal_max, "the seal asks for its most, no more (%d)" % world.seal.needed)
	var chunks := ceili(world.map.width / float(DungeonView.CHUNK)) * ceili(world.map.height / float(DungeonView.CHUNK))
	check(world._view.chunk_count() == chunks, "the map is drawn in chunks the renderer can skip (%d)" % world._view.chunk_count())
	var mist := world._view.mist
	check(mist.visible and mist.get_index() == world._view.get_child_count() - 1 and mist.mask.get_width() == world.map.width + DungeonView.OUTSIDE_MARGIN * 2 and mist.light_field == world.lights and mist.z_index > LightField.Z, "the mist covers the whole map, lit by the floor's light, drawn over it")
	world.build_floor(9, CONTENT)
	check(world.arena != null and world.map.width == config.width, "boss floors keep their size")
	world.difficulty = before
	game.depth = 2
	game._enter_floor()
	await _frames(3)

