class_name CombatTests
extends TestSuite
## In the game: projectiles, perks, skills, monsters and their abilities, difficulty, weapons.


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


## Each kind of perk does its job in the real game, then the level-up screen works.
func _test_perks_in_game(game: Game, world: World, player: Player) -> void:
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
	check(before - slime.hp > Combat.mitigate(10, slime.get_stats().defense), "Executioner hits wounded enemies harder")
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
	check(skeleton.is_dead or skeleton.statuses.has(&"burn"), "Burning Thorns set them on fire")
	skeleton.die(null)

	player.perks.add(_perk("multishot"))
	var volley := ProjectileSpec.new()
	volley.max_distance = 10.0
	world.fire_projectiles(player, Vector2.RIGHT, volley)
	check(volley.count == 2 and volley.spread_degrees > 0.0, "Multishot adds a projectile")
	# Extra projectiles share the volley's damage, and every source together adds 2 at most.
	var prism: RuneDef = load("res://data/runes/prism.tres")
	player.perks.add(_perk("multishot"))
	player.perks.set_gear([], [prism, prism])
	var fan := ProjectileSpec.new()
	fan.max_distance = 10.0
	fan.damage = 30
	world.fire_projectiles(player, Vector2.RIGHT, fan)
	check(fan.count == 3, "Multishot 2 and two Prism runes: 2 extra projectiles at most (%d shots)" % fan.count)
	check(fan.damage == roundi(30 * (1.0 + 0.65 * 2) / 3.0), "the extra shots share the volley's damage (%d a shot)" % fan.damage)
	player.perks.set_gear([], [])

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
	# Reroll: three other cards. Banish: that perk is gone for the run, another takes its place.
	game.run.rerolls = 1
	game.run.banishes = 1
	game.perk_panel.set_charges(1, 1)
	var reroll_button: Button = game.perk_panel.get_node("%RerollButton")
	var banish_button: Button = game.perk_panel.get_node("%BanishButton")
	check(reroll_button.visible and reroll_button.text == "Reroll (1)" and not banish_button.disabled, "the choice shows its reroll and banish")
	var first_cards := game.perk_panel.get_offered().duplicate()
	reroll_button.pressed.emit()
	await _frames(1)
	var rerolled := game.perk_panel.get_offered()
	check(game.run.rerolls == 0 and reroll_button.disabled, "a reroll is spent")
	check(rerolled.size() == 3 and not rerolled.any(func(p: PerkDef) -> bool: return first_cards.has(p)), "a reroll deals three other cards")
	banish_button.pressed.emit()
	check(game.perk_panel.is_banishing(), "Banish, then tap a card")
	var gone: PerkDef = rerolled[0]
	(cards.get_child(0) as Button).pressed.emit()
	await _frames(1)
	check(game.perk_panel.visible and game.run.banished.has(gone) and game.run.banishes == 0, "the tapped perk is banished, the choice stays open")
	check(not game.perk_panel.get_offered().has(gone) and game.perk_panel.get_offered().size() == 3, "another card takes its place")
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
	check(not player.perks.entries.any(func(e: PerkSet.Entry) -> bool: return game.run.banished.has(e.perk)), "the banished perk never came back")

	# Long text makes a taller card: nothing spills out of the frame.
	var wordy := PerkDef.new()
	wordy.display_name = "A Perk With A Rather Long Name"
	wordy.description = "This perk does a great many things, all of them described at length, so that the text runs over several lines and would never fit in the card's usual height. ".repeat(3)
	wordy.synergies = [_perk("ignite").synergies[0], _perk("vampirism").synergies[0]]
	var card := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
	add_child(card)
	card.show_perk(wordy, player.perks)
	await _frames(5)
	check((card.get_node("Margin") as Control).get_combined_minimum_size().y <= card.size.y + 1.0 and card.size.y > 320.0, "a card grows to fit long text (%d px)" % card.size.y)
	card.queue_free()
	for perk in CONTENT.perks:
		var real := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
		add_child(real)
		real.show_perk(perk, player.perks)
		await _frames(4)
		check((real.get_node("Margin") as Control).get_combined_minimum_size().y <= real.size.y + 1.0, "%s: its text fits its card" % perk.id)
		real.queue_free()
	game.run.banished.clear()

	# A card spells its family out: its name, how many more it takes, what the bonus does.
	var family := _perk("ignite").synergies[0]
	var spelled := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
	add_child(spelled)
	spelled.show_perk(_perk("ignite"), PerkSet.new())
	var words := _texts(spelled)
	check(words.contains("%s family" % family.display_name) and words.contains("more %s perk" % family.display_name) and words.contains(family.description), "a card says what its family is and does: %s" % words.left(160))
	spelled.queue_free()
	var almost := PerkSet.new()
	for perk in CONTENT.perks:
		if perk.synergies.has(family) and almost.pieces_of(family) < family.pieces - 1 and perk != _perk("ignite"):
			almost.add(perk)
	var waking := (load("res://src/ui/perk_choice/perk_card.tscn") as PackedScene).instantiate() as PerkCard
	add_child(waking)
	waking.show_perk(_perk("ignite"), almost)
	check(waking.completes and _texts(waking).contains("AWAKENS"), "the card that completes a family says so")
	waking.queue_free()
	check(game.perk_panel._rule.text.contains("family"), "the perk screen explains families in one line")

	# The bag's Perks: every family in words, every perk taken.
	game.open_inventory()
	await _frames(2)
	game.inventory_panel.open_build()
	var build := game.inventory_panel.get_node("BuildWindow") as BuildWindow
	check(game.inventory_panel.is_build_open() and build._families.get_child_count() == CONTENT.synergies.size(), "the build lists every family (%d)" % build._families.get_child_count())
	check(build._perks.get_child_count() == maxi(player.perks.entries.size(), 1), "and every perk taken")
	game.inventory_panel.close()
	await _frames(2)
	check(not game.inventory_panel.is_build_open() and not get_tree().paused, "closing the bag closes the build")


