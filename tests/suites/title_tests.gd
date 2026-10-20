class_name TitleTests
extends TestSuite
## The title screen and its panels.

func run() -> void:
	await _test_title_screen()
	await _test_touch_scroll()


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
	Profile.souls = 500
	(title.get_node("%ShrineButton") as Button).pressed.emit()
	await _frames(2)
	var shrine: ShrinePanel = title.get_node("%ShrinePanel")
	var rows: VBoxContainer = title.get_node("%Rows")
	check(shrine.visible and shrine.rows().size() == CONTENT.upgrades.size(), "the shrine lists every upgrade")
	check(rows.get_children().filter(func(n: Node) -> bool: return not n is UpgradeRow).size() >= 3, "...grouped under headings")
	var first: UpgradeRow = shrine.rows()[0]
	(first.get_node("%BuyButton") as Button).pressed.emit()
	await _frames(1)
	check(Profile.level_of(first.upgrade) == 1 and Profile.souls < 500, "buying at the shrine")
	check((title.get_node("%Souls") as Label).text.contains(str(Profile.souls)), "the shrine shows the souls left")
	_test_shrine_words(shrine)
	_test_difficulty_words()
	await _test_options_screen(title)
	# The codex: bestiary, achievements, runs.
	Profile.record_kill(&"slime")
	(title.get_node("%CodexButton") as Button).pressed.emit()
	await _frames(2)
	var codex: CodexPanel = title.get_node("%CodexPanel")
	var list: Container = codex.get_node("%List")
	check(codex.visible and list.get_child_count() == codex.bestiary_entries().size(), "the bestiary lists every monster and boss")
	check(codex.bestiary_entries().any(func(m: MonsterDef) -> bool: return m is BossDef), "bosses are in the bestiary")
	var entries := codex.bestiary_entries()
	var slime_card := list.get_child(entries.find(load("res://data/monsters/slime.tres"))) as Button
	var unseen := entries.filter(func(m: MonsterDef) -> bool: return Bestiary.rank_of(m, CONTENT.bestiary) == Bestiary.UNSEEN)
	check(not slime_card.disabled and (list.get_child(entries.find(unseen[0])) as Button).disabled, "slain monsters open their page, unknown ones don't")
	check(Profile.bestiary_rank(&"slime") == 1, "the first kill pays the first rank")
	slime_card.pressed.emit()
	await _frames(2)
	check(codex.is_page_open() and not (codex.get_node("%Scroll") as Control).visible, "tapping a monster opens its page")
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
	codex.open(CONTENT, CodexPanel.Tab.BESTIARY)
	codex.show_tab(CodexPanel.Tab.ACHIEVEMENTS)
	await _frames(1)
	check(list.get_child_count() == CONTENT.achievements.size(), "the achievements are listed")
	Profile.add_history({ "depth": 3, "cause": "Skeleton", "won": false })
	codex.show_tab(CodexPanel.Tab.RUNS)
	await _frames(1)
	check(list.get_child_count() == 1, "the last runs are listed")
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
	var row: UpgradeRow = shrine.rows().filter(func(r: UpgradeRow) -> bool: return r.upgrade == vitality)[0]
	var buy: Button = row.get_node("%BuyButton")
	var souls := Profile.souls
	Profile.souls = 0
	Profile.changed.emit()
	check(buy.disabled and buy.text.begins_with("Need"), "shrine: too few souls says how many are needed (%s)" % buy.text)
	Profile.levels[String(vitality.id)] = vitality.max_level
	Profile.changed.emit()
	check(buy.disabled and buy.text == "Maxed", "shrine: a maxed upgrade says so")
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
	for name in ["MusicSlider", "SoundSlider", "ShakeSlider", "ControlsSlider", "VibrationsCheck", "FixedStickCheck", "BatteryCheck", "FewerEffectsCheck", "RunTimerCheck", "TutorialCheck", "ReplayTutorialButton", "CloseButton"]:
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
	(options.get_node("%CloseButton") as Button).pressed.emit()
	await _frames(1)
	check(not options.visible, "options: Close")


# --- Gameplay (bot) ----------------------------------------------------------


## Every node under `root` for which `test` is true.
func _find_all(root: Node, test: Callable) -> Array:
	var found := []
	for child in root.get_children():
		if test.call(child):
			found.append(child)
		found.append_array(_find_all(child, test))
	return found
