class_name RemoteConfigTests
extends TestSuite
## The remote settings (RemoteConfig, RemoteTuning) on a fake server (FakeBoardBackend's game
## config): never the network. run_unit(): the allow-list's data, the game's own values offline or
## before a choice, bounds and unknown keys ignored, values applied only at safe points (and kept
## by a run, saved with it), the version gate, the kill switches, the Dawn Knell's omen for its UTC
## day only and nothing else remote in a Dawn Knell (the same race in every time zone), a
## limited-time event, the file. run_title(): the title screen's event plaque and message of the day
## (French), hidden when there are none, and gone once the event ends while the title stays open.

## Per test process (worktrees and parallel runs share one user:// folder).
var _file := "user://test_remote_config_%d.json" % OS.get_process_id()
const RemoteConfigScript := preload("res://src/autoload/remote_config.gd")  # its static helpers are called on the script, not the autoload

var _fake: FakeBoardBackend


func run_unit() -> void:
	_test_data()
	await _test_offline_defaults()
	await _test_bounds_and_unknown()
	await _test_safe_points()
	await _test_run_keeps_its_values()
	await _test_version_gate()
	await _test_kill_switches()
	await _test_daily_omen()
	await _test_daily_untuned()
	_test_daily_time_zones()
	await _test_event()
	await _test_cache()
	_restore()


func run_title() -> void:
	await _test_title_notes()
	await _test_title_event_ends()
	_restore()


## A fake server holding `values` as its game config; `chosen`: an online feature turned on (the
## scores published), without which nothing is read.
func _use_fake(values: Dictionary, chosen: bool = true) -> FakeBoardBackend:
	_fake = FakeBoardBackend.new()
	_fake.config = values.duplicate()
	Leaderboards.use_for_tests(_fake)
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	WorldStats.use_for_tests()
	RemoteConfig.use_for_tests()
	if chosen:
		Leaderboards.set_shown(true)
	return _fake


## A fresh read of the fake's config, then a safe point (the title's).
func _read(values: Dictionary) -> void:
	_use_fake(values)
	await RemoteConfig.fetch(true)
	RemoteConfig.apply()


func _restore() -> void:
	Settings.language = "en"
	Settings.apply()
	Leaderboards.use_for_tests()
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	WorldStats.use_for_tests()
	RemoteConfig.use_for_tests()
	_fake = null


func _difficulty(id: String) -> DifficultyDef:
	return CONTENT.get_difficulty(StringName(id))


func _curse(id: String) -> CurseDef:
	for curse in CONTENT.curses:
		if curse.id == StringName(id):
			return curse
	return null


func _event(id: String) -> FloorEventDef:
	for event in CONTENT.floor_events:
		if event.id == StringName(id):
			return event
	return null


## The UTC date `days` from now ("2026-10-24").
func _date(days: int) -> String:
	return Time.get_date_string_from_unix_time(int(Time.get_unix_time_from_system()) + days * 86400)


## An official Dawn Knell that passes RunSummary.check() (LeaderboardTests' own).
func _summary() -> RunSummary:
	var summary := RunSummary.new()
	summary.version = "test"
	summary.daily_day = DailyRun.today()
	summary.daily_official = true
	summary.difficulty = &"normal"
	summary.depth = 4
	summary.kills = 50
	summary.bosses = 1
	summary.gold = 100
	summary.time = 300.0
	summary.weapon = &"katana"
	summary.score = summary.expected_daily_score()
	return summary


