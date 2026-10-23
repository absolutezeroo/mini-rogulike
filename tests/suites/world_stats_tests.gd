class_name WorldStatsTests
extends TestSuite
## The world counters, "The Well's Toll" (WorldStats), on a fake server (FakeBoardBackend): never
## the network. run_unit(): the data (unique internal names, translated names and lines, the
## endings they count), numbers per language, nothing counted, sent or read without consent, in a
## debug run or a debug build, a run's counts batched into one update per counter and capped, the
## queue kept offline and sent when the network is back, withdrawing and deleting, the reads.
## run_title(): the title screen's line and the Toll on the Leaderboards page, shown and hidden.

const FILE := "user://test_world_stats.json"

var _fake: FakeBoardBackend


func run_unit() -> void:
	_test_data()
	_test_numbers()
	await _test_no_consent()
	await _test_debug()
	await _test_batched_run()
	await _test_offline_queue()
	await _test_endings_and_shrine()
	await _test_withdraw_and_delete()
	await _test_reads()
	_restore()


func run_title() -> void:
	await _test_title_line()
	await _test_toll_page()
	_restore()


## A fake server with every counter at 0 (or `values`); `consent`: the statistics accepted and a
## debug build allowed to send (the tests run in one); `published`: the scores published.
func _use_fake(consent: bool, published: bool = false, values: Dictionary = {}) -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	for def in WorldStats.config.stats:
		_fake.world[def.internal_name] = float(values.get(def.internal_name, 0.0))
		_fake.max_change[def.internal_name] = def.max_change
	Leaderboards.use_for_tests(_fake)
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	WorldStats.use_for_tests()
	if published:
		Leaderboards.set_shown(true)
	if consent:
		WorldStats.debug_builds_send = true
		Privacy.answer_age(true)
		Privacy.grant()
	return _fake


func _restore() -> void:
	DebugCheats.debug_run = false
	Leaderboards.use_for_tests()
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	WorldStats.use_for_tests()
	_fake = null


## A run that ended (not a debug one).
func _end_run(debug := false) -> void:
	var summary := RunSummary.new()
	summary.debug = debug
	Events.run_ended.emit(summary)
	await _frames(1)


## The updates the fake got for `internal_name` (their changes).
func _updates(internal_name: String) -> Array[int]:
	var changes: Array[int] = []
	for update in _fake.stat_updates:
		if update.stat == internal_name:
			changes.append(int(update.change))
	return changes


func _ending(id: String) -> EndingDef:
	return load("res://data/story/endings/%s.tres" % id) as EndingDef


func _test_data() -> void:
	var config := WorldStats.config
	check(config != null and config.stats.size() >= 6 and config.stats.size() <= 10, "the world counters load: 6 to 10 of them (data/online/world_stats.tres)")
	var fr := TranslationServer.get_translation_object("fr")
	var names := {}
	var feeds := {}
	for def in config.stats:
		check(not def.internal_name.is_empty() and not names.has(def.internal_name), "%s: an internal name of its own" % def.internal_name)
		names[def.internal_name] = true
		feeds[def.feed] = true
		check(def.internal_name == def.internal_name.to_lower() and not def.internal_name.contains(" "), "%s: Talo's internal name form (lower case, no space)" % def.internal_name)
		check(def.max_change > 0, "%s: a max change" % def.internal_name)
		check(def.title_line.is_empty() or def.title_line.contains("{count}"), "%s: its title line has {count}" % def.internal_name)
		for text in [def.display_name, def.title_line]:
			if text.is_empty():
				continue
			var french := fr.get_message(text) if fr else &""
			check(not String(french).is_empty() and String(french) != text, "%s is translated: %s" % [def.internal_name, text])
			if def.title_line == text:
				check(String(french).contains("{count}"), "%s: the French line keeps {count}" % def.internal_name)
		if def.feed == WorldStatDef.Feed.ENDING:
			check(_ending(String(def.ending)) != null and CONTENT.dungeon.finale.endings.any(func(e: EndingDef) -> bool: return e.id == def.ending), "%s counts an ending the bottom of the Well offers (%s)" % [def.internal_name, def.ending])
	check(feeds.has(WorldStatDef.Feed.KILLS) and feeds.has(WorldStatDef.Feed.DEATHS), "the demons slain and the souls claimed are counted")


