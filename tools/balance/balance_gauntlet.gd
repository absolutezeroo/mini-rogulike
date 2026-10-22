class_name BalanceGauntlet
extends Node
## Each act played the way a player meets it, on the engine: the rooms of its last normal floor
## one after the other (the act's monsters by spawn weight, the room size of that depth and
## difficulty, each monster rolled for a rank with the floor's own chances: Elites and rarer
## ranks come as often as in the game), Health and potions carried from room to room (the hero
## starts with POTIONS and drinks one when low), then the act's boss with what is left.
## Bots: `kite` (a decent player), `player` (the kite bot with a human's reaction time,
## BalanceBot.REACTION: an average player) and `face_tank` when asked (--bot=).
## This is the difficulties' measure: what a run costs, where it ends (table "gauntlet").
## Limits: no springs or shrines between rooms, no walking through the floor (each room comes to
## the hero at the floor's start), the earlier floors not played, one seed.

## Rooms fought before the boss (about the rooms on the way to a floor's stairs).
const ROOMS := 8
## Game seconds a room gets before it counts as a timeout (the gauntlet goes on).
const ROOM_TIMEOUT := 60.0
## Bots run when none is asked for.
const DEFAULT_BOTS: PackedStringArray = ["kite", "player"]
## Health Potions on the belt as the floor starts (35% of max Health each): about what a player
## carries into an act's last floor (a judgment: potions lie around and drop from monsters, and
## some are drunk on the way). Those picked up in the rooms join them. The bots drink one below
## DRINK_BELOW of max Health.
const POTIONS := 2
const POTION: ConsumableDef = preload("res://data/items/consumables/health_potion.tres")
const DRINK_BELOW := 0.35

var lab: BalanceLab
var jobs := BalanceJobs.new()
var content: ContentDB
var targets: BalanceTargets
var all_builds: Array[BalanceBuildDef] = []
var builds: Array[BalanceBuildDef] = []
var difficulties: Array[DifficultyDef] = []
var bots: PackedStringArray = DEFAULT_BOTS
var acts: Array[int] = []
var seed_value := 1
var quick := false
var verbose := true
## Game seconds before the boss fight is a timeout.
var timeout := 240.0


func run() -> BalanceReport:
	var report := BalanceReport.new()
	report.title = "Balance gauntlet"
	var started := Time.get_ticks_msec()
	var arena := BalanceArena.new()
	arena.lab = lab
	arena.content = content
	arena.targets = targets
	arena.all_builds = all_builds
	arena.timeout = timeout
	arena.verbose = false
	add_child(arena)
	lab.override_chances()
	var act_list: Array = range(1, content.dungeon.acts.size() + 1)
	if not acts.is_empty():
		act_list = act_list.filter(func(a: int) -> bool: return acts.has(a))
	var d_list := difficulties
	var bot_list := bots
	if quick:
		act_list = act_list.slice(0, 1)
		d_list = d_list.slice(0, 1)
		bot_list = bot_list.slice(0, 1)
	var runs: Array = []
	for act: int in act_list:
		var build := BalanceBuild.expected(all_builds, act)
		if build == null or (not builds.is_empty() and not builds.has(build)):
			continue
		var boss := content.dungeon.acts[act - 1].boss as BossDef
		if boss == null:
			continue
		for difficulty in d_list:
			for bot in bot_list:
				var id := "gauntlet|%d|%s|%s|%s|%d|%d|%.0f" % [act, BalanceJobs.build_id(build), BalanceContent.key(difficulty), bot, seed_value, ROOMS if not quick else 2, timeout]
				var roots := PackedStringArray([content.dungeon.acts[act - 1].resource_path, boss.resource_path])
				roots.append_array(BalanceJobs.build_roots(build, content))
				roots.append_array(BalanceArena.difficulty_roots(difficulty))
				var got: Variant = await jobs.unit(id, roots, func() -> Dictionary: return await gauntlet(arena, act, build, boss, difficulty, bot))
				if got == null:
					continue  # another worker's
				runs.append(got)
				if verbose and jobs.measuring:
					print("  gauntlet: %s" % run_line(got))
	lab.restore_chances()
	arena.queue_free()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	report.notes.append("Gauntlet: %d runs in %.0f s of real time (seed %d, %d rooms then the boss; %d Health Potions, drunk below %d%% Health)." % [runs.size(), seconds, seed_value, ROOMS if not quick else 2, POTIONS, roundi(DRINK_BELOW * 100.0)])
	report.timings["gauntlet"] = seconds
	report.data["gauntlet"] = runs
	_tables(report, runs)
	_check(report, runs)
	report.data["headline"] = headline(runs)
	return report


