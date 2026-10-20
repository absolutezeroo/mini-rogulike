extends Node
## What lasts between runs (autoload "Profile"): souls, shrine upgrades, records, the bestiary,
## achievements and the last runs.
## Saved as JSON in user://profile.json (works on phones too).

signal changed

const SAVE_PATH := "user://profile.json"

var souls := 0
## Upgrade id -> level bought.
var levels := {}
var runs := 0
var victories := 0
var best_depth := 0
## Difficulty picked on the title screen (DifficultyDef id).
var difficulty: StringName = &"normal"
## Victories per difficulty id (unlocks the next difficulty).
var wins := {}
## Nightmare ascension: the level picked for the next run, and the highest one open.
var ascension := 0
var ascension_unlocked := 0
## The story was told once (it plays before the first run).
var seen_intro := false
## Monster id -> how many were slain (the bestiary).
var kills_by_monster := {}
## Lifetime counters and bests (see AchievementDef.STAT_KEYS).
var stats := {}
## Achievement id -> when it was unlocked (Unix time).
var achievements := {}
## The last runs, newest first (see add_history()).
var history: Array = []
## Stats counted during each day and week ("d20380" / "w2911" -> stat -> value), and the
## quests already paid in them ("d20380" -> [quest ids]). Only the current ones are kept.
var period_stats := {}
var quests_claimed := {}
## The daily run (DailyRun): the day of the last official attempt (-1: never), its score, the
## best daily score ever, and the days in a row with an official attempt.
## The bestiary (Bestiary): monster ids met at least once, and the hunter rank paid per id.
var seen_monsters := {}
var bestiary_ranks := {}
## Bestiary challenges done: "monster_id/challenge_id" -> 1.
var challenges_done := {}
## Shiny monsters slain, by id (the bestiary's collection).
var shinies := {}
var daily_day := -1
var daily_score := 0
var daily_best := 0
var daily_streak := 0
## Tutorial hints already shown (HintDef id -> 1).
var hints_seen := {}
## Speedrun records (RunState.record_key() -> milliseconds): the fastest win, and that run's
## time at the end of each floor (its splits, to race against).
var best_times := {}
var best_splits := {}
## The oath sworn for the next runs (OathDef id; "" = none) and the weapon picked to start
## with (the Armory node; WeaponDef id, "" = the usual one).
var oath: StringName = &""
var starting_weapon: StringName = &""

const HISTORY_SIZE := 20
## Empty = nothing is read or written (tests).
var save_path := SAVE_PATH


func _ready() -> void:
	load_profile()


func level_of(upgrade: UpgradeDef) -> int:
	return levels.get(String(upgrade.id), 0)


func can_buy(upgrade: UpgradeDef) -> bool:
	var level := level_of(upgrade)
	return level < upgrade.max_level and souls >= upgrade.cost_for_level(level)


## A node of the Tree of Souls: open (parents, feat, fork) and affordable.
func can_buy_node(node: SoulNodeDef) -> bool:
	return node != null and node.upgrade != null and node.is_open() and souls >= node.next_cost()


func buy_node(node: SoulNodeDef) -> bool:
	return can_buy_node(node) and buy(node.upgrade)


## Gives back every soul spent on the tree (minus its reset price) and empties it.
func reset_tree(tree: SoulTreeDef) -> bool:
	var refund := tree.spent()
	if refund <= 0 or souls + refund < tree.reset_cost:
		return false
	for node in tree.nodes:
		if node and node.upgrade:
			levels.erase(String(node.upgrade.id))
	souls += refund - tree.reset_cost
	if not tree.open_oaths().any(func(o: OathDef) -> bool: return o.id == oath):
		oath = &""
	save_profile()
	changed.emit()
	return true


func buy(upgrade: UpgradeDef) -> bool:
	if not can_buy(upgrade):
		return false
	souls -= upgrade.cost_for_level(level_of(upgrade))
	levels[String(upgrade.id)] = level_of(upgrade) + 1
	save_profile()
	changed.emit()
	return true


## Souls for a run: monsters, depth reached, bosses, a big bonus for winning, times the difficulty.
static func souls_for_run(kills: int, depth: int, bosses: int, won: bool, multiplier: float = 1.0) -> int:
	return roundi((kills + (depth - 1) * 5 + bosses * 20 + (100 if won else 0)) * multiplier)