func _test_numbers() -> void:
	check(NumberText.of(1284302, "en") == "1,284,302" and NumberText.of(999, "en") == "999" and NumberText.of(1000, "en") == "1,000", "English groups thousands with commas")
	check(NumberText.of(1284302, "fr") == "1 284 302" and NumberText.of(0, "fr") == "0", "French groups them with a narrow no-break space")
	check(Fonts.MAIN.has_char(0x202f), "the font has the narrow no-break space")


func _test_no_consent() -> void:
	_use_fake(false)
	check(not WorldStats.may_send() and not WorldStats.may_read(), "nothing is sent or read before the player chose")
	WorldStats.count(WorldStatDef.Feed.KILLS, 5)
	Events.depth_changed.emit(3)
	Events.souls_offered.emit(40)
	await _end_run()
	await WorldStats.refresh(true)
	check(WorldStats.pending.is_empty() and WorldStats.queue.is_empty(), "without consent nothing is counted")
	check(_fake.calls == 0, "without a choice the server is never called (%d calls)" % _fake.calls)
	check(WorldStats.title_lines().is_empty(), "nothing to show")
	# The scores published, the statistics not accepted: the world is read, nothing is counted.
	_use_fake(false, true, { "demons-slain": 1234 })
	WorldStats.debug_builds_send = true
	WorldStats.count(WorldStatDef.Feed.KILLS, 5)
	await _end_run()
	check(WorldStats.queue.is_empty() and _fake.stat_updates.is_empty(), "published scores alone don't count the player's runs (the statistics' consent does)")
	await WorldStats.refresh(true)
	check(WorldStats.world_value(WorldStats.config.stat("demons-slain")) == 1234.0, "published scores: the world's numbers are read")
	check(WorldStats.my_value(WorldStats.config.stat("demons-slain")) < 0.0, "...but no share of the player's is shown")


func _test_debug() -> void:
	_use_fake(true)
	WorldStats.debug_builds_send = false
	check(not WorldStats.may_send(), "a debug build sends nothing (Talo would add a dev build's updates to the world's numbers)")
	WorldStats.count(WorldStatDef.Feed.KILLS, 3)
	check(WorldStats.pending.is_empty(), "...nor counts")
	WorldStats.debug_builds_send = true
	DebugCheats.debug_run = true
	WorldStats.count(WorldStatDef.Feed.KILLS, 3)
	check(WorldStats.pending.is_empty(), "a debug run counts nothing")
	DebugCheats.debug_run = false
	WorldStats.count(WorldStatDef.Feed.KILLS, 3)
	await _end_run(true)
	check(WorldStats.pending.is_empty() and WorldStats.queue.is_empty() and _fake.stat_updates.is_empty(), "a run told as a debug run sends nothing, and what it counted is dropped")
	WorldStats.use_for_tests()
	check(not WorldStats.may_send(), "the tests send nothing unless they ask for a fake server")


func _test_batched_run() -> void:
	_use_fake(true)
	for i in 37:
		WorldStats.count(WorldStatDef.Feed.KILLS)
	Events.boss_defeated.emit(null)
	for depth in [1, 2, 3, 4, 4]:
		Events.depth_changed.emit(depth)
	check(_fake.stat_updates.is_empty(), "nothing is sent during the run (no call per kill)")
	await _end_run()
	check(_updates("demons-slain") == [37], "the run's kills go in one update (%s)" % [_updates("demons-slain")])
	check(_updates("wardens-laid-to-rest") == [1] and _updates("floors-descended") == [3], "one update per counter: a warden, three floors (the floor resumed isn't counted again)")
	check(_updates("souls-claimed").is_empty() and _updates("potions-drunk").is_empty(), "a counter the run didn't add to isn't sent")
	check(WorldStats.queue.is_empty() and WorldStats.my_value(WorldStats.config.stat("demons-slain")) == 37.0, "sent: the player's share follows")
	# A run past what any run does: capped to the counter's max change.
	var demons := WorldStats.config.stat("demons-slain")
	WorldStats.count(WorldStatDef.Feed.KILLS, demons.max_change * 3)
	await _end_run()
	check(_updates("demons-slain") == [37, demons.max_change], "a run's share is capped to the max change Talo takes (%s)" % [_updates("demons-slain")])
	# A new Dawn Knell counts once, a resumed one doesn't.
	var run := RunState.new()
	run.daily_day = DailyRun.today()
	WorldStats._on_run_started(run, null)  # (the bus would also start the statistics' tracker)
	run.time = 50.0
	WorldStats._on_run_started(run, null)
	check(int(WorldStats.pending.get("dawn-knells-answered", 0)) == 1, "a new Dawn Knell is counted, not when it is resumed")
	WorldStats.pending.clear()


