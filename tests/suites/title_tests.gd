class_name TitleTests
extends TestSuite
## The title screen and its panels.

func run() -> void:
	await _test_title_screen()
	await _test_touch_scroll()
	await _test_resume_button()
	# The title's panels with keys and a gamepad, and their layouts (PcTests).
	var pc := PcTests.new()
	add_child(pc)
	await pc.run_title()
	pc.free()


## A run in progress: the Resume button sits in the column like the others, its floor on a line
## of its own (a long one-line label ran past the column on phones).
func _test_resume_button() -> void:
	var file := FileAccess.open(RunSave.path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": RunSave.VERSION, "depth": 11, "player": {"level": 23}}))
	file.close()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await get_tree().process_frame
	await get_tree().process_frame
	var resume: Button = title.get_node("%ContinueButton")
	var play: Button = title.get_node("%PlayButton")
	var labels := resume.find_children("*", "Label", true, false)
	check(resume.visible and resume.text.is_empty() and labels.size() == 2 and (labels[1] as Label).text.contains("11"), "a run in progress: Resume, its floor on a second line")
	check(is_equal_approx(resume.size.x, play.size.x), "Resume is as wide as Descend (%d vs %d)" % [resume.size.x, play.size.x])
	title.queue_free()
	RunSave.erase()
	await get_tree().process_frame


## Dragging over a list scrolls it, even when the drag starts on a card or a button, and a
## drag doesn't press the button.
func _test_touch_scroll() -> void:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 100)
	scroll.size = Vector2(300, 200)
	var list := VBoxContainer.new()
	scroll.add_child(list)
	var pressed := [0]
	for i in 30:
		var button := Button.new()
		button.custom_minimum_size = Vector2(280, 40)
		button.pressed.connect(func() -> void: pressed[0] += 1)
		list.add_child(button)
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(scroll)
	await _frames(3)
	check(scroll.get_children().any(func(n: Node) -> bool: return n is TouchScroll), "lists get drag-to-scroll by themselves")
	var at := Vector2(200, 250)
	_mouse(at, true)
	for i in 6:
		at.y -= 15.0
		var motion := InputEventMouseMotion.new()
		motion.position = at
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		get_viewport().push_input(motion, true)
		await _frames(1)
	_mouse(at, false)
	await _frames(2)
	check(scroll.scroll_vertical >= 60, "dragging scrolls the list (%d px)" % scroll.scroll_vertical)
	check(pressed[0] == 0, "a drag doesn't press the button under the finger")
	await _frames(2)
	check(list.get_children().all(func(b: Node) -> bool: return (b as Button).get_draw_mode() != BaseButton.DRAW_PRESSED), "...nor leaves it looking pressed")
	layer.queue_free()


