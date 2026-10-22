class_name FinaleTests
extends TestSuite
## In the game: the bottom of the Well (FinaleDef). The gate (no win: the last act's boss ends
## the run as before; a won profile: it leads down instead), saving between the last act's boss
## and the bottom, Tôma's fall and the Maw rising (no relic), the Maw's jaw (hits glance off
## while closed, land while open; it draws the hero in and bites), the win, the ending chosen
## (kept in the profile, its achievement), and a run picked up before the choice.


func _test_finale(game: Game) -> void:
	var finale := CONTENT.dungeon.finale
	check(finale != null and finale.boss != null and finale.boss.next_boss != null and finale.endings.size() == 2, "the bottom of the Well has its two forms and its two endings")
	if finale == null or finale.boss == null:
		return
	var total := CONTENT.dungeon.total_floors()

	# No win yet: the bottom is closed, the last act's boss wins the run (the first ending).
	Profile.reset()
	game.start_run()
	await _frames(3)
	check(not game.run.finale_open, "no win yet: the way to the bottom of the Well is closed")
	game.depth = total
	game._enter_floor()
	await _frames(3)
	check(not game.run.leads_to_finale() and game.world.next_routes.all(func(r: FloorRoute) -> bool: return r.biome != finale.biome), "the last act's arena leads to no bottom before a win")
	check(game.run.wins_with(game.world.arena.boss.def as BossDef), "its boss still wins the run (the first ending)")

	# A won profile (a Pilgrim win counts): the last act's boss leads down instead.
	Profile.wins = { "easy": 1 }
	game.start_run()
	await _frames(3)
	check(game.run.finale_open, "a won profile (even on Pilgrim): the way down to the bottom opens")
	var finish_floor := await _slay_last_act_boss(game)
	check(finish_floor, "the last act's boss falls")
	check(not game.has_won and game.run.finish_time < 0.0, "with the bottom open, the last act's boss no longer ends the run")
	check(game.world.next_routes.size() == 1 and game.world.next_routes[0].biome == finale.biome, "its arena opens one way down: to the bottom")
	var stairs := game.world.get_node("Entities").get_children().filter(func(n: Node) -> bool: return n is Stairs)
	check(stairs.size() == 1 and (stairs[0] as Stairs).route != null and (stairs[0] as Stairs).route.biome == finale.biome, "its stairs are signed with the bottom's name")
	check(await _relic_offered(game), "the last act's boss still offers its relic")

	# Saved between the last act's boss and the bottom: picked up at the bottom.
	game._save_run()
	var saved := RunSave.read()
	check(bool(saved.get("boss_slain", false)) and bool(saved.get("finale_open", false)) and not bool(saved.get("finale", true)), "the save knows the boss fell and the bottom waits")
	game.resume_run(saved)
	await _frames(5)
	_close_offers(game)
	check(game.run.finale and game.depth == total and game.world.finale == finale, "a run saved there picks up at the bottom of the Well, at the same depth")
	check(game.world.arena != null and game.world.arena.boss.def == finale.boss and game.world.arena.boss.dormant, "Tôma kneels in its arena, asleep")
	check(game.run.place_name(CONTENT) == finale.title, "the run says where it is")

	# Taking the stairs there works too (and its split is the last act's floor's).
	game.run.finale = false
	game.depth = total
	game._enter_floor()
	await _frames(3)
	await _slay_last_act_boss(game)
	_close_offers(game)
	game.world.stairs_reached.emit(0)
	for i in 60:
		await _frames(1)
		if not game._transitioning:
			break
	_close_offers(game)
	check(game.run.finale and game.depth == total and game.world.finale == finale and game.world.arena.boss.def == finale.boss, "the stairs lead down to the bottom, at the same depth")
	check(game.run.splits.size() == total and game.run.splits[total - 1] > 0.0, "the last act's floor gets its split on the way down")

	# The fight: Tôma wakes.
	var world: World = game.world
	var arena := world.arena
	var player: Player = game.player
	player.invincible = true
	var toma := arena.boss
	check(toma.global_position.y > world.map.cell_to_world(world.map.boss_room.get_center()).y, "Tôma waits below the middle (the Maw rises behind him)")
	player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 6))
	await _frames(3)
	check(arena.is_started and not toma.dormant and toma.rig.body.animation == &"intro", "walking in wakes Tôma: he opens his eyes and draws (intro)")
	check(toma.pick_skill(150.0) < 0 and not toma.can_attack() and toma.casting_index < 0, "he waits his waking out: no blow, no skill meanwhile")
	check(game.hud.get_node("%BossBar").visible and (game.hud.get_node("%BossName") as Label).text == finale.boss.display_name, "his name on the boss bar")
	check(toma.skills.skills.any(func(s: SkillDef) -> bool: return s.effects.any(func(e: Effect) -> bool: return e is GroundStrikeEffect)), "he turns the lantern's light on the hero (a strike on the ground)")

	# His lantern: a warning on the ground where the hero stands, then the strike.
	var lantern: SkillDef = load("res://data/skills/boss/toma_lantern.tres")
	player.invincible = false
	player.hp = player.get_max_hp()
	var hp_before := player.hp
	var spot := player.global_position
	lantern.effects[0].apply(toma, Vector2.DOWN)
	var warnings := world.get_node("Effects").get_children().filter(func(n: Node) -> bool: return n is GroundStrike)
	check(warnings.size() == 1 and (warnings[0] as GroundStrike).global_position.distance_to(spot) < 1.0, "the lantern marks the ground under the hero")
	toma._attack_cooldown = 5.0
	for i in 70:
		toma._attack_cooldown = 5.0
		toma.casting_index = -1
		player.global_position = spot
		player._invulnerable_time = 0.0
		await _frames(1)
	check(player.hp < hp_before, "standing in it hurts")
	player.invincible = true
	player.hp = player.get_max_hp()

	# Tôma falls: no relic, the arena stays shut, the Maw rises and takes his body.
	var finish := HitInfo.new()
	finish.amount = 999999
	finish.source = player
	toma.take_hit(finish)
	await _frames(3)
	check(toma.is_dead and is_instance_valid(toma) and toma.rig.body.animation == &"dead", "Tôma falls to his knees (his body stays)")
	check(arena.is_rising and not arena.is_defeated and arena.is_closed() and not game.has_won, "his fall doesn't end the fight: the arena stays shut")
	check(world.get_node("Entities").get_children().all(func(n: Node) -> bool: return not n is Stairs), "no stairs")
	await _wait(game, (finale.boss.rise_time + 0.6))
	_close_offers(game)
	var maw := arena.boss
	check(maw != toma and maw.def == finale.boss.next_boss and not maw.dormant and maw.target == player, "the Maw rises in the same arena and takes the fight")
	check(not is_instance_valid(toma) or toma.is_queued_for_deletion(), "it takes Tôma's body")
	check(game.offers.to_data(false).all(func(o: Dictionary) -> bool: return int(o.rarity) != PerkDef.Rarity.RARE) and not game.perk_panel.visible, "no relic between the two forms (Tôma's XP may level the hero up)")
	check((game.hud.get_node("%BossName") as Label).text == finale.boss.next_boss.display_name, "the boss bar passes to the Maw")
	check(maw.global_position.y < world.map.cell_to_world(world.map.boss_room.get_center()).y - world.map.tile_size * 4, "it rises at the top of the arena")

	# The jaw: closed, blows glance off; open, they land.
	var jaw := maw.def.traits[0] as WeakPointTrait
	check(jaw != null and jaw.stage_of(maw) == WeakPointTrait.Stage.CLOSED, "its jaw starts closed")
	var maw_hp := maw.hp
	var poke := HitInfo.new()
	poke.amount = 60
	poke.source = player
	maw.take_hit(poke)
	check(maw.hp == maw_hp and maw._hit_streak == 0, "closed, a blow glances off whole (no damage, no streak toward a shockwave)")
	check(world.get_node("Effects").get_children().any(func(n: Node) -> bool: return n is FloatingText), "and says so over it")
	var burn := OnHitStatus.new()
	burn.burn_damage = 5
	var burning := HitInfo.new()
	burning.amount = 20
	burning.source = player
	burning.status = burn
	maw.take_hit(burning)
	check(maw.statuses.is_empty(), "no status catches on the closed jaw")
	check(maw.pick_skill(200.0) >= 0 or maw.skills.skills.all(func(s: SkillDef) -> bool: return not maw.skills.is_ready(maw.skills.skills.find(s))), "closed, it may use its skills")
	maw.casting_index = -1
	jaw.open_now(maw)
	check(not jaw.is_open(maw), "opening takes a moment (blows still glance off)")
	await _wait(game, jaw.opening_time + 0.1)
	check(jaw.is_open(maw) and maw.rig.body.animation == jaw.open_pose, "then it holds its jaw open, Tôma inside")
	check(maw.pick_skill(200.0) < 0, "open, it uses no skill")
	maw.take_hit(poke)
	check(maw.hp < maw_hp, "open, the blow lands")
	# It draws the hero in, and bites him close.
	var mouth := jaw.mouth_of(maw)
	player.global_position = mouth + Vector2(0, 240)
	var far := player.global_position.distance_to(mouth)
	await _frames(20)
	check(player.global_position.distance_to(mouth) < far - 5.0, "open, it draws the hero toward its mouth")
	player.invincible = false
	player.hp = player.get_max_hp()
	hp_before = player.hp
	player.global_position = mouth + Vector2(0, 40)
	for i in int((jaw.bite_windup + 0.3) * 60.0):
		player.global_position = mouth + Vector2(0, 40)
		player._invulnerable_time = 0.0
		await _frames(1)
	check(player.hp < hp_before, "too close to the open mouth: it bites")
	check(game.run.marks.has("bitten"), "the run remembers it was bitten (the Maw's deed asks for a run never bitten)")
	player.invincible = true
	player.hp = player.get_max_hp()
	player.global_position = mouth + Vector2(0, 260)
	await _wait(game, jaw.time_left(maw) + jaw.closing_time + 0.2)
	check(jaw.stage_of(maw) == WeakPointTrait.Stage.CLOSED and maw.rig.body.animation != jaw.open_pose, "after its window the jaw shuts again")
	check(jaw.time_left(maw) <= jaw.closed_times[0] + 0.01, "for its closed time")

	# The Maw falls: the run is won, then an ending is chosen.
	var wins_before := Profile.total_wins()
	jaw.open_now(maw)
	await _wait(game, jaw.opening_time + 0.1)
	maw.take_hit(finish)
	await _frames(3)
	check(maw.is_dead and game.has_won and game.run.finish_time > 0.0, "the Maw's fall wins the run")
	check(not Narrative.is_deed_done(maw.def as BossDef, (maw.def as BossDef).chronicle.deeds()[0]), "bitten this run: not its deed")
	check(Profile.total_wins() == wins_before + 1 and game.run.splits.size() == total + 1, "the win counts at once, the bottom with its own split")
	check(game.run.ending_due, "an ending is due")
	game._save_run()
	var won_save := RunSave.read()
	check(bool(won_save.get("ending_due", false)), "a save before the choice keeps it due")
	await _wait(game, Game.ENDING_DELAY + 0.3)
	var panel := game.menus.ending
	check(panel.visible and get_tree().paused and not game.game_over_panel.visible, "the choice of an ending comes up, the game paused")
	check(panel.buttons().size() == 2 and panel.buttons()[0].text == finale.endings[0].choice and panel.buttons()[1].text == finale.endings[1].choice, "two endings, by touch: %s / %s" % [finale.endings[0].choice, finale.endings[1].choice])
	game._back()
	check(panel.visible, "Back doesn't dodge the choice")
	panel.buttons()[1].pressed.emit()
	await _frames(3)
	var ending := finale.endings[1]
	check(Profile.ending == ending.id, "the ending chosen is kept in the profile")
	check(Profile.stat_value(ending.stat) == 1 and Profile.is_achieved(&"he_who_keeps_watch"), "its achievement is earned")
	check(not Profile.is_achieved(&"the_last_knell"), "not the other one")
	var shown := game.game_over_panel.shown_text()
	check(game.game_over_panel.visible and shown.contains(ending.title) and shown.contains(ending.text.get_slice("\n", 0)), "the victory screen tells that ending")
	check(not game.run.ending_due, "no ending due any more")

	# A run won at the bottom and picked up before the choice: the choice first.
	game.resume_run(won_save)
	await _frames(5)
	check(game.run.has_won and game.menus.ending.visible, "a run won at the bottom and quit before the choice asks for it again")
	game.menus.ending.choose(0)
	await _frames(3)
	check(Profile.ending == finale.endings[0].id and Profile.is_achieved(&"the_last_knell"), "the other ending, its achievement")
	check(game.game_over_panel.visible, "then the victory screen")
	(game.game_over_panel.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	_close_offers(game)
	check(not get_tree().paused and not game.run.finale and game.depth == total + 1, "keep going: endless mode, past the bottom")
	Profile.reset()


## The story at the bottom (Boss stories on, as players have them): Tôma's meeting plays with
## his waking and names him (the reveal), the Maw is met once risen, each says its last words,
## their deeds, their meeting keys apart from the last act's arena at the same depth, and their
## past on the last act's floors.
func _test_finale_story(game: Game) -> void:
	var finale := CONTENT.dungeon.finale
	var narrative := CONTENT.narrative
	var stories := Settings.boss_stories
	Profile.reset()
	Profile.wins = { "easy": 1 }
	Settings.boss_stories = Settings.STORIES_FULL
	game.start_run()
	await _frames(3)
	var toma_def := finale.boss
	var maw_def := toma_def.next_boss
	var total := CONTENT.dungeon.total_floors()
	check(not narrative.keeper_reveal.is_met(), "a won profile that never slew the Effigy: the keeper is not named yet")
	var ahead := FragmentPlacer.wardens_ahead(game.world, CONTENT.dungeon, total - 1)
	check(ahead.has(toma_def) and ahead.has(maw_def), "the last act's floors may hold Tôma's and the Maw's past (the bottom open)")
	check(not FragmentPlacer.wardens_ahead(game.world, CONTENT.dungeon, 1).has(toma_def), "not the first act's")
	check(Narrative.fragments_to_place(toma_def).is_empty(), "his journal waits for the reveal")
	var said := PackedStringArray()
	var listen := func(text: String, _color: Color) -> void: said.append(text)
	Events.message_logged.connect(listen)

	# The last act's arena is met at depth 12; the bottom, at the same depth, has its own key.
	game.run.met_floors.clear()
	game.depth = total
	game.run.finale = false
	game.run.meet_here()
	game.run.finale = true
	check(not game.run.has_met_here() and game.run.floor_key() == "%df" % total, "the bottom's meeting is kept apart from the last act's arena")
	game._enter_floor()
	await _frames(3)
	var arena := game.world.arena
	var toma := arena.boss
	var meeting := game.meeting
	var view := meeting.view
	game.player.invincible = true
	game.player.global_position = game.world.map.cell_to_world(game.world.map.boss_room.get_center() + Vector2i(0, 6))
	await _frames(3)
	check(meeting.is_playing() and toma.dormant and meeting.director.subject == toma, "walking in: Tôma's story plays first, over the frozen world")
	var woke := false
	var spoke := false
	for i in 600:
		woke = woke or (meeting.director.played_animation and toma.rig.body.animation == &"intro")
		spoke = spoke or view.speech_text() == "\"%s\"" % toma_def.chronicle.waking_lines[0].line
		if view.heading_text() == toma_def.chronicle.chapters[0].title:
			break
		await _frames(1)
	check(woke, "his waking (intro) plays in the scene")
	check(view.name_text() == toma_def.display_name and spoke, "his name, and his first words: \"%s\"" % toma_def.chronicle.waking_lines[0].line)
	check(view.heading_text() == toma_def.chronicle.chapters[0].title, "then the first chapter of his story")
	await _end_scene(meeting)
	check(not meeting.is_playing() and not toma.dormant and not get_tree().paused, "then he fights")
	check(narrative.keeper_reveal.is_met(), "met at the bottom of the Well, the keeper may be named")
	check(Narrative.next_chapter(toma_def) == toma_def.chronicle.chapter_by_id(&"your_master"), "his next meeting tells who he is, by his name")

	# He falls to a hero who never rolled: his deed, his last words; the Maw rises, and is met.
	var finish := HitInfo.new()
	finish.amount = 999999
	finish.source = game.player
	toma.take_hit(finish)
	await _frames(3)
	var stood: DeedCondition = toma_def.chronicle.deeds()[0]
	check(Narrative.is_deed_done(toma_def, stood), "slain without a single roll: his deed is done")
	var maw_met := false
	for i in int((toma_def.rise_time + 2.0) * 60.0):
		_close_offers(game)
		if meeting.is_playing() and meeting.director.subject == arena.boss and arena.boss != toma:
			maw_met = true
			break
		await _frames(1)
	var last_words := "\"%s\"" % Narrative.last_words(toma_def).line
	check(said.has(last_words), "his last words, on his banner and in the log: %s" % last_words)
	var maw := arena.boss
	check(maw_met and maw.def == maw_def and arena.is_rising and maw.dormant, "risen, the Maw is met in its turn (a scene of its own)")
	check(maw.rig.modulate.a > 0.9, "after its rise, which the scene doesn't cut short")
	for i in 300:
		if view.name_text() == maw_def.display_name:
			break
		await _frames(1)
	check(view.name_text() == maw_def.display_name, "its name in the scene")
	await _end_scene(meeting)
	check(not meeting.is_playing() and not maw.dormant and not arena.is_rising and maw.target == game.player, "then it fights")
	check(game.run.has_met_here(maw_def.id) and game.run.met_floors.has("%df/%s" % [total, maw_def.id]), "its meeting is kept, apart from Tôma's")

	# Struck while open, never bitten: its deed; its last words.
	var jaw := maw.def.traits[0] as WeakPointTrait
	jaw.open_now(maw)
	await _wait(game, jaw.opening_time + 0.1)
	said.clear()
	maw.take_hit(finish)
	await _wait(game, Game.LAST_WORDS_DELAY + 0.3)
	var never: DeedCondition = maw_def.chronicle.deeds()[0]
	check(not game.run.marks.has("bitten") and Narrative.is_deed_done(maw_def, never), "never bitten: the Maw's deed is done")
	check(said.has("\"%s\"" % Narrative.last_words(maw_def).line), "its last words: the sun sets")
	# A sentence on the banner comes smaller, on the screen; a name stays big.
	var banner := game.hud.get_node("%DepthBanner") as Label
	var longest := "\"%s\"" % tr(toma_def.chronicle.last_words[1].line)
	game.hud.show_banner(longest)
	var width := Fonts.MAIN.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, banner.get_theme_font_size(&"font_size")).x
	var room := minf(banner.get_viewport_rect().size.x - 2.0 * Hud.BANNER_MARGIN, Hud.BANNER_WIDTH)
	var too_wide := Fonts.MAIN.get_string_size(banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1, Fonts.HUGE).x > room
	check((banner.get_theme_font_size(&"font_size") == Fonts.TITLE) == too_wide and width < room, "his longest last words fit the screen on the banner (%d of %d UI pixels)" % [roundi(width), roundi(room)])
	game.hud.show_banner(tr(maw_def.display_name))
	check(banner.get_theme_font_size(&"font_size") == Fonts.HUGE and _off_grid_texts(game.hud).is_empty(), "a name stays big, on the font's grid")
	await _wait(game, Game.ENDING_DELAY)
	check(game.menus.ending.visible, "then the choice of an ending, as without the story")
	if game.menus.ending.visible:
		game.menus.ending.choose(0)
		await _frames(3)
	(game.game_over_panel.get_node("%ContinueButton") as Button).pressed.emit()
	await _frames(3)
	_close_offers(game)
	Events.message_logged.disconnect(listen)
	Settings.boss_stories = stories
	Profile.reset()