func is_unlocked(def: DifficultyDef) -> bool:
	return def.unlocked_by == null or wins.get(String(def.unlocked_by.id), 0) > 0


## A Nightmare win at ascension `level` opens the next level (up to `max_level`).
func win_ascension(level: int, max_level: int) -> void:
	ascension_unlocked = clampi(maxi(ascension_unlocked, level + 1), 0, max_level)
	raise_stat("ascension", level)
	save_profile()


func select_ascension(level: int) -> void:
	ascension = clampi(level, 0, ascension_unlocked)
	save_profile()
	changed.emit()


func select_difficulty(def: DifficultyDef) -> void:
	difficulty = def.id
	save_profile()
	changed.emit()


func record_run(earned: int, depth: int, won: bool, difficulty_id: StringName = &"") -> void:
	souls += earned
	best_depth = maxi(best_depth, depth)
	if won:
		add_stat("wins")
		victories += 1
		if difficulty_id != &"":
			wins[String(difficulty_id)] = wins.get(String(difficulty_id), 0) + 1
	save_profile()
	changed.emit()


# --- Records ------------------------------------------------------------------

func record_kill(monster_id: StringName) -> void:
	kills_by_monster[String(monster_id)] = kill_count(monster_id) + 1


func kill_count(monster_id: StringName) -> int:
	return int(kills_by_monster.get(String(monster_id), 0))


func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount
	for period in _current_periods():
		var counts: Dictionary = period_stats.get(period, {})
		counts[key] = int(counts.get(key, 0)) + amount
		period_stats[period] = counts


## Keeps the best value ever seen (deepest floor, most gold in a run...).
func raise_stat(key: String, value: int) -> void:
	stats[key] = maxi(int(stats.get(key, 0)), value)
	for period in _current_periods():
		var counts: Dictionary = period_stats.get(period, {})
		counts[key] = maxi(int(counts.get(key, 0)), value)
		period_stats[period] = counts


## A stat counted during the day or week `period` (QuestBoard.period_key).
func period_stat(period: String, key: String) -> int:
	return int((period_stats.get(period, {}) as Dictionary).get(key, 0))


func is_quest_claimed(period: String, quest_id: StringName) -> bool:
	return (quests_claimed.get(period, []) as Array).has(String(quest_id))


## Pays a finished quest once. False if it was already paid.
func claim_quest(period: String, quest_id: StringName, reward: int) -> bool:
	if is_quest_claimed(period, quest_id):
		return false
	var claimed: Array = quests_claimed.get(period, [])
	claimed.append(String(quest_id))
	quests_claimed[period] = claimed
	souls += reward
	save_profile()
	changed.emit()
	return true


## Today's and this week's keys; older ones are dropped.
func _current_periods() -> Array[String]:
	var current: Array[String] = [QuestBoard.period_key(QuestDef.Period.DAILY), QuestBoard.period_key(QuestDef.Period.WEEKLY)]
	for old in period_stats.keys():
		if not current.has(old):
			period_stats.erase(old)
	for old in quests_claimed.keys():
		if not current.has(old):
			quests_claimed.erase(old)
	return current


## A counter, a best, or a record kept elsewhere in the profile.
func stat_value(key: String) -> int:
	match key:
		"species":
			return kills_by_monster.size()
		"best_depth":
			return best_depth
		"victories":
			return victories
		"hard_wins":
			return int(wins.get("hard", 0)) + int(wins.get("nightmare", 0))
		"nightmare_wins":
			return int(wins.get("nightmare", 0))
	return int(stats.get(key, 0))


func is_achieved(id: StringName) -> bool:
	return achievements.has(String(id))


## Unlocks it and pays its souls. Returns false if it was already unlocked.
func unlock_achievement(def: AchievementDef) -> bool:
	if is_achieved(def.id):
		return false
	achievements[String(def.id)] = int(Time.get_unix_time_from_system())
	souls += def.reward_souls
	save_profile()
	changed.emit()
	return true


## A finished run, kept for the run history (only the last HISTORY_SIZE).
func add_history(entry: Dictionary) -> void:
	entry["time"] = int(Time.get_unix_time_from_system())
	history.push_front(entry)
	if history.size() > HISTORY_SIZE:
		history.resize(HISTORY_SIZE)
	save_profile()


