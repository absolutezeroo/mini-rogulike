class_name LeaderboardTests
extends TestSuite
## The online leaderboards (Leaderboards, design/progression.md "Online leaderboards"), with a
## fake server in memory (FakeBoardBackend): never the network. run_unit(): the boards' data,
## the pseudonym filter, what is queued and sent (and what never is), the queue kept across a
## restart. run_title(): the Leaderboards page, with and without a server.

var _fake: FakeBoardBackend


func run_unit() -> void:
	_test_defs()
	_test_pseudonyms()
	_test_summary_checks()
	await _test_queue()
	await _test_run_end_event()
	await _test_load_board()
	_restore()


func run_title() -> void:
	await _test_page_unavailable()
	await _test_page_with_server()
	_restore()


## Back to the tests' usual: an offline backend, no file.
func _restore() -> void:
	Leaderboards.use_for_tests()
	if is_instance_valid(_fake):
		_fake = null


## A fresh fake server, and the service on it with no file.
func _use_fake() -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	Leaderboards.use_for_tests(_fake)
	return _fake


func _daily() -> LeaderboardDef:
	return Leaderboards.config.board(&"daily_challenge")


## A Dawn Knell's official attempt that ended on floor 4 (today's).
func _summary(official := true) -> RunSummary:
	var summary := RunSummary.new()
	summary.version = "test"
	summary.daily_day = DailyRun.today()
	summary.daily_official = official
	summary.difficulty = &"normal"
	summary.depth = 4
	summary.kills = 50
	summary.bosses = 1
	summary.gold = 100
	summary.time = 300.0
	summary.weapon = &"katana"
	summary.score = summary.expected_daily_score()
	return summary


func _test_defs() -> void:
	var config := Leaderboards.config
	check(config != null and not config.boards.is_empty(), "the leaderboards' data loads (data/leaderboards/leaderboards.tres)")
	var ids := {}
	var talo := {}
	for board in config.boards:
		check(board.problems().is_empty(), "%s is a valid board: %s" % [board.id, board.problems()])
		check(not ids.has(board.id) and not talo.has(board.talo_name), "%s: its id and Talo name are its own" % board.id)
		ids[board.id] = true
		talo[board.talo_name] = true
	var daily := _daily()
	check(daily != null and daily.shown and daily.submits and daily.score == LeaderboardDef.Score.DAILY_SCORE \
		and daily.period == LeaderboardDef.Period.DAILY and daily.higher_first, "the Dawn Knell's board: shown, daily, points, highest first")
	check(config.shown_boards().size() >= 1, "the page has a tab")
	for difficulty in [&"easy", &"normal", &"hard"]:
		var depth := config.board(StringName("depth_%s" % difficulty))
		var fastest := config.board(StringName("fastest_win_%s" % difficulty))
		check(depth != null and fastest != null and depth.difficulty == difficulty and not fastest.higher_first, "the deepest and the fastest win on %s are prepared as data" % difficulty)
	check(config.board(&"vigil") != null and not config.board(&"vigil").submits, "La Veille's board is prepared, nothing sent to it yet")
	check(config.top_count <= 50 and config.retry_seconds > 0.0 and config.name_min >= 2 and config.name_max <= 24, "the page's and the queue's numbers")
	# The access key: packed into the builds from a file that is never committed.
	var ignored := FileAccess.get_file_as_string("res://.gitignore")
	check(ignored.contains("/online/talo.cfg"), "the access key's file is ignored (never committed)")
	var presets := ConfigFile.new()
	presets.load("res://export_presets.cfg")
	for section in presets.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			check(str(presets.get_value(section, "include_filter", "")).contains("online/talo.cfg"), "%s packs the access key's file" % presets.get_value(section, "name"))
		elif section.ends_with(".options") and presets.has_section_key(section, "permissions/vibrate"):
			check(presets.get_value(section, "permissions/internet", false) == true, "%s may reach the network" % section)
	check(not str(ProjectSettings.get_setting("application/config/version", "")).is_empty(), "the game's version is set (sent with every entry)")