func _test_data() -> void:
	var config := RemoteConfig.config
	check(config != null and config.keys.size() >= 15, "the allow-list loads (data/online/remote_config.tres)")
	var names := {}
	var hooks := {}
	for def in config.keys:
		check(not def.key.is_empty() and not names.has(def.key) and not def.key.begins_with("META_"), "%s: a key of its own (never META_, Talo's reserved prefix)" % def.key)
		names[def.key] = true
		hooks[def.hook] = true
		check(not def.purpose.is_empty(), "%s says what it is for" % def.key)
		if def.kind == RemoteKeyDef.Kind.NUMBER:
			check(def.min_number <= def.default_number and def.default_number <= def.max_number and def.min_number > 0.0, "%s: its default inside its bounds, never 0" % def.key)
			check(is_equal_approx(def.default_number, 1.0), "%s: its default is the data's numbers unchanged (1)" % def.key)
		if def.hook == RemoteKeyDef.Hook.ENEMY_HEALTH or def.hook == RemoteKeyDef.Hook.ENEMY_DAMAGE:
			check(_difficulty(String(def.difficulty)) != null, "%s acts on a difficulty of the game (%s)" % [def.key, def.difficulty])
		if def.hook == RemoteKeyDef.Hook.EVENT_NAME or def.hook == RemoteKeyDef.Hook.MESSAGE:
			check(def.language in ["en", "fr"] and def.kind == RemoteKeyDef.Kind.TEXT, "%s: a text in a language of the game" % def.key)
	for hook: int in RemoteKeyDef.Hook.values():
		check(hooks.has(hook), "every hook has its key (%s)" % RemoteKeyDef.Hook.keys()[hook])
	for difficulty in CONTENT.difficulties:
		check(names.has("enemy_health_%s" % difficulty.id) and names.has("enemy_damage_%s" % difficulty.id), "%s has its Health and damage multipliers" % difficulty.id)
	check(RemoteConfigScript.compare_versions("0.10.0", "0.9.2") == 1 and RemoteConfigScript.compare_versions("0.3", "0.3.0") == 0 and RemoteConfigScript.compare_versions("0.2.9", "0.3.0") == -1, "game versions compare part by part")
	var day: Dictionary = RemoteConfigScript.parse_date("2026-10-31")
	var moment: Dictionary = RemoteConfigScript.parse_date("2026-10-31T18:30:00Z")
	check(day.day_only and int(day.at) == 1793404800 and not moment.day_only and int(moment.at) == 1793404800 + 18 * 3600 + 30 * 60, "dates read as UTC, a day or a moment")
	check(RemoteConfigScript.parse_date("31/10/2026") == null and RemoteConfigScript.parse_date("2026-13-01") == null, "a date in another form is refused")
	check(RemoteConfigScript.parse_date("2026-02-29") == null and RemoteConfigScript.parse_date("2026-04-31") == null and RemoteConfigScript.parse_date("2028-02-29") != null, "a day past its month's end is refused, a leap day taken (no engine error)")


func _test_offline_defaults() -> void:
	# No choice made: nothing is read, not even the config.
	_use_fake({ "souls_multiplier": "2" }, false)
	await RemoteConfig.fetch(true)
	check(_fake.calls == 0 and _fake.config_reads == 0, "before an online choice the config is never read (%d calls)" % _fake.calls)
	# Offline: the game's own values.
	_use_fake({ "souls_multiplier": "2" }, false)
	_fake.online = false
	Leaderboards.set_shown(true)
	await RemoteConfig.fetch(true)
	RemoteConfig.apply()
	check(RemoteConfig.status == BoardBackend.Status.OFFLINE and RemoteConfig.active.is_empty(), "offline: nothing read")
	var tuning := RemoteConfig.tuning(&"normal", DailyRun.today())
	check(tuning.is_neutral() and tuning.apply_to(_difficulty("normal")) == _difficulty("normal"), "offline: the game's own values, the difficulty untouched")
	check(RemoteConfig.message().is_empty() and RemoteConfig.event_info().is_empty() and not RemoteConfig.scores_off() and not RemoteConfig.statistics_off(), "offline: no message, no event, nothing switched off")
	# No key in the build: nothing at all.
	Leaderboards.use_for_tests()
	check(not RemoteConfig.may_fetch(), "no server: never read")