func _test_offline_queue() -> void:
	_use_fake(true)
	WorldStats.path = FILE
	_fake.online = false
	WorldStats.count(WorldStatDef.Feed.KILLS, 10)
	await _end_run()
	WorldStats.count(WorldStatDef.Feed.KILLS, 5)
	WorldStats.count(WorldStatDef.Feed.POTIONS, 2)
	await _end_run()
	check(int(WorldStats.queue.get("demons-slain", 0)) == 15 and int(WorldStats.queue.get("potions-drunk", 0)) == 2 and _fake.stat_updates.is_empty(), "offline: the runs' shares wait, added up")
	# The file keeps them (the app closed); a share counted mid-run too.
	WorldStats.count(WorldStatDef.Feed.FLOORS, 2)
	WorldStats.save_state()
	WorldStats.load_state()
	check(int(WorldStats.queue.get("demons-slain", 0)) == 15 and int(WorldStats.pending.get("floors-descended", 0)) == 2, "the queue and the run's counts survive a restart (user://world_stats.json)")
	_fake.online = true
	await WorldStats.flush()
	check(_updates("demons-slain") == [15] and _updates("potions-drunk") == [2] and WorldStats.queue.is_empty(), "the network back: one update per counter for everything that waited")
	check(int(WorldStats.pending.get("floors-descended", 0)) == 2, "a run still going keeps its counts for its end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FILE))
	WorldStats.path = ""
	# A counter the server refuses is dropped, not tried forever.
	_fake.world.erase("potions-drunk")
	WorldStats.count(WorldStatDef.Feed.POTIONS, 1)
	await _end_run()
	check(not WorldStats.queue.has("potions-drunk"), "a counter the server refuses is dropped")


func _test_endings_and_shrine() -> void:
	_use_fake(true)
	await _end_run()  # (the win is told first...)
	Events.ending_chosen.emit(_ending("ring_the_bell"))  # (...then the ending is chosen)
	await _frames(1)
	check(_updates("last-knells-rung") == [1] and _updates("nameless-keepers").is_empty(), "ringing the bell: one more Last Knell, sent at once")
	Events.ending_chosen.emit(_ending("take_his_place"))
	await _frames(1)
	check(_updates("nameless-keepers") == [1], "taking his place: one more Nameless Keeper")
	Events.souls_offered.emit(120)
	await _frames(1)
	check(_updates("souls-offered") == [120], "souls offered to the Tree go at once")
	var upgrade := CONTENT.upgrades[0]
	Profile.souls = 100000
	var before := _updates("souls-offered").size()
	Profile.buy(upgrade)
	await _frames(1)
	check(_updates("souls-offered").size() == before + 1, "buying at the shrine offers souls (Events.souls_offered)")
	Profile.reset()


func _test_withdraw_and_delete() -> void:
	_use_fake(true)
	_fake.online = false
	WorldStats.count(WorldStatDef.Feed.KILLS, 4)
	await _end_run()
	WorldStats.count(WorldStatDef.Feed.KILLS, 2)
	Privacy.refuse()
	check(WorldStats.queue.is_empty() and WorldStats.pending.is_empty(), "consent withdrawn: what waited is dropped")
	_fake.online = true
	_use_fake(true)
	WorldStats.count(WorldStatDef.Feed.KILLS, 4)
	await _end_run()
	Privacy.forget_online()
	check(WorldStats.mine.is_empty() and WorldStats.queue.is_empty() and WorldStats.world.is_empty(), "\"delete my online data\" forgets every share and number")


func _test_reads() -> void:
	_use_fake(true, false, { "demons-slain": 1284302, "last-knells-rung": 1 })
	await WorldStats.refresh(true)
	var demons := WorldStats.config.stat("demons-slain")
	check(WorldStats.read_status == BoardBackend.Status.OK and WorldStats.world_value(demons) == 1284302.0, "the world's numbers are read")
	var lines := WorldStats.title_lines()
	check(lines.has("1,284,302 demons slain in the Well"), "the title line, its number grouped (%s)" % [lines])
	check(not "\n".join(lines).contains("Last Knell"), "a counter under title_min_count stays off the title")
	var calls := _fake.calls
	await WorldStats.refresh()
	check(_fake.calls == calls, "read again only after refresh_seconds (cached)")
	# Offline: nothing to show, nothing fails.
	_use_fake(true)
	_fake.online = false
	await WorldStats.refresh(true)
	check(WorldStats.read_status == BoardBackend.Status.OFFLINE and WorldStats.title_lines().is_empty(), "offline: nothing shown")
	# No key: nothing at all.
	Leaderboards.use_for_tests()
	check(not WorldStats.may_read() and WorldStats.title_lines().is_empty(), "no server: hidden")


func _test_title_line() -> void:
	_use_fake(true, false, { "demons-slain": 1284302, "souls-claimed": 4521 })
	Settings.language = "fr"
	Settings.apply()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var line := title.world_line
	check(line.visible and (line.text == "1 284 302 démons abattus dans le Puits" or line.text.contains("4 521")), "the title shows a world counter, in French with its number grouped (%s)" % line.text)
	title._world_index += 1
	title.show_world_line()
	var second := line.text
	title._world_index += 1
	title.show_world_line()
	check(line.text != second, "the line turns through the counters")
	check(_off_grid_texts(line).is_empty(), "its text is on the font's grid")
	Settings.language = "en"
	Settings.apply()
	title.queue_free()
	# No choice: no line, and no call.
	_use_fake(false, false, { "demons-slain": 1284302 })
	title = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	check(not title.world_line.visible and _fake.calls == 0, "before a choice: no line, no call")
	title.queue_free()
	await _frames(1)


func _test_toll_page() -> void:
	_use_fake(true, true, { "demons-slain": 1284302 })
	var page := LeaderboardsPanel.new()
	add_child(page)
	WorldStats.count(WorldStatDef.Feed.KILLS, 7)
	await _end_run()
	page.open(LeaderboardsPanel.TOLL)
	await _frames(3)
	var list := page.get_node("%TollList") as VBoxContainer
	check((page.get_node("%TollTab") as Button).button_pressed and (page.get_node("%TollPanel") as Control).visible, "the Toll tab shows the world counters")
	check(list.get_child_count() == WorldStats.config.enabled_stats().size() + 1, "a line per counter, under its heading (%d)" % list.get_child_count())
	var demons := list.get_node_or_null("Toll_demons-slain")
	check(demons != null and (demons.get_child(1) as Label).text == "1,284,309" and (demons.get_child(2) as Label).text == "7", "the world's number and the player's share (%s)" % ((demons.get_child(1) as Label).text if demons else "none"))
	check(not (page.get_node("%TollStatus") as Control).visible, "no state line once read")
	check(_off_grid_texts(page).is_empty(), "the page's texts stay on the font's grid")
	# Offline: says so, Try again.
	_use_fake(true, true)
	_fake.online = false
	page.refresh()
	await _frames(3)
	check((page.get_node("%TollStatus") as Label).visible and (page.get_node("%TollRetryButton") as Control).visible and list.get_child_count() == 0, "offline: a line saying so and Try again, no numbers")
	# No choice: says why, nothing read.
	_use_fake(false)
	page.refresh()
	await _frames(3)
	check((page.get_node("%TollStatus") as Label).visible and _fake.calls == 0, "no choice yet: why, and no call")
	# Back on a board: the board's columns come back.
	page.open()
	await _frames(2)
	check(not (page.get_node("%TollPanel") as Control).visible, "a board tab hides the Toll")
	page.queue_free()
	await _frames(1)
