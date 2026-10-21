class_name BalanceSouls
extends RefCounted
## The souls of a whole campaign on Keeper, against the Tree of Souls: every source a player
## gets, run after run, from the measured floors (BalanceEconomy's per-depth averages: kills,
## kills of each kind, elites, chests, encounters, gold, XP) and the game's own data (the run's
## souls in DungeonConfig, the hidden floor, the bestiary's ranks and challenges, achievements,
## quests). Expected values, not a dice roll: run n adds what an average run of its result adds.
## What can't be measured is an assumption below, each with its reason; change them here.

## A Keeper career, run by run: [runs, result]. Result k = dies at act k's boss, 5 = wins; a
## fraction mixes the two around it (4.5: half the runs win). The last entry repeats. A first
## run dies to the first boss, the player learns an act every few runs and wins one run in two
## once the tree and practice carry him (the shrine's stats and the oaths make that possible).
const CAREER := [[2, 1.0], [4, 2.0], [8, 3.0], [10, 4.0], [0, 4.5]]
## Runs played a day (the daily quests pay once a day, the weekly ones once a week): an evening
## of one to two runs.
const RUNS_PER_DAY := 2.0
## Share of the drawn quests a player finishes: most dailies, fewer weeklies (a cursed floor or
## a win may not come).
const DAILY_DONE := 0.8
const WEEKLY_DONE := 0.7
## Minutes a floor takes (clearing most of it, the merchant, a boss on boss floors): converts
## runs into hours of play. Not measured by the tools (Codex > Runs keeps real times).
const MINUTES_PER_FLOOR := 3.5
## Chance, per kill of that kind, that a bestiary challenge happens on it. The finishing crit
## follows the crit chance (5-20%); untouched, a streak of 3 and a push into a hole depend on the
## player; boss challenges are per boss kill (melee weapons are most weapons; one weapon of ~15
## for a boss' own weapon challenge). ELITE uses the measured share of elites among the kills.
const CHALLENGE_PER_KILL := {
	HuntChallenge.Goal.PIT: 0.01, HuntChallenge.Goal.STREAK: 0.04, HuntChallenge.Goal.UNTOUCHED: 0.08,
	HuntChallenge.Goal.CRIT: 0.12, HuntChallenge.Goal.RANGED: 0.3, HuntChallenge.Goal.MELEE: 0.7,
	HuntChallenge.Goal.FAST: 0.3, HuntChallenge.Goal.NO_POTION: 0.5, HuntChallenge.Goal.HEALTHY: 0.25,
	HuntChallenge.Goal.WEAPON: 0.07,
}
## Per floor: monsters knocked into holes (the Pushover feat), secret rooms found (half of those
## the floors hide), Epic items picked up (of those lying on the floor).
const PUSHED_PER_FLOOR := 0.3
const SECRET_FOUND := 0.5
const EPICS_PICKED := 0.7
## A run past act II's boss finds the hidden floor: its key drops (HiddenFloorDef.key_chance)
## and the player finds the way down about half the time.
const HIDDEN_FOUND := 0.5
## The milestones shown in the table.
const MILESTONES := [1, 2, 3, 5, 8, 10, 15, 20, 30, 40, 50, 60, 80, 100, 150]
const MAX_RUNS := 300

var content: ContentDB
var targets: BalanceTargets
var level_for: Callable


func _init(content_db: ContentDB, balance_targets: BalanceTargets, level_of_xp: Callable) -> void:
	content = content_db
	targets = balance_targets
	level_for = level_of_xp


## Souls for every level of a node.
static func node_cost(node: SoulNodeDef) -> int:
	var total := 0
	if node and node.upgrade:
		for level in node.upgrade.max_level:
			total += node.upgrade.cost_for_level(level)
	return total


## Every node of the tree, both sides of each fork.
static func all_nodes_cost(tree: SoulTreeDef) -> int:
	var total := 0
	for node in tree.nodes:
		total += node_cost(node)
	return total