## Hurries the scene, then ends it (two taps), and waits for it to be over.
func _end_scene(meeting: BossMeeting) -> void:
	for tap in 2:
		meeting.director.tap()
		await _frames(3)
	for i in 120:
		if not meeting.is_playing():
			return
		await _frames(1)


## Puts the hero in the last act's arena (a fresh floor) and slays its boss. True once it fell.
func _slay_last_act_boss(game: Game) -> bool:
	game.depth = CONTENT.dungeon.total_floors()
	game.run.finale = false
	game._enter_floor()
	await _frames(3)
	var world := game.world
	if world.arena == null:
		return false
	game.player.invincible = true
	game.player.global_position = world.map.cell_to_world(world.map.boss_room.get_center() + Vector2i(0, 4))
	await _frames(3)
	var hit := HitInfo.new()
	hit.amount = 999999
	world.arena.boss.take_hit(hit)
	await _frames(4)
	return world.arena.is_defeated


## The boss' relic comes up by itself after a moment.
func _relic_offered(game: Game) -> bool:
	for attempt in 8:
		await get_tree().create_timer(Game.RELIC_DELAY * 0.5, true).timeout
		if game.perk_panel.visible:
			var offered := game.perk_panel.get_offered()
			var relic := not offered.is_empty() and offered[0].rarity == PerkDef.Rarity.RARE
			game.perk_panel.choose(0)
			await _frames(2)
			if relic:
				return true
	return false


## Waits `seconds` of play, taking any choice that comes up meanwhile (a relic).
func _wait(game: Game, seconds: float) -> void:
	for i in ceili(seconds * 60.0):
		_close_offers(game)
		await _frames(1)


## Takes whatever choice is on screen (a relic, a level up), so the test goes on.
func _close_offers(game: Game) -> void:
	for i in 4:
		if game.perk_panel.visible:
			game.perk_panel.choose(0)