func _test_pseudonyms() -> void:
	var config := Leaderboards.config
	var ok := PlayerName.Problem.NONE
	check(PlayerName.problem("Kagari", config) == ok and PlayerName.problem("Héloïse d'Ombre", config) == ok, "a plain name, accents and an apostrophe are fine")
	check(PlayerName.problem("ab", config) == PlayerName.Problem.TOO_SHORT, "too short")
	check(PlayerName.problem("a".repeat(config.name_max + 1), config) == PlayerName.Problem.TOO_LONG, "too long")
	check(PlayerName.problem("a<b>c", config) == PlayerName.Problem.BAD_CHARACTERS and PlayerName.problem("名前です", config) == PlayerName.Problem.BAD_CHARACTERS, "only the letters the font draws")
	check(PlayerName.problem("1234", config) == PlayerName.Problem.NO_LETTER, "at least a letter")
	check(PlayerName.problem("Sh1t lord", config) == PlayerName.Problem.REFUSED and PlayerName.problem("MÉRDE", config) == PlayerName.Problem.REFUSED, "a refused word, whatever its case, accents or digits")
	check(PlayerName.problem("pd 42", config) == PlayerName.Problem.REFUSED and PlayerName.problem("Spidey", config) == ok, "a short word only as a whole word")
	check(PlayerName.tidy("  Le   Rônin ") == "Le Rônin", "spaces tidied")
	check(PlayerName.readable("名前", config) == "??" and PlayerName.readable("x".repeat(40), config).length() == config.name_max, "a name from the server is drawn safely")
	var default := PlayerName.default_for("abc", config)
	check(PlayerName.problem(default, config) == ok and default == PlayerName.default_for("abc", config), "the default name passes and stays the same (%s)" % default)


func _test_summary_checks() -> void:
	var config := Leaderboards.config
	var summary := _summary()
	check(summary.check(config).is_empty(), "a real run passes the checks (%s)" % summary.check(config))
	summary.score += 1
	check(not summary.check(config).is_empty(), "a score its numbers don't make is refused")
	summary = _summary()
	summary.time = 2.0
	check(summary.check(config) == "too fast", "a run too fast is refused")
	summary = _summary()
	summary.kills = 99999
	summary.score = summary.expected_daily_score()
	check(not summary.check(config).is_empty(), "too many kills is refused")
	summary = _summary()
	summary.bosses = 9
	summary.score = summary.expected_daily_score()
	check(not summary.check(config).is_empty(), "more bosses than floors is refused")
	var props := _summary().props()
	for key in ["v", "diff", "depth", "kills", "time", "weapon", "seed", "relic"]:
		check(props.has(key), "the entry carries the run's %s" % key)


