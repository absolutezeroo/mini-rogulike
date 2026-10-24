extends Node
## Headless test runner. From a terminal at the project root:
##   godot --headless --fixed-fps 60 res://tests/run_tests.tscn
## Only some suites:  ... res://tests/run_tests.tscn -- --only=unit,title
## Suites (tests/suites/): unit (rules and data), title (title screen), game (a bot plays the real
## game, then combat, floor, secret and boss tests on it), tutorial (the first steps and the hints). Exit code = number of failed checks.

const SUITES := {
	"unit": preload("res://tests/suites/unit_tests.gd"),
	"title": preload("res://tests/suites/title_tests.gd"),
	"game": preload("res://tests/suites/game_tests.gd"),
	"tutorial": preload("res://tests/suites/tutorial_tests.gd"),
}
## Opt-in suites, run only when named in --only (balance: the balance targets with tools/balance;
## some of its checks fail on purpose today, see docs/balance.md). Loaded then, so a broken tool
## can't stop the other suites.
const OPT_IN := {
	"balance": "res://tests/suites/balance_tests.gd",
}


func _ready() -> void:
	# Without a sound card, playbacks are never released; keep the output clean.
	Sfx.enabled = false
	# Never touch the player's real save.
	Profile.save_path = ""
	Profile.reset()
	# Hints would pop up all over the other tests (the tutorial tests turn them on).
	Settings.tutorial_hints = false
	# No boss story before each fight either (the story tests turn them on).
	Settings.boss_stories = Settings.STORIES_OFF
	Settings.path = ""
	# The checks read English texts, whatever the machine's (or the saved) language.
	Settings.language = "en"
	Settings.apply()
	# The online leaderboards: no file, no server (never the network; LeaderboardTests uses a fake).
	Leaderboards.use_for_tests()
	# The player's privacy choices and the gameplay statistics: no file, no question on the title
	# screen, nothing queued (PrivacyTests turns them on with a fake server).
	Privacy.use_for_tests()
	Telemetry.use_for_tests()
	# The world counters: no file, nothing counted, read or sent (WorldStatsTests uses a fake).
	WorldStats.use_for_tests()
	# The remote settings: no file, nothing read, the game's own values (RemoteConfigTests uses a fake).
	RemoteConfig.use_for_tests()
	# Player feedback: no file, nothing waiting (FeedbackTests uses a fake server).
	Feedback.use_for_tests()
	# The suites play the phone's game (touch controls, "Tap" texts) unless a test picks a
	# keyboard or a gamepad (the pc tests); a test that sends a key puts touch back after it.
	InputDevice.use(InputDevice.Kind.TOUCH)
	RunSave.path = "user://test_run_%d.json" % OS.get_process_id()  # one per test process
	RunSave.erase()
	var only := _only()
	var suites := SUITES.duplicate()
	for suite_name: String in OPT_IN:
		if only.has(suite_name):
			suites[suite_name] = load(OPT_IN[suite_name])
	for suite_name: String in suites:
		if not only.is_empty() and not only.has(suite_name):
			continue
		var script: GDScript = suites[suite_name]
		if script == null or not script.can_instantiate() or not _helpers_compile():
			# A suite (or a script it uses) doesn't compile: that is a failure, not 0 checks.
			TestSuite.failures += 1
			printerr("FAIL: the %s suite doesn't compile" % suite_name)
			continue
		var suite: TestSuite = script.new()
		add_child(suite)
		var before := TestSuite.checks
		await suite.run()
		print("%s: %d checks" % [suite_name, TestSuite.checks - before])
		suite.queue_free()
	RunSave.erase()
	print("\n%d checks, %d failed" % [TestSuite.checks, TestSuite.failures])
	Sfx.stop_all()
	HitStop.reset()
	for i in 2:
		await get_tree().process_frame
	get_tree().quit(TestSuite.failures)


## Suites asked for with --only=a,b (all of them when empty).
func _only() -> PackedStringArray:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return arg.trim_prefix("--only=").split(",", false)
	return PackedStringArray()


## The suites the game suite borrows from compile too (a parse error in one would otherwise
## only show as a script error, with 0 failed).
func _helpers_compile() -> bool:
	for path in ["res://tests/suites/floor_tests.gd", "res://tests/suites/combat_tests.gd", "res://tests/suites/boss_tests.gd", "res://tests/suites/secret_tests.gd", "res://tests/suites/story_tests.gd", "res://tests/suites/finale_tests.gd", "res://tests/suites/pc_tests.gd", "res://tests/suites/bag_tests.gd", "res://tests/suites/dialogue_tests.gd", "res://tests/suites/level_tests.gd", "res://tests/suites/debug_tests.gd", "res://tests/suites/leaderboard_tests.gd", "res://tests/suites/privacy_tests.gd", "res://tests/suites/world_stats_tests.gd", "res://tests/suites/remote_config_tests.gd", "res://tests/suites/feedback_tests.gd", "res://tests/suites/soft_keyboard_tests.gd", "res://tests/suites/keeper_tests.gd", "res://tests/suites/tap_tests.gd"]:
		var helper := load(path) as GDScript
		if helper == null or not helper.can_instantiate():
			printerr("FAIL: %s doesn't compile" % path)
			return false
	return true