func mark_intro_seen() -> void:
	seen_intro = true
	save_profile()


func has_seen_hint(id: StringName) -> bool:
	return hints_seen.has(String(id))


func mark_hint(id: StringName) -> void:
	if has_seen_hint(id):
		return
	hints_seen[String(id)] = 1
	save_profile()


## The fastest win under `key` (seconds), 0 if none.
func best_time(key: String) -> float:
	return int(best_times.get(key, 0)) / 1000.0 if not key.is_empty() else 0.0


## The record run's time at the end of floor `depth` (seconds), 0 if none.
func best_split(key: String, depth: int) -> float:
	var splits: Array = best_splits.get(key, [])
	return int(splits[depth - 1]) / 1000.0 if depth >= 1 and depth <= splits.size() else 0.0


## A won run's time: true (and kept, with its splits) if it is the fastest under `key`.
func record_time(key: String, seconds: float, splits: Array[float]) -> bool:
	if key.is_empty() or seconds <= 0.0:
		return false
	var ms := roundi(seconds * 1000.0)
	if best_times.has(key) and int(best_times[key]) <= ms:
		return false
	best_times[key] = ms
	best_splits[key] = splits.map(func(split: float) -> int: return roundi(split * 1000.0))
	save_profile()
	changed.emit()
	return true


## The tutorial starts over (Options).
func reset_hints() -> void:
	hints_seen = {}
	save_profile()
	changed.emit()


func has_seen(monster_id: StringName) -> bool:
	return seen_monsters.has(String(monster_id)) or kill_count(monster_id) > 0


## A monster noticed the hero (or the other way round): its bestiary page opens. Saved with
## the profile's next save.
func mark_seen(monster_id: StringName) -> void:
	seen_monsters[String(monster_id)] = 1


## The hunter rank already paid for this kind (0: none).
func bestiary_rank(monster_id: StringName) -> int:
	return int(bestiary_ranks.get(String(monster_id), 0))


func pay_bestiary_rank(monster_id: StringName, rank: int, reward: int) -> void:
	bestiary_ranks[String(monster_id)] = maxi(rank, bestiary_rank(monster_id))
	souls += reward
	changed.emit()


func has_shiny(monster_id: StringName) -> bool:
	return shinies.has(String(monster_id))


## A Shiny of this kind slain. True the first time.
func add_shiny(monster_id: StringName) -> bool:
	var first := not has_shiny(monster_id)
	shinies[String(monster_id)] = int(shinies.get(String(monster_id), 0)) + 1
	return first


static func challenge_key(monster_id: StringName, challenge_id: StringName) -> String:
	return "%s/%s" % [monster_id, challenge_id]


func is_challenge_done(monster_id: StringName, challenge_id: StringName) -> bool:
	return challenges_done.has(challenge_key(monster_id, challenge_id))


## Marks it done and pays it. False if it already was.
func complete_challenge(monster_id: StringName, challenge_id: StringName, reward: int) -> bool:
	var key := challenge_key(monster_id, challenge_id)
	if challenges_done.has(key):
		return false
	challenges_done[key] = 1
	souls += reward
	changed.emit()
	return true


## Today's official attempt was already taken (later ones are practice).
func daily_played(day: int) -> bool:
	return daily_day == day


## The official attempt of `day` begins (counted now: quitting doesn't give a second one).
func start_daily(day: int) -> void:
	if daily_day == day:
		return
	daily_streak = daily_streak + 1 if daily_day == day - 1 else 1
	daily_day = day
	daily_score = 0
	save_profile()


## The official attempt of `day` ended (or a won run died later on): its score counts.
func finish_daily(day: int, score: int) -> void:
	if daily_day != day:
		return
	daily_score = maxi(daily_score, score)
	daily_best = maxi(daily_best, score)
	save_profile()
	changed.emit()


func count_run() -> void:
	runs += 1
	add_stat("runs")
	save_profile()