## Every label's text under `node`, in one string.
func _texts(node: Node) -> String:
	var parts := PackedStringArray()
	for label in node.find_children("*", "Label", true, false):
		parts.append((label as Label).text)
	return " | ".join(parts)


## The new perks and the families' bonuses, in a real fight.
func _test_synergies_in_game(game: Game, world: World, player: Player) -> void:
	player.xp = -1000000  # no level up (and its pause) from these kills
	var spot := world.find_open_point_near(player.global_position, 90.0)
	var shots: Node = world.get_node("Projectiles")
	var slime_def: MonsterDef = load("res://data/monsters/slime.tres")

	# Ice Shards: a kill bursts into shards flying out of the body.
	player.perks.add(_perk("ice_shards"))
	var rat := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	rat.dormant = true
	await _frames(1)
	var kill := HitInfo.new()
	kill.amount = 9999
	kill.source = player
	rat.take_hit(kill)
	await _frames(1)
	var shards := shots.get_children().filter(func(n: Node) -> bool: return (n as Projectile).global_position.distance_to(rat.global_position) < 40.0)
	check(shards.size() >= 4, "Ice Shards: the body bursts into shards (%d)" % shards.size())

	# Frost: three frost perks wake it; slowed enemies take more, crits freeze them.
	player.perks.add(_perk("frostbite"))
	player.perks.add(_perk("cold_snap"))
	var frost: SynergyDef = _perk("frostbite").synergies[0]
	check(player.perks.is_awake(frost), "three frost perks wake Frost")
	check((game.hud.get_node("%PerkTray") as Control).get_child(0) is Panel, "the HUD shows the awake family first")
	var slime := world.spawn_monster(slime_def, spot)
	slime.dormant = true
	slime.base_stats.max_hp = 9999
	slime.invalidate_stats()
	slime.hp = 9999
	await _frames(1)
	var plain := HitInfo.new()
	plain.amount = 20
	plain.source = player
	slime.statuses.clear()
	player.perks.modify_outgoing_hit(player, slime, plain)
	var normal := plain.amount
	slime.statuses.apply_slow(0.3, 2.0)
	var on_slowed := HitInfo.new()
	on_slowed.amount = 20
	on_slowed.source = player
	player.perks.modify_outgoing_hit(player, slime, on_slowed)
	check(on_slowed.amount >= roundi(normal * 1.4), "Frost: slowed enemies take more damage (%d vs %d)" % [on_slowed.amount, normal])
	var crit := HitInfo.new()
	crit.amount = 5
	crit.is_crit = true
	crit.source = player
	slime.take_hit(crit)
	check(slime.statuses.speed_multiplier() <= 0.15, "Frost: a critical hit freezes a slowed enemy")
	player.perks.clear()

	# Storm: every 4th hit, lightning jumps to the enemies around.
	for id in ["frenzy", "thunderclap", "shock_roll"]:
		player.perks.add(_perk(id))
	var others: Array[Monster] = []
	for i in 2:
		var other := world.spawn_monster(slime_def, slime.global_position + Vector2(40 + 30 * i, 0))
		other.dormant = true
		others.append(other)
	await _frames(1)
	var others_hp := others.map(func(m: Monster) -> int: return m.hp)
	for i in 4:
		var poke := HitInfo.new()
		poke.amount = 1
		poke.source = player
		slime.take_hit(poke)
	check(others[0].hp < others_hp[0] or others[1].hp < others_hp[1], "Storm: lightning jumps to the enemies nearby")
	player.perks.clear()

	# Thunderclap: a crit's shockwave hurts the enemies around, not the one struck.
	player.perks.add(_perk("thunderclap"))
	await _frames(1)
	var struck_hp := slime.hp
	others_hp = others.map(func(m: Monster) -> int: return m.hp)
	var crit_poke := HitInfo.new()
	crit_poke.amount = 7
	crit_poke.is_crit = true
	crit_poke.source = player
	slime.take_hit(crit_poke)
	check(struck_hp - slime.hp <= 7, "Thunderclap: the enemy struck takes only the crit (%d)" % (struck_hp - slime.hp))
	check(others[0].hp < others_hp[0] or others[1].hp < others_hp[1], "Thunderclap: the shockwave hurts the enemies around")
	player.perks.clear()

	# Echo: an echo can't echo (a skill is used at most twice per cooldown, whatever the sources).
	var sure_echo: PerkDef = _perk("echo").duplicate()
	var always := SkillEchoPassive.new()
	always.chance_per_stack = 1.0
	sure_echo.passives = [always]
	player.perks.add(sure_echo)
	var echo_index := player.skills.skills.find_custom(func(s: SkillDef) -> bool: return s != null)
	var uses := 0
	for i in 4:
		player.skills._cooldowns[echo_index] = 0.0 if i == 0 else player.skills._cooldowns[echo_index]
		if player.skills.try_use(echo_index, player, Vector2.RIGHT):
			uses += 1
		await _frames(1)
	check(uses == 2, "Echo: a 100% echo gives one free cast, not a loop (%d casts)" % uses)
	player.perks.clear()

	# Arcane: using a skill fires a ring of bolts.
	for id in ["arcane_focus", "arcane_power", "devotion"]:
		player.perks.add(_perk(id))
	for n in shots.get_children():
		n.queue_free()
	await _frames(1)
	var index := player.skills.skills.find_custom(func(s: SkillDef) -> bool: return s != null)
	player.skills._cooldowns[index] = 0.0
	player.skills.try_use(index, player, Vector2.RIGHT)
	await _frames(1)
	var near_hero := shots.get_children().filter(func(n: Node) -> bool: return (n as Projectile).global_position.distance_to(player.global_position) < 60.0)
	check(near_hero.size() >= 8, "Arcane: a skill also fires a ring of bolts (%d)" % near_hero.size())
	player.perks.clear()

	# Stat perks that now do something: Precision opens with a crit, Swiftness hits harder
	# after a roll, Iron Skin throws enemies back, the Guardian Ring wards every floor.
	player.perks.add(_perk("precision"))
	var opener := HitInfo.new()
	opener.amount = 10
	opener.source = player
	slime.hp = slime.get_max_hp()
	player.perks.modify_outgoing_hit(player, slime, opener)
	check(opener.is_crit and opener.amount > 10, "Precision: the first blow on an unhurt enemy is a crit")
	player.perks.clear()
	player.perks.add(_perk("swiftness"))
	var after_roll := HitInfo.new()
	after_roll.amount = 20
	after_roll.source = player
	player.perks.on_dash(player)
	player.perks.modify_outgoing_hit(player, slime, after_roll)
	check(after_roll.amount > 20, "Swiftness: hits right after a roll deal more")
	player.perks.clear()
	player.perks.add(_perk("iron_skin"))
	var pushed := world.spawn_monster(load("res://data/monsters/rat.tres"), player.global_position + Vector2(36, 0))
	pushed.dormant = true
	await _frames(1)
	var pushed_hp := pushed.hp
	var bite := HitInfo.new()
	bite.amount = 3
	bite.source = pushed
	player._invulnerable_time = 0.0
	player.take_hit(bite)
	check(pushed.is_dead or pushed.hp < pushed_hp, "Frost Armor: getting hit throws enemies back")
	check(pushed.is_dead or pushed.statuses.is_slowed(), "Frost Armor: and chills them")
	player.perks.clear()
	player.perks.add(_perk("guardian_ring"))
	player.ward = 0
	player.perks.on_floor_started(player)
	check(player.ward >= 20, "Guardian Ring: every floor starts with a ward")
	player.ward = 0
	player.perks.clear()

	# Gear affixes that do something: a Vampiric weapon heals on kill.
	var weapon_before := player.get_weapon()
	var vampiric: ItemAffixDef = load("res://data/affixes/vampiric.tres")
	var affixes: Array[ItemAffixDef] = [vampiric]
	var fang := LootRoller.make(weapon_before.base_item if weapon_before.base_item else weapon_before, ItemRarity.MAGIC, affixes)
	player.equipment.equip(fang)
	check(fang.get_details().contains(vampiric.description), "the item says what its affix does")
	player.hp = 5
	var prey := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	prey.dormant = true
	await _frames(1)
	var bite_back := HitInfo.new()
	bite_back.amount = 9999
	bite_back.source = player
	prey.take_hit(bite_back)
	check(player.hp > 5, "a Vampiric weapon heals on kill")
	player.equipment.equip(weapon_before)
	player.hp = 5
	var prey2 := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	prey2.dormant = true
	await _frames(1)
	prey2.take_hit(bite_back)
	check(player.hp == 5, "taken off, it stops")

	# Bestiary challenges: an elite slain by the hero, untouched since it saw them.
	Profile.reset()
	var done: Array[StringName] = []
	var on_done := func(_m: MonsterDef, c: HuntChallenge) -> void: done.append(c.id)
	Events.hunt_challenge_done.connect(on_done)
	var target := world.spawn_monster(load("res://data/monsters/rat.tres"), spot)
	world.make_elite(target)
	target.dormant = true
	await _frames(1)
	target.wake_up(player)
	await _frames(2)
	var finish := HitInfo.new()
	finish.amount = 99999
	finish.source = player
	target.take_hit(finish)
	await _frames(1)
	check(done.has(&"elite") and Profile.is_challenge_done(&"rat", &"elite"), "slaying an elite rat does its challenge")
	check(done.has(&"untouched"), "untouched since it saw the hero")
	check(Profile.souls > 0, "challenges pay souls")
	Events.hunt_challenge_done.disconnect(on_done)
	Profile.reset()

	# Blood: wounded you hit harder, kills heal.
	for id in ["vampirism", "bloodrage", "vitality"]:
		player.perks.add(_perk(id))
	player.hp = 1
	var hard := HitInfo.new()
	hard.amount = 20
	hard.source = player
	player.perks.modify_outgoing_hit(player, slime, hard)
	check(hard.amount > 20 + 1, "Blood: wounded, you hit harder (%d)" % hard.amount)
	player.perks.clear()

	for monster in [slime] + others:
		if is_instance_valid(monster) and not monster.is_dead:
			monster.die(null)
	player.hp = player.get_max_hp()
	player.xp = 0
	await _frames(5)