func _test_bounds_and_unknown() -> void:
	await _read({
		"enemy_health_hard": "1.5",
		"enemy_damage_hard": "5",
		"souls_multiplier": "lots",
		"made_up_key": "1",
		"daily_omen": "../../src/game/game.gd",
		"event_floor_event": "frostbound",
		"motd_en": "x".repeat(121),
		"scores_off": "maybe",
		"enemy_health_easy": "0.2",
		"enemy_damage_easy": "",
	})
	check(is_equal_approx(float(RemoteConfig.active.get("enemy_health_hard", 0.0)), 1.5), "a value inside its bounds is taken")
	for key in ["enemy_damage_hard", "souls_multiplier", "made_up_key", "daily_omen", "event_floor_event", "motd_en", "scores_off", "enemy_health_easy", "enemy_damage_easy"]:
		check(not RemoteConfig.active.has(key), "%s is ignored (out of bounds, not a number, unknown, no such id, too long, empty)" % key)
	var ignored := "\n".join(RemoteConfig.ignored)
	check(ignored.contains("made_up_key: not on the allow-list") and ignored.contains("enemy_damage_hard") and ignored.contains("daily_omen"), "what is ignored is listed (and printed in debug builds)")
	check(not ignored.contains("enemy_damage_easy"), "an empty value is just unset")
	var tuning := RemoteConfig.tuning(&"hard")
	check(is_equal_approx(tuning.enemy_health, 1.5) and is_equal_approx(tuning.enemy_damage, 1.0) and is_equal_approx(tuning.souls, 1.0), "out of bounds is ignored, never clamped: the game's own value stays")
	check(is_equal_approx(RemoteConfig.tuning(&"normal").enemy_health, 1.0), "a difficulty's multiplier leaves the others alone")
	check(RemoteConfig.parse(RemoteConfig.config.find("event_floor_event"), "frostbound") == null, "a curse is not a floor event (the event's boost takes floor events only)")
	check(RemoteConfig.parse(RemoteConfig.config.find("daily_omen"), "frostbound") == &"frostbound" and RemoteConfig.parse(RemoteConfig.config.find("daily_omen"), "Blood_Moon") == &"blood_moon", "a curse or event id of the game is taken (any case)")
	check(RemoteConfig.parse(RemoteConfig.config.find("motd_en"), "Line one\nline two") == "Line one line two", "a message keeps to one line")


func _test_safe_points() -> void:
	_use_fake({})  # (the choice made reads the config at once: nothing in it yet)
	RemoteConfig.begin_run()  # (a run going on)
	_fake.config = { "souls_multiplier": "2" }
	await RemoteConfig.fetch(true)
	check(is_equal_approx(float(RemoteConfig.latest.get("souls_multiplier", 0.0)), 2.0), "read during a run...")
	check(RemoteConfig.active.is_empty() and is_equal_approx(RemoteConfig.tuning(&"normal").souls, 1.0), "...it doesn't apply mid-run")
	RemoteConfig.at_title()
	check(not RemoteConfig.in_run and is_equal_approx(RemoteConfig.tuning(&"normal").souls, 2.0), "back at the title (a safe point): it applies")
	_fake.config = { "souls_multiplier": "3" }
	RemoteConfig.begin_run()
	check(is_equal_approx(RemoteConfig.tuning(&"normal").souls, 2.0), "a run starts with what was read before it")
	await RemoteConfig.fetch(true)
	check(is_equal_approx(RemoteConfig.tuning(&"normal").souls, 2.0), "a change read in the run waits")
	RemoteConfig.begin_run()  # (the next run: Retry)
	check(is_equal_approx(RemoteConfig.tuning(&"normal").souls, 3.0), "the next run's start takes it")


func _test_run_keeps_its_values() -> void:
	await _read({ "enemy_health_normal": "1.5", "enemy_damage_normal": "0.8", "souls_multiplier": "2" })
	var base := _difficulty("normal")
	var base_hp := base.monster_hp
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var saved_profile := Profile.difficulty
	Profile.difficulty = &"normal"
	var run := RunState.create(CONTENT, {}, rng)
	check(run.difficulty != base and is_equal_approx(run.difficulty.monster_hp, base_hp * 1.5) and is_equal_approx(run.difficulty.boss_hp, base.boss_hp * 1.5), "the run's difficulty carries the Health multiplier (its own copy)")
	check(is_equal_approx(run.difficulty.monster_damage, base.monster_damage * 0.8) and is_equal_approx(run.difficulty.souls, base.souls * 2.0), "...the damage and the souls")
	check(is_equal_approx(base.monster_hp, base_hp), "the game's difficulty itself is never changed")
	var rules := FloorRules.make(CONTENT.dungeon, run.difficulty, null, 3)
	var plain := FloorRules.make(CONTENT.dungeon, base, null, 3)
	check(is_equal_approx(rules.monster_hp(false), plain.monster_hp(false) * 1.5) and is_equal_approx(rules.floor_damage(), plain.floor_damage() * 0.8), "FloorRules scales the floor with it (no other multiplication)")
	var souls_plain := CONTENT.dungeon.souls_for_run(10, 3, 1, false, base.souls)
	run.kills = 10
	run.depth = 3
	run.bosses_slain = 1
	check(run.souls() == CONTENT.dungeon.souls_for_run(10, 3, 1, false, base.souls * 2.0) and run.souls() > souls_plain, "the run's souls follow the multiplier")
	# Saved and resumed after the config changed: the run keeps its own.
	var data := run.to_data()
	await _read({ "enemy_health_normal": "2" })
	var resumed := RunState.create(CONTENT, data, rng)
	check(is_equal_approx(resumed.difficulty.monster_hp, base_hp * 1.5) and is_equal_approx(resumed.tuning.souls, 2.0), "a resumed run keeps the values it started with")
	var fresh := RunState.create(CONTENT, {}, rng)
	check(is_equal_approx(fresh.difficulty.monster_hp, base_hp * 2.0), "a new run takes the new ones")
	# A save from before the remote settings: today's values, nothing breaks.
	data.erase("remote")
	check(RunState.create(CONTENT, data, rng).difficulty != null, "an older save (no remote values) resumes")
	Profile.difficulty = saved_profile