## One act: the rooms, then the boss. Returns { act, difficulty, bot, build, rooms: [...],
## room_taken_share, room_min_share, hp_at_boss, boss: {...}, outcome, died_in }.
func gauntlet(arena: BalanceArena, act: int, build: BalanceBuildDef, boss: BossDef, difficulty: DifficultyDef, bot: String) -> Dictionary:
	var depth := BalanceContent.boss_depth(content, act) - 1
	var room_count := ROOMS if not quick else 2
	var result := { "act": act, "difficulty": BalanceContent.key(difficulty), "bot": bot, "build": build.name, "depth": depth,
		"boss_id": String(boss.id), "rooms": [], "died_in": "", "outcome": "" }
	var s := lab.session(depth, difficulty)
	var rules := FloorRules.make(content.dungeon, difficulty, null, depth)
	var size := lab.room_size(depth, difficulty)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7717 + act * 101 + BalanceContent.key(difficulty).hash() % 1000
	var max_hp := 1
	var hp_share := 1.0
	var hp_left := 0
	var min_share := 1.0
	var taken := 0
	var healed := 0
	var drinks := 0
	var ranked := 0
	# The hero as he comes to the floor: the build, full Health, POTIONS on his belt.
	var game: Game = await lab.ensure(s)
	var hero := lab.ready_hero(game, build, difficulty, seed_value * 100)
	empty_belt(hero)
	for k in POTIONS:
		hero.store(POTION)
	BalanceBot.drink_below = DRINK_BELOW
	for i in room_count:
		var foes := lab.roll_room(act, depth, size, seed_value * 1000 + act * 10 + i)
		for foe: Dictionary in foes:
			var rank := _roll_rank(rules, rng)
			if rank:
				foe["rank"] = rank
				ranked += 1
		var r := await lab.pack(s, build, foes, bot, ROOM_TIMEOUT, seed_value * 100 + i, true)
		max_hp = maxi(int(r.hero_max_hp), 1)
		hp_left = 0 if r.result == "died" or not is_instance_valid(hero) else hero.hp
		hp_share = hp_left / float(max_hp)
		min_share = minf(min_share, float(r.min_hp_share))
		taken += int(r.taken)
		healed += int(r.healed)
		drinks += int(r.get("drinks", 0))
		(result.rooms as Array).append({ "result": r.result, "clear_time": r.clear_time, "taken": r.taken, "healed": r.healed,
			"drinks": r.get("drinks", 0), "hp_after": hp_share, "foes": BalanceArena.foes_id(foes) })
		if r.result == "died":
			result.died_in = "room %d" % (i + 1)
			break
	# What is left on the belt goes to the boss (potions picked up on the way too).
	var belt: Array[ItemDef] = []
	if is_instance_valid(hero) and hero.belt.item_at(0) is ConsumableDef:
		for k in hero.belt.count_at(0):
			belt.append(hero.belt.item_at(0))
	await lab.close(s)
	# The floor's cost: the resources (Health, what the potions heal) gone by the boss' door.
	var start := 1.0 + POTIONS * heal_share(POTION, max_hp)
	var left := hp_share
	for item in belt:
		left += heal_share(item, max_hp)
	result["floor_cost"] = 1.0 if not String(result.died_in).is_empty() else 1.0 - left / start
	result["room_taken_share"] = taken / float(max_hp)
	result["room_healed_share"] = healed / float(max_hp)
	result["room_drinks"] = drinks
	result["potions_at_boss"] = belt.size()
	result["room_min_share"] = min_share
	result["hp_at_boss"] = hp_share
	result["ranked"] = ranked
	if not String(result.died_in).is_empty():
		BalanceBot.drink_below = 0.0
		result.outcome = "died in " + String(result.died_in)
		return result
	# The Health he has, not its share: a bonus to max Health that came in a room (a kill
	# streak's...) is gone at the boss, the wounds are not.
	var fight := await arena.fight_boss(boss, build, difficulty, bot, null, hp_left, belt, true)
	BalanceBot.drink_below = 0.0
	result["boss"] = { "result": fight.get("result", "error"), "time": fight.get("time", 0.0), "min_hp_share": fight.get("min_hp_share", 0.0),
		"boss_hp_left_share": fight.get("boss_hp_left_share", 0.0), "damage_taken": fight.get("damage_taken", 0), "hits_taken": fight.get("hits_taken", 0),
		"healed": fight.get("healed", 0), "hero_max_hp": fight.get("hero_max_hp", 1), "error": fight.get("error", ""), "drinks": fight.get("drinks", 0) }
	match String(fight.get("result", "error")):
		"win":
			result.outcome = "win"
		"loss":
			result.outcome = "died to the boss"
			result.died_in = "boss"
		"timeout":
			result.outcome = "boss timeout"
		_:
			result.outcome = "error"
	return result


