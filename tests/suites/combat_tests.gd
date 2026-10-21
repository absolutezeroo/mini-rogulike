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
	_killing_blow(player)
	check(not player.is_dead and game.threshold.is_open(), "Phoenix Feather survives a killing blow (off to the Threshold)")
	check(player.perks.get_entry(phoenix).memory.get(&"used", 0) == 1, "the feather is used up")
	check(await _win_trial(game) and not player.is_dead and player.hp >= player.get_max_hp() / 3, "won, the hero is back on his feet")
	# Where there is no Threshold (the balance tools' bare arena), a second life heals in place.
	var in_place := (phoenix.passives[0] as CheatDeathPassive).duplicate() as CheatDeathPassive
	in_place.trial = null
	var spare := PerkSet.Entry.new()
	spare.perk = phoenix
	player.hp = 0
	check(in_place.prevent_death(player, spare) and player.hp == roundi(player.get_max_hp() * in_place.heal_ratio) and not game.threshold.is_open(), "without a trial, a second life heals in place")
	player.perks.clear()
	player.hp = player.get_max_hp()
	await _frames(10)

	# Level up: a moment in the world, nothing opens, the fight goes on. The choice waits behind
	# the HUD's perk button (with how many wait); tapping it opens 3 perks and pauses.
	var offers_button := game.hud.get_node("%OffersButton") as OffersButton
	check(not offers_button.visible and game.pending_offers() == 0, "no perk button while no choice waits")
	player.gain_xp(player.xp_to_next_level())
	await _frames(2)
	check(not game.perk_panel.visible and not get_tree().paused and not game.is_menu_open(), "a level up opens nothing and doesn't pause")
	check(player.get_children().any(func(n: Node) -> bool: return n is LevelUpVfx), "a level up lights rings around the hero instead")
	check(offers_button.visible and offers_button.count == 1 and game.pending_offers() == 1, "the perk button shows 1 choice waiting")
	await _frames(120)
	check(not game.perk_panel.visible and game.pending_offers() == 1 and not player.get_children().any(func(n: Node) -> bool: return n is LevelUpVfx), "the moment passes, the choice keeps waiting")
	check(await _tap_offers(game), "the perk button can be tapped")
	check(game.perk_panel.visible and get_tree().paused, "tapping it opens the perk choice and pauses")
	check(game.perk_panel.modulate.a < 0.99, "the choice fades in (no hard cut): %.2f" % game.perk_panel.modulate.a)
	check(not offers_button.visible and game.pending_offers() == 0, "the choice on screen is no longer counted")
	var cards: HBoxContainer = game.perk_panel.get_node("%Cards")
	check(cards.get_child_count() == 3, "three cards")
	check((cards.get_child(0) as Button).disabled, "cards ignore taps for a moment (no accidental pick)")
	await get_tree().create_timer(0.6, true).timeout
	check(not (cards.get_child(0) as Button).disabled, "cards become pickable")
	check(is_equal_approx(game.perk_panel.modulate.a, 1.0), "the choice is fully in after its fade")
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
	check(not game.perk_panel.visible and offers_button.visible and offers_button.count == 2, "two level ups: nothing opens, the button counts 2")
	# Later (and Back) put a choice off: back to the fight, it waits with the same cards.
	check(game.open_offers() and game.perk_panel.visible, "open_offers() opens the first choice")
	var put_off := game.perk_panel.get_offered().duplicate()
	(game.perk_panel.get_node("%LaterButton") as Button).pressed.emit()
	await _frames(2)
	check(not game.perk_panel.visible and not get_tree().paused and offers_button.count == 2, "Later: back to the game, both choices still wait")
	await _tap_offers(game)
	check(game.perk_panel.visible and game.perk_panel.get_offered() == put_off, "a choice put off comes back with the same cards (no free reroll)")
	game._back()
	await _frames(2)
	check(not game.perk_panel.visible and not get_tree().paused and game.pending_offers() == 2, "Back puts it off too")
	await _tap_offers(game)
	check(game.perk_panel.visible, "first of two choices")
	game.perk_panel.choose(0)
	await _frames(2)
	check(game.perk_panel.visible, "second choice follows right away")
	game.perk_panel.choose(0)
	await _frames(2)
	check(not offers_button.visible and game.pending_offers() == 0, "all taken: the perk button goes away")
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

	# Healing spells heal in full outside a boss fight, and half during one.
	for id in ["holy_light", "holy_shield", "smite"]:
		var spell: SkillDef = load("res://data/skills/player/%s.tres" % id)
		for effect in spell.effects:
			if effect is HealEffect:
				var heal := effect as HealEffect
				check(heal.boss_fight_ratio <= 0.5 and not world.is_boss_fight()
					and heal.heal_amount(player) == heal.amount + roundi(player.get_max_hp() * heal.max_hp_ratio),
					"%s heals in full outside a boss fight, half during one" % id)

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