## Healing from hits and kills in the real game: burns and side effects heal nothing, whole
## points only, summons feed no heal, shards fired by a perk trigger no on-hit perk, and the
## hero's healing per second stays under the limit (DungeonConfig > Sustain).
func _test_sustain_in_game(world: World, player: Player) -> void:
	player.xp = -1000000  # no level up (it heals to full) from these kills
	player.perks.clear()
	player.invincible = true  # nothing else may change the hero's health meanwhile
	var spot := world.find_open_point_near(player.global_position, 90.0)
	var leech: RuneDef = load("res://data/runes/leech.tres")
	var ratio: float = (leech.passives[0] as LifestealPassive).ratio_per_stack
	var dummy := world.spawn_monster(load("res://data/monsters/slime.tres"), spot)
	dummy.dormant = true
	dummy.base_stats.max_hp = 999999
	dummy.base_stats.defense = 0
	dummy.invalidate_stats()
	dummy.hp = 999999
	await _frames(1)
	player.perks.set_gear([], [leech])
	player.sustain = SustainMeter.new()
	player.hp = 10
	dummy.take_hit(Combat.make_tick(player, 50))
	check(player.hp == 10, "Leech: a burn tick heals nothing")
	dummy.take_hit(Combat.make_secondary_hit(player, 50))
	check(player.hp == 10, "Leech: a secondary hit (shockwave, chain, thorns) heals nothing")
	# Small direct hits: the fractions add up, no point is given away per hit.
	var dealt := 0
	var healed := 0
	for i in 6:
		var before := dummy.hp
		var hp_before := player.hp
		var hit := HitInfo.new()
		hit.amount = 7
		hit.source = player
		dummy.take_hit(hit)
		dealt += before - dummy.hp
		healed += player.hp - hp_before
	check(healed == floori(dealt * ratio + 0.0001), "Leech: %d damage heals %d, not one point a hit (%d)" % [dealt, floori(dealt * ratio + 0.0001), healed])

	# Shards fired by a perk are secondary: they feed no lifesteal and no chains.
	var spec := ProjectileSpec.new()
	spec.secondary = true
	spec.damage = 30
	spec.speed = 600.0
	spec.max_distance = 300.0
	player.hp = 10
	player.sustain = SustainMeter.new()
	var dummy_hp := dummy.hp
	world.fire_projectiles(player, Vector2.RIGHT, spec, dummy.global_position + Vector2(-24, 0))
	await _frames(10)
	check(dummy.hp < dummy_hp and player.hp == 10, "a shard fired by a perk hurts (%d -> %d) but heals nothing (%d)" % [dummy_hp, dummy.hp, player.hp])

	# The limit: three Leech runes on big hits every frame for a second heal no more than the
	# budget (burst + one second of refill).
	var rules: SustainRules = world.rules.config.sustain
	player.perks.set_gear([], [leech, leech, leech])
	player.sustain = SustainMeter.new()
	player.hp = 1
	var max_hp := player.get_max_hp()
	for frame in 60:
		var big := HitInfo.new()
		big.amount = 40
		big.source = player
		dummy.take_hit(big)
		await get_tree().physics_frame
	var gained := player.hp - 1
	var allowed := rules.capacity(max_hp) + rules.refill_per_second(max_hp, false) * 1.05
	check(gained <= ceili(allowed) and gained >= floori(rules.capacity(max_hp)), "stacked Leech heals %d in a second, the limit is %d (asked for %d)" % [gained, ceili(allowed), roundi(40 * ratio * 3 * 60)])
	player.perks.set_gear(player.equipment.affixes(), player.equipment.runes())

	# Summons feed no "on kill" heal; ordinary monsters do.
	player.perks.add(_perk("vampirism"))
	player.sustain = SustainMeter.new()
	player.hp = 10
	var called := world.spawn_monster(load("res://data/monsters/rat.tres"), spot + Vector2(30, 0))
	called.summoned = true
	called.dormant = true
	var plain := world.spawn_monster(load("res://data/monsters/rat.tres"), spot + Vector2(-30, 0))
	plain.dormant = true
	await _frames(1)
	var kill := HitInfo.new()
	kill.amount = 99999
	kill.source = player
	called.take_hit(kill)
	check(called.is_dead and player.hp == 10, "Vampirism: a summoned monster's death heals nothing")
	plain.take_hit(kill)
	check(plain.is_dead and player.hp > 10, "Vampirism: an ordinary kill heals")
	player.perks.clear()
	dummy.die(null)
	player.invincible = false
	player.hp = player.get_max_hp()
	player.xp = 0
	await _frames(5)


