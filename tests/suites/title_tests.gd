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
	check(shrine.visible and rows.get_child_count() == CONTENT.upgrades.size(), "the shrine lists every upgrade")
	var first: UpgradeRow = rows.get_child(0)
	(first.get_node("%BuyButton") as Button).pressed.emit()
	await _frames(1)
	check(Profile.level_of(first.upgrade) == 1 and Profile.souls < 500, "buying at the shrine")
	check((title.get_node("%Souls") as Label).text.contains(str(Profile.souls)), "the shrine shows the souls left")
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
	check(entries.size() == CONTENT.all_monsters().size() + entries.filter(func(m: MonsterDef) -> bool: return m is BossDef).size(), "every monster once")
	var slime_card := monster_cards[entries.find(load("res://data/monsters/slime.tres"))]
	var unseen := entries.filter(func(m: MonsterDef) -> bool: return Bestiary.rank_of(m, CONTENT.bestiary) == Bestiary.UNSEEN)
	check(not slime_card.disabled and monster_cards[entries.find(unseen[0])].disabled, "slain monsters open their page, unknown ones don't")
	check(_texts(slime_card).has("Known") and _texts(slime_card).has("1 slain") and _texts(monster_cards[entries.find(unseen[0])]).has("???"), "a card shows the rank and the kills (unknown ones: ???)")
	check(Profile.bestiary_rank(&"slime") == 1, "the first kill pays the first rank")
	check((codex.get_node("%Help") as Label).text.contains("rank"), "the bestiary explains the hunter ranks")
	slime_card.pressed.emit()
	await _frames(2)
	check(codex.is_page_open() and not (codex.get_node("%Scroll") as Control).is_visible_in_tree(), "tapping a monster opens its page")
	var page_text := " ".join(_texts(codex.get_node("%MonsterPage")))
	check(page_text.contains("Health") and page_text.contains("Move speed") and page_text.contains("Mastered: slay") and page_text.contains("Shiny"), "the page explains the stats, the ranks and the Shiny")
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