## The attack button (docs/design/interface.md): a tap is one basic attack, holding no longer
## repeats it but charges the weapon's charged attack (after a delay: taps never charge), shown
## by a gauge at the hero's feet and on the button; let go full, it goes off; a roll cancels it,
## a hit doesn't; every hero's weapon's charged attack works; a save doesn't keep a charge. And
## the hero's own effects never hide him (docs/vfx.md 2b).
func _test_charged_attacks(game: Game) -> void:
	var player: Player = game.player
	var world: World = game.world
	player.xp = -1000000
	var weapon_before := player.get_weapon()
	var perks_before := player.perks.to_data()
	player.perks.clear()
	await _clear_monsters(world)
	var spot := world.map.cell_to_world(_open_cell_near(world, player.global_position, 3))
	var target := world.spawn_monster(load("res://data/monsters/slime.tres"), spot + Vector2(40, 0))
	target.dormant = true
	target.flies = true
	target.base_stats.max_hp = 100000
	target.invalidate_stats()
	target.hp = 100000
	var place := func() -> void:
		target._knockback = Vector2.ZERO
		target.global_position = spot + Vector2(40, 0)
		player.global_position = spot
		player._knockback = Vector2.ZERO
	var attacks := [0]
	var unleashed: Array[ChargedAttackDef] = []
	var count_attack := func() -> void: attacks[0] += 1
	var count_charged := func(attack: ChargedAttackDef) -> void: unleashed.append(attack)
	player.attacked.connect(count_attack)
	player.charged_attack.connect(count_charged)
	var katana: WeaponDef = load("res://data/items/weapons/katana.tres")
	player.equipment.equip(katana)
	place.call()
	await _frames(40)
	var button: ActionButton = game.hud.get_node("%AttackButton")

	# A tap: one basic attack, no charge.
	var hp_before := target.hp
	_set_action(&"attack", true)
	await _frames(3)
	_set_action(&"attack", false)
	await _frames(10)
	check(attacks[0] == 1 and target.hp < hp_before, "charged: a tap is one basic attack (%d)" % attacks[0])
	check(unleashed.is_empty() and player.charge.state == AttackCharge.State.IDLE and not player.charge_vfx.is_showing(), "charged: a tap never charges")
	await _frames(30)

	# Held: one attack, then it charges (no more swings), slower, the gauge shows; let go: off.
	attacks[0] = 0
	var speed := player.get_move_speed()
	_set_action(&"attack", true)
	await _frames(int(player.def.charge_delay * 60.0) - 4)
	check(not player.charge.is_charging(), "charged: not before the delay")
	await _frames(12)
	check(player.charge.is_charging() and player.charge.ratio < 0.5, "charged: held past the delay, it charges")
	check(player.get_move_speed() < speed * 0.8, "charged: the hero is slower while charging (%.0f / %.0f)" % [player.get_move_speed(), speed])
	await _frames(2)
	check(player.charge_vfx.is_showing(), "charged: its gauge is at his feet")
	check(button.charge_ratio > 0.0, "charged: and on the attack button")
	check(VfxLayer.of(player.charge_vfx._ring) == VfxLayer.Layer.GROUND and player.charge_vfx._ring.z_index < 0, "charged: the gauge lies on the floor, under his feet")
	check(player.charge_vfx.get_parent() == player and player.charge_vfx.z_as_relative and player.charge_vfx.z_index == 0, "charged: the glow in his hand is on his body, never over it all")
	check(player.rig.weapon.visible, "charged: the weapon is held up in his hand")
	player.take_hit(Combat.make_secondary_hit(target, 1))
	check(player.charge.is_charging(), "charged: being hit does not cancel it")
	for i in 90:
		if player.charge.is_full():
			break
		await _frames(1)
	await _frames(1)
	check(player.charge.is_full() and player.charge_vfx.lit_steps() == ChargeVfx.STEPS and button.charge_full, "charged: it fills, the gauge full")
	check(attacks[0] == 1, "charged: holding no longer repeats the attack (%d)" % attacks[0])
	hp_before = target.hp
	_set_action(&"attack", false)
	await _frames(20)
	check(unleashed.size() == 1 and unleashed[0] == katana.charged, "charged: let go full, the katana's charged attack goes off")
	check(target.hp < hp_before, "charged: and hits")
	check(player.charge.state == AttackCharge.State.IDLE and not button.charge_full, "charged: the charge is spent")
	await _frames(20)
	check(not player.charge_vfx.is_showing(), "charged: the gauge goes")

	# A roll cancels it, until the button is let go.
	place.call()
	player.skills._cooldowns[0] = 0.0
	_set_action(&"attack", true)
	await _frames(int(player.def.charge_delay * 60.0) + 10)
	check(player.charge.is_charging(), "charged: charging again")
	_set_action(&"skill_1", true)
	await _frames(2)
	_set_action(&"skill_1", false)
	await _frames(70)
	check(player.charge.state == AttackCharge.State.SPENT and not player.charge.is_charging(), "charged: a roll cancels it")
	_set_action(&"attack", false)
	await _frames(5)
	check(unleashed.size() == 1, "charged: nothing goes off after a roll")

	# A save keeps no charge; the weapon keeps its charged attack.
	_set_action(&"attack", true)
	await _frames(int(player.def.charge_delay * 60.0) + 10)
	var saved := player.save_state()
	check(not JSON.stringify(saved).contains("charge"), "charged: the save has no charge in it")
	player.load_state(saved)
	check(player.charge.state == AttackCharge.State.IDLE and player.get_weapon().charged == katana.charged, "charged: back from a save, no charge, the same charged attack")
	_set_action(&"attack", false)
	await _frames(30)

	# Every hero's weapon: held full, let go, its charged attack hits.
	for file in DirAccess.get_files_at("res://data/items/weapons"):
		if not file.ends_with(".tres"):
			continue
		var weapon: WeaponDef = load("res://data/items/weapons/" + file)
		player.equipment.equip(weapon)
		place.call()
		await _frames(30)
		place.call()
		hp_before = target.hp
		var before := unleashed.size()
		_set_action(&"attack", true)
		for i in 150:
			if player.charge.is_full():
				break
			await _frames(1)
		var full := player.charge.is_full()
		_set_action(&"attack", false)
		await _frames(50)
		check(full and unleashed.size() == before + 1 and unleashed[-1] == weapon.charged, "charged: %s's charged attack goes off" % weapon.id)
		check(target.hp < hp_before, "charged: %s's charged attack hits" % weapon.id)
	player.attacked.disconnect(count_attack)
	player.charged_attack.disconnect(count_charged)

	# The hero's own effects never hide him: a staff's shot leaves his hand without a claw over
	# him, behind him going north; the level up's column stands behind him, its rings on the floor.
	var staff: WeaponDef = load("res://data/items/weapons/stick.tres")
	player.equipment.equip(staff)
	place.call()
	await _frames(20)
	player._attack_cooldown = 0.0
	var fx_before := player.rig.get_children().filter(func(n: Node) -> bool: return n is SheetVfx).size()
	player.attack(Vector2.UP)
	await _frames(2)
	check(player.rig.get_children().filter(func(n: Node) -> bool: return n is SheetVfx).size() == fx_before, "own effects: a staff's shot plays no claw over the hero")
	var shots := world.get_node("Projectiles").get_children()
	check(not shots.is_empty() and (shots[-1] as Node2D).z_index < 0, "own effects: his shot going north starts behind him")
	check(not shots.is_empty() and (shots[-1] as Node2D).global_position.y < player.global_position.y - 4.0, "own effects: it leaves from his hand, not his feet")
	var north_shot: Node2D = shots[-1] if not shots.is_empty() else null
	await _frames(8)
	check(not is_instance_valid(north_shot) or north_shot.z_index == 0, "own effects: clear of him, it flies over the bodies")
	player._attack_cooldown = 0.0
	player.attack(Vector2.DOWN)
	await _frames(2)
	shots = world.get_node("Projectiles").get_children()
	check(not shots.is_empty() and (shots[-1] as Node2D).z_index == 0, "own effects: his shot going south is in front of him")
	var lance: WeaponDef = load("res://data/items/weapons/lance.tres")
	player.equipment.equip(lance)
	await _frames(2)
	player._attack_cooldown = 0.0
	player.attack(Vector2.UP)
	await _frames(1)
	var swings := world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is SwingVfx)
	check(not swings.is_empty() and (swings[-1] as Node2D).global_position.y < player.global_position.y, "own effects: his thrust north sorts behind him")
	await _frames(30)
	player.rig.play_attack(load("res://data/items/weapons/monster/frost_fang.tres"), Vector2.RIGHT, 0.3)
	check(player.rig.get_children().any(func(n: Node) -> bool: return n is SheetVfx), "own effects: a creature's frost bite still claws (melee)")
	await _frames(30)
	LevelUpVfx.attach(player)
	await _frames(2)
	var level_up: LevelUpVfx = null
	for child in player.get_children():
		if child is LevelUpVfx:
			level_up = child
	check(level_up != null and level_up.show_behind_parent and level_up.z_as_relative and level_up.z_index == 0, "own effects: the level up's column stands behind the hero")
	check(level_up != null and VfxLayer.of(level_up._rings) == VfxLayer.Layer.GROUND and level_up._rings.z_index < 0, "own effects: its rings lie on the floor")
	check(level_up != null and level_up._glints.z_index > LightField.Z, "own effects: only a few glints at his sides shine in front")
	var shield: SkillDef = load("res://data/skills/player/holy_shield.tres")
	(shield.effects[0] as Effect).apply(player, Vector2.DOWN)
	var aegis := player.get_children().filter(func(n: Node) -> bool: return n is SheetVfx)
	check(not aegis.is_empty() and (aegis[-1] as Node2D).show_behind_parent, "own effects: Holy Shield's halo rises behind the hero")
	await _frames(100)

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
	# (The wall with the most open floor behind it, so walking away really goes somewhere.)
	var wall_dir := Vector2.ZERO
	var best_room := -1
	for dir: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var c := cell
		var steps := 0
		while world.map.is_floor(c) and steps < 40:
			c += dir
			steps += 1
		if world.map.is_floor(c):
			continue
		var room := 0
		while room < 12 and world.map.is_floor(c - dir * (room + 2)) and not world.nav.is_blocked(c - dir * (room + 2)):
			room += 1
		if room > best_room:
			best_room = room
			wall_dir = Vector2(dir)
			walker.global_position = world.map.cell_to_world(c - dir)
	walker.target = player  # (hunting: it stays awake wherever it stands)
	walker.move_direction = wall_dir
	await _frames(40)
	check(walker.is_stuck(), "walking into a wall for a moment: stuck")
	walker.move_direction = -wall_dir
	var stuck_at := walker.global_position
	for i in 120:  # (a prop or a pond a few steps back may slow it a moment)
		walker.target = player
		await _frames(1)
		if not walker.is_stuck():
			break
	check(not walker.is_stuck(), "walking away: not stuck any more (moved %d px, %d free cells behind, awake %s, %s)" % [walker.global_position.distance_to(stuck_at), best_room, world.awake_monsters.has(walker), walker.get_node("StateMachine").process_mode])
	await _clear_monsters(world)

	# From another room, out of sight, around the walls: it finds the hero.
	# (The room whose walk is closest to 600 px: layouts change with the data, so no fixed window.)
	var hunter_spot := Vector2.INF
	var best_gap := INF
	for room in world.map.rooms:
		var candidate := _solid_point_in(world, room)
		if world.has_line_of_sight(candidate, player.global_position):
			continue
		var path := world.find_path(candidate, player.global_position)
		var length := 0.0
		for k in range(1, path.size()):
			length += path[k - 1].distance_to(path[k])
		if length >= 250.0 and length <= 1500.0 and absf(length - 600.0) < best_gap:
			best_gap = absf(length - 600.0)
			hunter_spot = candidate
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