## Skills come from the weapon and from tomes; statuses, delays, dash strikes, skill stats.
func _test_skills(game: Game, world: World, player: Player) -> void:
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
	player._invulnerable_time = 0.0
	await _frames(100)
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
	var split := big.traits.filter(func(t: MonsterTrait) -> bool: return t is DeathSpawnTrait)
	check(not split.is_empty() and newcomers.size() == (split[0] as DeathSpawnTrait).count, "a giant slime splits when it dies")
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
	var burst := flam.get_trait(DeathBurstTrait) as DeathBurstTrait
	await _frames(int(burst.fuse * 60.0) + 4)
	check(player.hp < hp_before, "a dying flame spirit explodes")
	player.statuses.clear()

	# Charges are telegraphed casts that cross the room.
	var beast: MonsterDef = load("res://data/monsters/beast.tres")
	check(beast.skills.any(func(skill: SkillDef) -> bool: return skill.cast_time > 0.0 and skill.effects[0] is DashStrikeEffect), "the beast charges (telegraphed)")
	player.hp = player.get_max_hp()
	player.base_stats.defense = 999
	player.invalidate_stats()
	await _frames(5)


## Difficulty multipliers reach monsters; the run uses the difficulty picked on the title screen.
func _test_difficulty_in_game(game: Game, world: World, player: Player) -> void:
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


