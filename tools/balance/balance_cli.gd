extends Node
## The balance tools' command line (tools/balance/balance.tscn). From the project root:
##   godot --headless --fixed-fps 60 res://tools/balance/balance.tscn -- --mode=model
## Options (all optional):
##   --mode=model|arena|pack|marginal|economy|compound|all   what to run (default model)
##       model     static tables: every monster x rank x depth x difficulty, boss x phase x rank,
##                 weapon x rarity x armor, builds, the curve (seconds)
##       arena     real boss fights (every boss x builds of its act x difficulty x bot, boss ranks)
##                 and every weapon vs every boss
##       pack      rooms of each act's monsters: each kind, mixed rooms, ranked monsters
##       marginal  every perk level, relic, family, rune, affix, shrine level, encounter outcome
##                 added alone to each act's expected build (engine)
##       economy   real floors harvested: gold, XP, loot, shop prices, souls vs the shrine
##       compound  stacks that multiply: attack speed x crit x damage, projectiles, echo, burns,
##                 armor vs weak hits, healing vs the sustain cap
##       all       everything above, one report
##   --quick                       a small subset of each mode (the "balance" test suite)
##   --boss=king_slime,...         bosses (arena)
##   --build=expected_a1,...       builds (data/balance/builds/<name>.tres)
##   --difficulty=normal,hard      easy, normal, hard, nightmare, nightmare+N (default: all six of
##                                 easy..nightmare+10; --quick: normal)
##   --bot=face_tank,kite          arena/pack bots (default both)
##   --acts=2,4                    marginal: acts measured (default all)
##   --out=<dir>                   where reports go (default user://balance/)
##   --seed=N                      every measure starts from this seed (default 1): same run, same numbers
##   --all-pairs                   arena: every build against every boss
##   --timeout=240                 arena: game seconds before a fight is called a timeout
##   --jobs=2                      all: run the arena in a second Godot process (2 CPUs: ~half the time)
##   --in=<dir>,<dir>              merge: combine the reports of earlier runs (their state.json) into --out
## Each mode writes report.md (FLAGS first, numbered, then numbered tables), data.json, csv/ and
## state.json into <out>/<mode>/; --mode=all also writes <out>/report.md and <out>/data.json
## with everything. A short summary goes to stdout. Exit code 0 (flags are findings, not failures).

const DEFAULT_OUT := "user://balance"
const MODES := ["model", "arena", "pack", "marginal", "economy", "compound"]

var _args := {}