## What `item` heals, a share of max Health `max_hp` (its heal effects; 0 for anything else).
static func heal_share(item: ItemDef, max_hp: int) -> float:
	var share := 0.0
	var consumable := item as ConsumableDef
	if consumable == null:
		return 0.0
	for effect in consumable.effects:
		var heal := effect as HealEffect
		if heal:
			share += heal.max_hp_ratio + heal.amount / float(maxi(max_hp, 1))
	return share


## Every belt slot emptied (what an earlier measure left on the hero).
static func empty_belt(player: Player) -> void:
	for i in Belt.SLOTS:
		while player.belt.take(i) != null:
			pass


## A rank for a monster of the floor, as World.roll_elite() draws it (the floor's chances).
func _roll_rank(rules: FloorRules, rng: RandomNumberGenerator) -> MonsterRankDef:
	for rank in content.dungeon.rare_ranks:
		if rank and rng.randf() < rules.rank_chance(rank):
			return rank
	if rng.randf() < rules.elite_chance():
		return content.dungeon.elite_rank
	return null


static func run_line(r: Dictionary) -> String:
	var boss: Dictionary = r.get("boss", {})
	return "act %d | %s | %s | %s: %s; rooms took %d%%, healed %d%%, %d potions (lowest %d%%), %d ranked; at the boss %d%% with %d potions%s" % [r.act, r.difficulty, r.bot, r.build,
		String(r.outcome).to_upper(), roundi(100.0 * r.room_taken_share), roundi(100.0 * r.get("room_healed_share", 0.0)), r.get("room_drinks", 0), roundi(100.0 * r.room_min_share), r.ranked, roundi(100.0 * r.hp_at_boss), r.get("potions_at_boss", 0),
		"" if boss.is_empty() else ", boss %s in %.0f s (hero min %d%%, boss %d%% left, %d potions drunk)" % [boss.result, boss.time, roundi(100.0 * boss.min_hp_share), roundi(100.0 * boss.boss_hp_left_share), boss.get("drinks", 0)]]