func _test_version_gate() -> void:
	_use_fake({ "souls_multiplier": "2", "min_version": "0.4.0" })
	RemoteConfig.game_version = "0.3.0"
	await RemoteConfig.fetch(true)
	RemoteConfig.apply()
	check(RemoteConfig.gated and RemoteConfig.active.is_empty(), "a config for newer versions: all of it ignored by this one")
	_use_fake({ "souls_multiplier": "2", "max_version": "0.2.9", "scores_off": "true" })
	RemoteConfig.game_version = "0.3.0"
	await RemoteConfig.fetch(true)
	check(RemoteConfig.gated and not RemoteConfig.scores_off(), "a config for older versions: ignored, its kill switches too")
	_use_fake({ "souls_multiplier": "2", "min_version": "0.3.0", "max_version": "0.3.5" })
	RemoteConfig.game_version = "0.3.0"
	await RemoteConfig.fetch(true)
	RemoteConfig.apply()
	check(not RemoteConfig.gated and is_equal_approx(RemoteConfig.tuning(&"easy").souls, 2.0), "inside the versions: it applies")
	_use_fake({ "souls_multiplier": "2", "min_version": "zero" })
	await RemoteConfig.fetch(true)
	check(not RemoteConfig.gated and "\n".join(RemoteConfig.ignored).contains("min_version"), "a version that isn't one is ignored (not a gate)")


func _test_kill_switches() -> void:
	_use_fake({ "scores_off": "true" })
	Leaderboards.set_pseudonym("Kagari")
	RemoteConfig.begin_run()  # (mid-run: a kill switch applies at once anyway)
	await RemoteConfig.fetch(true)
	check(RemoteConfig.scores_off(), "the scores' kill switch applies as soon as read, mid-run too")
	check(Leaderboards.record(_summary()) == 0 and Leaderboards.queue.is_empty(), "no score is queued")
	await Leaderboards.flush()
	check(_fake.sent.is_empty(), "nor sent")
	_fake.config = {}
	await RemoteConfig.fetch(true)
	check(not RemoteConfig.scores_off() and Leaderboards.record(_summary()) == 1, "lifted: scores go again")
	await _frames(2)
	check(_fake.sent.size() == 1, "...and are sent")
	# The statistics' switch: no events, no world counters.
	_use_fake({})
	WorldStats.debug_builds_send = true
	Privacy.answer_age(true)
	Privacy.grant()
	check(Telemetry.is_active() and WorldStats.may_send(), "consent given: the statistics would go...")
	_fake.config = { "statistics_off": "1" }
	await RemoteConfig.fetch(true)
	check(not Telemetry.is_active() and not WorldStats.may_send(), "...the statistics' kill switch stops them and the world counters")
	WorldStats.count(WorldStatDef.Feed.KILLS, 3)
	check(WorldStats.pending.is_empty(), "nothing is counted meanwhile")
	check(Leaderboards.is_available() and not RemoteConfig.scores_off(), "the scores are a separate switch")


