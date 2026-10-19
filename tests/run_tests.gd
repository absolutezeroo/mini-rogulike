extends Node
## Headless test runner. From a terminal at the project root:
##   godot --headless --fixed-fps 60 res://tests/run_tests.tscn
## Only some suites:  ... res://tests/run_tests.tscn -- --only=unit,title
## Suites (tests/suites/): unit (rules and data), title (title screen), game (a bot plays the real
## game, then combat, floor and boss tests on it). Exit code = number of failed checks.

const SUITES := {
	"unit": preload("res://tests/suites/unit_tests.gd"),
	"title": preload("res://tests/suites/title_tests.gd"),
	"game": preload("res://tests/suites/game_tests.gd"),
}


func _ready() -> void:
	# Without a sound card, playbacks are never released; keep the output clean.
	Sfx.enabled = false
	# Never touch the player's real save.
	Profile.save_path = ""
	Profile.reset()
	Settings.path = ""
	RunSave.path = "user://test_run_%d.json" % OS.get_process_id()  # one per test process
	RunSave.erase()
	var only := _only()
	for suite_name: String in SUITES:
		if not only.is_empty() and not only.has(suite_name):
			continue
		var suite: TestSuite = SUITES[suite_name].new()
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