func _ready() -> void:
	var args := parse_args(OS.get_cmdline_user_args())
	_args = args
	var started := Time.get_ticks_msec()
	BalanceLab.isolate_profile()
	var content: ContentDB = load("res://data/content_db.tres")
	var targets := BalanceBuild.load_targets()
	var every_build := BalanceBuild.load_all()
	var builds := BalanceBuild.select(every_build, args.builds)
	var out_dir: String = args.out
	if out_dir.begins_with("user://") or out_dir.begins_with("res://"):
		out_dir = ProjectSettings.globalize_path(out_dir)
	var mode: String = args.mode
	if mode == "merge":
		_merge(args.inputs, out_dir)
		await _quit(0)
		return
	if builds.is_empty():
		printerr("balance: no build matches %s (see data/balance/builds/)" % ", ".join(args.builds))
		await _quit(1)
		return
	var keys: PackedStringArray = args.difficulties
	if keys.is_empty() and args.quick:
		keys = PackedStringArray(["normal"])
	var difficulties := BalanceContent.difficulties(content, keys)
	var bosses := _bosses(content, args.bosses)
	var modes: Array = MODES.duplicate() if mode == "all" else [mode]
	if not MODES.has(mode) and mode != "all":
		printerr("balance: unknown --mode=%s (%s, all, merge)" % [mode, ", ".join(MODES)])
		await _quit(1)
		return

	var lab := BalanceLab.new()
	lab.content = content
	lab.seed_value = args.seed
	add_child(lab)

	# --jobs=2: the arena (the longest part) in a second process.
	var child_pid := -1
	var child_dir := out_dir.path_join("arena")
	if mode == "all" and int(args.jobs) > 1:
		modes.erase("arena")
		var child_args := PackedStringArray(["--headless", "--fixed-fps", "60", "--path", ProjectSettings.globalize_path("res://"),
			"res://tools/balance/balance.tscn", "--", "--mode=arena", "--out=%s" % out_dir, "--seed=%d" % args.seed,
			"--timeout=%s" % args.timeout])
		var flags := { "builds": "--build", "difficulties": "--difficulty", "bosses": "--boss", "bots": "--bot" }
		for key: String in flags:
			if not (args[key] as PackedStringArray).is_empty():
				child_args.append("%s=%s" % [flags[key], ",".join(args[key])])
		if args.quick:
			child_args.append("--quick")
		if args.all_pairs:
			child_args.append("--all-pairs")
		child_pid = OS.create_process(OS.get_executable_path(), child_args)
		print("balance: arena running in process %d (--jobs=%d)" % [child_pid, args.jobs])

	var reports: Array[BalanceReport] = []
	for m: String in modes:
		var mode_started := Time.get_ticks_msec()
		var report: BalanceReport = await _run_mode(m, content, targets, every_build, builds, difficulties, bosses, lab)
		if report == null:
			continue
		report.notes.append("Run: %s" % _command(args))
		report.timings[m] = (Time.get_ticks_msec() - mode_started) / 1000.0
		report.write(out_dir.path_join(m))
		report.save_state(out_dir.path_join(m).path_join("state.json"))
		reports.append(report)
		print(report.summary())
		print("balance: %s done in %.0f s (real time)" % [m, report.timings[m]])

	if child_pid > 0:
		while OS.is_process_running(child_pid):
			await get_tree().create_timer(2.0).timeout
		var arena := BalanceReport.load_state(child_dir.path_join("state.json"))
		if arena:
			reports.append(arena)
			print(arena.summary())
		else:
			printerr("balance: the arena process left no report in %s" % child_dir)

	if mode == "all":
		var combined := _combine(reports)
		combined.notes.insert(0, "Run: %s" % _command(args))
		combined.write(out_dir)
		combined.save_state(out_dir.path_join("state.json"))
		print("")
		print(combined.summary(20))
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("balance: %s done in %.0f s (real time). Reports in %s" % [mode, seconds, out_dir])
	lab.queue_free()
	await _quit(0)


func _run_mode(m: String, content: ContentDB, targets: BalanceTargets, every_build: Array[BalanceBuildDef], builds: Array[BalanceBuildDef],
		difficulties: Array[DifficultyDef], bosses: Array[BossDef], lab: BalanceLab) -> BalanceReport:
	var args := _args
	match m:
		"model":
			var model := BalanceModel.new(content, targets, every_build)
			model.builds = builds
			model.difficulties = difficulties if not args.quick else BalanceContent.difficulties(content, PackedStringArray(["normal", "hard"]))
			model.bosses = bosses
			model.quick = args.quick
			return model.run()
		"arena":
			var arena := _arena(content, targets, every_build, builds, difficulties, bosses, lab)
			var report := await arena.run_bosses()
			var weapons := await arena.run_weapons()
			report.merge(weapons, "weapons")
			report.title = "Balance arena"
			arena.queue_free()
			return report
		"pack":
			var arena := _arena(content, targets, every_build, builds, difficulties, bosses, lab)
			var report := await arena.run_packs()
			arena.queue_free()
			return report
		"marginal":
			var marginal := BalanceMarginal.new()
			marginal.lab = lab
			marginal.content = content
			marginal.targets = targets
			marginal.all_builds = every_build
			marginal.seed_value = args.seed
			marginal.quick = args.quick
			for a: String in args.acts:
				marginal.acts.append(int(a))
			if args.quick and marginal.acts.is_empty():
				marginal.acts.append(2)
			add_child(marginal)
			var report := await marginal.run()
			marginal.queue_free()
			return report
		"economy":
			var economy := BalanceEconomy.new()
			economy.lab = lab
			economy.content = content
			economy.targets = targets
			economy.all_builds = every_build
			economy.difficulties = difficulties
			economy.seed_value = args.seed
			economy.quick = args.quick
			add_child(economy)
			var report := await economy.run()
			economy.queue_free()
			return report
		"compound":
			var compound := BalanceCompound.new()
			compound.lab = lab
			compound.content = content
			compound.targets = targets
			compound.all_builds = every_build
			compound.seed_value = args.seed
			compound.quick = args.quick
			add_child(compound)
			var report := await compound.run()
			compound.queue_free()
			return report
	return null


