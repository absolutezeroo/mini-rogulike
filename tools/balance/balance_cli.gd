extends Node
## The balance tools' command line (tools/balance/balance.tscn). From the project root:
##   godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=model
## Options (all optional):
##   --mode=model|arena|pack|all   what to run (default model)
##   --boss=king_slime,...         bosses (arena; model reports on these)
##   --build=expected_a1,...       builds (data/balance/builds/<name>.tres)
##   --difficulty=normal,hard      difficulties (default normal,hard)
##   --bot=face_tank,kite          arena/pack bots (default both)
##   --out=<dir>                   where reports go (default user://balance/)
##   --seed=N                      every fight starts from this seed (default 1): same run, same numbers
##   --all-pairs                   arena: every build against every boss (default: a build fights the
##                                 bosses of its own act)
##   --timeout=240                 arena: game seconds before a fight is called a timeout
## Each mode writes report.md (FLAGS first, then tables), data.json and a CSV per table into
## <out>/<mode>/; --mode=all also writes <out>/report.md and <out>/data.json with everything.
## A short summary goes to stdout. Exit code 0 (the flags are findings, not failures).

const DEFAULT_OUT := "user://balance"


func _ready() -> void:
	var args := parse_args(OS.get_cmdline_user_args())
	var started := Time.get_ticks_msec()
	BalanceArena.isolate_profile()
	var content: ContentDB = load("res://data/content_db.tres")
	var targets := BalanceBuild.load_targets()
	var every_build := BalanceBuild.load_all()
	var builds := BalanceBuild.select(every_build, args.builds)
	if builds.is_empty():
		printerr("balance: no build matches %s (see data/balance/builds/)" % ", ".join(args.builds))
		get_tree().quit(1)
		return
	var difficulties := _difficulties(content, args.difficulties)
	var bosses := _bosses(content, args.bosses)
	var out_dir: String = args.out
	if out_dir.begins_with("user://") or out_dir.begins_with("res://"):
		out_dir = ProjectSettings.globalize_path(out_dir)
	var mode: String = args.mode
	var reports: Array[BalanceReport] = []

	if mode == "model" or mode == "all":
		var model := BalanceModel.new(content, targets, every_build)
		model.builds = builds
		model.difficulties = difficulties
		model.bosses = bosses
		var report := model.run()
		report.notes.append("Seed: n/a (no randomness). Run: %s" % _command(args))
		report.write(out_dir.path_join("model"))
		reports.append(report)
		print(report.summary())

	if mode == "arena" or mode == "pack" or mode == "all":
		var arena := BalanceArena.new()
		arena.content = content
		arena.targets = targets
		arena.all_builds = every_build
		arena.builds = builds
		arena.difficulties = difficulties
		arena.bosses = bosses
		arena.bots = args.bots
		arena.seed_value = args.seed
		arena.all_pairs = args.all_pairs
		arena.timeout = args.timeout
		add_child(arena)
		if mode == "arena" or mode == "all":
			var report := await arena.run_bosses()
			report.notes.append("Run: %s" % _command(args))
			report.write(out_dir.path_join("arena"))
			reports.append(report)
			print(report.summary())
		if mode == "pack" or mode == "all":
			var report := await arena.run_packs()
			report.notes.append("Run: %s" % _command(args))
			report.write(out_dir.path_join("pack"))
			reports.append(report)
			print(report.summary())
		arena.queue_free()

	if mode == "all":
		var combined := BalanceReport.new()
		combined.title = "Balance report (model, arena, pack)"
		combined.notes.append("Run: %s" % _command(args))
		for report in reports:
			combined.notes.append("%s: %d errors, %d warnings (details in %s/)" % [report.title, report.error_count(), report.warn_count(), report.title.get_slice(" ", 1).to_lower()])
			combined.flags.append_array(report.flags)
			for t in report.tables:
				var copy := t.duplicate()
				copy.name = "%s_%s" % [report.title.get_slice(" ", 1).to_lower(), t.name]
				copy.caption = "%s: %s" % [report.title, t.caption]
				combined.tables.append(copy)
			combined.data[report.title.get_slice(" ", 1).to_lower()] = report.data
		combined.write(out_dir)
	if reports.is_empty():
		printerr("balance: unknown --mode=%s (model, arena, pack, all)" % mode)
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("balance: %s done in %.1f s (real time). Reports in %s" % [mode, seconds, out_dir])
	for i in 2:
		await get_tree().process_frame
	get_tree().quit(0)


## { mode, bosses, builds, difficulties, bots, out, seed, all_pairs, timeout } from the command line.
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var args := {
		"mode": "model", "bosses": PackedStringArray(), "builds": PackedStringArray(),
		"difficulties": PackedStringArray(["normal", "hard"]), "bots": PackedStringArray(["face_tank", "kite"]),
		"out": DEFAULT_OUT, "seed": 1, "all_pairs": false, "timeout": 240.0,
	}
	for arg in user_args:
		var key := arg.get_slice("=", 0)
		var value := arg.substr(key.length() + 1) if arg.contains("=") else ""
		match key:
			"--mode": args.mode = value
			"--boss", "--bosses": args.bosses = value.split(",", false)
			"--build", "--builds": args.builds = value.split(",", false)
			"--difficulty", "--difficulties": args.difficulties = value.split(",", false)
			"--bot", "--bots": args.bots = value.split(",", false)
			"--out": args.out = value
			"--seed": args.seed = int(value)
			"--all-pairs": args.all_pairs = true
			"--timeout": args.timeout = float(value)
	return args


static func _command(args: Dictionary) -> String:
	return "--mode=%s --boss=%s --build=%s --difficulty=%s --bot=%s --seed=%d%s" % [args.mode, ",".join(args.bosses),
		",".join(args.builds), ",".join(args.difficulties), ",".join(args.bots), args.seed, " --all-pairs" if args.all_pairs else ""]


static func _difficulties(content: ContentDB, ids: PackedStringArray) -> Array[DifficultyDef]:
	var result: Array[DifficultyDef] = []
	for difficulty in content.difficulties:
		if ids.is_empty() or ids.has(String(difficulty.id)):
			result.append(difficulty)
	return result


static func _bosses(content: ContentDB, ids: PackedStringArray) -> Array[BossDef]:
	var result: Array[BossDef] = []
	for act in content.dungeon.acts:
		for boss in act.all_bosses():
			if not result.has(boss) and (ids.is_empty() or ids.has(String(boss.id))):
				result.append(boss)
	return result