func reset() -> void:
	souls = 0
	levels = {}
	runs = 0
	victories = 0
	best_depth = 0
	difficulty = &"normal"
	wins = {}
	seen_intro = false
	ascension = 0
	ascension_unlocked = 0
	kills_by_monster = {}
	stats = {}
	achievements = {}
	history = []
	period_stats = {}
	quests_claimed = {}
	seen_monsters = {}
	bestiary_ranks = {}
	challenges_done = {}
	shinies = {}
	daily_day = -1
	daily_score = 0
	daily_best = 0
	daily_streak = 0
	hints_seen = {}
	best_times = {}
	best_splits = {}
	oath = &""
	starting_weapon = &""
	changed.emit()


func save_profile() -> void:
	if save_path.is_empty():
		return
	SafeFile.write_json(save_path, {
		"souls": souls, "levels": levels, "runs": runs, "victories": victories, "best_depth": best_depth,
		"difficulty": String(difficulty), "wins": wins, "seen_intro": seen_intro,
		"ascension": ascension, "ascension_unlocked": ascension_unlocked,
		"kills_by_monster": kills_by_monster, "stats": stats, "achievements": achievements, "history": history,
		"period_stats": period_stats, "quests_claimed": quests_claimed,
		"seen_monsters": seen_monsters, "bestiary_ranks": bestiary_ranks, "challenges_done": challenges_done, "shinies": shinies,
		"daily_day": daily_day, "daily_score": daily_score, "daily_best": daily_best, "daily_streak": daily_streak,
		"hints_seen": hints_seen,
		"best_times": best_times, "best_splits": best_splits,
		"oath": String(oath), "starting_weapon": String(starting_weapon),
	})


func load_profile() -> void:
	if save_path.is_empty():
		return
	var data: Variant = SafeFile.read_json(save_path)
	if data == null:
		return
	if not data is Dictionary:
		push_warning("Profile file is damaged, starting fresh.")
		return
	souls = int(data.get("souls", 0))
	levels = _ints(data.get("levels", {}))
	runs = int(data.get("runs", 0))
	victories = int(data.get("victories", 0))
	best_depth = int(data.get("best_depth", 0))
	difficulty = StringName(data.get("difficulty", "normal"))
	wins = _ints(data.get("wins", {}))
	seen_intro = bool(data.get("seen_intro", false))
	ascension = int(data.get("ascension", 0))
	ascension_unlocked = int(data.get("ascension_unlocked", 0))
	kills_by_monster = _ints(data.get("kills_by_monster", {}))
	stats = _ints(data.get("stats", {}))
	achievements = _ints(data.get("achievements", {}))
	seen_monsters = _ints(data.get("seen_monsters", {}))
	bestiary_ranks = _ints(data.get("bestiary_ranks", {}))
	challenges_done = _ints(data.get("challenges_done", {}))
	shinies = _ints(data.get("shinies", {}))
	daily_day = int(data.get("daily_day", -1))
	daily_score = int(data.get("daily_score", 0))
	daily_best = int(data.get("daily_best", 0))
	daily_streak = int(data.get("daily_streak", 0))
	hints_seen = _ints(data.get("hints_seen", {}))
	best_times = _ints(data.get("best_times", {}))
	oath = StringName(data.get("oath", ""))
	starting_weapon = StringName(data.get("starting_weapon", ""))
	best_splits = {}
	var saved_splits: Variant = data.get("best_splits", {})
	if saved_splits is Dictionary:
		for key: String in saved_splits:
			if saved_splits[key] is Array:
				best_splits[key] = (saved_splits[key] as Array).map(func(ms: Variant) -> int: return int(ms))
	period_stats = {}
	var saved_periods: Variant = data.get("period_stats", {})
	if saved_periods is Dictionary:
		for period: String in saved_periods:
			period_stats[period] = _ints(saved_periods[period])
	quests_claimed = {}
	var saved_claims: Variant = data.get("quests_claimed", {})
	if saved_claims is Dictionary:
		for period: String in saved_claims:
			if saved_claims[period] is Array:
				quests_claimed[period] = (saved_claims[period] as Array).map(func(id: Variant) -> String: return str(id))
	var saved_history: Variant = data.get("history", [])
	history = saved_history.filter(func(entry: Variant) -> bool: return entry is Dictionary) if saved_history is Array else []


## JSON numbers come back as floats.
static func _ints(data: Variant) -> Dictionary:
	var result := {}
	if data is Dictionary:
		for key in data:
			result[key] = int(data[key])
	return result