func _arena(content: ContentDB, targets: BalanceTargets, every_build: Array[BalanceBuildDef], builds: Array[BalanceBuildDef],
		difficulties: Array[DifficultyDef], bosses: Array[BossDef], lab: BalanceLab) -> BalanceArena:
	var arena := BalanceArena.new()
	arena.lab = lab
	arena.content = content
	arena.targets = targets
	arena.all_builds = every_build
	arena.builds = builds
	arena.difficulties = difficulties
	arena.core = arena.core_difficulties()
	arena.bosses = bosses
	arena.bots = _args.bots
	arena.seed_value = _args.seed
	arena.all_pairs = _args.all_pairs
	arena.timeout = _args.timeout
	arena.quick = _args.quick
	add_child(arena)
	return arena


static func _combine(reports: Array[BalanceReport]) -> BalanceReport:
	var combined := BalanceReport.new()
	combined.title = "Balance report"
	for report in reports:
		var key := report.title.trim_prefix("Balance ").to_lower().replace(" ", "_")
		combined.notes.append("%s: %d errors, %d warnings, %.0f s" % [report.title, report.error_count(), report.warn_count(), _total(report.timings)])
		combined.merge(report, key)
	var total := 0.0
	for key: String in combined.timings:
		total += float(combined.timings[key])
	combined.notes.append("Real time per part: %s" % ", ".join(combined.timings.keys().map(func(k: String) -> String: return "%s %.0f s" % [k, combined.timings[k]])))
	return combined


static func _total(timings: Dictionary) -> float:
	var total := 0.0
	for k: String in timings:
		total += float(timings[k])
	return total


func _merge(inputs: PackedStringArray, out_dir: String) -> void:
	var reports: Array[BalanceReport] = []
	for dir in inputs:
		var path := dir.path_join("state.json")
		var report := BalanceReport.load_state(path)
		if report == null:
			printerr("balance: no state.json in %s" % dir)
			continue
		reports.append(report)
	var combined := _combine(reports)
	combined.write(out_dir)
	combined.save_state(out_dir.path_join("state.json"))
	print(combined.summary(20))
	print("balance: merged %d reports into %s" % [reports.size(), out_dir])


func _quit(code: int) -> void:
	for i in 2:
		await get_tree().process_frame
	get_tree().quit(code)


## { mode, bosses, builds, difficulties, bots, acts, out, seed, all_pairs, timeout, quick, jobs, inputs } from the command line.
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var args := {
		"mode": "model", "bosses": PackedStringArray(), "builds": PackedStringArray(), "difficulties": PackedStringArray(),
		"bots": PackedStringArray(["face_tank", "kite"]), "acts": PackedStringArray(), "out": DEFAULT_OUT, "seed": 1,
		"all_pairs": false, "timeout": 240.0, "quick": false, "jobs": 1, "inputs": PackedStringArray(),
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
			"--acts", "--act": args.acts = value.split(",", false)
			"--out": args.out = value
			"--seed": args.seed = int(value)
			"--all-pairs": args.all_pairs = true
			"--timeout": args.timeout = float(value)
			"--quick": args.quick = true
			"--jobs": args.jobs = maxi(1, int(value))
			"--in": args.inputs = value.split(",", false)
	return args


static func _command(args: Dictionary) -> String:
	var parts := PackedStringArray(["--mode=%s" % args.mode])
	if args.quick:
		parts.append("--quick")
	for key: String in ["bosses", "builds", "difficulties", "bots", "acts"]:
		if not (args[key] as PackedStringArray).is_empty():
			parts.append("--%s=%s" % [key, ",".join(args[key])])
	parts.append("--seed=%d" % args.seed)
	if args.all_pairs:
		parts.append("--all-pairs")
	if int(args.jobs) > 1:
		parts.append("--jobs=%d" % args.jobs)
	return " ".join(parts)


static func _bosses(content: ContentDB, ids: PackedStringArray) -> Array[BossDef]:
	var result: Array[BossDef] = []
	for boss in BalanceContent.bosses(content):
		if ids.is_empty() or ids.has(String(boss.id)):
			result.append(boss)
	return result
