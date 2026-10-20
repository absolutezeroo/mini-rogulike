class_name BalanceTests
extends TestSuite
## Opt-in suite (only with --only=balance): the game's balance against its targets
## (data/balance/targets.tres), with the balance tools in their --quick form (tools/balance/,
## docs/balance.md > Tools):
## - the builds' data is sound, every kind of build exists, the content is all listed;
## - the model (Normal and Hard): one check per kind of target (all its flags are target breaks);
## - three real duels against the act I boss on Normal: the degenerate lifesteal build and the
##   expected build face-tanking (both must lose, with little healing), the expected build kiting
##   (should win);
## - the lab's quick marginal values (act II, a few picks) and economy (two Normal floors) run.
## Some of these FAIL today, on purpose: they are the balance work to do. Those are listed in
## KNOWN and printed as "FAIL (KNOWN ...)": they still count as failures. When one starts
## passing, remove it from KNOWN; a failure not in KNOWN is new.

## Checks known to fail on KNOWN_DATE (the baseline before any rebalancing), by the key printed with them.
const KNOWN := [
	"model: boss TTK", "model: boss hits to kill", "model: face-tank wins", "model: heal share",
	"model: monster TTK", "model: elite TTK", "model: epic TTK", "model: legendary TTK", "model: shiny TTK",
	"model: act curve",
	"duel: degenerate_lifesteal_a1 face-tank loses",
	"economy: shop",
]
const KNOWN_DATE := "2026-10-20"