func _tables(report: BalanceReport, runs: Array) -> void:
	var rows: Array = []
	for r: Dictionary in runs:
		var boss: Dictionary = r.get("boss", {})
		var cleared := (r.rooms as Array).filter(func(x: Dictionary) -> bool: return x.result == "clear").size()
		rows.append([r.act, r.difficulty, r.bot, r.build, "%d/%d" % [cleared, (r.rooms as Array).size()], r.ranked,
			BalanceReport.pct(r.room_taken_share), BalanceReport.pct(r.get("room_healed_share", 0.0)), r.get("room_drinks", 0), BalanceReport.pct(r.room_min_share), BalanceReport.pct(r.hp_at_boss),
			"%d (%d drunk)" % [r.get("potions_at_boss", 0), boss.get("drinks", 0)] if not boss.is_empty() else "-", BalanceReport.pct(r.get("floor_cost", NAN)), str(boss.get("result", "-")).to_upper(), boss.get("time", 0.0), BalanceReport.pct(boss.get("min_hp_share", NAN)),
			BalanceReport.pct(boss.get("boss_hp_left_share", NAN)), r.outcome])
	report.table("gauntlet", "Bosses", "Each act's last floor, %d rooms one after the other (ranks rolled with the floor's chances), Health and %d Health Potions carried, then the boss (engine). Taken / healed = all the rooms', a share of max Health" % [ROOMS, POTIONS],
		PackedStringArray(["Act", "Difficulty", "Bot", "Build", "Rooms cleared", "Ranked met", "Taken in rooms", "Healed in rooms", "Potions drunk", "Lowest in rooms", "Health at the boss",
			"Potions at the boss", "Floor cost", "Boss", "Boss time s", "Hero min at the boss", "Boss left", "Outcome"]), rows)
	# Per difficulty and bot: acts won, where the others ended.
	var summary: Array = []
	for d: DifficultyDef in difficulties:
		var d_key := BalanceContent.key(d)
		for bot in bots:
			var mine := runs.filter(func(r: Dictionary) -> bool: return r.difficulty == d_key and r.bot == bot)
			if mine.is_empty():
				continue
			var wins := mine.filter(func(r: Dictionary) -> bool: return r.outcome == "win")
			var at_boss: Array = mine.map(func(r: Dictionary) -> float: return r.hp_at_boss)
			var ends := PackedStringArray()
			for r: Dictionary in mine:
				if r.outcome != "win":
					ends.append("act %d: %s" % [r.act, r.outcome])
			var costs: Array = mine.map(func(r: Dictionary) -> float: return float(r.get("floor_cost", 0.0)))
			summary.append([d_key, bot, "%d/%d" % [wins.size(), mine.size()], BalanceReport.pct(BalanceContent.mean(at_boss)), BalanceReport.pct(BalanceContent.mean(costs)),
				"; ".join(ends) if not ends.is_empty() else "-"])
	report.table("gauntlet_summary", "Bosses", "Gauntlet per difficulty and bot: acts won, mean Health left at the boss' door, mean floor cost (the share of Health and potions spent before the boss), the runs that ended",
		PackedStringArray(["Difficulty", "Bot", "Acts won", "Mean Health at the boss", "Mean floor cost", "Ended"]), summary)


