class_name RunState
extends RefCounted
## The run in progress: how deep, how well it goes, on what difficulty, which bosses were drawn.
## Saved with the run (see Game._save_run() and RunSave), restored by load_data().

var depth := 1
var kills := 0
var bosses_slain := 0
## The last act's boss fell this run (the rest is endless mode).
var has_won := false
## The run's difficulty, with its ascension levels applied. Never null.
var difficulty: DifficultyDef
## One boss per act for this run, drawn among the act's bosses.
var bosses: Array[BossDef] = []
## Souls already added to the profile (a victory, then a death in endless mode).
var souls_awarded := 0
## Gold picked up this run (for the records).
var run_gold := 0
## Already in the profile's history (a won run is recorded once, when it ends).
var history_recorded := false
## The boss of the last cleared boss floor (its relic, in endless mode). Not saved.
var last_boss: BossDef
## Perk choices: rerolls (three new cards) and banishes left, and the perks banished for the run.
var rerolls := 0
var banishes := 0
var banished: Array[PerkDef] = []
## A daily run (DailyRun): its day, -1 for a normal run. `daily_official`: the day's first
## attempt, the one whose score counts.
var daily_day := -1
var daily_official := false
## Every floor of the run is built from this (and its depth): a resumed run finds the same floor.
var seed := 0
## In-game time, seconds (RunTimer): counts while playing, menus included, but not in the pause
## menu nor while a floor loads.
var time := 0.0
## The time at the end of each floor (index: depth - 1), for the splits.
var splits: Array[float] = []
## The time when the last boss fell (-1: not won yet). The run's speedrun time.
var finish_time := -1.0
## The ways down taken (FloorRoute): depth reached -> index of the route offered for it.
var routes := {}
## The oath sworn for this run (OathDef), or null.
var oath: OathDef


## A new run, or the saved one (`saved` from RunSave; empty for a new run).
## `daily_day`: a new daily run of that day (DailyRun), on Normal.
static func create(content: ContentDB, saved: Dictionary, rng: RandomNumberGenerator, daily_day: int = -1) -> RunState:
	var run := RunState.new()
	run.daily_day = int(saved.get("daily_day", daily_day))
	run.daily_official = bool(saved.get("daily_official", false))
	if run.daily_day >= 0 and saved.is_empty():
		run.difficulty = content.default_difficulty
	else:
		run.difficulty = _pick_difficulty(content, saved)
	run.seed = int(saved["seed"]) if saved.has("seed") else rng.randi()
	run.depth = int(saved.get("depth", 1))
	if saved.get("boss_slain", false):
		run.depth += 1  # saved after the floor's boss died: on to the next floor
	run.kills = int(saved.get("kills", 0))
	run.bosses_slain = int(saved.get("bosses_slain", 0))
	run.has_won = bool(saved.get("has_won", false))
	run.souls_awarded = int(saved.get("souls_awarded", 0))
	run.run_gold = int(saved.get("run_gold", 0))
	run.history_recorded = bool(saved.get("history_recorded", false))
	run.time = float(saved.get("time", 0.0))
	run.finish_time = float(saved.get("finish_time", -1.0))
	if saved.has("oath"):
		run.oath = RunSave.load_ref(saved["oath"]) as OathDef
	var taken: Dictionary = saved.get("routes", {})
	for key: Variant in taken:
		run.routes[int(key)] = int(taken[key])
	for split: Variant in saved.get("splits", []):
		run.splits.append(float(split))
	if saved.has("rerolls"):
		run.rerolls = int(saved.rerolls)
		run.banishes = int(saved.get("banishes", 0))
		for reference: Variant in saved.get("banished", []):
			var perk := RunSave.load_ref(reference) as PerkDef
			if perk:
				run.banished.append(perk)
	else:
		run.rerolls = content.dungeon.base_rerolls + ShrineUpgrades.extra_charges(content, UpgradeDef.Kind.REROLLS)
		run.banishes = content.dungeon.base_banishes + ShrineUpgrades.extra_charges(content, UpgradeDef.Kind.BANISHES)
	if saved.has("bosses"):
		for reference: Variant in saved.bosses:
			run.bosses.append(RunSave.load_ref(reference) as BossDef)
	else:
		for act in content.dungeon.acts:
			var choices := act.all_bosses()
			run.bosses.append(choices[rng.randi_range(0, choices.size() - 1)] if not choices.is_empty() else null)
	return run


## The profile's difficulty (or the saved run's), with its ascension; Normal if locked.
static func _pick_difficulty(content: ContentDB, saved: Dictionary) -> DifficultyDef:
	var difficulty := content.get_difficulty(StringName(saved.get("difficulty", Profile.difficulty)))
	if difficulty == null or not Profile.is_unlocked(difficulty):
		difficulty = content.default_difficulty
	var ascension := int(saved.get("ascension", Profile.ascension if saved.is_empty() else 0))
	if difficulty.has_ascensions and ascension > 0:
		difficulty = AscensionDef.apply_levels(difficulty, content.ascensions, mini(ascension, Profile.ascension_unlocked))
	return difficulty