func _test_daily_omen() -> void:
	var today := DailyRun.today()
	await _read({ "daily_omen": "frostbound", "daily_omen_date": _date(0) })
	check(DailyRun.omen(CONTENT, today) == _curse("frostbound"), "the omen is the day's twist")
	check(DailyRun.omen(CONTENT, today + 1) == null and DailyRun.omen(CONTENT, today - 1) == null, "only for that day")
	check(RemoteConfig.tuning(&"normal", today).omen == &"frostbound" and RemoteConfig.tuning(&"normal", -1).omen == &"", "a Dawn Knell of that day carries it, a normal run never")
	var tuning := RemoteConfig.tuning(&"normal", today)
	var depth := 2
	while depth < 20 and FloorRoute.offer(CONTENT, depth, _difficulty("normal"), 11).is_empty():
		depth += 1
	var routes := FloorRoute.offer(CONTENT, depth, _difficulty("normal"), 11, tuning)
	check(not routes.is_empty() and routes.all(func(r: FloorRoute) -> bool: return r.curse == _curse("frostbound") and r.floor_event == null), "every way down is under the omen (%d ways at depth %d)" % [routes.size(), depth])
	var plain := FloorRoute.offer(CONTENT, depth, _difficulty("normal"), 11)
	check(plain.size() == routes.size() and range(plain.size()).all(func(i: int) -> bool: return plain[i].biome == routes[i].biome), "the omen changes nothing else of the offer (the same worlds)")
	await _read({ "daily_omen": "blood_moon", "daily_omen_date": _date(0) })
	check(DailyRun.omen(CONTENT, today) == _event("blood_moon"), "a floor event can be the omen too")
	await _read({ "daily_omen": "frostbound" })
	check(DailyRun.omen(CONTENT, today) == null, "no date, no omen")


## A Dawn Knell is the same race for everyone: no multiplier, souls bonus or event boost reaches it,
## only its day's omen, and a resumed one keeps exactly what it started with.
func _test_daily_untuned() -> void:
	var today := DailyRun.today()
	var everything := { "enemy_health_normal": "1.5", "enemy_damage_normal": "0.8", "souls_multiplier": "2",
		"event_name_en": "Night of Souls", "event_ends": _date(1), "event_souls": "1.5", "event_floor_event": "blood_moon", "event_floor_weight": "10",
		"daily_omen": "frostbound", "daily_omen_date": _date(0) }
	await _read(everything)
	var tuning := RemoteConfig.tuning(&"normal", today)
	check(is_equal_approx(tuning.enemy_health, 1.0) and is_equal_approx(tuning.enemy_damage, 1.0) and is_equal_approx(tuning.souls, 1.0), "a Dawn Knell gets no remote multiplier, even when set")
	check(tuning.event_boost.is_empty() and tuning.event_name.is_empty() and tuning.omen == &"frostbound", "...nor the event's souls or floors: its omen only")
	var base := _difficulty("normal")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var daily := RunState.create(CONTENT, {}, rng, today)
	check(daily.difficulty == base and daily.tuning.omen == &"frostbound" and daily.tuning.event_boost.is_empty() and is_equal_approx(daily.tuning.souls, 1.0), "a new Dawn Knell plays on the game's own Keeper, under its omen")
	var saved_profile := Profile.difficulty
	Profile.difficulty = &"normal"
	var normal := RunState.create(CONTENT, {}, rng)
	Profile.difficulty = saved_profile
	check(normal.difficulty.id == &"normal" and is_equal_approx(normal.difficulty.monster_hp, base.monster_hp * 1.5) and is_equal_approx(normal.tuning.souls, 2.0 * 1.5) and is_equal_approx(normal.tuning.boost_of(&"blood_moon"), 10.0), "a normal run still gets the remote values and the event")
	# Resumed after the config changed: exactly its start values.
	var data := daily.to_data()
	await _read({ "enemy_health_normal": "2", "daily_omen": "blood_moon", "daily_omen_date": _date(0) })
	var resumed := RunState.create(CONTENT, data, rng)
	check(resumed.is_daily() and resumed.difficulty == base and resumed.tuning.omen == &"frostbound" and is_equal_approx(resumed.tuning.enemy_health, 1.0) and resumed.tuning.event_boost.is_empty(), "a resumed Dawn Knell keeps its start values (its omen, nothing else)")
	# A daily saved before this rule with remote values in it: only its omen is kept.
	data["remote"] = { "enemy_health": 2.0, "enemy_damage": 1.5, "souls": 3.0, "omen": "frostbound", "event_boost": { "blood_moon": 10.0 }, "event_name": "Night of Souls" }
	var old := RunState.create(CONTENT, data, rng)
	check(old.difficulty == base and old.tuning.event_boost.is_empty() and old.tuning.event_name.is_empty() and old.tuning.omen == &"frostbound", "an older daily save with remote values: only its omen is kept")
	# The omen belongs to its UTC day, the run's own (not the device's date).
	await _read({ "daily_omen": "frostbound", "daily_omen_date": "2026-11-03" })
	var day := floori(float((RemoteConfigScript.parse_date("2026-11-03") as Dictionary).at) / 86400.0)
	check(RemoteConfig.tuning(&"normal", day).omen == &"frostbound" and RemoteConfig.tuning(&"normal", day - 1).omen == &"" and RemoteConfig.tuning(&"normal", day + 1).omen == &"", "the omen applies to the Dawn Knell of its UTC day only")
	await _read({ "daily_omen": "frostbound", "daily_omen_date": "2026-11-03T23:30:00Z" })
	check(RemoteConfig.tuning(&"normal", day).omen == &"frostbound" and RemoteConfig.tuning(&"normal", day + 1).omen == &"", "a moment's date names its UTC day (23:30 UTC is still that day)")