func _test_queue() -> void:
	var fake := _use_fake()
	fake.online = false
	var board := _daily()
	var summary := _summary()
	check(Leaderboards.record(summary) == 1 and Leaderboards.queue.size() == 1, "an official Dawn Knell is queued")
	await _frames(1)
	var item: Dictionary = Leaderboards.queue[0] if not Leaderboards.queue.is_empty() else {}
	check(float(item.get("score", -1)) == summary.score and item.get("board") == String(board.id), "...with its score (%s)" % item.get("score"))
	var props: Dictionary = item.get("props", {})
	check(props.get("day") == str(DailyRun.today()) and props.get("kills") == "50" and props.get("name") == Leaderboards.display_name(), "...its day, the run's numbers and the name as props")
	check(fake.sent.is_empty() and Leaderboards.queue.size() == 1, "no network: it waits")
	# The same day's run going on (a win, then the endless floors): one entry, the better score.
	var later := _summary()
	later.kills = 80
	later.score = later.expected_daily_score()
	Leaderboards.record(later)
	await _frames(1)
	check(Leaderboards.queue.size() == 1 and float(Leaderboards.queue[0].score) == later.score, "one score a day: the better one kept")
	check(Leaderboards.record(_summary(false)) == 0, "a practice attempt is never queued")
	var cheat := _summary()
	cheat.debug = true
	check(Leaderboards.record(cheat) == 0, "a debug run is never queued")
	var normal := _summary()
	normal.daily_day = -1
	normal.daily_official = false
	check(Leaderboards.record(normal) == 0, "a normal run goes on no board yet (the others aren't sent to)")
	var impossible := _summary()
	impossible.score = 999999
	check(Leaderboards.record(impossible) == 0 and not Leaderboards.last_rejection.is_empty(), "an impossible run is never queued (%s)" % Leaderboards.last_rejection)
	check(Leaderboards.queue.size() == 1, "...and the queue still holds one score")

	# A restart: the queue and the device's id are read back from the file.
	var file := "user://test_leaderboards_%d.json" % OS.get_process_id()
	Leaderboards.path = file
	Leaderboards.save_state()
	var device := Leaderboards.device_id
	Leaderboards.load_state()
	check(Leaderboards.queue.size() == 1 and Leaderboards.device_id == device and not device.is_empty(), "the queue and the device's id survive a restart")
	Leaderboards.path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file))

	# The network is back: sent once, the queue empties, the default name goes with it.
	fake.online = true
	await Leaderboards.flush()
	check(Leaderboards.queue.is_empty() and fake.sent.size() == 1, "back online, the score is sent once and the queue empties (%d sent)" % fake.sent.size())
	check(not fake.sent.is_empty() and float(fake.sent[0].score) == later.score and fake.sent[0].period == str(DailyRun.today()), "...the day's best score, for its day")
	check(fake.names.values().has(Leaderboards.display_name()), "...under the player's name")
	await Leaderboards.flush()
	check(fake.sent.size() == 1, "nothing is sent twice")

	# Yesterday's score that couldn't be sent in time: its board is closed, it is dropped.
	Leaderboards.queue.append({ "board": String(board.id), "period": str(DailyRun.today() - 1), "score": 10.0, "props": {}, "at": 0 })
	await Leaderboards.flush()
	check(Leaderboards.queue.is_empty() and fake.sent.size() == 1, "a past day's score is dropped, not sent to today's board")

	# Opted out: nothing is queued or sent.
	Leaderboards.set_shown(false)
	check(Leaderboards.record(_summary()) == 0, "opted out: nothing is queued")
	await Leaderboards.flush()
	check(fake.sent.size() == 1, "...nor sent")
	Leaderboards.set_shown(true)

	# A refused name keeps the old one.
	check(Leaderboards.set_pseudonym("fuck") == PlayerName.Problem.REFUSED and Leaderboards.pseudonym.is_empty(), "a refused pseudonym isn't kept")
	check(Leaderboards.set_pseudonym("  Le Rônin ") == PlayerName.Problem.NONE and Leaderboards.display_name() == "Le Rônin" and Leaderboards.name_chosen, "a good one is, tidied")
	await Leaderboards.flush()
	check(fake.names.values().has("Le Rônin"), "...and the server is told")

	# No access key in the build: offline, nothing queued, nothing fails.
	Leaderboards.use_for_tests()
	check(not Leaderboards.is_available() and not Leaderboards.needs_name(), "no key: no leaderboards")
	check(Leaderboards.record(_summary()) == 0 and Leaderboards.queue.is_empty(), "...and nothing is queued")
	var view: Leaderboards.View = await Leaderboards.load_board(board)
	check(view.status == BoardBackend.Status.UNAVAILABLE, "...the board answers unavailable")


## The end of a real run reaches the queue through Events.run_ended (RunRecords.report_end()).
func _test_run_end_event() -> void:
	var fake := _use_fake()
	fake.online = false
	var day := DailyRun.today()
	var rng := RandomNumberGenerator.new()
	var run := RunState.create(CONTENT, {}, rng, day)
	run.daily_official = true
	run.depth = 2
	run.kills = 12
	run.time = 120.0
	var player := (load("res://src/entities/player/player.tscn") as PackedScene).instantiate() as Player
	player.process_mode = Node.PROCESS_MODE_DISABLED  # (no floor under it)
	add_child(player)
	player.setup(CONTENT.player)
	var records := RunRecords.new()
	records.content = CONTENT
	add_child(records)
	records.bind(run, player)
	records.report_end()
	await _frames(1)
	check(Leaderboards.queue.size() == 1 and float(Leaderboards.queue[0].score) == DailyRun.score(run), "a Dawn Knell's end is queued through Events.run_ended (%d)" % Leaderboards.queue.size())
	run.daily_official = false
	Leaderboards.queue.clear()
	records.report_end()
	check(Leaderboards.queue.is_empty(), "...a practice one isn't")
	run.daily_official = true
	DebugCheats.debug_run = true
	records.report_end()
	DebugCheats.debug_run = false
	check(Leaderboards.queue.is_empty(), "...nor a debug run")
	records.queue_free()
	player.queue_free()
	await _frames(1)