func _mouse(at: Vector2, down: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = at
	click.pressed = down
	get_viewport().push_input(click, true)


func _test_title_screen() -> void:
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	check(title.get_node("%PlayButton").visible, "the title screen has a Play button")
	check((title.get_node("%Title") as Label).text == CONTENT.story.title and title.get_node("%StoryButton").visible, "the title screen shows the name and the story")
	(title.get_node("%PlayButton") as Button).pressed.emit()
	await _frames(2)
	var cards: HBoxContainer = title.get_node("%DifficultyCards")
	check(title.get_node("%DifficultyPanel").visible and cards.get_child_count() == 4, "Play asks for a difficulty")
	check((cards.get_child(3) as Button).disabled and not (cards.get_child(2) as Button).disabled, "Nightmare locked, Hard open")
	check(not title.get_node("%AscensionRow").visible, "no ascension before a Nightmare win")
	Profile.ascension_unlocked = 2
	(title.get_node("%DifficultyPanel") as DifficultyPanel).open(CONTENT.difficulties, CONTENT.ascensions)
	(title.get_node("%AscensionPlus") as Button).pressed.emit()
	check(title.get_node("%AscensionRow").visible and Profile.ascension == 1 and (title.get_node("%AscensionLevel") as Label).text == "+1", "the ascension level is picked with Nightmare")
	Profile.ascension_unlocked = 0
	Profile.ascension = 0
	(title.get_node("%BackButton") as Button).pressed.emit()
	await _frames(1)
	check(not title.get_node("%DifficultyPanel").visible, "back to the title")
	(title.get_node("%DailyButton") as Button).pressed.emit()
	await _frames(2)
	check(title.daily_dialog.visible and not Game.daily_requested, "the daily run explains itself before it starts")
	check(title.daily_dialog.body.find_child("AnswerButton", true, false) != null, "...with a button to toll the knell")
	title.daily_dialog.hide()
	Profile.souls = 500
	var hints_were := Settings.tutorial_hints
	Settings.tutorial_hints = true
	Profile.hints_seen.erase("menu_shrine")
	(title.get_node("%ShrineButton") as Button).pressed.emit()
	await _frames(2)
	var shrine: ShrinePanel = title.get_node("%ShrinePanel")
	check(title.hint_box.visible and title.hint_box.shown_text().contains("Tree of Souls") or Profile.has_seen_hint(&"menu_shrine"), "the first visit explains the tree (%s)" % title.hint_box.shown_text())
	check(not title.show_menu_hint(&"menu_shrine"), "...once only")
	title.hint_box.hide_hint()
	Settings.tutorial_hints = hints_were
	var view: SoulTreeView = title.get_node("%TreeView")
	check(shrine.visible and view.buttons().size() == CONTENT.soul_tree.nodes.size(), "the shrine shows every node of the Tree of Souls")
	var vitality_node := CONTENT.soul_tree.find(&"vitality")
	view.button_of(vitality_node).pressed.emit()
	await _frames(1)
	check(shrine.picked() == vitality_node, "tapping a node picks it")
	(title.get_node("%BuyButton") as Button).pressed.emit()
	await _frames(1)
	check(Profile.level_of(vitality_node.upgrade) == 1 and Profile.souls < 500, "buying at the shrine")
	check((title.get_node("%Souls") as Label).text.contains(str(Profile.souls)), "the shrine shows the souls left")
	var fork := CONTENT.soul_tree.find(&"toughness")
	shrine.pick(fork)
	check(shrine.buy_picked() and fork.partner().is_shut() and not Profile.can_buy_node(fork.partner()), "a fork: taking one side shuts the other")
	var spent := CONTENT.soul_tree.spent()
	var before := Profile.souls
	var reset_button: Button = title.get_node("%ResetButton")
	var saved_runs := Profile.runs_since_reset
	Profile.runs_since_reset = CONTENT.soul_tree.reset_runs - 2
	Profile.changed.emit()
	check(reset_button.disabled and reset_button.text == "Reset in 2 runs", "the reset waits for its runs: \"Reset in 2 runs\", disabled (%s)" % reset_button.text)
	reset_button.pressed.emit()
	await _frames(1)
	check(Profile.souls == before and CONTENT.soul_tree.spent() == spent, "...and does nothing then")
	Profile.record_run(0, 2, false, &"normal")
	await _frames(1)
	check(reset_button.disabled and reset_button.text == "Reset in 1 run", "a run later: \"Reset in 1 run\" (%s)" % reset_button.text)
	Profile.record_run(0, 2, false, &"normal")
	await _frames(1)
	check(not reset_button.disabled and reset_button.text == "Reset the tree", "the runs done: the reset is open (%s)" % reset_button.text)
	before = Profile.souls
	reset_button.pressed.emit()
	await _frames(1)
	check(Profile.souls == before + spent and CONTENT.soul_tree.spent() == 0 and not fork.partner().is_shut(), "resetting the tree gives every soul back (%d)" % spent)
	check(reset_button.disabled and reset_button.text == "Reset in %d runs" % CONTENT.soul_tree.reset_runs, "after a reset, the next one takes its runs again (%s)" % reset_button.text)
	Profile.runs_since_reset = saved_runs
	Profile.buy_node(vitality_node)
	_test_shrine_words(shrine)
	# At the Well's Edge: the oaths the tree opened, and the Armory's weapon.
	var saved_levels := Profile.levels.duplicate()
	check(not OathPanel.has_choices(CONTENT) or Profile.levels.has("armory"), "nothing to swear before the tree opens it")
	Profile.levels["oath_colossus"] = 1
	Profile.levels["armory"] = 1
	check(OathPanel.has_choices(CONTENT), "an oath bought: something to choose before a run")
	var oaths: OathPanel = title.oath_panel
	oaths.open(CONTENT)
	await _frames(1)
	var oath_cards: HBoxContainer = oaths.get_node("%OathCards")
	var order := CONTENT.soul_tree.oaths()
	check(oaths.visible and oath_cards.get_child_count() == order.size() + 1, "a card per oath, and Unsworn")
	var colossus_index := order.find(CONTENT.soul_tree.find(&"oath_colossus").oath) + 1
	check(not (oath_cards.get_child(colossus_index) as Button).disabled and order.size() == 4 and oath_cards.get_children().filter(func(c: Node) -> bool: return (c as Button).disabled).size() == 3, "the oath bought is open, the others locked")
	(oath_cards.get_child(colossus_index) as Button).pressed.emit()
	await _frames(1)
	check(Profile.oath == &"colossus" and Game.sworn_oath(CONTENT) != null, "tapping a card swears the oath")
	var weapon_row: HBoxContainer = oaths.get_node("%WeaponRow")
	var armory: UpgradeDef = CONTENT.soul_tree.find(&"armory").upgrade
	var level_one := armory.armory_weapons.slice(0, armory.armory_count(1))
	var shown := weapon_row.get_children().map(func(slot: Node) -> ItemDef: return (slot as ItemSlot).item)
	check(weapon_row.is_visible_in_tree() and shown == level_one and OathPanel.weapons(CONTENT) == level_one, "the Armory level 1: a slot per weapon it opened, no other (%s)" % [shown.map(func(w: ItemDef) -> StringName: return w.id)])
	var armory_text: Label = oaths.get_node("%ArmoryText")
	check(armory_text.is_visible_in_tree() and armory_text.text == "Armory level 1: %d weapons. More in the Tree of Souls." % level_one.size(), "...and says its level and where to get more (%s)" % armory_text.text)
	(weapon_row.get_child(1) as ItemSlot).pressed.emit()
	await _frames(1)
	check(Profile.starting_weapon == level_one[1].id and Game.picked_weapon(CONTENT) == level_one[1] and (weapon_row.get_child(1) as ItemSlot).selected, "tapping a weapon picks it")
	Profile.levels["armory"] = 3
	oaths.open(CONTENT)
	await _frames(1)
	shown = weapon_row.get_children().map(func(slot: Node) -> ItemDef: return (slot as ItemSlot).item)
	var level_three := armory.armory_weapons.slice(0, armory.armory_count(3)).filter(func(w: WeaponDef) -> bool: return not CONTENT.locked_items.has(w))
	check(shown == level_three and shown.size() == level_one.size() + 2 * armory.armory_per_level and armory_text.text.begins_with("Armory level 3: %d weapons" % shown.size()), "the Armory level 3: two more weapons a level (%d)" % shown.size())
	check(not shown.any(func(w: ItemDef) -> bool: return CONTENT.locked_items.has(w) and not ShrineUpgrades.unlocked_items(CONTENT).has(w)), "never a weapon still locked in the dungeon")
	Profile.levels["armory"] = 1
	Profile.starting_weapon = level_three[level_three.size() - 1].id
	oaths.open(CONTENT)
	await _frames(1)
	check(Game.picked_weapon(CONTENT) == null and weapon_row.get_child_count() == level_one.size() and (weapon_row.get_child(0) as ItemSlot).selected, "a weapon the level no longer offers: the usual one, shown picked")
	oaths.hide()
	Profile.levels = saved_levels
	Profile.oath = &""
	Profile.starting_weapon = &""
	_test_difficulty_words()
	await _test_options_screen(title)
	# The codex: bestiary, achievements, runs.
	Profile.record_kill(&"slime")
	(title.get_node("%CodexButton") as Button).pressed.emit()
	await _frames(2)
	var codex: CodexPanel = title.get_node("%CodexPanel")
	var list: Container = codex.get_node("%List")
	var entries := codex.bestiary_entries()
	var monster_cards := codex.bestiary_cards()
	check(codex.visible and monster_cards.size() == entries.size() and monster_cards.map(func(c: CodexCard) -> MonsterDef: return c.monster) == entries, "the bestiary lists every monster and boss")
	check(entries.any(func(m: MonsterDef) -> bool: return m is BossDef), "bosses are in the bestiary")
	check(entries.size() == CONTENT.all_monsters().size() + CONTENT.abyss_monsters().size() + entries.filter(func(m: MonsterDef) -> bool: return m is BossDef).size(), "every monster once (the acts', the Deeps')")
	check(CONTENT.abyss_monsters().all(func(m: MonsterDef) -> bool: return entries.has(m)), "the Deeps' demons are in the bestiary")
	check(_texts(list).has(CONTENT.dungeon.abyss.display_name), "under their own heading")
	var slime_card := monster_cards[entries.find(load("res://data/monsters/slime.tres"))]
	var unseen := entries.filter(func(m: MonsterDef) -> bool: return Bestiary.rank_of(m, CONTENT.bestiary) == Bestiary.UNSEEN)
	check(not slime_card.disabled and monster_cards[entries.find(unseen[0])].disabled, "slain monsters open their page, unknown ones don't")
	check(_texts(slime_card).has("Known") and _texts(slime_card).has("1 slain") and _texts(monster_cards[entries.find(unseen[0])]).has("???"), "a card shows the rank and the kills (unknown ones: ???)")
	# The hidden floor's boss: after the acts and the Deeps (only the bottom of the Well's forms
	# follow it), its card and its floor's heading kept secret until met.
	var hidden_boss := CONTENT.dungeon.hidden_floor.boss
	var forms := CONTENT.dungeon.finale.boss.forms()
	var hidden_at := entries.size() - forms.size() - 1
	var list_texts := _texts(list)
	check(entries[hidden_at] == hidden_boss and monster_cards[hidden_at].disabled and _texts(monster_cards[hidden_at]).has("???"), "the hidden boss is last but the bottom's forms in the bestiary, a ??? card until met")
	check(not list_texts.any(func(text: String) -> bool: return text.contains(CONTENT.dungeon.hidden_floor.title) or text.contains(hidden_boss.display_name)), "nothing in the bestiary names the hidden floor or its boss before they are met")
	# The bottom of the Well's forms: last, in order, ??? cards under a ??? heading until met.
	check(entries.slice(entries.size() - forms.size()) == forms and forms.size() == 2, "the bottom of the Well's two forms close the bestiary, in order")
	for i in forms.size():
		var card := monster_cards[entries.size() - forms.size() + i]
		check(card.disabled and _texts(card).has("???"), "%s: a ??? card until met" % forms[i].id)
	check(not list_texts.any(func(text: String) -> bool: return text.contains(CONTENT.dungeon.finale.title) or forms.any(func(form: BossDef) -> bool: return text.contains(form.display_name))), "nothing in the bestiary names the bottom of the Well or its forms before they are met")
	check(Profile.bestiary_rank(&"slime") == 1, "the first kill pays the first rank")
	check((codex.get_node("%Help") as Label).text.contains("rank"), "the bestiary explains the hunter ranks")
	slime_card.pressed.emit()
	await _frames(2)
	check(codex.is_page_open() and not (codex.get_node("%Scroll") as Control).is_visible_in_tree(), "tapping a monster opens its page")
	var page_text := " ".join(_texts(codex.get_node("%MonsterPage")))
	check(page_text.contains("Health") and page_text.contains("Move speed") and page_text.contains("Mastered: slay") and page_text.contains("Celestial"), "the page explains the stats, the ranks and the Celestial")
	# Every page, every attack plays in the preview (warning, then what it does).
	for monster in entries:
		Profile.record_kill(monster.id)
		codex.open_monster(monster)
		await _frames(2)
		var buttons := _find_all(codex, func(n: Node) -> bool: return n is Button and n.toggle_mode and n.get_parent() is HFlowContainer)
		for button: Button in buttons:
			button.pressed.emit()
			await _frames(70)
		check(buttons.size() >= 1 or monster.weapon == null, "%s: its attacks are listed (%d)" % [monster.id, buttons.size()])
	var previews := _find_all(codex, func(n: Node) -> bool: return n is AttackPreview)
	check(previews.size() == 1, "one preview on the page")
	codex.back()
	check(not codex.is_page_open() and codex.visible, "back: from the page to the list")
	codex.back()
	check(not codex.visible, "back again: the codex closes")
	codex.open(CONTENT, CodexPanel.Tab.QUESTS)
	await _frames(1)
	var quest_text := " ".join(_texts(list))
	check((codex.get_node("%QuestsTab") as Button).button_pressed and quest_text.contains("Daily quests") and quest_text.contains("Weekly quests") and quest_text.contains("souls"), "the quests tab: daily and weekly quests and their souls")
	check(_find_all(list, func(n: Node) -> bool: return n is StatBar).size() == QuestBoard.DAILY_COUNT + QuestBoard.WEEKLY_COUNT, "a progress bar per quest")
	check((codex.get_node("%Help") as Label).text.contains("Shrine"), "the quests tab says what souls are for")
	codex.show_tab(CodexPanel.Tab.ACHIEVEMENTS)
	await _frames(1)
	check(list.get_child_count() == CONTENT.achievements.size() and not (codex.get_node("%QuestsTab") as Button).button_pressed, "the achievements are listed")
	check(_texts(list.get_child(0)).any(func(t: String) -> bool: return t.begins_with("+") and t.ends_with("souls")), "an achievement shows its reward")
	Profile.add_history({ "depth": 3, "cause": "Skeleton", "won": false, "time": 1760000000, "duration": 600000 })
	codex.show_tab(CodexPanel.Tab.RUNS)
	await _frames(1)
	check(list.get_child_count() == 1, "the last runs are listed")
	var run_text := " ".join(_texts(list))
	check(run_text.contains("Died on floor 3") and run_text.contains("Slain by Skeleton") and run_text.contains("10:00"), "a run says how far it went, how it ended, how long it took")
	(codex.get_node("%BestiaryTab") as Button).pressed.emit()
	await _frames(1)
	check(codex.bestiary_cards().size() == entries.size(), "a tab button shows its tab")
	var off_grid := _off_grid_texts(title)
	check(off_grid.is_empty(), "every text of the title screen and its panels is on the font's grid (Fonts.SIZES, a one-pixel outline): %s" % ", ".join(off_grid.slice(0, 6)))
	title.queue_free()
	Profile.reset()
	await _frames(2)

	# The story: typed out page by page, a tap shows the whole page, the next tap the next page.
	check(not Profile.seen_intro, "the story was not told yet")
	var story_screen: StoryScreen = load("res://src/ui/story/story_screen.tscn").instantiate()
	add_child(story_screen)
	await _frames(3)
	var text: Label = story_screen.get_node("%Text")
	check(story_screen.page == 0 and story_screen.is_typing() and text.visible_ratio < 1.0, "the story types itself out")
	story_screen.advance()
	check(text.visible_ratio == 1.0 and not story_screen.is_typing(), "a tap shows the whole page")
	story_screen.advance()
	check(story_screen.page == 1 and text.text == CONTENT.story.intro_pages[1], "the next tap turns the page")
	story_screen.queue_free()
	await _frames(2)


## The shrine says each upgrade's level, what you have, what the next level adds, and why a
## Buy button is off.
func _test_shrine_words(shrine: ShrinePanel) -> void:
	var vitality: UpgradeDef = load("res://data/upgrades/vitality.tres")
	check(UpgradeRow.level_text(vitality, 2) == "Level 2 / 5", "shrine: the level out of the max")
	var status := UpgradeRow.status_text(vitality, 2)
	check(status.contains("Now: +16 max health") and status.contains("Next: +24 max health"), "shrine: now and next level (%s)" % status)
	check(UpgradeRow.status_text(vitality, 0).contains("+8 max health"), "shrine: what the first level gives")
	check(UpgradeRow.status_text(vitality, 5).contains("maxed"), "shrine: maxed")
	var unlock: UpgradeDef = load("res://data/upgrades/pyromancy.tres")
	check(UpgradeRow.level_text(unlock, 0) == "Locked" and UpgradeRow.level_text(unlock, 1) == "Unlocked", "shrine: unlocks say locked / unlocked")
	var node := CONTENT.soul_tree.find(&"vitality")
	shrine.pick(node)
	var buy: Button = shrine.get_node("%BuyButton") if shrine.has_node("%BuyButton") else shrine.owner.get_node("%BuyButton")
	var souls := Profile.souls
	Profile.souls = 0
	Profile.changed.emit()
	check(buy.disabled and buy.text.begins_with("Need"), "shrine: too few souls says how many are needed (%s)" % buy.text)
	Profile.levels[String(vitality.id)] = vitality.max_level
	Profile.changed.emit()
	check(buy.disabled and buy.text == "Maxed", "shrine: a maxed upgrade says so")
	var locked := CONTENT.soul_tree.find(&"armory")
	shrine.pick(locked)
	check(buy.disabled and buy.text == "Locked" and locked.blocker().begins_with("Needs"), "shrine: a node whose parents aren't bought says what it needs (%s)" % locked.blocker())
	Profile.levels.erase(String(vitality.id))
	Profile.souls = souls
	Profile.changed.emit()


## Each difficulty in plain words, and the ascension's twists.
func _test_difficulty_words() -> void:
	var normal: DifficultyDef = load("res://data/difficulties/normal.tres")
	var hard: DifficultyDef = load("res://data/difficulties/hard.tres")
	var easy: DifficultyDef = load("res://data/difficulties/easy.tres")
	var words := DifficultyCard.effects(hard, normal).map(func(e: Array) -> String: return e[0])
	for expected in ["Monster health +30%", "Monster damage +35%", "Time to dodge -15%", "+1 monster per room", "Monsters spot you sooner", "Bigger floors (+20%)"]:
		check(words.has(expected), "difficulty: Hard says \"%s\" (%s)" % [expected, words])
	var heal: Array = DifficultyCard.effects(easy, normal).filter(func(e: Array) -> bool: return (e[0] as String).begins_with("Heal"))
	check(heal.size() == 1 and heal[0][1] == 1, "difficulty: Easy's healing is a help")
	check(DifficultyCard.effects(normal, normal).size() == 1, "difficulty: Normal is the reference")
	var lines := DifficultyPanel.ascension_lines(CONTENT.ascensions, 2, 3)
	check(lines.size() == 3 and lines[0].begins_with("+1") and lines[2].begins_with("Next, +3"), "ascension: the twists so far, then the next (%s)" % lines)
	check(DifficultyPanel.ascension_lines(CONTENT.ascensions, 2, 2)[2].begins_with("Win Nightmare +2"), "ascension: how to open the next level")


## The options: every control there, grouped, and tapping an option's name flips it.
func _test_options_screen(title: TitleScreen) -> void:
	var options: OptionsPanel = title.get_node("%OptionsPanel")
	(title.get_node("%OptionsButton") as Button).pressed.emit()
	await _frames(2)
	check(options.visible, "the options open from the title")
	for name in ["MasterSlider", "MusicSlider", "InterfaceSlider", "CombatSlider", "AmbienceSlider", "ShakeSlider", "ControlsSlider", "VibrationsCheck", "FixedStickCheck", "BatteryCheck", "FewerEffectsCheck", "FlashesCheck", "RunTimerCheck", "TutorialCheck", "ReplayTutorialButton", "CloseButton"]:
		check(options.get_node_or_null("%" + name) != null, "options: %s" % name)
	var battery: CheckButton = options.get_node("%BatteryCheck")
	var before := Settings.battery_saver
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = Vector2(4, 4)
	tap.pressed = false
	(battery.get_parent().get_child(0) as Control).gui_input.emit(tap)
	check(Settings.battery_saver != before and battery.button_pressed != before, "options: tapping the name flips the switch")
	battery.button_pressed = before
	# The language: French at once (the window rebuilt in it), then back to English.
	var french: Button = options.get_node_or_null("%FrenchButton")
	check(french != null and options.get_node_or_null("%EnglishButton") != null, "options: the language buttons")
	if french:
		french.pressed.emit()
		await _frames(2)
		check(Settings.language == "fr" and TranslationServer.get_locale() == "fr", "options: Français switches the game to French")
		var english: Button = options.get_node("%EnglishButton")
		check(english != null and options.visible and _texts(options).has("Langue") and _texts(options).has("Son"), "options: the window is rebuilt in French")
		check((options.get_node("%FrenchButton") as Button).button_pressed and not english.button_pressed, "options: the language in use stays pressed")
		english.pressed.emit()
		await _frames(2)
		check(Settings.language == "en" and TranslationServer.get_locale() == "en" and _texts(options).has("Language"), "options: English switches back")
	(options.get_node("%CloseButton") as Button).pressed.emit()
	await _frames(1)
	check(not options.visible, "options: Close")


# --- Gameplay (bot) ----------------------------------------------------------


## The texts of every label under `root`.
func _texts(root: Node) -> Array:
	return _find_all(root, func(n: Node) -> bool: return n is Label).map(func(l: Label) -> String: return l.text)


## Every node under `root` for which `test` is true.
func _find_all(root: Node, test: Callable) -> Array:
	var found := []
	for child in root.get_children():
		if test.call(child):
			found.append(child)
		found.append_array(_find_all(child, test))
	return found
