class_name BalanceTests
extends TestSuite
## Opt-in suite (only with --only=balance): the game's balance against its targets
## (data/balance/targets.tres), with the balance tools (tools/balance/, docs/balance.md).
## - the builds' data is sound;
## - the model's checks, one per kind of target (all its flags are target breaks);
## - three real duels against the act I boss on Normal: the degenerate lifesteal build and the
##   expected build face-tanking (both must lose, with little healing), the expected build kiting
##   (should win).
## Some of these FAIL today, on purpose: they are the balance work to do (the lifesteal
## face-tank above all). Those are listed in KNOWN and printed as "FAIL (KNOWN ...)": they still
## count as failures. When one starts passing, remove it from KNOWN; a failure not in KNOWN is new.

## Checks known to fail on 2026-10-20 (before any rebalancing), by the key printed with them.
const KNOWN := [
	"model: boss TTK", "model: boss hits to kill", "model: degenerate DPS", "model: elite TTK",
	"model: face-tank wins", "model: heal share", "model: monster TTK", "model: perk value", "model: weapon DPS",
	"duel: degenerate_lifesteal_a1 face-tank loses", "duel: degenerate_lifesteal_a1 heal share",
]
const KNOWN_DATE := "2026-10-20"


func run() -> void:
	var targets := BalanceBuild.load_targets()
	var builds := BalanceBuild.load_all()
	check(builds.size() >= 6, "balance builds found in data/balance/builds/ (%d)" % builds.size())
	for tag in ["baseline", "expected", "degenerate"]:
		check(builds.any(func(b: BalanceBuildDef) -> bool: return b.has_tag(tag)), "a %s build exists" % tag)
	for act in range(1, 5):
		check(builds.any(func(b: BalanceBuildDef) -> bool: return b.act == act and b.has_tag("expected")), "an expected build for act %d" % act)
	for build in builds:
		for problem in BalanceBuild.problems(build, CONTENT):
			check(false, "build data: %s" % problem)

	# The model: one check per kind of target.
	var model := BalanceModel.new(CONTENT, targets, builds)
	model.difficulties = [CONTENT.get_difficulty(&"normal"), CONTENT.get_difficulty(&"hard")] as Array[DifficultyDef]
	var report := model.run()
	var by_category := {}
	for flag in report.flags:
		if not by_category.has(flag.category):
			by_category[flag.category] = []
		by_category[flag.category].append(flag)
	for category in ["model: boss TTK", "model: boss hits to kill", "model: face-tank wins", "model: heal share",
			"model: monster TTK", "model: elite TTK", "model: perk value", "model: degenerate DPS", "model: weapon DPS", "build data"]:
		var flags: Array = by_category.get(category, [])
		var examples := PackedStringArray()
		for i in mini(flags.size(), 3):
			examples.append("%s: %s (target %s)" % [flags[i].subject, flags[i].value, flags[i].target])
		_target(flags.is_empty(), category, "%d broken%s" % [flags.size(), (": " + "; ".join(examples)) if not examples.is_empty() else ""])

	# Real duels on the engine.
	var arena := BalanceArena.new()
	arena.content = CONTENT
	arena.targets = targets
	arena.all_builds = builds
	arena.verbose = false
	add_child(arena)
	arena._override_chances()
	var boss: BossDef = CONTENT.dungeon.acts[0].boss
	var normal := CONTENT.get_difficulty(&"normal")
	for duel: Array in [["degenerate_lifesteal_a1", "face_tank"], ["expected_a1", "face_tank"], ["expected_a1", "kite"]]:
		var build := BalanceBuild.find(builds, duel[0])
		if build == null:
			check(false, "build %s exists" % duel[0])
			continue
		var r := await arena.fight_boss(boss, build, normal, duel[1])
		var line := BalanceArena._fight_line(r)
		print("  duel: %s" % line)
		check(r.result != "error", "the duel %s %s ran (%s)" % [duel[0], duel[1], r.get("error", "")])
		if duel[1] == "face_tank":
			_target(r.result != "win", "duel: %s face-tank loses" % duel[0], "%s vs %s on Normal: %s" % [duel[0], boss.id, line])
			var share_max := targets.heal_share_max_degenerate if build.has_tag("degenerate") else targets.heal_share_max_expected
			_target(r.heal_share <= share_max, "duel: %s heal share" % duel[0], "healed %d%% of the damage taken (target <= %d%%): %s" % [
				roundi(r.heal_share * 100.0), roundi(share_max * 100.0), FightLog_sources(r)])
		else:
			_target(r.result == "win", "duel: %s kite wins" % duel[0], "%s vs %s on Normal: %s" % [duel[0], boss.id, line])
	arena._restore_chances()
	arena.queue_free()
	BalanceArena.isolate_profile()  # back to a clean in-memory profile for whatever runs next


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


static func FightLog_sources(r: Dictionary) -> String:
	return BalanceArena.FightLog.sources_text(r.get("heal_sources", {}))