## The page's view: the top, the player's place past it, the lines around.
func _test_load_board() -> void:
	var fake := _use_fake()
	var board := _daily()
	var today := board.period_key()
	fake.fill(board, today, 60, 2000.0, 20.0, PackedStringArray(["Akane", "Basho", "Chiyo"]))
	Leaderboards.keep_default_name()
	var summary := _summary()  # 50 kills, floor 4, a boss, 100 gold: 310 points, rank 86 of 61
	Leaderboards.record(summary)
	await Leaderboards.flush()
	var view: Leaderboards.View = await Leaderboards.load_board(board)
	check(view.status == BoardBackend.Status.OK and view.top.size() == Leaderboards.config.top_count and view.total == 61, "the top 50 of 61 (%d, %d)" % [view.top.size(), view.total])
	check(view.mine != null and view.mine.rank == 61, "the player's place past the top (%s)" % (view.mine.rank if view.mine else -1))
	check(view.around.size() >= 2 and view.around.any(func(e: BoardBackend.Entry) -> bool: return view.mine and e.alias_id == view.mine.alias_id), "...with the lines around it")
	var yesterday: Leaderboards.View = await Leaderboards.load_board(board, 1)
	check(yesterday.status == BoardBackend.Status.OK and yesterday.top.is_empty() and yesterday.mine == null, "yesterday's board is its own (empty here)")
	fake.online = false
	var offline: Leaderboards.View = await Leaderboards.load_board(board)
	check(offline.status == BoardBackend.Status.OFFLINE, "no network: the page is told so")


func _test_page_unavailable() -> void:
	Leaderboards.use_for_tests()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var button := title.get_node("%LeaderboardsButton") as Button
	check(button.is_visible_in_tree(), "the title screen has a Leaderboards button")
	button.pressed.emit()
	await _frames(3)
	var page := title.leaderboards
	check(page.visible and not page.name_dialog.visible, "it opens the page, no name asked without a server")
	var status := page.get_node("%Status") as Label
	check(status.visible and status.text == tr("Online leaderboards are not available in this version of the game."), "no key: the page says the leaderboards are unavailable (%s)" % status.text)
	check(not (page.get_node("%RetryButton") as Control).visible, "...with nothing to retry")
	check(title.back() and not page.visible, "Back closes it")
	title.queue_free()
	await _frames(2)


func _test_page_with_server() -> void:
	var fake := _use_fake()
	var board := _daily()
	fake.fill(board, board.period_key(), 55, 2400.0, 30.0, PackedStringArray(["Akane", "Basho", "Chiyo", "Daigo"]))
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(2)
	var page := title.leaderboards
	(title.get_node("%LeaderboardsButton") as Button).pressed.emit()
	await _frames(3)
	check(page.name_dialog.visible, "the first time, the page asks for a name")
	var edit := page.name_dialog.get_node("%NameEdit") as LineEdit
	edit.text = "shit"
	(page.name_dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	check(page.name_dialog.visible and not (page.name_dialog.get_node("%NameError") as Label).text.is_empty(), "a refused name says why and stays")
	edit.text = "Kagari"
	(page.name_dialog.get_node("%ConfirmButton") as Button).pressed.emit()
	await _frames(4)
	check(not page.name_dialog.visible and Leaderboards.display_name() == "Kagari", "a good one is taken")
	check((page.get_node("%NameText") as Label).text.contains("Kagari"), "the page says the name shown")
	var list := page.get_node("%TopList") as VBoxContainer
	check(list.get_child_count() == Leaderboards.config.top_count, "the top 50 is listed (%d)" % list.get_child_count())
	check((page.get_node("%MineText") as Label).text == tr("You have no score on this board yet."), "no score yet: said so")
	check(_off_grid_texts(page).is_empty(), "the page's texts are on the font's grid: %s" % [_off_grid_texts(page)])
	var screen := get_viewport().get_visible_rect()
	var top_scroll := list.get_parent() as Control
	check(screen.encloses(top_scroll.get_global_rect()), "the list's box stays on the screen")
	for label: Label in page.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and not label.text.is_empty() and not top_scroll.is_ancestor_of(label):
			check(screen.encloses(label.get_global_rect().grow(-1.0)), "%s stays on the screen" % label.text.left(30))
	(page.get_node("%YesterdayTab") as Button).pressed.emit()
	await _frames(3)
	check((page.get_node("%Status") as Label).visible and list.get_child_count() == 0, "yesterday: nobody, said so")
	fake.online = false
	(page.get_node("%TodayTab") as Button).pressed.emit()
	await _frames(3)
	check((page.get_node("%RetryButton") as Control).visible, "no network: Retry")
	fake.online = true
	(page.get_node("%RetryButton") as Button).pressed.emit()
	await _frames(3)
	check(list.get_child_count() > 0 and not (page.get_node("%RetryButton") as Control).visible, "Retry loads it")
	page.close()
	title.queue_free()
	await _frames(2)