## Targets: the decent player (kite) gets through every act where it should win
## (kite_should_win_on); the average player (player bot) through every act on Pilgrim, and
## Keeper costs him (gauntlet_keeper_*: not a stroll, not a wall).
func _check(report: BalanceReport, runs: Array) -> void:
	for r: Dictionary in runs:
		var subject := "act %d gauntlet (%s, %s)" % [r.act, r.difficulty, r.bot]
		if r.outcome == "error":
			report.flag(BalanceReport.ERROR, "gauntlet: error", subject, str(r.get("boss", {}).get("error", "?")), "a run", "the run could not be measured")
			continue
		var must_win: bool = (r.bot == "kite" and targets.kite_should_win_on.has(r.difficulty)) \
			or (r.bot == "player" and targets.gauntlet_player_wins_on.has(r.difficulty))
		if must_win and r.outcome != "win":
			report.flag(BalanceReport.WARN, "gauntlet: lost", subject, r.outcome, "wins", "the act could not be played through by this bot (%d%% Health at the boss)" % roundi(100.0 * r.hp_at_boss))
	# Keeper: the average player's floor costs him, and he wins most acts.
	var keeper := runs.filter(func(r: Dictionary) -> bool: return r.difficulty == "normal" and r.bot == "player" and r.outcome != "error")
	if not keeper.is_empty():
		var cost := BalanceContent.mean(keeper.map(func(r: Dictionary) -> float: return float(r.get("floor_cost", 0.0))))
		if cost < targets.gauntlet_keeper_floor_cost_min or cost > targets.gauntlet_keeper_floor_cost_max:
			report.flag(BalanceReport.WARN, "gauntlet: Keeper floor cost", "Keeper, player bot, %d acts" % keeper.size(), BalanceReport.pct(cost),
				"%s-%s" % [BalanceReport.pct(targets.gauntlet_keeper_floor_cost_min), BalanceReport.pct(targets.gauntlet_keeper_floor_cost_max)],
				"the share of his Health and potions an average player spends on an act's last floor: %s" % ("a stroll (rooms cost nothing)" if cost < targets.gauntlet_keeper_floor_cost_min else "too much (he reaches the boss spent)"))
		var won := keeper.filter(func(r: Dictionary) -> bool: return r.outcome == "win").size() / float(keeper.size())
		if won < targets.gauntlet_keeper_player_wins_min:
			report.flag(BalanceReport.WARN, "gauntlet: Keeper wall", "Keeper, player bot, %d acts" % keeper.size(), BalanceReport.pct(won),
				">= %s" % BalanceReport.pct(targets.gauntlet_keeper_player_wins_min), "an average player loses too many acts: a wall, not a challenge")


## How far down an act took the hero: 1 - his lowest Health (rooms, then the boss), as a share
## of max Health; 1 when he died.
static func lost_share(r: Dictionary) -> float:
	if r.outcome != "win" and r.outcome != "boss timeout":
		return 1.0
	var lowest: float = r.room_min_share
	var boss: Dictionary = r.get("boss", {})
	if not boss.is_empty():
		lowest = minf(lowest, float(boss.min_hp_share))
	return 1.0 - lowest


## The summary's table (summary.md): act x difficulty, each bot's outcome and lowest Health.
func headline(runs: Array) -> String:
	if runs.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append("Gauntlet (each act's last floor, %d rooms then the boss; outcome, floor cost / lowest Health; K kite, P player, F face-tank):" % (ROOMS if not quick else 2))
	lines.append("")
	var header := PackedStringArray(["Act"])
	var keys: Array = difficulties.map(func(d: DifficultyDef) -> String: return BalanceContent.key(d))
	header.append_array(PackedStringArray(keys))
	lines.append("| %s |" % " | ".join(header))
	lines.append("|%s" % "---|".repeat(header.size()))
	var act_ids: Array = []
	for r: Dictionary in runs:
		if not act_ids.has(r.act):
			act_ids.append(r.act)
	act_ids.sort()
	for act: int in act_ids:
		var row := PackedStringArray([str(act)])
		for d_key: String in keys:
			var cell := PackedStringArray()
			for r: Dictionary in runs:
				if r.act == act and r.difficulty == d_key:
					var tag: String = { "kite": "K", "player": "P", "face_tank": "F" }.get(r.bot, r.bot)
					var died: bool = r.outcome != "win" and r.outcome != "boss timeout"
					cell.append("%s %s %d%%/%d%%" % [tag, "W" if r.outcome == "win" else ("T" if r.outcome == "boss timeout" else ("L boss" if r.died_in == "boss" else "L " + String(r.died_in))),
						roundi(100.0 * float(r.get("floor_cost", 0.0))), 0 if died else roundi(100.0 * (1.0 - lost_share(r)))])
			row.append(" / ".join(cell) if not cell.is_empty() else "-")
		lines.append("| %s |" % " | ".join(row))
	return "\n".join(lines)