## A full tree: every node a player can own at once (the dearer side of each fork).
static func full_tree_cost(tree: SoulTreeDef) -> int:
	var total := 0
	for node in tree.nodes:
		var other := node.partner() if node else null
		var cost := node_cost(node)
		if other == null or cost > node_cost(other) or (cost == node_cost(other) and node.excludes != null):
			total += cost
	return total


## The cheapest first level of a node open from the start.
static func first_node_cost(tree: SoulTreeDef) -> int:
	var cheapest := 1 << 30
	for node in tree.nodes:
		if node and node.upgrade and node.requires.is_empty() and node.feat == null:
			cheapest = mini(cheapest, node.upgrade.cost_for_level(0))
	return cheapest


## The one-time pools: every hunter rank and challenge of the bestiary (the acts' monsters and
## bosses, the hidden floor's boss) and every achievement. { ranks, challenges, achievements }.
static func one_time_pools(content_db: ContentDB) -> Dictionary:
	var rules := content_db.bestiary
	var ranks := 0
	var challenges := 0
	for monster in _bestiary_kinds(content_db):
		for souls in rules.souls_for(monster):
			ranks += souls
		for challenge in rules.challenges_for(monster):
			challenges += challenge.souls
	var achievements := 0
	for achievement in content_db.achievements:
		achievements += achievement.reward_souls
	return { "ranks": ranks, "challenges": challenges, "achievements": achievements }


static func _bestiary_kinds(content_db: ContentDB) -> Array[MonsterDef]:
	var kinds: Array[MonsterDef] = []
	var lists: Array = []
	for act in content_db.dungeon.acts:
		lists.append(act.monsters)
		lists.append(act.all_bosses())
	var hidden := content_db.dungeon.hidden_floor
	if hidden:
		lists.append(hidden.monsters)
		lists.append([hidden.boss])
	for list: Array in lists:
		for monster: MonsterDef in list:
			if monster and not kinds.has(monster):
				kinds.append(monster)
	return kinds