## Two players at the same instant, one in Tokyo (UTC+9), one in Paris (UTC+2): the same Dawn
## Knell (day, floors, weapon, relic, board key), since everything comes from the Unix time.
func _test_daily_time_zones() -> void:
	# 2026-10-25 08:00 in Tokyo and 2026-10-25 01:00 in Paris are both 2026-10-24 23:00 UTC.
	var tokyo := Time.get_unix_time_from_datetime_string("2026-10-25T08:00:00") - 9 * 3600
	var paris := Time.get_unix_time_from_datetime_string("2026-10-25T01:00:00") - 2 * 3600
	var day_tokyo := DailyRun.today(tokyo)
	var day_paris := DailyRun.today(paris)
	var utc_day := floori(float((RemoteConfigScript.parse_date("2026-10-24") as Dictionary).at) / 86400.0)
	check(tokyo == paris and day_tokyo == day_paris and day_tokyo == utc_day, "the same instant is the same Dawn Knell day in every time zone (the UTC day, %d)" % day_tokyo)
	check(DailyRun.seed_of(day_tokyo) == DailyRun.seed_of(day_paris) and DailyRun.floor_seed(day_tokyo, 3) == DailyRun.floor_seed(day_paris, 3), "...the same floors")
	check(DailyRun.weapon(CONTENT, day_tokyo) == DailyRun.weapon(CONTENT, day_paris) and DailyRun.relic(CONTENT, day_tokyo) == DailyRun.relic(CONTENT, day_paris), "...the same weapon and relic")
	var board := Leaderboards.config.board(&"daily_challenge")
	check(board != null and board.period_key(0, tokyo) == board.period_key(0, paris) and board.period_key(0, tokyo) == str(utc_day), "...and the same day's board")


func _test_event() -> void:
	await _read({ "event_name_en": "Night of Souls", "event_name_fr": "Nuit des Âmes", "event_ends": _date(1), "event_souls": "1.5", "event_floor_event": "blood_moon", "event_floor_weight": "10" })
	var event := RemoteConfig.event_info()
	check(event.get("name") == "Night of Souls" and is_equal_approx(float(event.get("souls", 0.0)), 1.5), "the event runs, with its name and bonus")
	var tuning := RemoteConfig.tuning(&"normal")
	check(is_equal_approx(tuning.souls, 1.5) and is_equal_approx(tuning.boost_of(&"blood_moon"), 10.0) and tuning.event_name == "Night of Souls", "a run started during it gets the souls bonus and the boosted floor event")
	var counts := [0, 0]
	for boosted in 2:
		var rng := RandomNumberGenerator.new()
		rng.seed = 99
		for i in 300:
			if FloorRoute.pick_event(CONTENT, 10, rng, tuning if boosted == 1 else null) == _event("blood_moon"):
				counts[boosted] += 1
	check(counts[1] > counts[0] * 2, "the boosted floor event comes far more often (%d against %d in 300)" % [counts[1], counts[0]])
	OnlineSession.fake_now = int(Time.get_unix_time_from_system()) + 3 * 86400
	check(RemoteConfig.event_info().is_empty() and RemoteConfig.tuning(&"normal").is_neutral(), "past its end: nothing of it applies")
	OnlineSession.fake_now = -1
	await _read({ "event_ends": _date(1), "event_souls": "2" })
	check(RemoteConfig.event_info().is_empty() and is_equal_approx(RemoteConfig.tuning(&"normal").souls, 1.0), "no name: no event")
	await _read({ "event_name_en": "Night of Souls", "event_souls": "2" })
	check(RemoteConfig.event_info().is_empty(), "no end: no event")