## Souls this run is worth so far (what the shrine gets when it ends).
func souls() -> int:
	return Profile.souls_for_run(kills, depth, bosses_slain, has_won, difficulty.souls)


## Adds the souls not given yet to the profile; returns them.
func award_souls(won_now: bool, ascension_count: int) -> int:
	var total := souls()
	var earned := total - souls_awarded
	souls_awarded = total
	Profile.record_run(earned, depth, won_now, difficulty.id, difficulty.counts_feats)
	if won_now and difficulty.has_ascensions:
		Profile.win_ascension(difficulty.ascension, ascension_count)
	return earned


## What the save keeps of the run (the floor and the hero are added by the game).
func to_data() -> Dictionary:
	return {
		"depth": depth,
		"kills": kills,
		"bosses_slain": bosses_slain,
		"has_won": has_won,
		"souls_awarded": souls_awarded,
		"run_gold": run_gold,
		"history_recorded": history_recorded,
		"bosses": RunSave.refs(bosses),
		"rerolls": rerolls,
		"banishes": banishes,
		"banished": RunSave.refs(banished),
		"daily_day": daily_day,
		"daily_official": daily_official,
		"seed": seed,
		"time": time,
		"splits": splits,
		"finish_time": finish_time,
		"routes": routes,
		"oath": RunSave.ref(oath),
		"difficulty": String(difficulty.id),
		"ascension": difficulty.ascension,
	}


## The seed of the ways down offered toward floor `floor_depth` (the same all day in a daily run).
func route_seed(floor_depth: int) -> int:
	return FloorRoute.seed_for(DailyRun.seed_of(daily_day) if is_daily() else seed, floor_depth)


func is_daily() -> bool:
	return daily_day >= 0


## The floor `depth` is done (the stairs are taken, or its boss was the last): its split.
## Returns the split's time.
func split(floor_depth: int) -> float:
	if splits.size() < floor_depth:
		splits.resize(floor_depth)
		for i in splits.size():
			if splits[i] <= 0.0:
				splits[i] = time  # a floor skipped (debug) takes the same time
	splits[floor_depth - 1] = time
	return time


## The time a speedrunner would quote: the win, or the time so far.
func run_time() -> float:
	return finish_time if finish_time >= 0.0 else time


## What its records are kept under: the difficulty and its ascension ("normal", "nightmare/a3").
## Empty for a daily run (its own race).
func record_key() -> String:
	if is_daily():
		return ""
	var key := String(difficulty.id)
	if difficulty.ascension > 0:
		key += "/a%d" % difficulty.ascension
	return key


## The run's numbers for the end-of-run screen, as [label, value] pairs (Difficulty, Reached,
## Level, Monsters slain, Bosses slain, Time, the daily score). `time_note` follows the time
## ("New record!"); without it, the record to beat is given for a run not won.
func summary_rows(content: ContentDB, level: int, time_note: String = "") -> Array:
	var act := content.dungeon.act_for_depth(depth)
	var time_text := TimeText.of(run_time())
	var record := Profile.best_time(record_key())
	if not time_note.is_empty():
		time_text += "  " + time_note
	elif record > 0.0 and finish_time < 0.0:
		time_text += "  " + tr("(record %s)") % TimeText.of(record)
	var rows: Array = [
		[tr("Difficulty"), tr(difficulty.display_name)],
		[tr("Reached"), tr("%s, depth %d") % [tr(act.title) if act else tr("Dungeon"), depth]],
		[tr("Hero level"), str(level)],
		[tr("Monsters slain"), str(kills)],
		[tr("Bosses slain"), str(bosses_slain)],
		[tr("Time"), time_text],
	]
	if is_daily():
		var note := tr("(best %d)") % Profile.daily_best if daily_official else tr("(practice)")
		rows.append([tr("Daily score"), "%d  %s" % [DailyRun.score(self), note]])
	return rows


## "Keeper - The Well's Maw, depth 3, level 5 / 42 monsters slain, 1 boss" (+ the daily score).
func summary(content: ContentDB, level: int) -> String:
	var act := content.dungeon.act_for_depth(depth)
	var text := tr("%s - %s, depth %d, level %d\n%d monsters slain, %d bosses") % [
		tr(difficulty.display_name), tr(act.title) if act else tr("Dungeon"), depth, level, kills, bosses_slain]
	text += "\n" + tr("Time %s") % TimeText.of(run_time())
	var record := Profile.best_time(record_key())
	if record > 0.0 and finish_time < 0.0:
		text += "   " + tr("(record %s)") % TimeText.of(record)
	if is_daily():
		var note := tr("(best %d)") % Profile.daily_best if daily_official else tr("(practice)")
		text += "\n" + tr("Daily score %d") % DailyRun.score(self) + "  " + note
	return text