## The career on Keeper, run by run, every source; table "economy_campaign" and its flags.
func campaign(report: BalanceReport, per_depth: Array) -> void:
	var acts := _acts(per_depth.filter(func(p: Dictionary) -> bool: return p.difficulty == "normal"))
	if acts.is_empty():
		return
	var tree := content.soul_tree
	var full_tree := full_tree_cost(tree)
	var all_nodes := all_nodes_cost(tree)
	var first_node := first_node_cost(tree)
	var pools := one_time_pools(content)
	var rules := content.bestiary
	var quest_rate := _quests_per_run()
	var elite_share := _elite_share(acts)
	var kinds := _bestiary_kinds(content)
	var hidden := content.dungeon.hidden_floor
	# The career's state: expected kills of each kind, lifetime stats, what was paid.
	var kills_of := {}
	var paid_ranks := {}
	var challenge_paid := {}
	var stats := {}
	var unlocked := {}
	var sums := { "run": 0.0, "ranks": 0.0, "challenges": 0.0, "achievements": 0.0, "quests": 0.0 }
	var rows: Array = []
	var minutes := 0.0
	var first_node_run := -1
	var full_run := -1
	var all_run := -1
	var burst_at_10 := 0.0
	for n in range(1, MAX_RUNS + 1):
		var result := _result_of(n)
		var run := _mix(acts, result)
		minutes += run.floors * MINUTES_PER_FLOOR
		sums.run += run.souls
		sums.quests += quest_rate
		for kind: String in run.by_kind:
			kills_of[kind] = float(kills_of.get(kind, 0.0)) + float(run.by_kind[kind])
		for key: String in ["kills", "elites", "bosses", "chests", "encounters", "epics", "pushed", "secrets", "hidden_bosses", "victories"]:
			stats[key] = float(stats.get(key, 0.0)) + float(run.get(key, 0.0))
		for key: String in ["best_depth", "run_gold", "run_level"]:
			stats[key] = maxf(float(stats.get(key, 0.0)), float(run.get(key, 0.0)))
		# Hunter ranks (paid when the expected kills cross the rank) and challenges (paid as
		# their chance of being done grows: expected souls).
		var species := 0
		for monster in kinds:
			var key := String(monster.id)
			var slain: float = kills_of.get(key, 0.0)
			if slain >= 1.0:
				species += 1
			var thresholds := rules.kills_for(monster)
			var souls := rules.souls_for(monster)
			var rank := 0
			for i in thresholds.size():
				if slain >= thresholds[i]:
					rank = i + 1
			for i in range(int(paid_ranks.get(key, 0)), rank):
				sums.ranks += souls[i] if i < souls.size() else 0
			paid_ranks[key] = maxi(int(paid_ranks.get(key, 0)), rank)
			for challenge in rules.challenges_for(monster):
				var chance: float = elite_share if challenge.goal == HuntChallenge.Goal.ELITE else float(CHALLENGE_PER_KILL.get(challenge.goal, 0.05))
				var done := 1.0 - pow(1.0 - chance, slain)
				var c_key := "%s/%s" % [key, challenge.id]
				sums.challenges += (done - float(challenge_paid.get(c_key, 0.0))) * challenge.souls
				challenge_paid[c_key] = done
		stats["species"] = species
		for achievement in content.achievements:
			if not unlocked.has(achievement.id) and float(stats.get(achievement.stat_key(), 0.0)) >= achievement.target:
				unlocked[achievement.id] = n
				sums.achievements += achievement.reward_souls
		var total: float = sums.run + sums.ranks + sums.challenges + sums.achievements + sums.quests
		if first_node_run < 0 and total >= first_node:
			first_node_run = n
		if full_run < 0 and total >= full_tree:
			full_run = n
		if all_run < 0 and total >= all_nodes:
			all_run = n
		if n == 10:
			burst_at_10 = sums.ranks + sums.challenges + sums.achievements
		if MILESTONES.has(n):
			rows.append([n, _result_text(result), "%.1f" % (minutes / 60.0), roundi(run.souls), roundi(sums.run), roundi(sums.ranks), roundi(sums.challenges),
				roundi(sums.achievements), roundi(sums.quests), roundi(total), BalanceReport.pct(total / maxf(full_tree, 1.0))])
		if all_run > 0 and n >= MILESTONES[MILESTONES.size() - 1]:
			break
	var hours_of := func(runs: int) -> String:
		if runs < 0:
			return "never (%d runs)" % MAX_RUNS
		var m := 0.0
		for i in range(1, runs + 1):
			m += float(_mix(acts, _result_of(i)).floors) * MINUTES_PER_FLOOR
		return "run %d (~%.0f h)" % [runs, m / 60.0]
	report.table("economy_campaign", "Economy",
		("A Keeper career (expected values; results %s; %.0f runs a day for the quests; %.1f min a floor) vs the Tree of Souls: full tree %d souls (the dearer side of each fork), "
		+ "every node %d. First node (%d souls): %s. Full tree: %s. Every node: %s. One-time pools: hunter ranks %d, challenges %d, achievements %d (%s of the full tree)") % [
			", ".join(CAREER.map(func(c: Array) -> String: return ("%d x %s" % [c[0], _result_text(c[1])]) if c[0] > 0 else ("then " + _result_text(c[1])))),
			RUNS_PER_DAY, MINUTES_PER_FLOOR, full_tree, all_nodes, first_node, hours_of.call(first_node_run), hours_of.call(full_run), hours_of.call(all_run),
			pools.ranks, pools.challenges, pools.achievements, BalanceReport.pct(float(pools.ranks + pools.challenges + pools.achievements) / maxf(full_tree, 1.0))],
		PackedStringArray(["Run", "Result", "Hours", "This run", "Runs (sum)", "Hunter ranks", "Challenges", "Achievements", "Quests", "Total", "Of the full tree"]), rows)
	var later := content.achievements.filter(func(a: AchievementDef) -> bool: return not unlocked.has(a.id))
	report.notes.append("Campaign: achievements a Keeper career doesn't reach (Martyr, Nightmare, ascension, the Threshold...): %s." % ", ".join(later.map(func(a: AchievementDef) -> String: return "%s (%d)" % [a.id, a.reward_souls])))
	# Flags.
	if full_run < 0 or full_run < targets.campaign_runs_to_tree_min or full_run > targets.campaign_runs_to_tree_max:
		report.flag(BalanceReport.WARN, "economy: souls", "runs to a full Tree of Souls (Keeper career, every source)", "%d runs" % full_run,
			"%.0f-%.0f" % [targets.campaign_runs_to_tree_min, targets.campaign_runs_to_tree_max], "%d souls; see table economy_campaign" % full_tree)
	if first_node_run < 0 or first_node_run > targets.campaign_first_node_runs_max:
		report.flag(BalanceReport.WARN, "economy: souls", "runs to the first node (Keeper career)", "%d runs" % first_node_run,
			"<= %d" % targets.campaign_first_node_runs_max, "the cheapest node costs %d souls" % first_node)
	if burst_at_10 > targets.campaign_burst_share_max * full_tree:
		report.flag(BalanceReport.WARN, "economy: souls", "one-time souls in the first 10 runs (ranks, challenges, achievements)", "%d souls (%s of the full tree)" % [roundi(burst_at_10), BalanceReport.pct(burst_at_10 / full_tree)],
			"<= %s" % BalanceReport.pct(targets.campaign_burst_share_max), "the first hours' burst must not hand out the tree")