func run() -> void:
	var targets := BalanceBuild.load_targets()
	var builds := BalanceBuild.load_all()
	check(builds.size() >= 10, "balance builds found in data/balance/builds/ (%d)" % builds.size())
	for tag in ["baseline", "expected", "degenerate", "family"]:
		check(builds.any(func(b: BalanceBuildDef) -> bool: return b.has_tag(tag)), "a %s build exists" % tag)
	for act in range(1, CONTENT.dungeon.acts.size() + 1):
		check(BalanceBuild.expected(builds, act) != null, "an expected build for act %d" % act)
	for synergy in CONTENT.synergies:
		check(builds.any(func(b: BalanceBuildDef) -> bool: return b.has_tag("family") and b.has_tag(String(synergy.id))), "a family build for %s" % synergy.id)
	for build in builds:
		for problem in BalanceBuild.problems(build, CONTENT):
			check(false, "build data: %s" % problem)
	for key in BalanceContent.ALL_DIFFICULTIES:
		check(BalanceContent.difficulty(CONTENT, key) != null, "the tools know the difficulty %s" % key)

	# The model: one check per kind of target.
	var model := BalanceModel.new(CONTENT, targets, builds)
	model.difficulties = BalanceContent.difficulties(CONTENT, PackedStringArray(["normal", "hard"]))
	model.quick = true
	var report := model.run()
	check(report.tables.size() >= 10, "the model wrote its tables (%d)" % report.tables.size())
	_targets_of(report, ["model: boss TTK", "model: boss hits to kill", "model: face-tank wins", "model: heal share",
		"model: monster TTK", "model: monster hits to kill", "model: elite TTK", "model: epic TTK", "model: legendary TTK",
		"model: shiny TTK", "model: ranked boss TTK", "model: act curve", "model: difficulty curve", "model: degenerate DPS",
		"model: weapon DPS", "content: unlisted", "build data"])

	# Phase 2C: the five families built on purpose stay comparable (DPS vs the expected act III
	# build: each 1.0x-1.5x; Blood's strength is its sustain and low-health power, not raw DPS).
	var family_ratios := {}
	for table: Dictionary in report.tables:
		if table.name == "degenerate_dps":
			for row: Array in table.rows:
				family_ratios[String(row[0])] = float(String(row[6]).trim_suffix("x"))
	for synergy in CONTENT.synergies:
		var key := "family_%s_a3" % synergy.id
		var ratio: float = family_ratios.get(key, -1.0)
		_target(ratio >= 1.0 and ratio <= 1.5, "family: %s DPS" % synergy.id, "%s: %.2fx the expected build's DPS (target 1.0-1.5x)" % [key, ratio])

	# Real duels on the engine.
	var lab := BalanceLab.new()
	lab.content = CONTENT
	add_child(lab)
	var arena := BalanceArena.new()
	arena.lab = lab
	arena.content = CONTENT
	arena.targets = targets
	arena.all_builds = builds
	arena.verbose = false
	add_child(arena)
	lab.override_chances()
	var boss: BossDef = CONTENT.dungeon.acts[0].boss
	var normal := BalanceContent.difficulty(CONTENT, "normal")
	for duel: Array in [["degenerate_lifesteal_a1", "face_tank"], ["expected_a1", "face_tank"], ["expected_a1", "kite"]]:
		var build := BalanceBuild.find(builds, duel[0])
		if build == null:
			check(false, "build %s exists" % duel[0])
			continue
		var r := await arena.fight_boss(boss, build, normal, duel[1])
		var line := BalanceArena.fight_line(r)
		print("  duel: %s" % line)
		check(r.result != "error", "the duel %s %s ran (%s)" % [duel[0], duel[1], r.get("error", "")])
		if duel[1] == "face_tank":
			_target(r.result != "win", "duel: %s face-tank loses" % duel[0], "%s vs %s on Normal: %s" % [duel[0], boss.id, line])
			var share_max := targets.heal_share_max_degenerate if build.has_tag("degenerate") else targets.heal_share_max_expected
			_target(r.heal_share <= share_max, "duel: %s heal share" % duel[0], "healed %d%% of the damage taken (target <= %d%%): %s" % [
				roundi(r.heal_share * 100.0), roundi(share_max * 100.0), BalanceLab.sources_text(r.get("heal_sources", {}))])
		else:
			_target(r.result == "win", "duel: %s kite wins" % duel[0], "%s vs %s on Normal: %s" % [duel[0], boss.id, line])
	lab.restore_chances()
	arena.queue_free()

	# The lab: quick marginal values and economy run and measure something.
	var marginal := BalanceMarginal.new()
	marginal.lab = lab
	marginal.content = CONTENT
	marginal.targets = targets
	marginal.all_builds = builds
	marginal.quick = true
	marginal.verbose = false
	marginal.acts = [2] as Array[int]
	add_child(marginal)
	var m_report := await marginal.run()
	var values: Array = m_report.data.get("marginal", [])
	check(values.size() >= 6, "marginal values measured (%d)" % values.size())
	check(values.any(func(e: Dictionary) -> bool: return e.id == "strength" and e.dps > 0.0), "Strength adds measured DPS on the act II build")
	check(values.any(func(e: Dictionary) -> bool: return e.id == "might" and e.dps > 0.0), "the Might shrine level adds measured DPS")
	_targets_of(m_report, ["marginal: too strong", "marginal: too weak"])
	marginal.queue_free()
	var economy := BalanceEconomy.new()
	economy.lab = lab
	economy.content = CONTENT
	economy.targets = targets
	economy.all_builds = builds
	economy.difficulties = [normal] as Array[DifficultyDef]
	economy.quick = true
	economy.verbose = false
	add_child(economy)
	var e_report := await economy.run()
	var floors: Array = e_report.data.get("floors", [])
	check(floors.size() >= 2, "economy floors harvested (%d)" % floors.size())
	check(floors.all(func(f: Dictionary) -> bool: return f.kills > 0 and f.gold_monsters + f.gold_chests + f.gold_props > 0), "every harvested floor gave kills and gold")
	_targets_of(e_report, ["economy: shop", "economy: reroll", "economy: forge", "economy: souls", "economy: build level"])
	economy.queue_free()
	lab.queue_free()
	BalanceLab.isolate_profile()  # back to a clean in-memory profile for whatever runs next


## One _target per category: passes when the report has no flag of it.
func _targets_of(report: BalanceReport, categories: Array) -> void:
	var by_category := {}
	for flag in report.flags:
		if not by_category.has(flag.category):
			by_category[flag.category] = []
		by_category[flag.category].append(flag)
	for category: String in categories:
		var flags: Array = by_category.get(category, [])
		var examples := PackedStringArray()
		for i in mini(flags.size(), 3):
			examples.append("%s: %s (target %s)" % [flags[i].subject, flags[i].value, flags[i].target])
		_target(flags.is_empty(), category, "%d broken%s" % [flags.size(), (": " + "; ".join(examples)) if not examples.is_empty() else ""])


## A target check: counted like check(), printed as KNOWN when it is a known failure.
func _target(ok: bool, key: String, details: String) -> void:
	checks += 1
	if ok:
		if KNOWN.has(key):
			print("  PASS (was a known failure, remove it from KNOWN): %s" % key)
		return
	failures += 1
	if KNOWN.has(key):
		printerr("FAIL (KNOWN, current state %s): %s | %s" % [KNOWN_DATE, key, details])
	else:
		printerr("FAIL: %s | %s" % [key, details])