func _test_cache() -> void:
	_use_fake({ "motd_en": "The Well stirs.", "made_up_key": "x" })
	RemoteConfig.path = _file
	await RemoteConfig.fetch(true)
	RemoteConfig.fetched.clear()
	RemoteConfig.active.clear()
	RemoteConfig.load_state()
	check(RemoteConfig.fetched.get("motd_en") == "The Well stirs." and not RemoteConfig.fetched.has("made_up_key"), "the last good read survives a restart (user://remote_config.json), the allow-list's keys only")
	check(RemoteConfig.message() == "The Well stirs.", "...and applies from the start (offline too)")
	_fake.online = false
	await RemoteConfig.fetch(true)
	check(RemoteConfig.message() == "The Well stirs.", "a failed read keeps the values kept")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_file))
	RemoteConfig.path = ""


func _test_title_notes() -> void:
	_use_fake({ "event_name_en": "Night of Souls", "event_name_fr": "Nuit des Âmes", "event_ends": _date(3), "event_souls": "1.5",
		"event_floor_event": "blood_moon", "event_floor_weight": "4", "motd_en": "The Well stirs tonight.", "motd_fr": "Le Puits s'agite ce soir." })
	Settings.language = "fr"
	Settings.apply()
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	check(title.event_plaque.visible and title.event_title.text == "Nuit des Âmes", "the title shows the running event, in French (%s)" % title.event_title.text)
	check(title.event_details.text.contains("50") and title.event_details.text.contains(tr(_event("blood_moon").display_name)), "with what it gives (%s)" % title.event_details.text)
	check(title.message_line.visible and title.message_line.text == "Le Puits s'agite ce soir.", "the message of the day, in French")
	check(not (title.get_node("%Subtitle") as Control).visible, "in the tagline's place (no line more in the left column)")
	check(_off_grid_texts(title.event_plaque).is_empty() and _off_grid_texts(title.message_line).is_empty(), "their texts are on the font's grid")
	title.queue_free()
	await _frames(1)
	# Only English given: shown in French games too.
	_use_fake({ "motd_en": "The Well stirs tonight." })
	title = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	check(title.message_line.text == "The Well stirs tonight." and not title.event_plaque.visible, "English is the fallback; no event, no plaque")
	title.queue_free()
	await _frames(1)
	# No choice: nothing read, nothing shown.
	_use_fake({ "motd_en": "The Well stirs tonight." }, false)
	title = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	check(not title.message_line.visible and not title.event_plaque.visible and _fake.calls == 0, "before an online choice: nothing read, nothing shown")
	check((title.get_node("%Subtitle") as Control).visible, "the tagline stays")
	title.queue_free()
	await _frames(1)


## The event ends while the title stays open: the plaque goes at the next check (a fake clock).
func _test_title_event_ends() -> void:
	_use_fake({ "event_name_en": "Night of Souls", "event_ends": _date(1), "event_souls": "1.5" })
	var title: TitleScreen = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	var timer := title.get_node("RemoteNotesTimer") as Timer
	check(title.event_plaque.visible and timer != null and not timer.is_stopped() and is_equal_approx(timer.wait_time, RemoteConfig.config.title_refresh_seconds), "the event shows, and the title checks it again on a timer")
	title.daily_dialog.open(title.content, DailyRun.today())
	check(title.daily_dialog.find_child("EventLine", true, false) != null, "the Dawn Knell's card says the event stays out of it")
	title.daily_dialog.hide()
	var end_at := int((RemoteConfigScript.parse_date(_date(1)) as Dictionary).at) + 86400
	OnlineSession.fake_now = end_at - 30 * 60
	timer.timeout.emit()
	check(title.event_plaque.visible and title.event_details.text.contains(tr("Ends within the hour")), "half an hour before its end: still there, ending within the hour")
	OnlineSession.fake_now = end_at
	timer.timeout.emit()
	check(not title.event_plaque.visible, "its end passed: the plaque is gone without leaving the title")
	title.queue_free()
	await _frames(1)
	# A title shown after the end never shows it.
	title = load("res://src/ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(3)
	check(not title.event_plaque.visible, "a title shown after the event's end has no plaque")
	title.queue_free()
	await _frames(1)
	OnlineSession.fake_now = -1