## Every weapon swings or shoots, and both its skills work, in the real game.
func _test_weapon_kits(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	player.xp = -1000000
	var weapon_before := player.get_weapon()
	# No perks meanwhile (an Echo would leave a skill ready again, a family fire extra bolts).
	var perks_before := player.perks.to_data()
	player.perks.clear()
	# Alone with the target: a wandering monster stepping in the way would take the hits.
	await _clear_monsters(world)
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	target.dormant = true
	target.flies = true  # a big knockback must not send it down a hole
	target.base_stats.max_hp = 100000
	target.invalidate_stats()
	target.hp = 100000
	var target_spot := target.global_position
	for id in ["ninjaku", "rapier", "big_sword", "whip", "bow", "shuriken"]:
		var weapon: WeaponDef = load("res://data/items/weapons/%s.tres" % id)
		check(CONTENT.items.has(weapon), "%s can be found" % id)
		# Back in place: the previous weapons may have knocked it against a wall.
		target._knockback = Vector2.ZERO
		target.global_position = target_spot
		player.global_position = target_spot + Vector2(-50, 0)
		await _frames(2)
		player.equipment.equip(weapon)
		check(player.skills.skills[1] == weapon.skills[0] and player.skills.skills[2] == weapon.skills[1], "%s gives its two skills" % id)
		var hp_before := target.hp
		player._attack_cooldown = 0.0
		check(player.attack(Vector2.RIGHT) and player.rig.weapon.visible, "%s attacks with the weapon in hand" % id)
		await _frames(30)
		for slot in [1, 2]:
			player.skills._cooldowns[slot] = 0.0
			player.use_skill(slot)
			check(player.skills.cooldown_ratio(slot) > 0.0, "%s: %s is used" % [id, weapon.skills[slot - 1].id])
			await _frames(50)
		check(target.hp < hp_before, "%s hurts" % id)
	target.queue_free()
	player.equipment.equip(weapon_before)
	player.perks.load_data(perks_before)
	player.xp = 0
	await _frames(5)


## Shields, thieves, summoners and bombers.
func _test_monster_behaviours(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	var acts: Array = []
	for act in CONTENT.dungeon.acts:
		for m: MonsterDef in act.monsters:
			acts.append(m.id)
	for id in [&"shell_guard", &"thief_racoon", &"brood_mother", &"bomber", &"sand_drake"]:
		check(acts.has(id), "%s roams the Well" % id)

	# The wyrms: a body follows the head's path, burns at a touch, only the head takes hits.
	var bosses: Array = []
	for act in CONTENT.dungeon.acts:
		bosses.append_array(act.all_bosses().map(func(b: BossDef) -> StringName: return b.id))
	check(bosses.has(&"jade_wyrm") and bosses.has(&"azure_wyrm"), "the two wyrms guard acts")
	var wyrm := world.spawn_monster(load("res://data/monsters/bosses/jade_wyrm.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 3)))
	wyrm.dormant = true
	await _frames(2)
	var bodies := wyrm.get_children().filter(func(n: Node) -> bool: return n is WyrmBody)
	check(bodies.size() == 1, "a wyrm has a body")
	var body: WyrmBody = bodies[0]
	var start: Vector2 = body._points[0]
	for i in 30:
		wyrm.global_position += Vector2(4, 0)
		await _frames(1)
	check(body._points[0] != start and body._points[0].distance_to(wyrm.global_position) < 60.0, "the body follows the head")
	wyrm.dormant = false
	wyrm.skills.set_skills([] as Array[SkillDef])
	wyrm._attack_cooldown = 99.0
	wyrm.target = null
	player.hp = player.get_max_hp()
	player.ward = 0  # a Guardian Ring taken earlier would soak it
	var hp_before := player.hp
	var keep_at := wyrm.global_position
	for i in 3:
		player._invulnerable_time = 0.0
		player.global_position = body._points[3]
		wyrm.global_position = keep_at
		await _frames(1)
	check(player.hp < hp_before, "touching the body burns")
	wyrm.queue_free()
	player.hp = player.get_max_hp()
	await _frames(2)

	# Shell Guard: hits from the front are mostly blocked, hits in the back land in full.
	var shell := world.spawn_monster(load("res://data/monsters/shell_guard.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	shell.dormant = true
	await _frames(2)
	var lost := []
	var guard := shell.get_trait(GuardTrait) as GuardTrait
	check(guard != null, "the Shell Guard has a shield (GuardTrait)")
	for push: Vector2 in [Vector2.LEFT, Vector2.RIGHT]:
		shell.facing = Vector2.RIGHT
		guard.set_direction(shell, Vector2.RIGHT)
		shell._invulnerable_time = 0.0
		shell.hp = shell.get_max_hp()
		var hit := HitInfo.new()
		hit.amount = 20
		hit.knockback = push * 100.0  # pushed left = struck from the right, where the shell is
		shell.take_hit(hit)
		lost.append(shell.get_max_hp() - shell.hp)
	check(lost[0] * 3 < lost[1], "the shell blocks blows from the front (%d vs %d from behind)" % lost)
	var burn := Combat.make_secondary_hit(null, 10)
	shell.hp = shell.get_max_hp()
	shell.take_hit(burn)
	check(shell.get_max_hp() - shell.hp == Combat.mitigate(10, shell.get_stats().defense), "burns and blasts go around the shell")
	shell.queue_free()

	# Thief: grabs gold, runs, gives it back with interest when slain.
	var thief := world.spawn_monster(load("res://data/monsters/thief_racoon.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	await _frames(2)
	player.gold = 60
	player.hp = player.get_max_hp()
	player._invulnerable_time = 0.0
	player.take_hit(Combat.make_hit(1, 0.0, thief))
	var thievery := thief.get_trait(ThiefTrait) as ThiefTrait
	check(player.gold < 60 and thievery.stolen(thief) == 60 - player.gold, "the thief steals gold (%d)" % thievery.stolen(thief))
	check(not thief.can_attack(), "and runs instead of fighting")
	var stolen := thievery.stolen(thief)
	thief.die(player)
	await _frames(3)
	var dropped := 0
	for node in world.get_node("Entities").get_children():
		if node is GoldPickup:
			dropped += (node as GoldPickup).amount
	check(dropped + player.gold - (60 - stolen) > stolen, "slaying it gives the gold back, and more (%d)" % dropped)

	# Brood Mother lays spiders.
	var mother := world.spawn_monster(load("res://data/monsters/brood_mother.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	mother.dormant = true
	await _frames(2)
	var before := _count_monsters(world, &"spider")
	mother.skills.try_use(0, mother, Vector2.RIGHT)
	await _frames(2)
	check(_count_monsters(world, &"spider") == before + 2, "the Brood Mother lays spiders")
	for m in world.get_hostiles(Actor.Faction.PLAYER):
		if m is Monster and (m.def.id == &"spider" or m == mother):
			m.queue_free()

	# Bomber: lobbed bombs blow up.
	var bomber: MonsterDef = load("res://data/monsters/bomber.tres")
	var throw := bomber.skills[0].effects[0] as ProjectileEffect
	check(throw != null and throw.explosion_radius > 0.0 and bomber.keep_distance > 0.0, "the Bomber keeps away and throws bombs that explode")
	await _frames(2)


## Regressions found by the code review.
func _test_review_fixes(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	await _clear_monsters(world)
	player.hp = player.get_max_hp()
	player.ward = 0  # a Guardian Ring taken earlier would soak the burn
	while game.perk_panel.visible:  # a level up waiting would keep the game paused
		game.perk_panel.choose(0)
		await _frames(2)

	# A burn tick doesn't make the hero invulnerable (or monsters' hits would be swallowed).
	player._invulnerable_time = 0.0
	player.statuses.apply_dot(&"burn", 1, 0.1, 0.5, null, Color.ORANGE)
	await _frames(9)
	check(player.hp < player.get_max_hp() and player._invulnerable_time == 0.0, "burn ticks give no invulnerability frames")
	player.statuses.clear()
	player.hp = player.get_max_hp()

	# Slows: a frost hit wears off even while the cold keeps slowing a little.
	player.statuses.apply_slow(0.6, 0.2)
	for i in 30:
		player.statuses.apply_slow(0.1, 0.2, &"cold")
		await get_tree().physics_frame
	check(is_equal_approx(player.statuses.speed_multiplier(), 0.9), "a frost hit wears off under a lasting slow (%.2f)" % player.statuses.speed_multiplier())
	player.statuses.clear()

	# The same buff twice refreshes instead of stacking.
	var rage := StatBlock.new()
	rage.attack = 5
	var attack_before := player.get_stats().attack
	player.add_timed_bonus(rage, 1.0)
	player.add_timed_bonus(rage, 1.0)
	check(player.get_stats().attack == attack_before + 5, "a second elixir refreshes the first")

	# Shields know where a dash strike comes from (its knockback goes sideways).
	var shell := world.spawn_monster(load("res://data/monsters/shell_guard.tres"), world.map.cell_to_world(_open_cell_near(world, player.global_position, 2)))
	shell.dormant = true
	await _frames(2)
	shell.facing = Vector2.RIGHT
	(shell.get_trait(GuardTrait) as GuardTrait).set_direction(shell, Vector2.RIGHT)
	var dash := HitInfo.new()
	dash.amount = 20
	dash.knockback = Vector2.UP * 100.0
	dash.origin = shell.global_position + Vector2.RIGHT * 60.0
	var hp_before := shell.hp
	shell.take_hit(dash)
	check(hp_before - shell.hp <= 5, "the shell blocks a dash strike from the front (%d)" % (hp_before - shell.hp))
	shell.queue_free()

	# Summoned monsters give nothing (no farming a summoner).
	var summon := SummonEffect.new()
	summon.monsters = [load("res://data/monsters/slime.tres")]
	summon.count = 1
	summon.apply(player, Vector2.RIGHT)
	var minion: Monster = null
	for m in world.get_hostiles(Actor.Faction.PLAYER):
		if (m as Monster).summoned:
			minion = m
	check(minion != null, "summons are marked")
	if minion:
		var xp_before := player.xp
		var level_before := player.level
		minion.die(player)
		check(player.xp == xp_before and player.level == level_before, "a summoned monster gives no XP")
	await _frames(2)

	# No XP for a dead hero (a kill landing after the hero's death would heal him to full).
	var dead_xp := player.xp
	player.is_dead = true
	player.gain_xp(99999)
	check(player.xp == dead_xp, "a dead hero gains nothing")
	player.is_dead = false

	# Saves: written in one step, and a half-written file never replaces a good one.
	var path := "user://test_safe_%d.json" % OS.get_process_id()
	check(SafeFile.write_json(path, {"a": 1}) and SafeFile.read_json(path).a == 1.0, "safe save round trip")
	var cut := FileAccess.open(path, FileAccess.WRITE)
	cut.store_string("{\"a\": ")
	cut.close()
	var temp := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	temp.store_string("{\"a\": 2}")
	temp.close()
	check(SafeFile.read_json(path) != null and SafeFile.read_json(path).a == 2.0, "a damaged save falls back on the last full write")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))

	# Taking the stairs: no menu, no second descent until the next floor is there.
	var depth_before: int = game.depth
	game._on_stairs_reached()
	game._on_stairs_reached()
	check(game.is_menu_open() and game.depth == depth_before, "during the descent: no menus, and the depth changes only on arrival")
	game.open_pause_menu()
	check(not game.pause_menu.visible, "the pause menu can't open in the middle of the stairs")
	for i in 120:
		if not game._transitioning:
			break
		await _frames(1)
	check(game.depth == depth_before + 1 and not get_tree().paused, "one floor down, game running (depth %d)" % game.depth)
	await _frames(5)


## What isn't seen sleeps; monsters spot the hero further on harder difficulties; they walk
## around what their body can't cross and get unstuck; they find the hero from the next room.
func _test_ai_movement(game: Game) -> void:
	var world: World = game.world
	var player: Player = game.player
	player.invincible = true
	await _clear_monsters(world)
	var rat_def: MonsterDef = load("res://data/monsters/rat.tres")

	# Sleep and wake.
	var far_room := world.map.rooms[0]
	var far_distance := 0.0
	for room in world.map.rooms:
		var d := world.map.cell_to_world(room.get_center()).distance_to(player.global_position)
		if d > far_distance:
			far_distance = d
			far_room = room
	var sleeper := world.spawn_monster(rat_def, _solid_point_in(world, far_room))
	var near := world.spawn_monster(rat_def, player.global_position + Vector2(120, 0))
	await _frames(20)
	check(far_distance > 1200.0, "a room far off screen (%d px)" % far_distance)
	check(not sleeper.is_awake and sleeper.process_mode == Node.PROCESS_MODE_DISABLED, "a monster far off screen sleeps")
	check(near.is_awake and world.awake_monsters.has(near) and not world.awake_monsters.has(sleeper), "one in view thinks")
	var spot := sleeper.global_position
	await _frames(30)
	check(sleeper.global_position == spot, "a sleeping monster doesn't move")
	var hit := HitInfo.new()
	hit.amount = 1
	hit.source = player
	sleeper.take_hit(hit)
	check(sleeper.is_awake, "hit from afar, it wakes up")
	await _frames(20)
	check(sleeper.is_awake and sleeper.target == player, "and stays awake while it hunts")
	await _clear_monsters(world)

	# Further on harder difficulties.
	var before := world.difficulty
	world.difficulty = CONTENT.get_difficulty(&"easy")
	world.rules = FloorRules.make(CONTENT.dungeon, world.difficulty, null, world.depth)
	var easy_rat := world.spawn_monster(rat_def, player.global_position + Vector2(80, 0))
	world.difficulty = CONTENT.get_difficulty(&"nightmare")
	world.rules = FloorRules.make(CONTENT.dungeon, world.difficulty, null, world.depth)
	var nightmare_rat := world.spawn_monster(rat_def, player.global_position + Vector2(80, 0))
	check(nightmare_rat.detect_radius() > rat_def.detect_radius and easy_rat.detect_radius() < rat_def.detect_radius, "monsters spot the hero from further on Nightmare (%d), closer on Easy (%d)" % [nightmare_rat.detect_radius(), easy_rat.detect_radius()])
	world.difficulty = before
	world.rules = FloorRules.make(CONTENT.dungeon, before, world.floor_event, world.depth, world.curse)
	await _clear_monsters(world)

	# A clear walk: open floor yes; a blocked cell (a pond, a hole, a prop) on the way, no.
	var cell := _open_cell_near(world, player.global_position, 3)
	var walker := world.spawn_monster(rat_def, world.map.cell_to_world(cell))
	walker.get_node("StateMachine").process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	var ahead := world.map.cell_to_world(cell + Vector2i(3, 0))
	check(walker.has_clear_walk(ahead), "a clear walk on open floor")
	world.set_cell_blocked(cell + Vector2i(2, 0), true)
	walker._walk_checks.clear()
	check(not walker.has_clear_walk(ahead), "not across a blocked cell, even in sight")
	world.set_cell_blocked(cell + Vector2i(2, 0), false)
	walker._walk_checks.clear()
	var other_side := world.map.cell_to_world(cell) + Vector2(0, -2000)
	check(not walker.has_clear_walk(other_side), "nor through walls")

	# Walking into a wall: stuck.
	var wall_dir := Vector2.ZERO
	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c := cell
		var steps := 0
		while world.map.is_floor(c) and steps < 40:
			c += dir
			steps += 1
		if not world.map.is_floor(c):
			wall_dir = Vector2(dir)
			walker.global_position = world.map.cell_to_world(c - dir)
			break
	walker.target = player  # (hunting: it stays awake wherever it stands)
	walker.move_direction = wall_dir
	await _frames(40)
	check(walker.is_stuck(), "walking into a wall for a moment: stuck")
	walker.move_direction = -wall_dir
	await _frames(40)
	check(not walker.is_stuck(), "walking away: not stuck any more")
	await _clear_monsters(world)

	# From another room, out of sight, around the walls: it finds the hero.
	var hunter_spot := Vector2.INF
	for room in world.map.rooms:
		var candidate := _solid_point_in(world, room)
		if world.has_line_of_sight(candidate, player.global_position):
			continue
		var path := world.find_path(candidate, player.global_position)
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		if length >= 300.0 and length <= 900.0:
			hunter_spot = candidate
			break
	check(hunter_spot != Vector2.INF, "a room out of sight, a short walk away")
	if hunter_spot != Vector2.INF:
		var hunter := world.spawn_monster(rat_def, hunter_spot)
		hunter.get_node("StateMachine").transition_to(&"Chase")
		var reached := false
		var closest := INF
		for i in 60 * 12:
			hunter.target = player  # (it knows where the hero is: a hunt, not a search)
			await _frames(1)
			if not is_instance_valid(hunter) or hunter.is_dead:
				break
			var d := hunter.global_position.distance_to(player.global_position)
			closest = minf(closest, d)
			if d <= hunter.attack_range(player) + 24.0:
				reached = true
				break
		check(reached, "a monster finds its way to the hero around the walls (closest %d px)" % closest)
	await _clear_monsters(world)
	player.invincible = false