## The trial of the Threshold: a killing blow with a second life pulls the hero into the limbo
## while his floor waits out of the tree; won, he is back on the very spot with the floor as it
## was. Each feather opens one trial.
func _test_threshold(game: Game, world: World, player: Player) -> void:
	var threshold := game.threshold
	var feather := _perk("phoenix_feather")
	var trial := (feather.passives[0] as CheatDeathPassive).trial
	check(trial != null, "the Phoenix Feather opens the trial of the Threshold")
	await _clear_monsters(world)
	player.perks.clear()
	player.hp = player.get_max_hp()
	player.perks.add(feather)
	# Two monsters wait on the floor, out of the blast's reach; one is hurt and burning.
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	var watchers: Array[Monster] = []
	for spot in _free_points_away(world, player.global_position, 6, 10, 2):
		var watcher := world.spawn_monster(skeleton, spot)
		watcher.dormant = true
		watchers.append(watcher)
	check(watchers.size() == 2, "two monsters to watch over")
	if watchers.size() < 2:
		return
	await _frames(1)
	watchers[0].hp -= 3
	watchers[0].statuses.apply_dot(&"burn", 1, 0.5, 30.0, player, Palette.FIRE)
	player.statuses.apply_dot(&"poison", 1, 0.5, 30.0, null, Color(0.5, 0.9, 0.6))
	game._save_run()
	var saved := RunSave.read()
	var floor_mode := world.process_mode
	var fell_at := player.global_position
	var floor_children := world.get_node("Entities").get_child_count()
	_killing_blow(player, watchers[1])
	check(not player.is_dead and threshold.is_open(), "a killing blow with a second life opens the Threshold")
	await get_tree().process_frame
	check(world.process_mode == Node.PROCESS_MODE_DISABLED, "the floor stops where it is")
	var frozen_at: Array[Vector2] = [watchers[0].global_position, watchers[1].global_position]
	var hp_then: Array[int] = [watchers[0].hp, watchers[1].hp]
	var burn_left: float = watchers[0].statuses._dots[0].time_left
	var clock := game.run.time
	check(await _until_trial(game), "the veil lifts on the trial")
	var limbo := threshold.limbo
	check(limbo != null and player.world == limbo and limbo.is_ancestor_of(player), "the hero is in the limbo")
	check(not world.is_inside_tree() and game.world == world, "his floor waits, out of the tree")
	check(player.hp == maxi(1, roundi(player.get_max_hp() * trial.hero_health)), "he fights at %d%% of his Health" % roundi(trial.hero_health * 100.0))
	check(player.statuses.is_empty(), "his statuses stay behind")
	check(threshold.needed == trial.kills_for(world.depth, CONTENT.dungeon) and threshold.time_left <= trial.time_for(world.depth, CONTENT.dungeon), "the rules of his act: %d spectres, %d s" % [threshold.needed, roundi(threshold.time_limit)])
	var spectres := limbo.get_hostiles(Actor.Faction.PLAYER)
	check(not spectres.is_empty(), "spectres rise")
	if not spectres.is_empty():
		var spectre := spectres[0] as Monster
		check(spectre.summoned and spectre.modulate.a < 1.0 and (spectre.rig == null or spectre.rig.pallor > 0.0), "pale, see-through and worth nothing (no XP, gold or loot)")
		check(spectre.target == player, "and they come for him")
	check((game.hud.get_node("ThresholdHud") as Control).visible and not (game.hud.get_node("%Minimap") as Control).visible, "the HUD shows the trial, not the floor's map")
	check(not (game.hud.get_node("%BagButton") as Control).visible, "no bag button in there")
	game._save_run()
	check(RunSave.read() == saved, "nothing is saved during the trial")
	game.open_inventory()
	check(not game.inventory_panel.visible, "the bag stays shut in the Threshold")
	await _frames(30)
	check(game.run.time > clock + 0.3, "the run's clock keeps counting")
	check(watchers[0].global_position == frozen_at[0] and watchers[1].global_position == frozen_at[1], "the floor's monsters wait where they stood")
	# Won: home, as if nothing had moved.
	var home := {}
	threshold.closed.connect(func(won: bool) -> void:
		home.won = won
		home.at = [watchers[0].global_position, watchers[1].global_position]
		home.hp = [watchers[0].hp, watchers[1].hp]
		home.burn = watchers[0].statuses._dots[0].time_left if watchers[0].statuses.has(&"burn") else -1.0, CONNECT_ONE_SHOT)
	check(await _win_trial(game) and home.get("won", false), "slaying them all wins the trial")
	check(player.world == world and world.is_inside_tree() and world.process_mode == floor_mode, "the hero is back on his floor, and it runs again")
	check(player.global_position == fell_at and player.get_parent() == world.get_node("Entities"), "on the very spot he fell")
	check(home.get("at", []) == frozen_at and home.get("hp", []) == hp_then, "the floor's monsters as they were (same place, same Health)")
	check(is_equal_approx(float(home.get("burn", -1.0)), burn_left), "their statuses too (%.2f s of burn left)" % float(home.get("burn", -1.0)))
	check(world.get_node("Entities").get_child_count() == floor_children, "nothing came or went on the floor")
	check(not player.is_dead and player.hp == roundi(player.get_max_hp() * (feather.passives[0] as CheatDeathPassive).heal_ratio), "back at half Health")
	check(player._invulnerable_time > 0.0, "with a moment of grace")
	check(threshold.limbo == null and (game.hud.get_node("%Minimap") as Control).visible and not (game.hud.get_node("ThresholdHud") as Control).visible, "the limbo is gone, the HUD is the floor's again")
	check(Profile.stat_value("thresholds") >= 1 and Profile.is_achieved(&"not_yet"), "it counts (the Not Yet achievement)")
	await _frames(2)
	check(not is_instance_valid(limbo), "the limbo is freed")
	# The feather is spent: one trial per stack.
	var entry := player.perks.get_entry(feather)
	check(not (feather.passives[0] as CheatDeathPassive).prevent_death(player, entry) and not threshold.is_open(), "a spent feather opens no trial (once per stack)")
	player.perks.add(feather)
	_killing_blow(player, watchers[0])
	check(threshold.is_open() and player.perks.get_entry(feather).memory.get(&"used", 0) == 2, "a second feather, a second trial")
	check(await _until_trial(game) and await _win_trial(game) and not player.is_dead, "won again")
	for watcher in watchers:
		watcher.die(null)
	player.perks.clear()
	player.hp = player.get_max_hp()
	await _frames(5)