## The measured acts on Keeper: per act, what its normal floors give a typical player.
func _acts(per_depth: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var config := content.dungeon
	var xp := 0.0
	for a in config.acts.size():
		var act := { "kills": 0.0, "by_kind": {}, "elites": 0.0, "chests": 0.0, "encounters": 0.0, "epics": 0.0, "gold": 0.0, "floors": config.acts[a].floors }
		var measured := 0
		var act_xp := 0.0
		for p: Dictionary in per_depth:
			if p.act != a + 1:
				continue
			measured += 1
			act.kills += p.kills_typical
			act.elites += p.ranked * p.kill_share
			act.chests += p.chests
			act.encounters += p.encounters
			act.epics += float(p.items[3]) * EPICS_PICKED
			act.gold += p.gold_typical
			act_xp += p.xp_typical
			for kind: String in p.by_kind:
				act.by_kind[kind] = float(act.by_kind.get(kind, 0.0)) + float(p.by_kind[kind]) * p.kill_share
		if measured == 0:
			return []
		# Every normal floor of the act, from the ones measured.
		var scale := float(config.acts[a].floors - 1) / measured
		for key: String in ["kills", "elites", "chests", "encounters", "epics", "gold"]:
			act[key] *= scale
		for kind: String in act.by_kind:
			act.by_kind[kind] *= scale
		xp += act_xp * scale
		act["xp_before_boss"] = xp
		result.append(act)
		var boss := config.acts[a].boss
		xp += boss.xp_reward if boss else 0
	return result


## Run n's result in the career.
func _result_of(n: int) -> float:
	var seen := 0
	for step: Array in CAREER:
		seen += int(step[0])
		if step[0] == 0 or n <= seen:
			return float(step[1])
	return float(CAREER[CAREER.size() - 1][1])


## An average run of `result` (fractions mix the results around it).
func _mix(acts: Array[Dictionary], result: float) -> Dictionary:
	var low := clampi(floori(result), 1, acts.size() + 1)
	var high := clampi(low + 1, 1, acts.size() + 1)
	var weight := clampf(result - low, 0.0, 1.0)
	var a := _run(acts, low)
	if weight <= 0.0:
		return a
	var b := _run(acts, high)
	var mixed := {}
	for key: String in a:
		if a[key] is Dictionary:
			var d := {}
			for k: String in a[key]:
				d[k] = float(a[key][k]) * (1.0 - weight)
			for k: String in b[key]:
				d[k] = float(d.get(k, 0.0)) + float(b[key][k]) * weight
			mixed[key] = d
		else:
			mixed[key] = float(a[key]) * (1.0 - weight) + float(b[key]) * weight
	return mixed


## A run that dies at act `result`'s boss (or wins: acts + 1): what it slays, finds and earns.
func _run(acts: Array[Dictionary], result: int) -> Dictionary:
	var config := content.dungeon
	var won := result > acts.size()
	var passed := mini(result, acts.size())
	var bosses := passed if won else result - 1
	var run := { "kills": 0.0, "by_kind": {}, "elites": 0.0, "chests": 0.0, "encounters": 0.0, "epics": 0.0, "run_gold": 0.0,
		"floors": 0.0, "bosses": float(bosses), "victories": 1.0 if won else 0.0, "hidden_bosses": 0.0 }
	for a in passed:
		var act: Dictionary = acts[a]
		run.kills += act.kills
		run.elites += act.elites
		run.chests += act.chests
		run.encounters += act.encounters
		run.epics += act.epics
		run.run_gold += act.gold
		run.floors += act.floors - 1
		for kind: String in act.by_kind:
			run.by_kind[kind] = float(run.by_kind.get(kind, 0.0)) + float(act.by_kind[kind])
		if a < bosses:  # its boss slain: one of the act's bosses, each as likely
			var choices := config.acts[a].all_bosses()
			for boss in choices:
				run.by_kind[String(boss.id)] = float(run.by_kind.get(String(boss.id), 0.0)) + 1.0 / choices.size()
	run.floors += passed  # the boss floors (the last one where it dies, or the last one won)
	run["pushed"] = run.floors * PUSHED_PER_FLOOR
	run["secrets"] = run.floors * config.secret_room_chance * SECRET_FOUND
	var depth := config.total_floors() if won else BalanceContent.boss_depth(content, result)
	run["best_depth"] = float(depth)
	run["run_level"] = float(level_for.call(acts[passed - 1].xp_before_boss))
	var souls := float(config.souls_for_run(roundi(run.kills) + bosses, depth, bosses, won))
	var hidden := config.hidden_floor
	if hidden and bosses >= 2:  # past act II's boss: the hidden floor, sometimes
		var found := hidden.key_chance * HIDDEN_FOUND
		souls += hidden.bonus_souls * found
		run.hidden_bosses = found
		if hidden.boss:
			run.by_kind[String(hidden.boss.id)] = float(run.by_kind.get(String(hidden.boss.id), 0.0)) + found
	run["souls"] = souls
	run.kills += bosses
	return run


## Souls a run brings from the quests, on average (the pool's rewards, how many are drawn, how
## many are done, runs a day).
func _quests_per_run() -> float:
	var per_period := { QuestDef.Period.DAILY: [0.0, 0.0], QuestDef.Period.WEEKLY: [0.0, 0.0] }
	for quest in content.quests:
		var w := float(maxi(quest.spawn_weight, 1))
		per_period[quest.period][0] += (quest.reward.x + quest.reward.y) * 0.5 * w
		per_period[quest.period][1] += w
	var daily: float = per_period[QuestDef.Period.DAILY][0] / maxf(per_period[QuestDef.Period.DAILY][1], 1.0)
	var weekly: float = per_period[QuestDef.Period.WEEKLY][0] / maxf(per_period[QuestDef.Period.WEEKLY][1], 1.0)
	return (daily * QuestBoard.DAILY_COUNT * DAILY_DONE + weekly * QuestBoard.WEEKLY_COUNT * WEEKLY_DONE / 7.0) / RUNS_PER_DAY


## Share of the kills that are elites (or better), measured on Keeper.
func _elite_share(acts: Array[Dictionary]) -> float:
	var kills := 0.0
	var elites := 0.0
	for act in acts:
		kills += act.kills
		elites += act.elites
	return elites / maxf(kills, 1.0)


static func _result_text(result: float) -> String:
	if result >= 5.0:
		return "wins"
	if is_equal_approx(result, roundf(result)):
		return "dies at act %d's boss" % roundi(result)
	var low := floori(result)
	return "%d%% %s, else %s" % [roundi((result - low) * 100.0), "wins" if low + 1 >= 5 else "act %d" % (low + 1), "act %d" % low]
