class_name TitleTests
extends TestSuite
## The title screen and its panels.

func run() -> void:
	await _test_title_screen()


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
	check(codex.visible and list.get_child_count() == codex.bestiary_entries().size(), "the bestiary lists every monster and boss")
	check(codex.bestiary_entries().any(func(m: MonsterDef) -> bool: return m is BossDef), "bosses are in the bestiary")
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


# --- Gameplay (bot) ----------------------------------------------------------