## The trial lost: the hero dies for real, back where he fell, of what slew him the first time.
## Slain in there (a second feather doesn't help), or the knell tolls first; or he gives up in
## there (pause menu): his floor comes back all the same.
func _test_threshold_lost(game: Game) -> void:
	var skeleton: MonsterDef = load("res://data/monsters/skeleton.tres")
	for how in ["slain inside", "the knell tolled", "gave up"]:
		game.start_run()
		await _frames(5)
		var player := game.player
		var world := game.world
		var feather := _perk("phoenix_feather")
		player.perks.add(feather)
		var killer := world.spawn_monster(skeleton, _free_points_away(world, player.global_position, 6, 10, 1)[0])
		killer.dormant = true
		var fell_at := player.global_position
		_killing_blow(player, killer)
		check(await _until_trial(game), "the trial opens")
		match how:
			"the knell tolled":
				game.threshold.time_left = 0.05
			"gave up":
				player.give_up()
			_:
				player.perks.add(feather)  # a second feather: no help in there
				var spectre := game.threshold.limbo.get_hostiles(Actor.Faction.PLAYER)[0]
				_killing_blow(player, spectre)
				check(not player.is_dead and game.threshold.state == Threshold.State.LEAVING, "slain in the Threshold, the trial is lost")
				check(player.perks.get_entry(feather).memory.get(&"used", 0) == 1, "no second feather spent in there")
		check(await _until_home(game), "the hero is taken back (%s)" % how)
		check(player.is_dead, "the trial lost (%s), he dies for real" % how)
		var cause := tr("giving up") if how == "gave up" else killer.display_name
		check(player.killed_by == cause, "of what slew him (%s)" % player.killed_by)
		check(player.world == world and world.is_inside_tree() and player.global_position == fell_at, "where he fell")
		check(game.threshold.limbo == null and world.process_mode != Node.PROCESS_MODE_DISABLED, "the limbo is gone, the floor runs")
		await get_tree().create_timer(1.5).timeout
		check(game.game_over_panel.visible and not RunSave.exists(), "the run ends")


## Up to `count` free floor points between `near` and `far` cells from `from`, spread apart.
func _free_points_away(world: World, from: Vector2, near: int, far: int, count: int) -> Array[Vector2]:
	var origin := world.map.world_to_cell(from)
	var found: Array[Vector2] = []
	for y in range(origin.y - far, origin.y + far + 1):
		for x in range(origin.x - far, origin.x + far + 1):
			var cell := Vector2i(x, y)
			var distance := Vector2(cell - origin).length()
			if distance < near or distance > far or not world.map.in_bounds(cell) or not world.is_free_cell(cell):
				continue
			var point := world.map.cell_to_world(cell)
			if found.all(func(other: Vector2) -> bool: return other.distance_to(point) > 128.0):
				found.append(point)
				if found.size() >= count:
					return found
	return found
